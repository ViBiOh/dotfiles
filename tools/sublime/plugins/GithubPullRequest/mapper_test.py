import unittest
from types import SimpleNamespace

try:
    from .mapper import LineMap
except ImportError:
    from mapper import LineMap


def _line(origin, old_lineno, new_lineno, position, content):
    return SimpleNamespace(
        origin=origin,
        old_lineno=old_lineno,
        new_lineno=new_lineno,
        position=position,
        content=content,
    )


def _make_map():
    """Multi-hunk FileDiff-like fixture (duck-typed, no diff import).

    Head buffer rows (0-based) -> content:
        row0  new1   ctx    "alpha"
        row1  new2   added  "beta-added"
        row2  new3   ctx    "epsilon"       (hunk1 also deletes base 2,3 here)
        rows3-7        (gap between hunk1 and hunk2, not in any hunk)
        row8  new9   ctx    "zeta"
        row9  new10  added  "eta-added"
        row10 new11  ctx    "theta"
        rows11-19      (gap)
        row20 new21  ctx    "iota"          (hunk3 trailing-deletes base 21)
    """
    hunk1 = SimpleNamespace(
        lines=[
            _line(" ", 1, 1, 1, "alpha"),
            _line("+", None, 2, 2, "beta-added"),
            _line("-", 2, None, 3, "gamma-removed"),
            _line("-", 3, None, 4, "delta-removed"),
            _line(" ", 4, 3, 5, "epsilon"),
        ]
    )
    hunk2 = SimpleNamespace(
        lines=[
            _line(" ", 10, 9, 7, "zeta"),
            _line("+", None, 10, 8, "eta-added"),
            _line(" ", 11, 11, 9, "theta"),
        ]
    )
    hunk3 = SimpleNamespace(
        lines=[
            _line(" ", 20, 21, 11, "iota"),
            _line("-", 21, None, 12, "kappa-removed"),
        ]
    )

    return LineMap(SimpleNamespace(hunks=[hunk1, hunk2, hunk3]))


class LineMapTest(unittest.TestCase):
    def setUp(self):
        self.line_map = _make_map()

    def test_is_commentable(self):
        cases = {
            "added_row": (1, True),
            "context_row_first": (0, True),
            "context_row_hunk_boundary": (2, True),
            "context_row_hunk2": (8, True),
            "added_row_hunk2": (9, True),
            "context_row_hunk2_last": (10, True),
            "trailing_context_hunk3": (20, True),
            "gap_between_hunks_start": (3, False),
            "gap_between_hunks_end": (7, False),
            "gap_after_hunk2": (11, False),
            "negative_row": (-1, False),
            "out_of_range": (1000, False),
        }

        for name, (row, expected) in cases.items():
            with self.subTest(name=name):
                self.assertEqual(self.line_map.is_commentable(row), expected)

    def test_anchor_to_row(self):
        cases = {
            "right_first": ("RIGHT", 1, 0),
            "right_mid": ("RIGHT", 5, 4),
            "right_zero_invalid": ("RIGHT", 0, None),
            "left_deleted_first": ("LEFT", 2, 2),
            "left_deleted_second": ("LEFT", 3, 2),
            "left_trailing_eof": ("LEFT", 21, 20),
            "left_unknown_base": ("LEFT", 999, None),
            "unknown_side": ("BOTH", 5, None),
        }

        for name, (side, line, expected) in cases.items():
            with self.subTest(name=name):
                self.assertEqual(self.line_map.anchor_to_row(side, line), expected)

    def test_comment_range(self):
        cases = {
            "single_row": (
                (1, 1),
                {"side": "RIGHT", "line": 2, "position": 2},
            ),
            "multi_row_within_hunk": (
                (0, 2),
                {
                    "side": "RIGHT",
                    "line": 3,
                    "position": 5,
                    "start_line": 1,
                    "start_side": "RIGHT",
                },
            ),
            "snap_to_single_commentable": (
                (3, 8),
                {"side": "RIGHT", "line": 9, "position": 7},
            ),
            "snap_both_ends_multi": (
                (5, 10),
                {
                    "side": "RIGHT",
                    "line": 11,
                    "position": 9,
                    "start_line": 9,
                    "start_side": "RIGHT",
                },
            ),
            "across_hunk_boundary": (
                (2, 8),
                {
                    "side": "RIGHT",
                    "line": 9,
                    "position": 7,
                    "start_line": 3,
                    "start_side": "RIGHT",
                },
            ),
            "reversed_span": (
                (2, 0),
                {
                    "side": "RIGHT",
                    "line": 3,
                    "position": 5,
                    "start_line": 1,
                    "start_side": "RIGHT",
                },
            ),
            "no_commentable_gap": ((3, 7), None),
        }

        for name, ((start_row, end_row), expected) in cases.items():
            with self.subTest(name=name):
                self.assertEqual(
                    self.line_map.comment_range(start_row, end_row), expected
                )


if __name__ == "__main__":
    unittest.main()
