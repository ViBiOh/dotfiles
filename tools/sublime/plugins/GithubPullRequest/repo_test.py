import os
import unittest
from types import SimpleNamespace

try:
    from . import repo
    from .state import SESSION
except ImportError:
    import repo
    from state import SESSION


def _view(file_name):
    return SimpleNamespace(file_name=lambda: file_name)


class RelPathTest(unittest.TestCase):
    def setUp(self):
        SESSION.reset()
        SESSION.root = os.sep + os.path.join("repo")

    def tearDown(self):
        SESSION.reset()

    def test_cases(self):
        root = SESSION.root
        cases = {
            "inside_the_repo": (os.path.join(root, "a.py"), "a.py"),
            "nested": (os.path.join(root, "pkg", "b.py"), "pkg/b.py"),
            "outside_the_repo": (os.sep + os.path.join("other", "c.py"), None),
            "no_file": (None, None),
        }

        for name, (file_name, expected) in cases.items():
            with self.subTest(name):
                self.assertEqual(repo.rel_path(_view(file_name)), expected)

    def test_no_root_loaded(self):
        SESSION.root = None

        self.assertIsNone(repo.rel_path(_view(os.sep + "repo" + os.sep + "a.py")))

    def test_abs_path_round_trips(self):
        absolute = repo.abs_path("pkg/b.py")

        self.assertEqual(absolute, os.path.join(SESSION.root, "pkg", "b.py"))
        self.assertEqual(repo.rel_path(_view(absolute)), "pkg/b.py")


class RunGitTest(unittest.TestCase):
    def test_read_only_command_succeeds(self):
        # `git --version` needs no repository and mutates nothing.
        rc, out = repo.run_git(os.getcwd(), ["--version"])

        self.assertEqual(rc, 0)
        self.assertIn("git version", out)

    def test_failure_returns_one_and_empty(self):
        rc, out = repo.run_git(os.getcwd(), ["definitely-not-a-git-command"])

        self.assertNotEqual(rc, 0)
        self.assertEqual(out, "")

    def test_git_root_outside_a_repo(self):
        self.assertIsNone(repo.git_root(os.sep))


if __name__ == "__main__":
    unittest.main()
