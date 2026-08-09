"""Sublime Text glue for GithubPullRequest — on-demand GitHub PR review.

Nothing here runs until ``GithubPullRequest: Load pull-request`` is invoked. The heavy
lifting (gh / git subprocess calls) lives in the pure-Python core; this module only:

* drives those calls off the UI thread (``set_timeout_async``) and mutates the
  view back on the main thread,
* draws the diff via ``set_reference_document`` (no git mutation),
* marks threads and queued drafts with gutter icons,
* renders threads as ``show_popup`` overlays and handles their action links,
* queues comments into a local draft and submits them as one review.
"""

import difflib
import os
import shlex
import subprocess
import webbrowser

import sublime
import sublime_plugin

try:
    from . import render
    from .gh import GH, GHError
    from .mapper import LineMap
    from .review import Review
    from .state import SESSION
except ImportError:
    import render
    from gh import GH, GHError
    from mapper import LineMap
    from review import Review
    from state import SESSION

SETTINGS_FILE = "GithubPullRequest.sublime-settings"

REGION_KEY = "githubpullrequest.threads"
DRAFT_REGION_KEY = "githubpullrequest.drafts"
STATUS_KEY = "githubpullrequest.status"

# Conventional Comments (https://conventionalcomments.org) labels, used by the
# add-comment picker. Overridable via the `comment_labels` setting. The optional
# `emoji` shows in the picker and is prefixed to the posted comment; drop it to get
# a plain `label: subject`.
_DEFAULT_COMMENT_LABELS = [
    {"emoji": "👏", "label": "praise", "description": "highlight something positive"},
    {
        "emoji": "💅",
        "label": "nitpick",
        "description": "trivial, non-blocking preference",
    },
    {"emoji": "💡", "label": "suggestion", "description": "propose a specific change"},
    {"emoji": "⚠️", "label": "issue", "description": "a problem that needs addressing"},
    {"emoji": "📌", "label": "todo", "description": "small, necessary change"},
    {"emoji": "❓", "label": "question", "description": "asking for clarification"},
    {"emoji": "💭", "label": "thought", "description": "a non-blocking idea"},
    {"emoji": "🧹", "label": "chore", "description": "process / housekeeping task"},
    {"emoji": "📝", "label": "note", "description": "an FYI, non-blocking"},
]


def _label_tag(entry):
    """'💡 suggestion' when the label has an emoji, else 'suggestion'."""
    emoji = entry.get("emoji", "")
    label = entry["label"]

    return f"{emoji} {label}" if emoji else label


# Prompt appended to the agent command in the tmux review pane. `{base}` is the base branch.
_DEFAULT_REVIEW_PROMPT = (
    "Do a thorough code review of the changes on the current branch compared to "
    "origin/{base}. Start by running `git diff origin/{base}...HEAD` to see the full "
    "diff. Review correctness first, then design and maintainability. Present each "
    "finding in Conventional Comments style (e.g. 'suggestion:', 'issue:', 'nitpick:')."
)


# --------------------------------------------------------------------------- #
# small helpers
# --------------------------------------------------------------------------- #
def _settings():
    return sublime.load_settings(SETTINGS_FILE)


def _async(fn):
    sublime.set_timeout_async(fn, 0)


def _main(fn):
    sublime.set_timeout(fn, 0)


def _status(message):
    sublime.status_message(f"GithubPullRequest: {message}")


def _error(message):
    sublime.error_message(f"GithubPullRequest: {message}")


def _git_root(path):
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=path,
            stderr=subprocess.STDOUT,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    return out.decode("utf-8").strip()


def _run_git(root, args):
    try:
        proc = subprocess.run(
            ["git"] + args, cwd=root, capture_output=True, text=True, timeout=5
        )
    except (OSError, subprocess.SubprocessError):
        return 1, ""

    return proc.returncode, proc.stdout


def _codeowners_map(root, paths):
    """path -> owners string via the `codeowners` binary, in one call. Empty on any
    failure (binary missing, non-zero exit). '(unowned)' collapses to ''."""
    if not paths:
        return {}

    try:
        proc = subprocess.run(
            ["codeowners", "--"] + paths,
            cwd=root,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return {}

    if proc.returncode != 0:
        return {}

    owners = {}
    for line in proc.stdout.splitlines():
        parts = line.split()
        if not parts:
            continue

        path = parts[0]
        names = parts[1:]
        if names == ["(unowned)"]:
            names = []

        owners[path] = " ".join(names)

    return owners


def _head_opcodes(root, rel, view):
    """difflib opcodes (committed HEAD as ``a``, live buffer as ``b``) for the file, or
    None when HEAD has no such path. The buffer is read live, so unsaved edits count."""
    rc, committed = _run_git(root, ["show", f"HEAD:{rel}"])
    if rc != 0:
        return None

    committed_lines = committed.splitlines()
    buffer_lines = view.substr(sublime.Region(0, view.size())).splitlines()

    matcher = difflib.SequenceMatcher(
        None, committed_lines, buffer_lines, autojunk=False
    )

    return matcher.get_opcodes()


def _head_anchor(view, start_row, end_row):
    """Translate a 0-based buffer-row selection to the 0-based head-commit rows GitHub
    anchors comments to, plus whether the selection carries the reviewer's own local
    (uncommitted) edits.

    The buffer holds the PR head file, but local edits that insert/remove lines shift
    buffer rows away from the head-commit line numbers. Walking the diff (via the cached
    opcodes shared with `_remap_head_row`) maps them back: an ``equal`` run maps
    row-for-row; a ``replace`` run maps to its whole committed block. Returns the buffer
    rows unchanged when HEAD is unavailable, or ``(None, None, has_edit)`` when the
    selection maps to no head line at all (e.g. a purely local insertion, which GitHub
    cannot anchor a comment to)."""
    opcodes = _view_head_opcodes(view)
    if opcodes is None:
        return start_row, end_row, False

    head_rows = []
    has_edit = False

    for tag, i1, i2, j1, j2 in opcodes:
        lo = max(j1, start_row)
        hi = min(j2, end_row + 1)
        overlaps = lo < hi

        if overlaps and tag in ("replace", "insert"):
            has_edit = True

        if not overlaps or tag == "insert":
            continue

        if tag == "equal":
            head_rows.append(i1 + (lo - j1))
            head_rows.append(i1 + (hi - 1 - j1))
        else:  # replace: the whole committed block maps to this local block
            head_rows.append(i1)
            head_rows.append(i2 - 1)

    if not head_rows:
        return None, None, has_edit

    return min(head_rows), max(head_rows), has_edit


# Cache of difflib opcodes (committed HEAD vs live buffer) per view, keyed by the
# view's change_count so a `git show HEAD` is paid only when the buffer changed.
_OPCODE_CACHE = {}


def _view_head_opcodes(view):
    path = _rel_path(view)
    if path is None or not SESSION.root:
        return None

    change = view.change_count()
    cached = _OPCODE_CACHE.get(view.id())
    if cached and cached[0] == change:
        return cached[1]

    opcodes = _head_opcodes(SESSION.root, path, view)
    _OPCODE_CACHE[view.id()] = (change, opcodes)

    return opcodes


def _head_row_to_buffer_row(opcodes, head_row):
    """Where a 0-based head-commit row currently sits in the buffer, following the
    reviewer's local edits. A changed/removed head line anchors to its block start."""
    for tag, i1, i2, j1, j2 in opcodes:
        if i1 <= head_row < i2:
            if tag == "equal":
                return j1 + (head_row - i1)

            return j1

    return None


def _remap_head_row(view, head_row):
    """Head-commit row -> current buffer row (identity when the buffer matches HEAD or
    HEAD is unavailable). Keeps gutter icons, popups and navigation on the right line
    even after local edits shift the buffer away from the PR head."""
    if head_row is None:
        return None

    opcodes = _view_head_opcodes(view)
    if not opcodes:
        return head_row

    mapped = _head_row_to_buffer_row(opcodes, head_row)

    return head_row if mapped is None else mapped


def _detect_base_branch(root):
    """Repo default branch via origin/HEAD (e.g. 'main'); falls back to 'main'."""
    rc, out = _run_git(root, ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"])
    if rc == 0 and out.strip():
        ref = out.strip()  # e.g. "origin/main"

        return ref.split("/", 1)[1] if "/" in ref else ref

    return "main"


def _attached_tmux_session():
    """Name of an attached tmux session (any session if none attached), or None."""
    try:
        proc = subprocess.run(
            ["tmux", "list-sessions", "-F", "#{session_name}\t#{session_attached}"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    if proc.returncode != 0:
        return None

    first = None
    for line in proc.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) != 2:
            continue

        name, attached = parts
        if first is None:
            first = name
        if attached != "0":
            return name

    return first


def _launch_agent_review(root):
    if SESSION.active and SESSION.pr and SESSION.pr.get("base"):
        base = SESSION.pr["base"]
    else:
        base = _detect_base_branch(root)

    session = _attached_tmux_session()
    if session is None:
        _main(lambda: _error("no tmux session found — start/attach tmux first"))
        return

    agent = _settings().get("agent_command") or ["claude"]
    template = _settings().get("agent_review_prompt", _DEFAULT_REVIEW_PROMPT)
    prompt = template.format(base=base)

    # Build "<agent...> <prompt>" as one shell-quoted command string so tmux runs it
    # via the shell with the prompt as a single last argument (multiline / special
    # characters are safe). The agent + args are user-configurable.
    inner = " ".join(shlex.quote(part) for part in (list(agent) + [prompt]))
    args = ["tmux", "split-window", "-h", "-t", session, "-c", root, inner]

    try:
        proc = subprocess.run(args, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as err:
        _main(lambda message=str(err): _error(message))
        return

    if proc.returncode != 0:
        failure = proc.stderr.strip() or "tmux failed"
        _main(lambda message=failure: _error(message))
        return

    _main(
        lambda: _status(f"review agent launched in tmux ({session}) vs origin/{base}")
    )


def _window_cwd(window):
    view = window.active_view()
    if view and view.file_name():
        return os.path.dirname(view.file_name())

    folders = window.folders()

    return folders[0] if folders else None


def _rel_path(view):
    file_name = view.file_name()
    if not file_name or not SESSION.root:
        return None

    rel = os.path.relpath(file_name, SESSION.root)
    if rel.startswith(".."):
        return None

    return rel.replace(os.sep, "/")


def _abs_path(rel):
    return os.path.join(SESSION.root, rel.replace("/", os.sep))


def _thread_line(thread):
    """Head-side line a thread is anchored to: its current line, else its original."""
    return thread.get("line") or thread.get("original_line")


def _first_hunk_line(path):
    """Head-side start line of the file's first hunk (else line 1)."""
    entry = SESSION.files_by_path.get(path)
    if entry:
        hunks = entry["file_diff"].hunks
        if hunks:
            return hunks[0].new_start

    return 1


def _first_comment_line(path):
    """Line of the first comment on the file: the earliest unresolved thread or
    pending draft, else the earliest thread, else the first hunk."""
    lines = [
        _thread_line(thread)
        for thread in SESSION.threads_by_path.get(path, [])
        if not thread.get("is_resolved")
    ]
    lines += [draft.get("line") for _, draft in _drafts_for_path(path)]
    lines = [line for line in lines if line]
    if lines:
        return min(lines)

    fallback = [
        _thread_line(thread) for thread in SESSION.threads_by_path.get(path, [])
    ]
    fallback = [line for line in fallback if line]
    if fallback:
        return min(fallback)

    return _first_hunk_line(path)


def _thread_row(view, thread):
    """0-based buffer row a thread anchors to, or None."""
    line_map = SESSION.line_maps.get(thread["path"])
    if line_map is None:
        return None

    side = thread.get("side") or "RIGHT"
    line = _thread_line(thread)
    if line is None:
        return None

    return _remap_head_row(view, line_map.anchor_to_row(side, line))


# --------------------------------------------------------------------------- #
# decoration (diff reference doc, thread + draft gutter icons)
# --------------------------------------------------------------------------- #
def _decorate_view(view):
    if not SESSION.active:
        return

    path = _rel_path(view)
    if path is None or path not in SESSION.files_by_path:
        return

    _apply_reference_document(view, path)
    _apply_thread_icons(view, path)
    _apply_draft_icons(view, path)


def _apply_reference_document(view, path):
    entry = SESSION.files_by_path.get(path)
    if entry and entry.get("is_binary"):
        return

    if path in SESSION.base_blob_cache:
        base = SESSION.base_blob_cache[path]
        if base is not None:
            view.set_reference_document(base)
        return

    is_new = bool(entry and entry["file_diff"].is_new)

    def worker():
        base = None
        try:
            base = SESSION.review.base_blob(path)
        except (GHError, OSError, subprocess.SubprocessError):
            base = None

        # A file added in the PR has no content at the merge-base, so its base is
        # the empty string: every line is an addition and the whole gutter is green.
        if base is None and is_new:
            base = ""

        def apply():
            SESSION.base_blob_cache[path] = base
            if base is not None and view.is_valid():
                view.set_reference_document(base)

        _main(apply)

    _async(worker)


def _apply_thread_icons(view, path):
    if not _settings().get("show_gutter_icon", True):
        return

    icon = _settings().get("gutter_icon", "bookmark")

    regions = []
    for thread in SESSION.threads_by_path.get(path, []):
        if thread.get("is_resolved"):
            continue

        row = _thread_row(view, thread)
        if row is None:
            continue

        point = view.text_point(row, 0)
        regions.append(sublime.Region(point, point))

    view.erase_regions(REGION_KEY)
    if regions:
        view.add_regions(
            REGION_KEY,
            regions,
            "region.bluish",
            icon,
            sublime.HIDDEN | sublime.PERSISTENT,
        )


def _apply_draft_icons(view, path):
    """Gutter icons for locally-queued draft comments, in a distinct (purple)
    color so pending comments read differently from posted threads."""
    if not _settings().get("show_gutter_icon", True):
        return

    icon = _settings().get("gutter_icon", "bookmark")

    regions = []
    for _, draft in _drafts_for_path(path):
        line = draft.get("line")
        if not line:
            continue

        row = _remap_head_row(view, line - 1)
        if row is None:
            continue

        point = view.text_point(row, 0)
        regions.append(sublime.Region(point, point))

    view.erase_regions(DRAFT_REGION_KEY)
    if regions:
        view.add_regions(
            DRAFT_REGION_KEY,
            regions,
            "region.purplish",
            icon,
            sublime.HIDDEN | sublime.PERSISTENT,
        )


def _drafts_for_path(path):
    """(uid, draft) pairs for a path's RIGHT-side queued comments; the uid (stable,
    not positional) drives per-draft Edit/Discard actions."""
    if not SESSION.review:
        return []

    return [
        (draft["uid"], draft)
        for draft in SESSION.review.drafts()
        if draft.get("path") == path and draft.get("side") == "RIGHT"
    ]


# --------------------------------------------------------------------------- #
# comment compose split (write a comment below the file; save to submit)
# --------------------------------------------------------------------------- #
def _split_below_layout(layout, fraction=0.7):
    """Add a full-width group below the current layout (existing groups shrink into
    the top `fraction`). Works for any starting layout."""
    rows = layout["rows"]
    cols = layout["cols"]

    new_rows = [row * fraction for row in rows] + [1.0]
    bottom = [0, len(rows) - 1, len(cols) - 1, len(new_rows) - 1]

    return {
        "cols": list(cols),
        "rows": new_rows,
        "cells": [list(cell) for cell in layout["cells"]] + [bottom],
    }


def _open_compose(source_view, prefill, context):
    """Open a scratch compose buffer in a split below the file. Save submits it
    (see the keymap / GithubPullRequestSubmitCommentCommand); closing cancels.
    `context` = {"mode": "new", path, payload}, {"mode": "edit", uid}, or
    {"mode": "reply", thread_id}."""
    window = source_view.window()

    # One compose at a time: opening a second while one is live would capture the
    # already-split layout as its "original" and break the restore. Focus the open one.
    for existing in window.views():
        if existing.settings().get("github_pull_request_compose"):
            window.focus_view(existing)
            _status("finish the open comment first")
            return

    layout = window.layout()
    window.set_layout(_split_below_layout(layout))
    window.focus_group(window.num_groups() - 1)

    verb = {"edit": "Edit PR comment", "reply": "Reply"}.get(
        context.get("mode"), "PR comment"
    )

    compose = window.new_file()
    compose.set_scratch(True)
    compose.set_name(f"{verb} (save to submit, close to cancel)")
    compose.assign_syntax("Packages/Markdown/Markdown.sublime-syntax")

    settings = compose.settings()
    # Keep the prefilled suggestion byte-for-byte: a ```suggestion``` must match the
    # head line's leading whitespace exactly, so tabs must not be expanded to spaces.
    settings.set("translate_tabs_to_spaces", False)
    settings.set("detect_indentation", False)
    settings.set("github_pull_request_compose", True)
    settings.set("github_pull_request_context", context)
    settings.set("github_pull_request_source_id", source_view.id())
    settings.set("github_pull_request_orig_layout", layout)

    compose.run_command("append", {"characters": prefill})
    compose.sel().clear()
    compose.sel().add(sublime.Region(compose.size()))
    window.focus_view(compose)


def _restore_after_compose(window, orig_layout, source_id):
    """Remove the compose group (restore the saved layout) and refocus the file."""
    if window is None:
        return

    if orig_layout:
        window.set_layout(orig_layout)

    for view in window.views():
        if view.id() == source_id:
            window.focus_view(view)
            break


def _clear_view(view):
    view.erase_regions(REGION_KEY)
    view.erase_regions(DRAFT_REGION_KEY)
    view.erase_status(STATUS_KEY)

    # Only PR-file views had their reference document overridden. Reloading the
    # file makes Sublime re-derive its own git diff (reset_reference_document alone
    # does not make it resume). We never change the buffer, so on a clean view the
    # revert reloads identical text; skip dirty views to avoid discarding edits.
    if _rel_path(view) not in SESSION.files_by_path:
        return

    if view.is_dirty():
        view.reset_reference_document()
    else:
        view.run_command("revert")


def _decorate_all_views():
    for window in sublime.windows():
        for view in window.views():
            _decorate_view(view)

    _update_status()


def _update_status():
    if not SESSION.active or not SESSION.pr:
        return

    window = sublime.active_window()
    view = window.active_view() if window else None
    if view is None:
        return

    pr = SESSION.pr
    unresolved = sum(SESSION.unresolved_count(path) for path in SESSION.threads_by_path)
    badge = render.draft_badge(len(SESSION.review.drafts()))

    status = "PR #{} · {} files · {} unresolved".format(
        pr["number"], len(SESSION.files), unresolved
    )
    if badge:
        status += " · " + badge

    view.set_status(STATUS_KEY, status)


# --------------------------------------------------------------------------- #
# thread popups + action links
# --------------------------------------------------------------------------- #
def _threads_at_row(view, row):
    path = _rel_path(view)
    if path is None:
        return []

    found = []
    for thread in SESSION.threads_by_path.get(path, []):
        if _thread_row(view, thread) == row:
            found.append(thread)

    return found


def _drafts_at_row(view, row):
    path = _rel_path(view)
    if path is None:
        return []

    return [
        (uid, draft)
        for uid, draft in _drafts_for_path(path)
        if draft.get("line") and _remap_head_row(view, draft["line"] - 1) == row
    ]


def _show_threads_popup(view, row, point):
    threads = _threads_at_row(view, row)
    drafts = _drafts_at_row(view, row)
    if not threads and not drafts:
        return

    parts = [render.thread_popup_html(thread) for thread in threads]
    if drafts:
        parts.append(render.pending_html(drafts))

    view.show_popup(
        "".join(parts),
        sublime.HIDE_ON_MOUSE_MOVE_AWAY,
        point,
        800,
        600,
        lambda href: _handle_action(view, href),
    )


def _open_external(url):
    """Hand a link to the browser, but only http(s). Popup bodies are rendered from
    comment HTML written by anyone who can comment on the PR, so an unfiltered href
    would let a comment hand an arbitrary scheme (file:, javascript:, ...) to the OS."""
    if not url.startswith(("http://", "https://")):
        _status("refused to open a non-http link")
        return

    webbrowser.open(url)


def _handle_action(view, href):
    action = render.decode_action(href)
    if action is None:
        _open_external(href)
        return

    kind = action.get("action")

    if kind == "open":
        _open_external(action.get("url", ""))
    elif kind == "reply":
        _open_compose(view, "", {"mode": "reply", "thread_id": action["id"]})
    elif kind in ("resolve", "unresolve"):
        _set_resolved(action["id"], kind == "resolve")
    elif kind == "discard":
        _discard_draft(int(action["uid"]))
    elif kind == "edit":
        _edit_draft(view, int(action["uid"]))
    elif kind == "apply_suggestion":
        _apply_suggestion(view, action["id"], int(action.get("sug", 0)))


def _edit_draft(view, uid):
    drafts = SESSION.review.drafts() if SESSION.review else []
    draft = next((d for d in drafts if d.get("uid") == uid), None)
    if draft is None:
        return

    _open_compose(view, draft.get("body", ""), {"mode": "edit", "uid": uid})


def _discard_draft(uid):
    def worker():
        try:
            SESSION.review.discard_draft(uid)
        except GHError as err:
            _main(lambda message=str(err): _error(message))
            return

        def apply():
            _decorate_all_views()
            _refresh_files_panel(sublime.active_window())
            _status("draft discarded")

        _main(apply)

    _async(worker)


def _set_resolved(thread_id, resolved):
    def worker():
        try:
            SESSION.review.set_thread_resolved(thread_id, resolved)
        except GHError as err:
            _main(lambda message=str(err): _error(message))
            return

        _reload_threads()

    _async(worker)


def _find_thread(thread_id):
    for threads in SESSION.threads_by_path.values():
        for candidate in threads:
            if candidate["id"] == thread_id:
                return candidate

    return None


def _apply_suggestion(view, thread_id, index):
    thread = _find_thread(thread_id)
    if thread is None:
        return

    suggestions = []
    for comment in thread["comments"]:
        suggestions.extend(render.suggestions_in(comment["body"]))

    if index >= len(suggestions):
        return

    line = _thread_line(thread)
    if line is None:
        # An outdated thread can lose both its current and original line, so there is
        # no head row to write the suggestion over.
        _status("cannot locate the suggestion's lines in this buffer")
        return

    start_line = thread.get("start_line") or line

    start_row = _remap_head_row(view, start_line - 1)
    end_row = _remap_head_row(view, line - 1)
    if start_row is None or end_row is None:
        _status("cannot locate the suggestion's lines in this buffer")
        return

    view.run_command(
        "github_pull_request_replace_lines",
        {
            "start_row": start_row,
            "end_row": end_row,
            "text": suggestions[index].rstrip("\n"),
        },
    )
    _status("suggestion applied")


# --------------------------------------------------------------------------- #
# load / reload
# --------------------------------------------------------------------------- #
def _build_session(root, pr, review, files, threads, owners):
    SESSION.reset()
    SESSION.active = True
    SESSION.root = root
    SESSION.pr = pr
    SESSION.review = review
    SESSION.files = files
    SESSION.files_by_path = {entry["path"]: entry for entry in files}
    SESSION.line_maps = {entry["path"]: LineMap(entry["file_diff"]) for entry in files}
    SESSION.owners_by_path = owners
    _index_threads(threads)


def _index_threads(threads):
    # Outdated threads (their diff hunk no longer matches the code) are usually
    # mis-anchored noise; drop them here so gutter icons, panel counts, navigation
    # and the comment list all exclude them consistently. Toggle with hide_outdated.
    hide_outdated = _settings().get("hide_outdated", True)

    by_path = {}
    for thread in threads:
        if hide_outdated and thread.get("is_outdated"):
            continue

        by_path.setdefault(thread["path"], []).append(thread)

    SESSION.threads_by_path = by_path


def _reload_threads():
    try:
        threads = SESSION.review.review_threads()
    except GHError as err:
        _main(lambda message=str(err): _error(message))
        return

    def apply():
        _index_threads(threads)
        _decorate_all_views()
        _refresh_files_panel(sublime.active_window())

    _main(apply)


def _load(window):
    cwd = _window_cwd(window)
    if cwd is None:
        _main(lambda: _error("open a folder from the repository first"))
        return

    root = _git_root(cwd)
    if root is None:
        _main(lambda: _error("not inside a git repository"))
        return

    gh = GH(cwd=root)
    review = Review(gh, root)

    try:
        pr = review.resolve_pr()

        if pr.get("state") != "OPEN":
            state = (pr.get("state") or "unknown").lower()
            _main(
                lambda n=pr["number"], s=state: _error(
                    f"PR #{n} is {s} — only open PRs can be loaded."
                )
            )
            return

        files = review.changed_files()
        threads = review.review_threads()
        review.load_pending()
    except GHError as err:
        _main(lambda message=str(err): _error(message))
        return

    owners = _codeowners_map(root, [entry["path"] for entry in files])

    def apply():
        _build_session(root, pr, review, files, threads, owners)
        _decorate_all_views()
        _status("loaded PR #{} ({} files)".format(pr["number"], len(files)))
        window.run_command("github_pull_request_files_panel")

    _main(apply)


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #
class GithubPullRequestLoadCommand(sublime_plugin.WindowCommand):
    def run(self):
        _status("loading pull request…")
        _async(lambda: _load(self.window))


class GithubPullRequestReviewInTmuxCommand(sublime_plugin.WindowCommand):
    """Open a tmux pane running the configured review agent (default `claude`) with a
    review prompt for this branch vs its base. Does not require a loaded PR."""

    def run(self):
        cwd = _window_cwd(self.window)
        root = (
            SESSION.root
            if SESSION.active and SESSION.root
            else (_git_root(cwd) if cwd else None)
        )
        if root is None:
            _error("not inside a git repository")
            return

        _status("launching review agent…")
        _async(lambda: _launch_agent_review(root))


FILES_PANEL = "githubpullrequest_files"


def _files_panel_text():
    entries = SESSION.file_entries_for_panel()
    if not entries:
        return None

    # Two lines per file so each gets its own result_file_regex click target: the
    # file row jumps to the first hunk; the indented comment sub-line (only when the
    # file has comments) jumps to the first comment. `path:line` trails both, padded
    # to a fixed column so they align. The syntax file colors +N / -M / (K…) / (P…).
    path_col = 34
    lines = []
    total_pending = 0
    for entry in entries:
        path = entry["path"]
        unresolved = entry.get("unresolved", 0)
        pending = entry.get("pending", 0)
        total_pending += pending

        stats = "+{} -{}".format(entry.get("additions", 0), entry.get("deletions", 0))
        owners = entry.get("owners", "")
        file_row = f"{stats.ljust(path_col)}{path}:{_first_hunk_line(path)}"
        if owners:
            # Owners trail the "path:line" nav token so column alignment is kept and
            # result_file_regex still finds the target (it is no longer $-anchored).
            file_row += "  " + owners
        lines.append(file_row)

        notes = " ".join(
            note
            for note in (
                f"({unresolved} unresolved)" if unresolved else "",
                f"({pending} pending)" if pending else "",
            )
            if note
        )
        if notes:
            lines.append(
                "{}{}:{}".format(
                    ("    " + notes).ljust(path_col), path, _first_comment_line(path)
                )
            )

    pr = SESSION.pr
    header = "PR #{} · {} · {} files".format(pr["number"], pr["title"], len(entries))
    if total_pending:
        header += f" · {total_pending} pending"

    return header + "\n" + "\n".join(lines) + "\n"


def _show_files_panel(window):
    text = _files_panel_text()
    if text is None:
        _status("no changed files")
        return

    window.destroy_output_panel(FILES_PANEL)
    panel = window.create_output_panel(FILES_PANEL)
    settings = panel.settings()
    settings.set("result_file_regex", r"([^ \t]+):(\d+)")
    settings.set("result_base_dir", SESSION.root)
    settings.set("line_numbers", False)
    settings.set("gutter", False)
    settings.set("scroll_past_end", False)
    panel.assign_syntax(
        "Packages/GithubPullRequest/GithubPullRequestFiles.sublime-syntax"
    )
    panel.set_read_only(False)
    panel.run_command("append", {"characters": text})
    panel.set_read_only(True)

    window.run_command("show_panel", {"panel": f"output.{FILES_PANEL}"})


def _refresh_files_panel(window):
    """Rebuild the panel in place when it is already visible (e.g. after a draft
    is queued or discarded) so its counts stay current, without stealing focus."""
    if window and window.active_panel() == f"output.{FILES_PANEL}":
        _show_files_panel(window)


class GithubPullRequestFilesPanelCommand(sublime_plugin.WindowCommand):
    """Persistent bottom panel listing changed files. Double-click / Enter (or
    F4) on a row opens the file at its line via result_file_regex navigation."""

    def is_enabled(self):
        return SESSION.active

    def run(self):
        _show_files_panel(self.window)


class GithubPullRequestListCommentsCommand(sublime_plugin.WindowCommand):
    def is_enabled(self):
        return SESSION.active

    def run(self):
        threads = []
        for path in sorted(SESSION.threads_by_path):
            threads.extend(SESSION.threads_by_path[path])

        if not threads:
            _status("no review comments")
            return

        items = []
        for thread in threads:
            first = thread["comments"][0] if thread["comments"] else {}
            snippet = (first.get("body", "") or "").splitlines()
            tags = []
            if thread.get("is_resolved"):
                tags.append("resolved")
            if thread.get("is_outdated"):
                tags.append("outdated")

            trigger = "{}:{}".format(thread["path"], _thread_line(thread) or 1)
            detail = "{} · {} comment(s){} — {}".format(
                first.get("author", "?"),
                len(thread["comments"]),
                " [{}]".format(", ".join(tags)) if tags else "",
                snippet[0] if snippet else "",
            )
            items.append(sublime.QuickPanelItem(trigger, details=detail))

        def on_done(index):
            if index < 0:
                return

            thread = threads[index]
            view = self.window.open_file(
                "{}:{}".format(
                    _abs_path(thread["path"]),
                    _thread_line(thread) or 1,
                ),
                sublime.ENCODED_POSITION,
            )
            _async(lambda: _show_when_ready(view, thread))

        self.window.show_quick_panel(items, on_done)


def _show_when_ready(view, thread, attempts=20):
    if view.is_loading() and attempts > 0:
        sublime.set_timeout(lambda: _show_when_ready(view, thread, attempts - 1), 50)
        return

    row = _thread_row(view, thread)
    if row is None:
        return

    point = view.text_point(row, 0)
    _show_threads_popup(view, row, point)


class GithubPullRequestAddCommentCommand(sublime_plugin.TextCommand):
    def is_enabled(self):
        return SESSION.active and _rel_path(self.view) in SESSION.files_by_path

    def run(self, edit):
        path = _rel_path(self.view)
        line_map = SESSION.line_maps.get(path)
        if line_map is None:
            _status("file is not part of the PR")
            return

        region = self.view.sel()[0]
        start_row = self.view.rowcol(region.begin())[0]
        end_row = self.view.rowcol(region.end())[0]
        if region.end() > region.begin() and self.view.rowcol(region.end())[1] == 0:
            end_row -= 1

        view = self.view

        # The buffer may carry the reviewer's own local edits, which shift buffer rows
        # away from the PR head-commit line numbers GitHub anchors comments to. Map the
        # selection back onto head rows so the comment (and any ```suggestion``` it
        # carries) targets the right lines and can be applied as-is. has_diff tells us
        # whether the selection is locally edited (so a suggestion is worth prefilling).
        head_start, head_end, has_diff = _head_anchor(view, start_row, end_row)

        payload = None
        if head_start is not None:
            payload = line_map.comment_range(head_start, head_end)
        if payload is None:
            _status("no commentable line in the selection")
            return

        # Suggestion content is the reviewer's LOCAL version of the selected lines
        # (from the buffer), which GitHub applies over the head lines above.
        content = "\n".join(
            view.substr(view.line(view.text_point(row, 0)))
            for row in range(start_row, end_row + 1)
        )
        suggestion_block = f"```suggestion\n{content}\n```"

        def compose(tag):
            # Full comment body prefill. On a locally-changed line the suggestion block
            # goes on its own line (so the ``` fence stays valid after the label).
            if has_diff:
                head = f"{tag}: \n\n" if tag else ""

                return head + suggestion_block

            return f"{tag}: " if tag else ""

        # Conventional Comments: pick a label (fuzzy) then compose. The picker is
        # skippable via its first entry and can be disabled in settings.
        labels = []
        if _settings().get("conventional_comments", True):
            labels = _settings().get("comment_labels", _DEFAULT_COMMENT_LABELS)

        new_context = {"mode": "new", "path": path, "payload": payload}

        if not labels:
            _open_compose(view, compose(""), new_context)
            return

        items = [sublime.QuickPanelItem("(plain comment)", details="no label")]
        items += [
            sublime.QuickPanelItem(_label_tag(e), details=e.get("description", ""))
            for e in labels
        ]

        def on_label(index):
            if index < 0:
                return

            tag = "" if index == 0 else _label_tag(labels[index - 1])
            _main(lambda: _open_compose(view, compose(tag), new_context))

        view.window().show_quick_panel(items, on_label)


class GithubPullRequestSubmitCommentCommand(sublime_plugin.TextCommand):
    """Submit the compose buffer's body — queue a new comment or update an edited
    one, per its context (bound to save). Closing without saving cancels."""

    def run(self, edit):
        settings = self.view.settings()
        context = settings.get("github_pull_request_context")
        if not context:
            return

        body = self.view.substr(sublime.Region(0, self.view.size()))
        if not body.strip() or not SESSION.active or not SESSION.review:
            self.view.close()  # nothing to submit -> treat as cancel
            return

        window = self.view.window()
        mode = context.get("mode")

        def worker():
            local = False
            try:
                if mode == "edit":
                    SESSION.review.edit_draft(context["uid"], body)
                elif mode == "reply":
                    SESSION.review.reply_comment(context["thread_id"], body)
                else:
                    SESSION.review.queue_comment(
                        context["path"], context["payload"], body
                    )
            except GHError as err:
                message = str(err)
                if mode != "new":
                    _main(lambda m=message: _error(m))
                    return

                # New comment failed to reach GitHub but is kept locally by
                # queue_comment; notify and still refresh so its draft icon shows.
                local = True
                _main(
                    lambda m=message: _error(
                        "couldn't reach GitHub — comment saved locally and will be "
                        "sent when you submit the review.\n\n" + m
                    )
                )

            if mode == "reply":
                _reload_threads()  # posted reply -> refresh the thread display
                _main(lambda: _status("reply posted"))
                return

            def apply():
                _decorate_all_views()
                _refresh_files_panel(window)
                if mode == "edit":
                    _status("comment updated")
                elif not local:
                    _status("comment queued (submit the review to post)")
                _update_status()

            _main(apply)

        _async(worker)
        self.view.close()  # triggers on_pre_close -> layout is restored


class GithubPullRequestNextCommentCommand(sublime_plugin.TextCommand):
    forward = True

    def is_enabled(self):
        return SESSION.active and _rel_path(self.view) in SESSION.files_by_path

    def run(self, edit):
        path = _rel_path(self.view)
        rows = sorted(
            {
                row
                for thread in SESSION.threads_by_path.get(path, [])
                if not thread.get("is_resolved")
                for row in [_thread_row(self.view, thread)]
                if row is not None
            }
        )
        if not rows:
            _status("no comments in this file")
            return

        current = self.view.rowcol(self.view.sel()[0].begin())[0]
        target = None
        if self.forward:
            target = next((row for row in rows if row > current), rows[0])
        else:
            target = next((row for row in reversed(rows) if row < current), rows[-1])

        point = self.view.text_point(target, 0)
        self.view.sel().clear()
        self.view.sel().add(sublime.Region(point, point))
        self.view.show_at_center(point)
        _show_threads_popup(self.view, target, point)


class GithubPullRequestPrevCommentCommand(GithubPullRequestNextCommentCommand):
    forward = False


class GithubPullRequestReplaceLinesCommand(sublime_plugin.TextCommand):
    """Internal: replace a row range with text (used to apply a suggestion)."""

    def run(self, edit, start_row, end_row, text):
        start = self.view.text_point(start_row, 0)
        end = self.view.line(self.view.text_point(end_row, 0)).end()
        self.view.replace(edit, sublime.Region(start, end), text)


class GithubPullRequestSubmitReviewCommand(sublime_plugin.WindowCommand):
    def is_enabled(self):
        return SESSION.active

    def run(self):
        verdicts = [
            ("Comment", "COMMENT"),
            ("Approve", "APPROVE"),
            ("Request changes", "REQUEST_CHANGES"),
        ]
        drafts = len(SESSION.review.drafts())
        items = [
            sublime.QuickPanelItem(label, details=f"{drafts} queued comment(s)")
            for label, _ in verdicts
        ]

        def on_verdict(index):
            if index < 0:
                return

            verdict = verdicts[index][1]
            self.window.show_input_panel(
                "Review summary (optional):",
                "",
                lambda body: self._submit(verdict, body),
                None,
                None,
            )

        self.window.show_quick_panel(items, on_verdict)

    def _submit(self, verdict, body):
        def worker():
            try:
                SESSION.review.submit_review(verdict, body)
            except GHError as err:
                _main(lambda message=str(err): _error(message))
                return

            # Submitting is the end of the review: tear everything down.
            _main(lambda: _end_review(f"review submitted ({verdict}) — ended"))

        _async(worker)


class GithubPullRequestDiscardDraftsCommand(sublime_plugin.WindowCommand):
    def is_enabled(self):
        return SESSION.active and bool(SESSION.review.drafts())

    def run(self):
        window = self.window

        def worker():
            try:
                SESSION.review.clear_drafts()
            except GHError as err:
                _main(lambda message=str(err): _error(message))
                return

            def apply():
                _decorate_all_views()
                _refresh_files_panel(window)
                _status("drafts discarded")
                _update_status()

            _main(apply)

        _status("discarding drafts…")
        _async(worker)


def _end_review(message="review ended"):
    """Clear all decorations, the panel, and session state. Main-thread only."""
    for window in sublime.windows():
        for view in window.views():
            _clear_view(view)
        window.destroy_output_panel(FILES_PANEL)

    SESSION.reset()
    _OPCODE_CACHE.clear()
    _status(message)


def _end_after(action, done_message):
    """Run a review mutation off the UI thread, then end the review on success."""

    def worker():
        try:
            action()
        except GHError as err:
            _main(lambda message=str(err): _error(message))
            return

        _main(lambda: _end_review(done_message))

    _async(worker)


class GithubPullRequestEndReviewCommand(sublime_plugin.WindowCommand):
    def is_enabled(self):
        return SESSION.active

    def run(self):
        review = SESSION.review
        drafts = review.drafts() if review else []
        if not drafts:
            _end_review()
            return

        local = review.local_count()
        if local:
            # Some comments never reached GitHub; ending would lose them unless sent.
            choice = sublime.yes_no_cancel_dialog(
                f"You have {local} comment(s) not yet sent to GitHub.",
                "Submit to GitHub",
                "Discard",
            )
            if choice == sublime.DIALOG_YES:
                _end_after(review.flush_local, "review ended (comments sent to GitHub)")
            elif choice == sublime.DIALOG_NO:
                _end_after(review.clear_drafts, "review ended (comments discarded)")
            return

        # All queued comments are already on GitHub as a pending review.
        choice = sublime.yes_no_cancel_dialog(
            f"You have {len(drafts)} pending comment(s) saved as a GitHub pending review.",
            "Keep on GitHub",
            "Discard from GitHub",
        )
        if choice == sublime.DIALOG_YES:
            # Pending review stays on GitHub; it is restored next time you load the PR.
            _end_review()
        elif choice == sublime.DIALOG_NO:
            _end_after(review.clear_drafts, "review ended (pending discarded)")


# --------------------------------------------------------------------------- #
# event listener
# --------------------------------------------------------------------------- #
class GithubPullRequestListener(sublime_plugin.EventListener):
    def on_load_async(self, view):
        _decorate_view(view)

    def on_pre_close(self, view):
        _OPCODE_CACHE.pop(view.id(), None)

        # A compose buffer closing (via submit or cancel) restores the pre-split
        # layout and refocuses the file it was written against.
        if not view.settings().get("github_pull_request_compose"):
            return

        window = view.window()
        orig = view.settings().get("github_pull_request_orig_layout")
        source_id = view.settings().get("github_pull_request_source_id")
        sublime.set_timeout(lambda: _restore_after_compose(window, orig, source_id), 0)

    def on_activated_async(self, view):
        _decorate_view(view)
        _update_status()

    def on_post_save_async(self, view):
        # Reapply the reference document after a save so the gutter diff survives.
        _decorate_view(view)

    def on_hover(self, view, point, hover_zone):
        if not SESSION.active:
            return

        if not _settings().get("auto_show_popup", True):
            return

        if hover_zone not in (sublime.HOVER_TEXT, sublime.HOVER_GUTTER):
            return

        row = view.rowcol(point)[0]
        if _threads_at_row(view, row) or _drafts_at_row(view, row):
            _show_threads_popup(view, row, view.text_point(row, 0))
