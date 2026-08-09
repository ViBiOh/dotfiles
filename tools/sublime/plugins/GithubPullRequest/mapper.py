from typing import Dict, Optional


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
