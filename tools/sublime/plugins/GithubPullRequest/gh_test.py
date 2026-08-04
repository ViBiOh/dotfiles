import json
import subprocess
import unittest

try:
    from . import gh as ghmod
    from .gh import GH, GHError
except ImportError:
    import gh as ghmod
    from gh import GH, GHError


def _raiser(exc):
    def run(*args, **kwargs):
        raise exc

    return run


class DefaultRunnerTest(unittest.TestCase):
    """The real subprocess runner must degrade to a non-zero result (-> GHError)
    on timeout or exec failure instead of raising an uncaught exception."""

    def test_timeout_becomes_nonzero(self):
        original = ghmod.subprocess.run
        ghmod.subprocess.run = _raiser(subprocess.TimeoutExpired(cmd="gh", timeout=30))
        try:
            rc, out, err = ghmod._default_runner(["gh", "api", "user"], None)
        finally:
            ghmod.subprocess.run = original

        self.assertEqual(rc, 124)
        self.assertIn("timed out", err)

    def test_oserror_becomes_nonzero(self):
        original = ghmod.subprocess.run
        ghmod.subprocess.run = _raiser(FileNotFoundError("gh not found"))
        try:
            rc, out, err = ghmod._default_runner(["gh"], None)
        finally:
            ghmod.subprocess.run = original

        self.assertEqual(rc, 127)
        self.assertIn("gh not found", err)


class FakeRunner:
    """Records the args/cwd it is called with and returns a canned result."""

    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr
        self.args = None
        self.cwd = None
        self.stdin = None

    def __call__(self, args, cwd, stdin=None):
        self.args = args
        self.cwd = cwd
        self.stdin = stdin

        return self.returncode, self.stdout, self.stderr


class GHTest(unittest.TestCase):
    def test_success_cases(self):
        cases = {
            "api_get_parses_json": {
                "stdout": '{"login": "octocat"}',
                "call": lambda gh: gh.api("user"),
                "expected_args": ["gh", "api", "user"],
                "expected_return": {"login": "octocat"},
            },
            "api_get_non_json_returns_raw": {
                "stdout": "",
                "call": lambda gh: gh.api("repos/o/r/issues/1/lock", method="PUT"),
                "expected_args": ["gh", "api", "repos/o/r/issues/1/lock", "-X", "PUT"],
                "expected_return": "",
            },
            "api_patch_with_fields": {
                "stdout": '{"state": "closed"}',
                "call": lambda gh: gh.api(
                    "repos/o/r/issues/1",
                    method="PATCH",
                    fields={"state": "closed", "title": "hi"},
                ),
                "expected_args": [
                    "gh",
                    "api",
                    "repos/o/r/issues/1",
                    "-X",
                    "PATCH",
                    "-f",
                    "state=closed",
                    "-f",
                    "title=hi",
                ],
                "expected_return": {"state": "closed"},
            },
            "graphql_unwraps_data": {
                "stdout": '{"data": {"viewer": {"login": "octocat"}}}',
                "call": lambda gh: gh.graphql(
                    "query { viewer { login } }",
                    variables={"number": 5, "resolved": True, "body": "@octo hi"},
                ),
                "expected_args": [
                    "gh",
                    "api",
                    "graphql",
                    "-f",
                    "query=query { viewer { login } }",
                    "-F",
                    "number=5",
                    "-F",
                    "resolved=True",
                    "-f",
                    "body=@octo hi",
                ],
                "expected_return": {"viewer": {"login": "octocat"}},
            },
            "pr_diff_raw_text": {
                "stdout": "diff --git a/f b/f\n+added\n",
                "call": lambda gh: gh.pr_diff(),
                "expected_args": ["gh", "pr", "diff"],
                "expected_return": "diff --git a/f b/f\n+added\n",
            },
            "pr_diff_with_number": {
                "stdout": "diff --git a/f b/f\n",
                "call": lambda gh: gh.pr_diff(42),
                "expected_args": ["gh", "pr", "diff", "42"],
                "expected_return": "diff --git a/f b/f\n",
            },
            "pr_view_default_fields": {
                "stdout": '{"number": 42, "title": "T"}',
                "call": lambda gh: gh.pr_view(),
                "expected_args": [
                    "gh",
                    "pr",
                    "view",
                    "--json",
                    "number,title,baseRefName,headRefName,headRefOid,url,author,body,state",
                ],
                "expected_return": {"number": 42, "title": "T"},
            },
            "pr_view_number_and_custom_fields": {
                "stdout": '{"number": 7}',
                "call": lambda gh: gh.pr_view(7, fields=["number", "title", "state"]),
                "expected_args": [
                    "gh",
                    "pr",
                    "view",
                    "7",
                    "--json",
                    "number,title,state",
                ],
                "expected_return": {"number": 7},
            },
        }

        for name, case in cases.items():
            with self.subTest(name=name):
                runner = FakeRunner(returncode=0, stdout=case["stdout"])
                gh = GH(cwd="/repo", runner=runner)

                result = case["call"](gh)

                self.assertEqual(runner.args, case["expected_args"])
                self.assertEqual(result, case["expected_return"])
                self.assertEqual(runner.cwd, "/repo")

    def test_api_json_body(self):
        runner = FakeRunner(returncode=0, stdout='{"id": 1}')
        gh = GH(cwd="/repo", runner=runner)

        body = {"event": "COMMENT", "comments": [{"path": "a.py", "line": 3}]}
        result = gh.api("repos/o/r/pulls/1/reviews", method="POST", input_obj=body)

        self.assertEqual(
            runner.args,
            ["gh", "api", "repos/o/r/pulls/1/reviews", "-X", "POST", "--input", "-"],
        )
        self.assertEqual(json.loads(runner.stdin), body)
        self.assertEqual(result, {"id": 1})

    def test_error_cases(self):
        cases = {
            "api_non_zero_raises": {
                "returncode": 1,
                "stdout": "",
                "stderr": "gh: Not Found (HTTP 404)",
                "call": lambda gh: gh.api("repos/o/r/pulls/999"),
                "needle": "Not Found (HTTP 404)",
            },
            "graphql_non_zero_raises": {
                "returncode": 1,
                "stdout": "",
                "stderr": "gh: bad credentials",
                "call": lambda gh: gh.graphql("query { viewer { login } }"),
                "needle": "bad credentials",
            },
            "graphql_errors_payload_raises": {
                "returncode": 0,
                "stdout": json.dumps(
                    {"data": None, "errors": [{"message": "Field 'x' doesn't exist"}]}
                ),
                "stderr": "",
                "call": lambda gh: gh.graphql("query { x }"),
                "needle": "Field 'x' doesn't exist",
            },
            "pr_diff_non_zero_raises": {
                "returncode": 1,
                "stdout": "",
                "stderr": "no pull requests found",
                "call": lambda gh: gh.pr_diff(),
                "needle": "no pull requests found",
            },
            "pr_view_non_zero_raises": {
                "returncode": 1,
                "stdout": "",
                "stderr": "no default remote",
                "call": lambda gh: gh.pr_view(),
                "needle": "no default remote",
            },
        }

        for name, case in cases.items():
            with self.subTest(name=name):
                runner = FakeRunner(
                    returncode=case["returncode"],
                    stdout=case["stdout"],
                    stderr=case["stderr"],
                )
                gh = GH(runner=runner)

                with self.assertRaises(GHError) as ctx:
                    case["call"](gh)

                self.assertIn(case["needle"], str(ctx.exception))

    def test_cwd_defaults_to_none(self):
        runner = FakeRunner(returncode=0, stdout="{}")
        gh = GH(runner=runner)

        gh.api("user")

        self.assertIsNone(runner.cwd)


if __name__ == "__main__":
    unittest.main()
