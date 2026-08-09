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
        lines = text.splitlines()

        self.assertEqual(lines[0], "PR #42 · T · 2 files")
        # alphabetical, from SESSION.file_entries_for_panel
        self.assertIn("+2 -0", lines[1])
        self.assertIn("a.py:1", lines[1])
        self.assertIn("+3 -1", lines[2])
        self.assertIn("b.py:10", lines[2])
        self.assertTrue(text.endswith("\n"))

    def test_owners_trail_the_nav_token(self):
        _load_session([_entry("a.py")], owners={"a.py": "@team"})

        row = panel.files_panel_text().splitlines()[1]

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
                lines = panel.files_panel_text().splitlines()

                if expected is None:
                    self.assertEqual(len(lines), 2, lines)
                else:
                    self.assertEqual(len(lines), 3, lines)
                    self.assertIn(expected, lines[2])

    def test_pending_total_in_header(self):
        _load_session(
            [_entry("a.py"), _entry("b.py")],
            drafts=[
                {"uid": 0, "path": "a.py", "side": "RIGHT", "line": 1},
                {"uid": 1, "path": "b.py", "side": "RIGHT", "line": 2},
            ],
        )

        self.assertIn("· 2 pending", panel.files_panel_text().splitlines()[0])

    def test_counts_row_navigates_to_the_first_comment(self):
        _load_session(
            [_entry("a.py", hunk_start=1)],
            {"a.py": [{"id": "T1", "line": 30, "is_resolved": False}]},
            [{"uid": 0, "path": "a.py", "side": "RIGHT", "line": 12, "start_line": 9}],
        )

        # earliest of: unresolved thread line 30, draft range starting at 9
        self.assertIn("a.py:9", panel.files_panel_text().splitlines()[2])


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
