"""Where a comment lives in the buffer RIGHT NOW.

Three coordinate spaces meet here:

* **buffer rows** of the live view, which carry the reviewer's own uncommitted edits,
* **head-commit rows** (``git show HEAD:<path>``), which is what GitHub anchors to,
* the **PR diff**, which decides what is commentable (``mapper.LineMap``).

Local edits shift buffer rows away from head rows, so both directions are needed:
``head_anchor`` maps a selection buffer -> head when authoring, ``remap_head_row``
maps head -> buffer when placing icons, popups and navigation. Both walk the same
difflib opcodes (committed as ``a``, live buffer as ``b``), cached per view.

Imports ``sublime`` (it reads view text), so the pure opcode arithmetic lives in
mapper.py and is unit-tested there."""

import difflib

import sublime

try:
    from .mapper import draft_span, head_anchor, head_row_to_buffer_row, thread_span
    from .repo import rel_path, run_git
    from .state import SESSION
except ImportError:
    from mapper import draft_span, head_anchor, head_row_to_buffer_row, thread_span
    from repo import rel_path, run_git
    from state import SESSION

# Opcodes (committed HEAD vs live buffer) per view, keyed by the view's change_count so
# a `git show HEAD` is paid only when the buffer actually changed.
_OPCODE_CACHE = {}

# Covered rows per thread, per view. `on_hover` hit-tests every thread on every mouse
# move and each covered line costs an opcode scan, so recomputing is wasteful. Keyed by
# change_count plus _THREADS_STAMP (bumped when the thread index is rebuilt), which
# together cover everything the rows depend on.
_THREAD_ROWS_CACHE = {}
_THREADS_STAMP = 0


def bump_threads_stamp():
    """Invalidate every cached row set: thread lines just changed. Called by the
    session code after it rebuilds the thread index (`global` cannot cross modules)."""
    global _THREADS_STAMP
    _THREADS_STAMP += 1


def forget_view(view_id):
    _OPCODE_CACHE.pop(view_id, None)
    _THREAD_ROWS_CACHE.pop(view_id, None)


def clear_caches():
    _OPCODE_CACHE.clear()
    _THREAD_ROWS_CACHE.clear()


def _head_opcodes(root, rel, view):
    """difflib opcodes (committed HEAD as ``a``, live buffer as ``b``) for the file, or
    None when HEAD has no such path. The buffer is read live, so unsaved edits count."""
    rc, committed = run_git(root, ["show", f"HEAD:{rel}"])
    if rc != 0:
        return None

    committed_lines = committed.splitlines()
    buffer_lines = view.substr(sublime.Region(0, view.size())).splitlines()

    matcher = difflib.SequenceMatcher(
        None, committed_lines, buffer_lines, autojunk=False
    )

    return matcher.get_opcodes()


def view_opcodes(view):
    path = rel_path(view)
    if path is None or not SESSION.root:
        return None

    change = view.change_count()
    cached = _OPCODE_CACHE.get(view.id())
    if cached and cached[0] == change:
        return cached[1]

    opcodes = _head_opcodes(SESSION.root, path, view)
    _OPCODE_CACHE[view.id()] = (change, opcodes)

    return opcodes


def selection_to_head(view, start_row, end_row):
    """Buffer-row selection -> the head-commit rows GitHub can anchor to, plus whether
    the selection carries the reviewer's local (uncommitted) edits. Returns the buffer
    rows unchanged when HEAD is unavailable; see `mapper.head_anchor` for the mapping."""
    opcodes = view_opcodes(view)
    if opcodes is None:
        return start_row, end_row, False

    return head_anchor(opcodes, start_row, end_row)


def remap_head_row(view, head_row):
    """Head-commit row -> current buffer row (identity when the buffer matches HEAD or
    HEAD is unavailable). Keeps gutter icons, popups and navigation on the right line
    even after local edits shift the buffer away from the PR head."""
    if head_row is None:
        return None

    opcodes = view_opcodes(view)
    if not opcodes:
        return head_row

    mapped = head_row_to_buffer_row(opcodes, head_row)

    return head_row if mapped is None else mapped


def _rows_for_lines(view, to_row, start_line, end_line):
    """Sorted, de-duplicated buffer rows for an inclusive head-side line range.
    `to_row` turns one head line into a head row (side-aware for threads)."""
    rows = set()
    for line in range(start_line, end_line + 1):
        row = remap_head_row(view, to_row(line))
        if row is not None:
            rows.add(row)

    return sorted(rows)


def _compute_thread_rows(view, thread):
    line_map = SESSION.line_maps.get(thread["path"])
    if line_map is None:
        return []

    span = thread_span(thread)
    if span is None:
        return []

    side = thread.get("side") or "RIGHT"

    return _rows_for_lines(
        view, lambda line: line_map.anchor_to_row(side, line), span[0], span[1]
    )


def thread_rows(view, thread):
    """Every buffer row a thread covers. github.com highlights a multi-line comment
    across its whole range, so mark and hit-test all of it, not just the anchor."""
    stamp = (view.change_count(), _THREADS_STAMP)

    cached = _THREAD_ROWS_CACHE.get(view.id())
    if cached is None or cached[0] != stamp:
        cached = (stamp, {})
        _THREAD_ROWS_CACHE[view.id()] = cached

    by_thread = cached[1]
    thread_id = thread["id"]
    if thread_id not in by_thread:
        by_thread[thread_id] = _compute_thread_rows(view, thread)

    return by_thread[thread_id]


def draft_rows(view, draft):
    """Every buffer row a queued draft covers (RIGHT side, so row = line - 1)."""
    span = draft_span(draft)
    if span is None:
        return []

    return _rows_for_lines(view, lambda line: line - 1, span[0], span[1])


def thread_row(view, thread):
    """First buffer row of a thread's range, or None. This is its navigation anchor, so
    a multi-line thread is a single stop rather than one per covered row."""
    rows = thread_rows(view, thread)

    return rows[0] if rows else None
