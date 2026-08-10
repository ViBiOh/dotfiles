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

import os
import shlex
import subprocess
import webbrowser

import sublime
import sublime_plugin

try:
    from . import render
    from .anchors import (
        bump_threads_stamp,
        clear_caches,
        draft_rows,
        forget_view,
        remap_head_row,
        selection_to_head,
        thread_row,
        thread_rows,
    )
    from .gh import GH, GHError
    from .labels import DEFAULT_COMMENT_LABELS, label_tag
    from .layout import split_below_layout
    from .mapper import (
        LineMap,
        payload_range_label,
        payload_span,
        thread_span,
        thread_start_line,
    )
    from .owners import codeowners_map
    from .panel import drafts_for_path, files_panel_text
    from .repo import abs_path, git_root, rel_path, run_git
    from .review import CommentRejected, Review
    from .state import SESSION
except ImportError:
    import render
    from anchors import (
        bump_threads_stamp,
        clear_caches,
        draft_rows,
        forget_view,
        remap_head_row,
        selection_to_head,
        thread_row,
        thread_rows,
    )
    from gh import GH, GHError
    from labels import DEFAULT_COMMENT_LABELS, label_tag
    from layout import split_below_layout
    from mapper import (
        LineMap,
        payload_range_label,
        payload_span,
        thread_span,
        thread_start_line,
    )
    from owners import codeowners_map
    from panel import drafts_for_path, files_panel_text
    from repo import abs_path, git_root, rel_path, run_git
    from review import CommentRejected, Review
    from state import SESSION

SETTINGS_FILE = "GithubPullRequest.sublime-settings"

REGION_KEY = "githubpullrequest.threads"
DRAFT_REGION_KEY = "githubpullrequest.drafts"
STATUS_KEY = "githubpullrequest.status"


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


def _detect_base_branch(root):
    """Repo default branch via origin/HEAD (e.g. 'main'); falls back to 'main'."""
    rc, out = run_git(root, ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"])
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


# --------------------------------------------------------------------------- #
# decoration (diff reference doc, thread + draft gutter icons)
# --------------------------------------------------------------------------- #
def _decorate_view(view):
    if not SESSION.active:
        return

    path = rel_path(view)
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


def _row_regions(view, rows):
    """One empty region per row, so a gutter icon lands on every one of them (a
    single multi-line region would only mark its first row)."""
    regions = []
    for row in rows:
        point = view.text_point(row, 0)
        regions.append(sublime.Region(point, point))

    return regions


def _apply_thread_icons(view, path):
    if not _settings().get("show_gutter_icon", True):
        return

    icon = _settings().get("gutter_icon", "bookmark")

    rows = set()
    for thread in SESSION.threads_by_path.get(path, []):
        if thread.get("is_resolved"):
            continue

        rows.update(thread_rows(view, thread))

    regions = _row_regions(view, sorted(rows))

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

    rows = set()
    for _, draft in drafts_for_path(path):
        rows.update(draft_rows(view, draft))

    regions = _row_regions(view, sorted(rows))

    view.erase_regions(DRAFT_REGION_KEY)
    if regions:
        view.add_regions(
            DRAFT_REGION_KEY,
            regions,
            "region.purplish",
            icon,
            sublime.HIDDEN | sublime.PERSISTENT,
        )


# --------------------------------------------------------------------------- #
# comment compose split (write a comment below the file; save to submit)
# --------------------------------------------------------------------------- #


def _open_compose(source_view, prefill, context, target=""):
    """Open a scratch compose buffer in a split below the file. Save submits it
    (see the keymap / GithubPullRequestSubmitCommentCommand); closing cancels.
    `context` = {"mode": "new", path, payload}, {"mode": "edit", uid}, or
    {"mode": "reply", thread_id}. `target` labels the lines the comment will land on
    and is shown in the tab title, so the posted range is visible while writing."""
    window = source_view.window()

    # One compose at a time: opening a second while one is live would capture the
    # already-split layout as its "original" and break the restore. Focus the open one.
    for existing in window.views():
        if existing.settings().get("github_pull_request_compose"):
            window.focus_view(existing)
            _status("finish the open comment first")
            return

    layout = window.layout()
    window.set_layout(split_below_layout(layout))
    window.focus_group(window.num_groups() - 1)

    verb = {"edit": "Edit PR comment", "reply": "Reply"}.get(
        context.get("mode"), "PR comment"
    )
    if target:
        verb = f"{verb} {target}"

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
    if rel_path(view) not in SESSION.files_by_path:
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

    status = (
        f"PR #{pr['number']} · {len(SESSION.files)} files · {unresolved} unresolved"
    )
    if badge:
        status += " · " + badge

    view.set_status(STATUS_KEY, status)


# --------------------------------------------------------------------------- #
# thread popups + action links
# --------------------------------------------------------------------------- #
def _threads_at_row(view, row):
    """Threads covering this row. Any row of a multi-line range counts, so hovering
    anywhere in the range opens the thread, as on github.com."""
    path = rel_path(view)
    if path is None:
        return []

    found = []
    for thread in SESSION.threads_by_path.get(path, []):
        if row in thread_rows(view, thread):
            found.append(thread)

    return found


def _drafts_at_row(view, row):
    path = rel_path(view)
    if path is None:
        return []

    return [
        (uid, draft)
        for uid, draft in drafts_for_path(path)
        if row in draft_rows(view, draft)
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


def _mutate_then_refresh(action, done_message, window=None):
    """Run a review mutation off the UI thread, then redraw everything that shows draft
    state (gutter icons, files panel, status) back on the main thread."""

    def worker():
        try:
            action()
        except GHError as err:
            _main(lambda message=str(err): _error(message))
            return

        def apply():
            _decorate_all_views()
            _refresh_files_panel(window or sublime.active_window())
            _status(done_message)
            _update_status()

        _main(apply)

    _async(worker)


def _discard_draft(uid):
    _mutate_then_refresh(lambda: SESSION.review.discard_draft(uid), "draft discarded")


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

    # An outdated thread can lose both its current and original line, leaving no head
    # row to write the suggestion over.
    span = thread_span(thread)
    if span is None:
        _status("cannot locate the suggestion's lines in this buffer")
        return

    start_row = remap_head_row(view, span[0] - 1)
    end_row = remap_head_row(view, span[1] - 1)
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

    bump_threads_stamp()


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

    root = git_root(cwd)
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

    owners = codeowners_map(root, [entry["path"] for entry in files])

    def apply():
        _build_session(root, pr, review, files, threads, owners)
        _decorate_all_views()
        _status(f"loaded PR #{pr['number']} ({len(files)} files)")
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
            else (git_root(cwd) if cwd else None)
        )
        if root is None:
            _error("not inside a git repository")
            return

        _status("launching review agent…")
        _async(lambda: _launch_agent_review(root))


FILES_PANEL = "githubpullrequest_files"


def _open_paths(window):
    """Repo-relative paths of the PR's changed files that are open as a tab in this
    window, which drives the panel's "already open" marker. Walks the window's tabs
    rather than probing every changed file, so the cost follows the number of open tabs,
    not the size of the PR. Output panels are not tabs, so this never matches itself."""
    open_paths = set()

    for view in window.views():
        # rel_path is None for unsaved buffers, files outside the repo, and whenever no
        # review is loaded, none of which can be in files_by_path.
        path = rel_path(view)
        if path in SESSION.files_by_path:
            open_paths.add(path)

    return frozenset(open_paths)


def _files_panel(window):
    """The files panel, created on first use and reused afterwards.

    `result_base_dir` is re-applied on every call because it depends on SESSION.root,
    which changes when another PR is loaded into the same window; the panel now outlives
    a load (it is only destroyed by End review), so it would otherwise keep resolving
    clicks against the previous repository."""
    panel = window.find_output_panel(FILES_PANEL)

    if panel is None:
        panel = window.create_output_panel(FILES_PANEL)

        settings = panel.settings()
        settings.set("result_file_regex", r"([^ \t]+):(\d+)")
        settings.set("line_numbers", False)
        settings.set("gutter", False)
        settings.set("scroll_past_end", False)

        panel.assign_syntax(
            "Packages/GithubPullRequest/GithubPullRequestFiles.sublime-syntax"
        )

    panel.settings().set("result_base_dir", SESSION.root)

    return panel


def _write_files_panel(panel, text):
    """Replace the panel body in place, keeping the scroll position. Rewriting beats
    destroy-and-recreate: the panel keeps its identity, so refreshing it cannot reset
    the viewport or re-run show_panel."""
    viewport = panel.viewport_position()

    panel.set_read_only(False)
    panel.run_command("github_pull_request_set_text", {"text": text})
    panel.set_read_only(True)

    panel.set_viewport_position(viewport, False)


def _show_files_panel(window):
    text = files_panel_text(_open_paths(window))
    if text is None:
        _status("no changed files")
        return

    _write_files_panel(_files_panel(window), text)

    window.run_command("show_panel", {"panel": f"output.{FILES_PANEL}"})


def _refresh_files_panel(window):
    """Update the visible panel's text in place so its counts and open-tab markers stay
    current. Does not create or show the panel, and does not steal focus."""
    if not window or window.active_panel() != f"output.{FILES_PANEL}":
        return

    panel = window.find_output_panel(FILES_PANEL)
    if panel is None:
        return

    text = files_panel_text(_open_paths(window))
    if text is not None:
        _write_files_panel(panel, text)


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

            trigger = f"{thread['path']}:{thread_start_line(thread) or 1}"
            tag_note = f" [{', '.join(tags)}]" if tags else ""
            author = first.get("author", "?")
            body = snippet[0] if snippet else ""
            detail = (
                f"{author} · {len(thread['comments'])} comment(s){tag_note} — {body}"
            )
            items.append(sublime.QuickPanelItem(trigger, details=detail))

        def on_done(index):
            if index < 0:
                return

            thread = threads[index]
            view = self.window.open_file(
                f"{abs_path(thread['path'])}:{thread_start_line(thread) or 1}",
                sublime.ENCODED_POSITION,
            )
            _async(lambda: _show_when_ready(view, thread))

        self.window.show_quick_panel(items, on_done)


def _show_when_ready(view, thread, attempts=20):
    if view.is_loading() and attempts > 0:
        sublime.set_timeout(lambda: _show_when_ready(view, thread, attempts - 1), 50)
        return

    row = thread_row(view, thread)
    if row is None:
        return

    point = view.text_point(row, 0)
    _show_threads_popup(view, row, point)


class GithubPullRequestAddCommentCommand(sublime_plugin.TextCommand):
    def is_enabled(self):
        return SESSION.active and rel_path(self.view) in SESSION.files_by_path

    def run(self, edit):
        path = rel_path(self.view)
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
        head_start, head_end, has_diff = selection_to_head(view, start_row, end_row)

        payload = None
        if head_start is not None:
            payload = line_map.comment_range(head_start, head_end)
        if payload is None:
            _status("no commentable line in the selection")
            return

        # GitHub only anchors comments to lines the PR diff actually carries, so a
        # selection reaching into unchanged code is narrowed to its commentable part.
        # Say so, and put the final range in the compose tab title: silently posting a
        # single-line comment for a multi-line selection is the surprise we avoid here.
        target = payload_range_label(payload)
        if payload_span(payload) != (head_start + 1, head_end + 1):
            _status(f"selection narrowed to {target} (the rest is outside the PR diff)")

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
            labels = _settings().get("comment_labels", DEFAULT_COMMENT_LABELS)

        new_context = {"mode": "new", "path": path, "payload": payload}

        if not labels:
            _open_compose(view, compose(""), new_context, target)
            return

        items = [sublime.QuickPanelItem("(plain comment)", details="no label")]
        items += [
            sublime.QuickPanelItem(label_tag(e), details=e.get("description", ""))
            for e in labels
        ]

        def on_label(index):
            if index < 0:
                return

            tag = "" if index == 0 else label_tag(labels[index - 1])
            _main(lambda: _open_compose(view, compose(tag), new_context, target))

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
            except CommentRejected as err:
                # Permanent: GitHub will not anchor this comment (its lines are not in
                # the PR diff, usually because the loaded diff went stale). It is not
                # queued, so say so plainly instead of promising a later retry.
                _main(
                    lambda m=str(err): _error(
                        m + "\n\nReload the pull request and comment again."
                    )
                )
                return
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
        return SESSION.active and rel_path(self.view) in SESSION.files_by_path

    def run(self, edit):
        path = rel_path(self.view)
        rows = sorted(
            {
                row
                for thread in SESSION.threads_by_path.get(path, [])
                if not thread.get("is_resolved")
                for row in [thread_row(self.view, thread)]
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


class GithubPullRequestSetTextCommand(sublime_plugin.TextCommand):
    """Internal: replace a view's whole body (used to rewrite the files panel in
    place). The caller owns the read-only flag."""

    def run(self, edit, text):
        self.view.replace(edit, sublime.Region(0, self.view.size()), text)


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
            except CommentRejected as err:
                # Unsent comments were flushed first and GitHub refused some of them.
                # They are dropped (not re-queued), so submitting again goes through.
                _main(
                    lambda message=str(err): _error(
                        message + "\n\nSubmit the review again to finish."
                    )
                )
                return
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
        _status("discarding drafts…")
        _mutate_then_refresh(
            SESSION.review.clear_drafts, "drafts discarded", self.window
        )


def _end_review(message="review ended"):
    """Clear all decorations, the panel, and session state. Main-thread only."""
    for window in sublime.windows():
        for view in window.views():
            _clear_view(view)
        window.destroy_output_panel(FILES_PANEL)

    SESSION.reset()
    clear_caches()
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

        # The tab set changed, so the panel's "already open" markers are stale.
        _refresh_files_panel(view.window())

    def on_pre_close(self, view):
        forget_view(view.id())

        window = view.window()

        # Fires BEFORE the view goes away, so it is still in window.views().
        # Refresh on the next tick, once the tab is really gone.
        sublime.set_timeout(lambda: _refresh_files_panel(window), 0)

        # A compose buffer closing (via submit or cancel) restores the pre-split
        # layout and refocuses the file it was written against.
        if not view.settings().get("github_pull_request_compose"):
            return

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
