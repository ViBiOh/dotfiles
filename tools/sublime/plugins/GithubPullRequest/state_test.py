"""The SESSION singleton. Panel tests drive it incidentally; these pin its own contract,
since every command reads it and `reset` is what End review relies on to leave no trace."""

import unittest

try:
    from .state import SESSION
except ImportError:
    from state import SESSION


class FakeReview:
    def __init__(self, drafts):
        self._drafts = drafts

    def drafts(self):
        return list(self._drafts)


def _thread(resolved=False):
    return {"is_resolved": resolved}


def _entry(path, additions=1, deletions=0):
    return {"path": path, "additions": additions, "deletions": deletions}


class SessionTest(unittest.TestCase):
    def setUp(self):
        SESSION.reset()

    def tearDown(self):
        SESSION.reset()

    def test_reset_clears_everything(self):
        SESSION.active = True
        SESSION.root = "/repo"
        SESSION.pr = {"number": 1}
        SESSION.review = FakeReview([])
        SESSION.files = [_entry("a.py")]
        SESSION.files_by_path = {"a.py": _entry("a.py")}
        SESSION.threads_by_path = {"a.py": [_thread()]}
        SESSION.line_maps = {"a.py": object()}
        SESSION.base_blob_cache = {"a.py": "x"}
        SESSION.base_blob_pending = {"a.py"}
        SESSION.owners_by_path = {"a.py": "@team"}

        SESSION.reset()

        self.assertFalse(SESSION.active)
        self.assertIsNone(SESSION.root)
        self.assertIsNone(SESSION.pr)
        self.assertIsNone(SESSION.review)
        self.assertEqual(SESSION.files, [])
        self.assertEqual(SESSION.files_by_path, {})
        self.assertEqual(SESSION.threads_by_path, {})
        self.assertEqual(SESSION.line_maps, {})
        self.assertEqual(SESSION.base_blob_cache, {})
        self.assertEqual(SESSION.base_blob_pending, set())
        self.assertEqual(SESSION.owners_by_path, {})

    def test_unresolved_count(self):
        SESSION.threads_by_path = {
            "a.py": [_thread(), _thread(resolved=True), _thread()],
            "b.py": [_thread(resolved=True)],
        }

        cases = {"some": ("a.py", 2), "none_left": ("b.py", 0), "unknown": ("z.py", 0)}

        for name, (path, expected) in cases.items():
            with self.subTest(name):
                self.assertEqual(SESSION.unresolved_count(path), expected)

    def test_pending_by_path(self):
        SESSION.review = FakeReview(
            [{"path": "a.py"}, {"path": "a.py"}, {"path": "b.py"}]
        )

        self.assertEqual(SESSION.pending_by_path(), {"a.py": 2, "b.py": 1})

    def test_pending_by_path_without_a_review(self):
        self.assertEqual(SESSION.pending_by_path(), {})

    def test_file_entries_are_sorted_and_enriched(self):
        SESSION.files = [_entry("z.py"), _entry("a.py")]
        SESSION.threads_by_path = {"a.py": [_thread(), _thread(resolved=True)]}
        SESSION.owners_by_path = {"a.py": "@team"}
        SESSION.review = FakeReview([{"path": "z.py"}])

        entries = SESSION.file_entries_for_panel()

        self.assertEqual([e["path"] for e in entries], ["a.py", "z.py"])
        self.assertEqual(entries[0]["unresolved"], 1)
        self.assertEqual(entries[0]["pending"], 0)
        self.assertEqual(entries[0]["owners"], "@team")
        self.assertEqual(entries[1]["unresolved"], 0)
        self.assertEqual(entries[1]["pending"], 1)
        self.assertEqual(entries[1]["owners"], "")

    def test_file_entries_do_not_mutate_the_originals(self):
        # The panel enriches copies; writing through would leak counts into SESSION.files
        # and they would go stale the moment a draft is queued.
        SESSION.files = [_entry("a.py")]

        SESSION.file_entries_for_panel()

        self.assertNotIn("unresolved", SESSION.files[0])
        self.assertNotIn("pending", SESSION.files[0])
        self.assertNotIn("owners", SESSION.files[0])


if __name__ == "__main__":
    unittest.main()
