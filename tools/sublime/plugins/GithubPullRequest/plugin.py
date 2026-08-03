"""Sublime Text glue for GithubPullRequest — on-demand GitHub PR review.

Nothing here runs until ``PR: Load pull-request`` is invoked. The heavy lifting
(gh / git subprocess calls) lives in the pure-Python core; this module only:

* drives those calls off the UI thread (``set_timeout_async``) and mutates the
  view back on the main thread,
* draws the diff via ``set_reference_document`` (no git mutation),
* marks threads and queued drafts with gutter icons,
* renders threads as ``show_popup`` overlays and handles their action links,
* queues comments into a local draft and submits them as one review.
"""

import os
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

    return "{} {}".format(emoji, label) if emoji else label


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
    sublime.status_message("GithubPullRequest: {}".format(message))


def _error(message):
    sublime.error_message("GithubPullRequest: {}".format(message))


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


def _panel_line(path):
    """Line to jump to when a file is opened from a list: the first unresolved
    thread, else the first changed line, else line 1."""
    lines = [
        thread.get("line") or thread.get("original_line")
        for thread in SESSION.threads_by_path.get(path, [])
        if not thread.get("is_resolved")
    ]
    lines = [line for line in lines if line]
    if lines:
        return min(lines)

    line_map = SESSION.line_maps.get(path)
    if line_map is not None:
        rows = line_map.added_rows()
        if rows:
            return rows[0] + 1

    return 1


def _thread_row(view, thread):
    """0-based buffer row a thread anchors to, or None."""
    line_map = SESSION.line_maps.get(thread["path"])
    if line_map is None:
        return None

    side = thread.get("side") or "RIGHT"
    line = thread.get("line") or thread.get("original_line")
    if line is None:
        return None

    return line_map.anchor_to_row(side, line)


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

        point = view.text_point(line - 1, 0)
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
    """(index, draft) pairs for a path's RIGHT-side queued comments; index is the
    position in review.drafts() so it can drive per-draft Discard actions."""
    if not SESSION.review:
        return []

    return [
        (index, draft)
        for index, draft in enumerate(SESSION.review.drafts())
        if draft.get("path") == path and draft.get("side") == "RIGHT"
    ]


def _clear_view(view):
    view.erase_regions(REGION_KEY)
    view.erase_regions(DRAFT_REGION_KEY)
    view.erase_status(STATUS_KEY)
    try:
        view.reset_reference_document()
    except Exception:
        pass


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
        (index, draft)
        for index, draft in _drafts_for_path(path)
        if draft.get("line") == row + 1
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


def _handle_action(view, href):
    action = render.decode_action(href)
    if action is None:
        webbrowser.open(href)
        return

    kind = action.get("action")

    if kind == "open":
        webbrowser.open(action.get("url", ""))
    elif kind == "reply":
        _prompt_reply(action["id"])
    elif kind in ("resolve", "unresolve"):
        _set_resolved(action["id"], kind == "resolve")
    elif kind == "discard":
        _discard_draft(int(action["idx"]))
    elif kind == "apply_suggestion":
        _apply_suggestion(view, action["id"], int(action.get("sug", 0)))


def _discard_draft(index):
    def worker():
        try:
            SESSION.review.discard_draft(index)
        except IndexError:
            return
        except GHError as err:
            _main(lambda message=str(err): _error(message))
            return

        def apply():
            _decorate_all_views()
            _refresh_files_panel(sublime.active_window())
            _status("draft discarded")

        _main(apply)

    _async(worker)


def _prompt_reply(thread_id):
    def on_done(body):
        if not body.strip():
            return

        def worker():
            try:
                SESSION.review.reply_comment(thread_id, body)
            except GHError as err:
                _main(lambda message=str(err): _error(message))
                return

            _reload_threads()

        _async(worker)

    sublime.active_window().show_input_panel("Reply:", "", on_done, None, None)


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

    line = thread.get("line") or thread.get("original_line")
    start_line = thread.get("start_line") or line

    view.run_command(
        "github_pull_request_replace_lines",
        {
            "start_row": start_line - 1,
            "end_row": line - 1,
            "text": suggestions[index].rstrip("\n"),
        },
    )
    _status("suggestion applied")


# --------------------------------------------------------------------------- #
# load / reload
# --------------------------------------------------------------------------- #
def _build_session(cwd, root, pr, review, files, threads):
    SESSION.reset()
    SESSION.active = True
    SESSION.cwd = cwd
    SESSION.root = root
    SESSION.pr = pr
    SESSION.review = review
    SESSION.files = files
    SESSION.files_by_path = {entry["path"]: entry for entry in files}
    SESSION.line_maps = {entry["path"]: LineMap(entry["file_diff"]) for entry in files}
    _index_threads(threads)


def _index_threads(threads):
    by_path = {}
    for thread in threads:
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
        files = review.changed_files()
        threads = review.review_threads()
        review.load_pending()
    except GHError as err:
        _main(lambda message=str(err): _error(message))
        return

    def apply():
        _build_session(cwd, root, pr, review, files, threads)
        _decorate_all_views()
        _status("loaded PR #{} ({} files)".format(pr["number"], len(files)))
        window.run_command("github_pull_request_files_panel")

    _main(apply)


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #
class GithubPullRequestLoadCommand(sublime_plugin.WindowCommand):
    def run(self, url=None):
        _status("loading pull request…")
        _async(lambda: _load(self.window))


FILES_PANEL = "githubpullrequest_files"


def _files_panel_text():
    entries = SESSION.file_entries_for_panel()
    if not entries:
        return None

    # Fixed-width stats columns so the table lines up; the clickable "path:line"
    # trails each row (matched by result_file_regex). The syntax file colors the
    # +N / -M / (K unresolved) / (P pending) columns.
    lines = []
    total_pending = 0
    for entry in entries:
        unresolved = entry.get("unresolved", 0)
        pending = entry.get("pending", 0)
        total_pending += pending

        notes = " ".join(
            note
            for note in (
                "({} unresolved)".format(unresolved) if unresolved else "",
                "({} pending)".format(pending) if pending else "",
            )
            if note
        )
        lines.append(
            "{:<5} {:<6} {:<28} {}:{}".format(
                "+{}".format(entry.get("additions", 0)),
                "-{}".format(entry.get("deletions", 0)),
                notes,
                entry["path"],
                _panel_line(entry["path"]),
            )
        )

    pr = SESSION.pr
    header = "PR #{} · {} · {} files".format(pr["number"], pr["title"], len(entries))
    if total_pending:
        header += " · {} pending".format(total_pending)

    return header + "\n" + "\n".join(lines) + "\n"


def _show_files_panel(window):
    text = _files_panel_text()
    if text is None:
        _status("no changed files")
        return

    window.destroy_output_panel(FILES_PANEL)
    panel = window.create_output_panel(FILES_PANEL)
    settings = panel.settings()
    settings.set("result_file_regex", r"([^ \t]+):(\d+)$")
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

    window.run_command("show_panel", {"panel": "output.{}".format(FILES_PANEL)})


def _refresh_files_panel(window):
    """Rebuild the panel in place when it is already visible (e.g. after a draft
    is queued or discarded) so its counts stay current, without stealing focus."""
    if window and window.active_panel() == "output.{}".format(FILES_PANEL):
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

            trigger = "{}:{}".format(
                thread["path"], thread.get("line") or thread.get("original_line")
            )
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
                    thread.get("line") or thread.get("original_line") or 1,
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

        payload = line_map.comment_range(start_row, end_row)
        if payload is None:
            _status("no commentable line in the selection")
            return

        view = self.view
        window = view.window()

        where = "line {}".format(payload["line"])
        if "start_line" in payload:
            where = "lines {}-{}".format(payload["start_line"], payload["line"])

        def queue(prefix, subject):
            if not subject.strip():
                return

            def worker():
                try:
                    SESSION.review.queue_comment(path, payload, prefix + subject)
                except GHError as err:
                    _main(lambda message=str(err): _error(message))
                    return

                def apply():
                    _apply_draft_icons(view, path)
                    _refresh_files_panel(window)
                    _status("comment queued (submit the review to post)")
                    _update_status()

                _main(apply)

            _status("queuing comment…")
            _async(worker)

        def ask_subject(prefix):
            tag = prefix[:-2] if prefix else ""  # "suggestion: " -> "suggestion"
            prompt = "{} on {}:".format(tag or "Comment", where)
            window.show_input_panel(
                prompt, "", lambda subject: queue(prefix, subject), None, None
            )

        # Conventional Comments: pick a label (fuzzy), then type the subject. The
        # picker is skippable via its first entry and can be disabled in settings.
        labels = []
        if _settings().get("conventional_comments", True):
            labels = _settings().get("comment_labels", _DEFAULT_COMMENT_LABELS)

        if not labels:
            ask_subject("")
            return

        items = [sublime.QuickPanelItem("(plain comment)", details="no label")]
        items += [
            sublime.QuickPanelItem(
                _label_tag(entry), details=entry.get("description", "")
            )
            for entry in labels
        ]

        def on_label(index):
            if index < 0:
                return

            prefix = "" if index == 0 else "{}: ".format(_label_tag(labels[index - 1]))
            _main(lambda: ask_subject(prefix))

        window.show_quick_panel(items, on_label)


class GithubPullRequestShowCommentsCommand(sublime_plugin.TextCommand):
    def is_enabled(self):
        return SESSION.active and _rel_path(self.view) in SESSION.files_by_path

    def run(self, edit):
        region = self.view.sel()[0]
        row = self.view.rowcol(region.begin())[0]
        point = self.view.text_point(row, 0)
        if not _threads_at_row(self.view, row) and not _drafts_at_row(self.view, row):
            _status("no comments on this line")
            return

        _show_threads_popup(self.view, row, point)


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
            sublime.QuickPanelItem(label, details="{} queued comment(s)".format(drafts))
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
            _main(lambda: _end_review("review submitted ({}) — ended".format(verdict)))

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
    _status(message)


class GithubPullRequestEndReviewCommand(sublime_plugin.WindowCommand):
    def is_enabled(self):
        return SESSION.active

    def run(self):
        drafts = SESSION.review.drafts() if SESSION.review else []
        if not drafts:
            _end_review()
            return

        choice = sublime.yes_no_cancel_dialog(
            "You have {} pending comment(s) saved as a GitHub pending review.".format(
                len(drafts)
            ),
            "Keep on GitHub",
            "Discard from GitHub",
        )

        if choice == sublime.DIALOG_YES:
            # Pending review stays on GitHub; it is restored next time you load the PR.
            _end_review()
        elif choice == sublime.DIALOG_NO:

            def worker():
                try:
                    SESSION.review.clear_drafts()
                except GHError as err:
                    _main(lambda message=str(err): _error(message))
                    return

                _main(lambda: _end_review("review ended (pending discarded)"))

            _async(worker)


# --------------------------------------------------------------------------- #
# event listener
# --------------------------------------------------------------------------- #
class GithubPullRequestListener(sublime_plugin.EventListener):
    def on_load_async(self, view):
        _decorate_view(view)

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
