from typing import Dict, Optional, Tuple

# --------------------------------------------------------------------------- #
# Local-edit mapping (buffer vs the committed head file).
#
# These walk difflib opcodes produced with the COMMITTED file as `a` and the LIVE
# buffer as `b`. They are pure so they can be tested headlessly; plugin.py owns the
# git/view I/O that produces the opcodes. Keeping them out of LineMap preserves its
# contract: LineMap only knows head-commit rows and the PR diff.
# --------------------------------------------------------------------------- #


def head_anchor(opcodes, start_row: int, end_row: int) -> Tuple:
    """Map a 0-based buffer-row selection onto the head-commit rows it covers, plus
    whether it carries the reviewer's local (uncommitted) edits.

    Returns ``(first_head_row, last_head_row, has_edit)``, or ``(None, None, has_edit)``
    when the selection covers no head line at all (a purely local insertion, which
    GitHub cannot anchor a comment to)."""
    head_rows = []
    has_edit = False

    for tag, i1, i2, j1, j2 in opcodes:
        lo = max(j1, start_row)
        hi = min(j2, end_row + 1)
        overlaps = lo < hi

        if tag == "delete":
            # Locally removed lines occupy NO buffer rows (j1 == j2), so the `lo < hi`
            # test can never hold for them. A deletion has to be treated as a position
            # BETWEEN rows: it belongs to the selection when that position falls in the
            # selected span. Without this a deletion is invisible, so no suggestion is
            # offered and its head lines stay out of the comment range, i.e. proposing
            # "remove these lines" never works.
            if start_row <= j1 <= end_row + 1:
                has_edit = True
                head_rows.append(i1)
                head_rows.append(i2 - 1)

            continue

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


def head_row_to_buffer_row(opcodes, head_row: int) -> Optional[int]:
    """Where a 0-based head-commit row currently sits in the buffer, following the
    reviewer's local edits. A changed/removed head line anchors to its block start."""
    for tag, i1, i2, j1, j2 in opcodes:
        if i1 <= head_row < i2:
            if tag == "equal":
                return j1 + (head_row - i1)

            return j1

    return None


class LineMap:
    """Map between Sublime buffer rows (holding the PR head file) and GitHub review
    coordinates. Duck-typed on ``file_diff``: reads ``.hunks``, each hunk's ``.lines``,
    and each line's ``.origin`` / ``.old_lineno`` / ``.new_lineno`` / ``.content``.
    Does NOT import diff.py."""

    def __init__(self, file_diff) -> None:
        self._lines = []
        self._commentable = set()

        max_new = None

        for hunk in getattr(file_diff, "hunks", None) or []:
            for line in getattr(hunk, "lines", None) or []:
                self._lines.append(line)

                origin = getattr(line, "origin", "")
                new_lineno = getattr(line, "new_lineno", None)

                if new_lineno is not None and (max_new is None or new_lineno > max_new):
                    max_new = new_lineno

                if origin in ("+", " ") and new_lineno is not None:
                    self._commentable.add(new_lineno)

        self._last_head_row = (max_new - 1) if max_new is not None else None

    def is_commentable(self, row: int) -> bool:
        if row < 0:
            return False

        return (row + 1) in self._commentable

    def anchor_to_row(self, side: str, line: int) -> Optional[int]:
        if side == "RIGHT":
            if line < 1:
                return None

            return line - 1

        if side == "LEFT":
            return self._left_row(line)

        return None

    def comment_range(self, start_row: int, end_row: int) -> Optional[Dict]:
        """RIGHT-side comment payload for a buffer row span, narrowed to the rows the
        PR diff actually carries (GitHub refuses to anchor anywhere else). None when
        the span holds no commentable row.

        NOTE: the narrowing can shrink a multi-row span down to a single row, which
        yields a single-line payload (no ``start_line``) and therefore a single-line
        comment on GitHub. Callers must surface that, or the reviewer sees a one-line
        comment where they selected many."""
        if start_row > end_row:
            start_row, end_row = end_row, start_row

        commentable = [
            row for row in range(start_row, end_row + 1) if self.is_commentable(row)
        ]
        if not commentable:
            return None

        eff_start = commentable[0]
        eff_end = commentable[-1]
        end_line = eff_end + 1

        payload = {
            "side": "RIGHT",
            "line": end_line,
        }

        if eff_start != eff_end:
            payload["start_line"] = eff_start + 1
            payload["start_side"] = "RIGHT"

        return payload

    def _anchor_after(self, index: int) -> int:
        """Head buffer row a deletion sits at: the row of the nearest following line
        that has a head-side line number. Falls back to the last head row at EOF."""
        total = len(self._lines)

        scan = index
        while scan < total:
            new_lineno = getattr(self._lines[scan], "new_lineno", None)
            if new_lineno is not None:
                return new_lineno - 1
            scan += 1

        return self._last_head_row if self._last_head_row is not None else 0

    def _left_row(self, line: int) -> Optional[int]:
        for index, current in enumerate(self._lines):
            if (
                getattr(current, "origin", "") == "-"
                and getattr(current, "old_lineno", None) == line
            ):
                return self._anchor_after(index + 1)

        return None
