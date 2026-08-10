"""Text model for the changed-files bottom panel, plus the "where does this file's
first comment live" line pickers it navigates to.

Reads ``SESSION`` but imports no ``sublime``: this builds the panel's TEXT, while
plugin.py owns creating the output panel and its settings. Colouring is done by
GithubPullRequestFiles.sublime-syntax, not here."""

from typing import Dict, FrozenSet, List, Optional, Tuple

try:
    from .mapper import draft_span, thread_start_line
    from .state import SESSION
except ImportError:
    from mapper import draft_span, thread_start_line
    from state import SESSION

# Width the `path:line` nav token is padded to, so file rows and their indented
# comment sub-rows line up in a column.
_PATH_COL = 34

# Every row starts with a fixed-width marker slot: a dot when the file is open as a tab,
# blanks when it is not. A .sublime-syntax can only assign scopes by matching TEXT, so a
# real character is required to grey the row (a zero-width one is no good: Sublime renders
# format characters as their codepoint). Both slots are the SAME width so the path column
# stays aligned either way, and the marker sits outside the `path:line` nav token so
# result_file_regex still matches.
_OPEN_MARKER = "● "
_CLOSED_MARKER = "  "


def drafts_for_path(path: str) -> List[Tuple[int, Dict]]:
    """(uid, draft) pairs for a path's RIGHT-side queued comments; the uid (stable,
    not positional) drives per-draft Edit/Discard actions."""
    if not SESSION.review:
        return []

    return [
        (draft["uid"], draft)
        for draft in SESSION.review.drafts()
        if draft.get("path") == path and draft.get("side") == "RIGHT"
    ]


def first_hunk_line(path: str) -> int:
    """Head-side start line of the file's first hunk (else line 1)."""
    entry = SESSION.files_by_path.get(path)
    if entry:
        hunks = entry["file_diff"].hunks
        if hunks:
            return hunks[0].new_start

    return 1


def first_comment_line(path: str) -> int:
    """Line of the first comment on the file: the earliest unresolved thread or pending
    draft, else the earliest thread, else the first hunk. Multi-line comments count
    from where their range starts, which is where GitHub scrolls to."""
    threads = SESSION.threads_by_path.get(path, [])

    unresolved = [
        thread_start_line(thread) for thread in threads if not thread.get("is_resolved")
    ]
    unresolved += [
        span[0]
        for span in (draft_span(draft) for _, draft in drafts_for_path(path))
        if span
    ]

    for candidates in (unresolved, [thread_start_line(thread) for thread in threads]):
        lines = [line for line in candidates if line]
        if lines:
            return min(lines)

    return first_hunk_line(path)


def _file_row(entry: Dict, marker: str) -> str:
    path = entry["path"]
    stats = f"+{entry.get('additions', 0)} -{entry.get('deletions', 0)}"
    row = f"{marker}{stats.ljust(_PATH_COL)}{path}:{first_hunk_line(path)}"

    owners = entry.get("owners", "")
    if owners:
        # Owners trail the "path:line" nav token so column alignment is kept and
        # result_file_regex still finds the target (it is no longer $-anchored).
        row += "  " + owners

    return row


def _notes_row(entry: Dict, marker: str) -> Optional[str]:
    """Indented sub-row naming the file's comment counts, or None when it has none.
    It navigates to the first comment rather than the first hunk."""
    path = entry["path"]
    notes = " ".join(
        note
        for note in (
            f"({entry.get('unresolved', 0)} unresolved)"
            if entry.get("unresolved", 0)
            else "",
            f"({entry.get('pending', 0)} pending)" if entry.get("pending", 0) else "",
        )
        if note
    )
    if not notes:
        return None

    indented = ("    " + notes).ljust(_PATH_COL)

    return f"{marker}{indented}{path}:{first_comment_line(path)}"


def files_panel_text(open_paths: FrozenSet[str] = frozenset()) -> Optional[str]:
    """Full panel body, or None when the PR changes no files.

    Two lines per file so each gets its own result_file_regex click target: the file
    row jumps to the first hunk, the comment sub-row (only when the file has comments)
    jumps to the first comment. A blank line separates the header from the rows.
    `open_paths` are the repo-relative paths currently open as a tab; their rows get the
    `_OPEN_MARKER` the syntax file greys."""
    entries = SESSION.file_entries_for_panel()
    if not entries:
        return None

    lines = []
    for entry in entries:
        marker = _OPEN_MARKER if entry["path"] in open_paths else _CLOSED_MARKER

        lines.append(_file_row(entry, marker))

        notes = _notes_row(entry, marker)
        if notes:
            lines.append(notes)

    pending = sum(entry.get("pending", 0) for entry in entries)

    pr = SESSION.pr
    header = f"PR #{pr['number']} · {pr['title']} · {len(entries)} files"
    if pending:
        header += f" · {pending} pending"

    return header + "\n\n" + "\n".join(lines) + "\n"
