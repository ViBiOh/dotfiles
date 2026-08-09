import subprocess
import unittest

try:
    from .owners import codeowners_map
except ImportError:
    from owners import codeowners_map


class ScriptedRunner:
    def __init__(self, result=None, raises=None):
        self._result = result
        self._raises = raises
        self.calls = []

    def __call__(self, args, cwd):
        self.calls.append({"args": args, "cwd": cwd})

        if self._raises is not None:
            raise self._raises

        return self._result


class CodeownersMapTest(unittest.TestCase):
    def test_parsing(self):
        cases = {
            "single_owner": (
                "a.go @team\n",
                {"a.go": "@team"},
            ),
            "multiple_owners_joined": (
                "a.go @team @other\n",
                {"a.go": "@team @other"},
            ),
            "unowned_collapses_to_empty": (
                "a.go (unowned)\n",
                {"a.go": ""},
            ),
            "blank_lines_skipped": (
                "a.go @team\n\n\nb.go @team2\n",
                {"a.go": "@team", "b.go": "@team2"},
            ),
            "path_with_no_owner_column": (
                "a.go\n",
                {"a.go": ""},
            ),
        }

        for name, (stdout, expected) in cases.items():
            with self.subTest(name):
                runner = ScriptedRunner(result=(0, stdout, ""))

                self.assertEqual(
                    codeowners_map("/repo", ["a.go"], runner=runner), expected
                )

    def test_one_call_for_every_path(self):
        runner = ScriptedRunner(result=(0, "", ""))

        codeowners_map("/repo", ["a.go", "b.go", "c.go"], runner=runner)

        self.assertEqual(len(runner.calls), 1)
        self.assertEqual(
            runner.calls[0]["args"], ["codeowners", "--", "a.go", "b.go", "c.go"]
        )
        self.assertEqual(runner.calls[0]["cwd"], "/repo")

    def test_degrades_to_empty(self):
        cases = {
            "no_paths_short_circuits": (ScriptedRunner(result=(0, "x y\n", "")), [], 0),
            "non_zero_exit": (ScriptedRunner(result=(1, "", "boom")), ["a.go"], 1),
            "binary_missing": (
                ScriptedRunner(raises=OSError("no codeowners")),
                ["a.go"],
                1,
            ),
            "timeout": (
                ScriptedRunner(raises=subprocess.TimeoutExpired("codeowners", 10)),
                ["a.go"],
                1,
            ),
        }

        for name, (runner, paths, expected_calls) in cases.items():
            with self.subTest(name):
                self.assertEqual(codeowners_map("/repo", paths, runner=runner), {})
                self.assertEqual(len(runner.calls), expected_calls)


if __name__ == "__main__":
    unittest.main()
