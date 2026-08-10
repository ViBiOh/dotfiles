import re
import unittest
from types import SimpleNamespace

try:
    from . import panel
    from .state import SESSION
except ImportError:
    import panel
    from state import SESSION


def _entry(path, additions=1, deletions=0, hunk_start=1):
    hunks = [SimpleNamespace(new_start=hunk_start)] if hunk_start else []

    return {
        "path": path,
        "additions": additions,
        "deletions": deletions,
        "is_binary": False,
        "file_diff": SimpleNamespace(hunks=hunks, is_new=False),
    }


class FakeReview:
    def __init__(self, drafts=None):
        self._drafts = drafts or []

    def drafts(self):
        return list(self._drafts)


def _rows(text):
    """The file/notes rows: everything after the header and its blank separator."""
    lines = text.splitlines()

    return lines[2:]


def _header(text):
    return text.splitlines()[0]


def _load_session(entries, threads_by_path=None, drafts=None, owners=None, title="T"):
    SESSION.reset()
    SESSION.active = True
    SESSION.root = "/repo"
    SESSION.pr = {"number": 42, "title": title}
    SESSION.files = entries
    SESSION.files_by_path = {entry["path"]: entry for entry in entries}
    SESSION.threads_by_path = threads_by_path or {}
    SESSION.owners_by_path = owners or {}
    SESSION.review = FakeReview(drafts)


class PanelTest(unittest.TestCase):
    def tearDown(self):
        SESSION.reset()

    def test_no_files_returns_none(self):
        _load_session([])

        self.assertIsNone(panel.files_panel_text())

    def test_header_and_one_row_per_file(self):
        _load_session([_entry("b.py", 3, 1, hunk_start=10), _entry("a.py", 2, 0)])

        text = panel.files_panel_text()
        rows = _rows(text)

        self.assertEqual(_header(text), "PR #42 · T · 2 files")
        self.assertEqual(text.splitlines()[1], "", "header needs a blank separator")
        # alphabetical, from SESSION.file_entries_for_panel
        self.assertIn("+2 -0", rows[0])
        self.assertIn("a.py:1", rows[0])
        self.assertIn("+3 -1", rows[1])
        self.assertIn("b.py:10", rows[1])
        self.assertTrue(text.endswith("\n"))

    def test_owners_trail_the_nav_token(self):
        _load_session([_entry("a.py")], owners={"a.py": "@team"})

        row = _rows(panel.files_panel_text())[0]

        self.assertTrue(row.endswith("  @team"))
        self.assertIn("a.py:1  @team", row)

    def test_counts_row_only_when_the_file_has_comments(self):
        cases = {
            "no_comments": ({}, [], None),
            "unresolved_only": (
                {"a.py": [{"id": "T1", "line": 5, "is_resolved": False}]},
                [],
                "(1 unresolved)",
            ),
            "pending_only": (
                {},
                [{"uid": 0, "path": "a.py", "side": "RIGHT", "line": 8}],
                "(1 pending)",
            ),
            "both": (
                {"a.py": [{"id": "T1", "line": 5, "is_resolved": False}]},
                [{"uid": 0, "path": "a.py", "side": "RIGHT", "line": 8}],
                "(1 unresolved) (1 pending)",
            ),
            "resolved_is_not_counted": (
                {"a.py": [{"id": "T1", "line": 5, "is_resolved": True}]},
                [],
                None,
            ),
        }

        for name, (threads, drafts, expected) in cases.items():
            with self.subTest(name):
                _load_session([_entry("a.py")], threads, drafts)
                rows = _rows(panel.files_panel_text())

                if expected is None:
                    self.assertEqual(len(rows), 1, rows)
                else:
                    self.assertEqual(len(rows), 2, rows)
                    self.assertIn(expected, rows[1])

    def test_pending_total_in_header(self):
        _load_session(
            [_entry("a.py"), _entry("b.py")],
            drafts=[
                {"uid": 0, "path": "a.py", "side": "RIGHT", "line": 1},
                {"uid": 1, "path": "b.py", "side": "RIGHT", "line": 2},
            ],
        )

        self.assertIn("· 2 pending", _header(panel.files_panel_text()))

    def test_counts_row_navigates_to_the_first_comment(self):
        _load_session(
            [_entry("a.py", hunk_start=1)],
            {"a.py": [{"id": "T1", "line": 30, "is_resolved": False}]},
            [{"uid": 0, "path": "a.py", "side": "RIGHT", "line": 12, "start_line": 9}],
        )

        # earliest of: unresolved thread line 30, draft range starting at 9
        self.assertIn("a.py:9", _rows(panel.files_panel_text())[1])


PATHS = ["a.py", "bbbb.py"]
MARKER = panel._OPEN_MARKER


class OpenTabMarkerTest(unittest.TestCase):
    """Rows whose file is open as a tab carry a marker the syntax file greys, along with
    the path. Both marker slots are the same width so the path column never shifts, and the
    marker must never leak into the result_file_regex nav token."""

    def tearDown(self):
        SESSION.reset()

    def test_marker_only_on_open_files(self):
        _load_session([_entry("a.py"), _entry("b.py")])

        rows = _rows(panel.files_panel_text(frozenset({"b.py"})))

        self.assertFalse(rows[0].startswith(MARKER))  # a.py closed
        self.assertIn("a.py:1", rows[0])
        self.assertTrue(rows[1].startswith(MARKER))  # b.py open
        self.assertIn("b.py:1", rows[1])

    def test_defaults_to_no_markers(self):
        _load_session([_entry("a.py")])

        self.assertNotIn(MARKER, panel.files_panel_text())

    def test_open_paths_not_in_the_pr_are_ignored(self):
        _load_session([_entry("a.py")])

        self.assertNotIn(MARKER, panel.files_panel_text(frozenset({"elsewhere.py"})))

    def test_path_column_is_aligned_whatever_the_marker(self):
        _load_session([_entry("a.py"), _entry("bbbb.py")])

        for name, open_paths in {
            "none_open": frozenset(),
            "one_open": frozenset({"a.py"}),
            "all_open": frozenset({"a.py", "bbbb.py"}),
        }.items():
            with self.subTest(name):
                rows = _rows(panel.files_panel_text(open_paths))
                starts = [row.index(path) for row, path in zip(rows, PATHS)]

                self.assertEqual(len(set(starts)), 1, rows)

    def test_notes_row_carries_the_same_marker(self):
        _load_session(
            [_entry("a.py")],
            {"a.py": [{"id": "T1", "line": 5, "is_resolved": False}]},
        )

        rows = _rows(panel.files_panel_text(frozenset({"a.py"})))

        self.assertTrue(rows[0].startswith(MARKER))
        self.assertTrue(rows[1].startswith(MARKER))
        self.assertIn("(1 unresolved)", rows[1])

    def test_marker_stays_outside_the_nav_token(self):
        # result_file_regex is ([^ \t]+):(\d+); the marker must not glue onto the path.
        _load_session([_entry("a.py")])
        row = _rows(panel.files_panel_text(frozenset({"a.py"})))[0]

        match = re.search(r"([^ \t]+):(\d+)", row)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), "a.py")
        self.assertEqual(match.group(2), "1")


class NavLineTranslationTest(unittest.TestCase):
    """The panel stores GitHub (head-commit) lines, but a click must land where the
    gutter icon is, which local edits may have moved. plugin.py injects the translation
    because it needs a view; the default is identity."""

    def tearDown(self):
        SESSION.reset()

    def test_defaults_to_the_head_line(self):
        _load_session(
            [_entry("a.py", hunk_start=383)],
            {"a.py": [{"id": "T1", "line": 383, "is_resolved": False}]},
        )

        rows = _rows(panel.files_panel_text())

        self.assertIn("a.py:383", rows[0])
        self.assertIn("a.py:383", rows[1])

    def test_translates_both_nav_targets(self):
        # The reported case: a pending comment on head line 383 sits on buffer line 411.
        _load_session(
            [_entry("a.py", hunk_start=383)],
            drafts=[{"uid": 0, "path": "a.py", "side": "RIGHT", "line": 383}],
        )

        shifted = {}

        def to_buffer_line(path, head_line):
            shifted[path] = head_line

            return head_line + 28

        rows = _rows(panel.files_panel_text(frozenset(), to_buffer_line))

        self.assertIn("a.py:411", rows[0])  # file row -> first hunk
        self.assertIn("a.py:411", rows[1])  # comment row -> the draft
        self.assertEqual(shifted, {"a.py": 383}, "head line must be passed through")

    def test_translation_is_per_path(self):
        _load_session([_entry("a.py", hunk_start=10), _entry("b.py", hunk_start=20)])

        def to_buffer_line(path, head_line):
            return head_line + (100 if path == "b.py" else 0)

        rows = _rows(panel.files_panel_text(frozenset(), to_buffer_line))

        self.assertIn("a.py:10", rows[0])
        self.assertIn("b.py:120", rows[1])

    def test_marker_and_alignment_survive_translation(self):
        _load_session([_entry("a.py", hunk_start=1)])

        row = _rows(panel.files_panel_text(frozenset({"a.py"}), lambda p, n: 4321))[0]

        self.assertTrue(row.startswith(MARKER))
        match = re.search(r"([^ \t]+):(\d+)", row)
        self.assertEqual((match.group(1), match.group(2)), ("a.py", "4321"))


class FirstCommentLineTest(unittest.TestCase):
    def tearDown(self):
        SESSION.reset()

    def test_precedence(self):
        cases = {
            "unresolved_thread_wins_over_hunk": (
                {"a.py": [{"id": "T1", "line": 20, "is_resolved": False}]},
                [],
                20,
            ),
            "multi_line_thread_counts_from_its_start": (
                {
                    "a.py": [
                        {"id": "T1", "line": 20, "start_line": 14, "is_resolved": False}
                    ]
                },
                [],
                14,
            ),
            "outdated_thread_uses_original_lines": (
                {"a.py": [{"id": "T1", "original_line": 18, "is_resolved": False}]},
                [],
                18,
            ),
            "draft_can_beat_a_thread": (
                {"a.py": [{"id": "T1", "line": 20, "is_resolved": False}]},
                [{"uid": 0, "path": "a.py", "side": "RIGHT", "line": 7}],
                7,
            ),
            "resolved_only_falls_back_to_the_resolved_thread": (
                {"a.py": [{"id": "T1", "line": 25, "is_resolved": True}]},
                [],
                25,
            ),
            "nothing_falls_back_to_the_first_hunk": ({}, [], 5),
            "left_side_draft_is_ignored": (
                {},
                [{"uid": 0, "path": "a.py", "side": "LEFT", "line": 2}],
                5,
            ),
            "draft_on_another_file_is_ignored": (
                {},
                [{"uid": 0, "path": "other.py", "side": "RIGHT", "line": 2}],
                5,
            ),
        }

        for name, (threads, drafts, expected) in cases.items():
            with self.subTest(name):
                _load_session([_entry("a.py", hunk_start=5)], threads, drafts)

                self.assertEqual(panel.first_comment_line("a.py"), expected)

    def test_first_hunk_line_defaults_to_one_without_hunks(self):
        _load_session([_entry("a.py", hunk_start=None)])

        self.assertEqual(panel.first_hunk_line("a.py"), 1)
        self.assertEqual(panel.first_hunk_line("unknown.py"), 1)

    def test_drafts_for_path_without_a_review(self):
        SESSION.reset()

        self.assertEqual(panel.drafts_for_path("a.py"), [])


if __name__ == "__main__":
    unittest.main()
