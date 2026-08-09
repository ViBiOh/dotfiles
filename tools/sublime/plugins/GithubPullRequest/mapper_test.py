import difflib
import unittest
from types import SimpleNamespace

try:
    from .mapper import LineMap, head_anchor, head_row_to_buffer_row
except ImportError:
    from mapper import LineMap, head_anchor, head_row_to_buffer_row


def _line(origin, old_lineno, new_lineno, content):
    return SimpleNamespace(
        origin=origin,
        old_lineno=old_lineno,
        new_lineno=new_lineno,
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
            _line(" ", 1, 1, "alpha"),
            _line("+", None, 2, "beta-added"),
            _line("-", 2, None, "gamma-removed"),
            _line("-", 3, None, "delta-removed"),
            _line(" ", 4, 3, "epsilon"),
        ]
    )
    hunk2 = SimpleNamespace(
        lines=[
            _line(" ", 10, 9, "zeta"),
            _line("+", None, 10, "eta-added"),
            _line(" ", 11, 11, "theta"),
        ]
    )
    hunk3 = SimpleNamespace(
        lines=[
            _line(" ", 20, 21, "iota"),
            _line("-", 21, None, "kappa-removed"),
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
                {"side": "RIGHT", "line": 2},
            ),
            "multi_row_within_hunk": (
                (0, 2),
                {
                    "side": "RIGHT",
                    "line": 3,
                    "start_line": 1,
                    "start_side": "RIGHT",
                },
            ),
            "snap_to_single_commentable": (
                (3, 8),
                {"side": "RIGHT", "line": 9},
            ),
            "snap_both_ends_multi": (
                (5, 10),
                {
                    "side": "RIGHT",
                    "line": 11,
                    "start_line": 9,
                    "start_side": "RIGHT",
                },
            ),
            "across_hunk_boundary": (
                (2, 8),
                {
                    "side": "RIGHT",
                    "line": 9,
                    "start_line": 3,
                    "start_side": "RIGHT",
                },
            ),
            "reversed_span": (
                (2, 0),
                {
                    "side": "RIGHT",
                    "line": 3,
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


def _opcodes(committed, buffer_text):
    """Real difflib opcodes, committed file as `a` and live buffer as `b`, exactly as
    plugin._head_opcodes builds them."""
    return difflib.SequenceMatcher(
        None, committed.splitlines(), buffer_text.splitlines(), autojunk=False
    ).get_opcodes()


_COMMITTED = "one\ntwo\nthree\nfour\nfive\n"


class HeadAnchorTest(unittest.TestCase):
    """A local edit under the cursor must be detected (has_edit) so the compose buffer
    is prefilled with a ```suggestion```, and the selection must map onto the head rows
    the edit replaces so GitHub can apply it."""

    def test_local_edits(self):
        # (buffer text, selected buffer rows) -> (head_start, head_end, has_edit)
        cases = {
            "untouched buffer, one row": (
                _COMMITTED,
                (2, 2),
                (2, 2, False),
            ),
            "untouched buffer, range": (
                _COMMITTED,
                (1, 3),
                (1, 3, False),
            ),
            "replaced line under cursor": (
                "one\ntwo\nCHANGED\nfour\nfive\n",
                (2, 2),
                (2, 2, True),
            ),
            "inserted line under cursor": (
                "one\ntwo\nNEW\nthree\nfour\nfive\n",
                (2, 2),
                (None, None, True),
            ),
            # A deletion is zero-width in the buffer: the classic overlap test misses
            # it entirely, which silently disabled suggestion prefill for line removal.
            "deleted line, cursor on the line that took its place": (
                "one\ntwo\nfour\nfive\n",
                (2, 2),
                (2, 3, True),
            ),
            "deleted line, cursor on the line above it": (
                "one\ntwo\nfour\nfive\n",
                (1, 1),
                (1, 2, True),
            ),
            "deleted first line, cursor at top": (
                "two\nthree\nfour\nfive\n",
                (0, 0),
                (0, 1, True),
            ),
            "deleted last line, cursor on the new last line": (
                "one\ntwo\nthree\nfour\n",
                (3, 3),
                (3, 4, True),
            ),
            "deleted block, selection spanning it": (
                "one\nfive\n",
                (0, 1),
                (0, 4, True),
            ),
            "deletion far away is not picked up": (
                "one\ntwo\nfour\nfive\n",
                (3, 3),
                (4, 4, False),
            ),
        }

        for name, (buffer_text, (start_row, end_row), expected) in cases.items():
            with self.subTest(name):
                opcodes = _opcodes(_COMMITTED, buffer_text)

                self.assertEqual(head_anchor(opcodes, start_row, end_row), expected)

    def test_deleted_head_rows_are_commentable_targets(self):
        """The deleted head lines must land in the anchor range, otherwise the comment
        targets the wrong lines and the suggestion cannot remove anything."""
        opcodes = _opcodes(_COMMITTED, "one\ntwo\nfive\n")

        head_start, head_end, has_edit = head_anchor(opcodes, 2, 2)

        self.assertTrue(has_edit)
        # head rows 2..3 ("three", "four") were removed; row 4 ("five") is the cursor.
        self.assertEqual((head_start, head_end), (2, 4))


class HeadRowToBufferRowTest(unittest.TestCase):
    def test_mapping(self):
        cases = {
            "identical buffer": (_COMMITTED, 3, 3),
            "after a local insertion": ("NEW\none\ntwo\nthree\nfour\nfive\n", 0, 1),
            "after a local deletion": ("one\nthree\nfour\nfive\n", 3, 2),
            "a deleted row anchors to its block start": (
                "one\nthree\nfour\nfive\n",
                1,
                1,
            ),
            "out of range": (_COMMITTED, 99, None),
        }

        for name, (buffer_text, head_row, expected) in cases.items():
            with self.subTest(name):
                opcodes = _opcodes(_COMMITTED, buffer_text)

                self.assertEqual(head_row_to_buffer_row(opcodes, head_row), expected)


if __name__ == "__main__":
    unittest.main()
