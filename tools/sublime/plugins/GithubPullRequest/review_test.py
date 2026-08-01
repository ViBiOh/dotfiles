import json
import unittest

try:
    from .gh import GH
    from .review import Review
except ImportError:
    from gh import GH
    from review import Review


_PR_VIEW = {
    "number": 42,
    "title": "Add feature",
    "baseRefName": "main",
    "headRefName": "feature",
    "headRefOid": "deadbeef",
    "url": "https://github.com/octo/repo/pull/42",
}

_DIFF = (
    "diff --git a/foo.py b/foo.py\n"
    "--- a/foo.py\n"
    "+++ b/foo.py\n"
    "@@ -1,2 +1,3 @@\n"
    " ctx\n"
    "+added one\n"
    "+added two\n"
    "-removed\n"
)

_THREADS_PAGE_1 = {
    "repository": {
        "pullRequest": {
            "reviewThreads": {
                "pageInfo": {"hasNextPage": True, "endCursor": "CURSOR1"},
                "nodes": [
                    {
                        "id": "T1",
                        "isResolved": False,
                        "isOutdated": False,
                        "path": "foo.py",
                        "line": 3,
                        "originalLine": 3,
                        "startLine": None,
                        "diffSide": "RIGHT",
                        "comments": {
                            "nodes": [
                                {
                                    "author": {"login": "alice"},
                                    "body": "nit",
                                    "createdAt": "2026-01-01T00:00:00Z",
                                    "url": "https://github.com/octo/repo/pull/42#c1",
                                    "diffHunk": "@@ -1,2 +1,3 @@",
                                }
                            ]
                        },
                    }
                ],
            }
        }
    }
}

_THREADS_PAGE_2 = {
    "repository": {
        "pullRequest": {
            "reviewThreads": {
                "pageInfo": {"hasNextPage": False, "endCursor": "CURSOR2"},
                "nodes": [
                    {
                        "id": "T2",
                        "isResolved": True,
                        "isOutdated": True,
                        "path": "bar.py",
                        "line": None,
                        "originalLine": 10,
                        "startLine": 8,
                        "diffSide": "LEFT",
                        "comments": {
                            "nodes": [
                                {
                                    "author": None,
                                    "body": "old",
                                    "createdAt": "2026-01-02T00:00:00Z",
                                    "url": "https://github.com/octo/repo/pull/42#c2",
                                    "diffHunk": "@@ -8,2 +8,0 @@",
                                }
                            ]
                        },
                    }
                ],
            }
        }
    }
}


class ScriptedGH:
    """A gh runner that dispatches canned results by matching the args list.

    Records every invocation (args + stdin) so tests can assert on the JSON
    body piped to `gh api --input -`."""

    def __init__(self, **canned):
        self._canned = canned
        self.calls = []
        self._graphql_pages = list(canned.get("graphql_pages", []))

    def __call__(self, args, cwd, stdin=None):
        self.calls.append({"args": args, "stdin": stdin})

        if "graphql" in args:
            if self._graphql_pages:
                return 0, self._graphql_pages.pop(0), ""

            return 0, self._canned.get("graphql", "{}"), ""

        if args[:3] == ["gh", "pr", "view"]:
            return 0, self._canned.get("pr_view", "{}"), ""

        if args[:3] == ["gh", "pr", "diff"]:
            return 0, self._canned.get("pr_diff", ""), ""

        if args[:2] == ["gh", "api"]:
            return 0, self._canned.get("api", "{}"), ""

        return 1, "", "unexpected gh call: {}".format(args)


class ScriptedGit:
    """A git runner that dispatches canned (rc, stdout, stderr) by args match."""

    def __init__(self, responses=None):
        self._responses = responses or {}
        self.calls = []

    def __call__(self, args, cwd, stdin=None):
        self.calls.append(args)

        if "merge-base" in args:
            ref = args[-1]
            key = "merge-base:{}".format(ref)
            if key in self._responses:
                return self._responses[key]

        if "show" in args:
            key = "show:{}".format(args[-1])
            if key in self._responses:
                return self._responses[key]

        return 1, "", "unexpected git call: {}".format(args)


def _make_review(gh_runner, git_runner):
    gh = GH(cwd="/repo", runner=gh_runner)

    return Review(gh, "/repo", git_runner=git_runner)


class ResolvePRTest(unittest.TestCase):
    def test_resolve_pr(self):
        cases = {
            "from_current_branch": {
                "expect_view_args": ["gh", "pr", "view", "--json"],
            },
        }

        for name, case in cases.items():
            with self.subTest(name=name):
                gh_runner = ScriptedGH(pr_view=json.dumps(_PR_VIEW))
                review = _make_review(gh_runner, ScriptedGit())

                result = review.resolve_pr()

                self.assertEqual(
                    gh_runner.calls[0]["args"][: len(case["expect_view_args"])],
                    case["expect_view_args"],
                )
                self.assertEqual(result["number"], 42)
                self.assertEqual(result["title"], "Add feature")
                self.assertEqual(result["base"], "main")
                self.assertEqual(result["head"], "feature")
                self.assertEqual(result["head_oid"], "deadbeef")
                self.assertEqual(result["owner"], "octo")
                self.assertEqual(result["repo"], "repo")


class MergeBaseTest(unittest.TestCase):
    def test_merge_base(self):
        cases = {
            "primary_success": {
                "responses": {"merge-base:origin/main": (0, "abc123\n", "")},
                "expected": "abc123",
                "expected_last_ref": "origin/main",
            },
            "fallback_to_local_ref": {
                "responses": {
                    "merge-base:origin/main": (1, "", "no origin"),
                    "merge-base:main": (0, "def456\n", ""),
                },
                "expected": "def456",
                "expected_last_ref": "main",
            },
            "fallback_to_base_name": {
                "responses": {
                    "merge-base:origin/main": (1, "", "no origin"),
                    "merge-base:main": (1, "", "no ref"),
                },
                "expected": "main",
                "expected_last_ref": "main",
            },
        }

        for name, case in cases.items():
            with self.subTest(name=name):
                git_runner = ScriptedGit(responses=case["responses"])
                review = _make_review(
                    ScriptedGH(pr_view=json.dumps(_PR_VIEW)), git_runner
                )
                review.resolve_pr()

                result = review.merge_base()

                self.assertEqual(result, case["expected"])
                self.assertEqual(git_runner.calls[-1][-1], case["expected_last_ref"])

    def test_merge_base_cached(self):
        git_runner = ScriptedGit(
            responses={"merge-base:origin/main": (0, "abc123\n", "")}
        )
        review = _make_review(ScriptedGH(pr_view=json.dumps(_PR_VIEW)), git_runner)
        review.resolve_pr()

        review.merge_base()
        review.merge_base()

        merge_base_calls = [c for c in git_runner.calls if "merge-base" in c]
        self.assertEqual(len(merge_base_calls), 1)


class ChangedFilesTest(unittest.TestCase):
    def test_changed_files(self):
        gh_runner = ScriptedGH(pr_view=json.dumps(_PR_VIEW), pr_diff=_DIFF)
        review = _make_review(gh_runner, ScriptedGit())
        review.resolve_pr()

        files = review.changed_files()

        self.assertEqual(len(files), 1)
        entry = files[0]
        self.assertEqual(entry["path"], "foo.py")
        self.assertEqual(entry["additions"], 2)
        self.assertEqual(entry["deletions"], 1)
        self.assertFalse(entry["is_binary"])
        self.assertEqual(entry["file_diff"].path, "foo.py")


class ReviewThreadsTest(unittest.TestCase):
    def test_paginated_mapping(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                json.dumps({"data": _THREADS_PAGE_1}),
                json.dumps({"data": _THREADS_PAGE_2}),
            ],
        )
        review = _make_review(gh_runner, ScriptedGit())
        review.resolve_pr()

        threads = review.review_threads()

        self.assertEqual(len(threads), 2)

        first = threads[0]
        self.assertEqual(first["id"], "T1")
        self.assertEqual(first["side"], "RIGHT")
        self.assertEqual(first["line"], 3)
        self.assertFalse(first["is_resolved"])
        self.assertEqual(first["url"], "https://github.com/octo/repo/pull/42#c1")
        self.assertEqual(first["comments"][0]["author"], "alice")
        self.assertEqual(first["comments"][0]["diff_hunk"], "@@ -1,2 +1,3 @@")

        second = threads[1]
        self.assertEqual(second["id"], "T2")
        self.assertEqual(second["side"], "LEFT")
        self.assertIsNone(second["line"])
        self.assertEqual(second["start_line"], 8)
        self.assertTrue(second["is_resolved"])
        self.assertTrue(second["is_outdated"])
        self.assertEqual(second["comments"][0]["author"], "ghost")

    def test_pagination_passes_cursor(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                json.dumps({"data": _THREADS_PAGE_1}),
                json.dumps({"data": _THREADS_PAGE_2}),
            ],
        )
        review = _make_review(gh_runner, ScriptedGit())
        review.resolve_pr()

        review.review_threads()

        graphql_calls = [c for c in gh_runner.calls if "graphql" in c["args"]]
        self.assertEqual(len(graphql_calls), 2)

        first_args = graphql_calls[0]["args"]
        self.assertNotIn("cursor=CURSOR1", first_args)

        second_args = graphql_calls[1]["args"]
        self.assertIn("cursor=CURSOR1", second_args)


class BaseBlobTest(unittest.TestCase):
    def test_base_blob(self):
        cases = {
            "found": {
                "responses": {
                    "merge-base:origin/main": (0, "abc123\n", ""),
                    "show:abc123:foo.py": (0, "file contents\n", ""),
                },
                "path": "foo.py",
                "expected": "file contents\n",
            },
            "not_found": {
                "responses": {
                    "merge-base:origin/main": (0, "abc123\n", ""),
                    "show:abc123:new.py": (1, "", "does not exist"),
                },
                "path": "new.py",
                "expected": None,
            },
        }

        for name, case in cases.items():
            with self.subTest(name=name):
                git_runner = ScriptedGit(responses=case["responses"])
                review = _make_review(
                    ScriptedGH(pr_view=json.dumps(_PR_VIEW)), git_runner
                )
                review.resolve_pr()

                result = review.base_blob(case["path"])

                self.assertEqual(result, case["expected"])


class DraftQueueTest(unittest.TestCase):
    def test_queue_comment(self):
        cases = {
            "single_line": {
                "payload": {"side": "RIGHT", "line": 5},
                "expected": {
                    "path": "foo.py",
                    "body": "hi",
                    "side": "RIGHT",
                    "line": 5,
                },
            },
            "multi_line": {
                "payload": {
                    "side": "RIGHT",
                    "line": 8,
                    "start_line": 5,
                    "start_side": "RIGHT",
                },
                "expected": {
                    "path": "foo.py",
                    "body": "range",
                    "side": "RIGHT",
                    "line": 8,
                    "start_line": 5,
                    "start_side": "RIGHT",
                },
            },
        }

        for name, case in cases.items():
            with self.subTest(name=name):
                review = _make_review(ScriptedGH(), ScriptedGit())

                review.queue_comment(
                    "foo.py", case["payload"], case["expected"]["body"]
                )

                self.assertEqual(review.drafts(), [case["expected"]])

    def test_drafts_returns_copy(self):
        review = _make_review(ScriptedGH(), ScriptedGit())
        review.queue_comment("foo.py", {"side": "RIGHT", "line": 1}, "b")

        got = review.drafts()
        got.append("mutated")

        self.assertEqual(len(review.drafts()), 1)

    def test_discard_and_clear(self):
        review = _make_review(ScriptedGH(), ScriptedGit())
        review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")
        review.queue_comment("b.py", {"side": "RIGHT", "line": 2}, "two")

        review.discard_draft(0)
        self.assertEqual(len(review.drafts()), 1)
        self.assertEqual(review.drafts()[0]["path"], "b.py")

        review.clear_drafts()
        self.assertEqual(review.drafts(), [])


class SubmitReviewTest(unittest.TestCase):
    def test_submit_builds_payload_and_clears(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            api=json.dumps({"id": 999, "state": "PENDING"}),
        )
        review = _make_review(gh_runner, ScriptedGit())
        review.resolve_pr()

        review.queue_comment("foo.py", {"side": "RIGHT", "line": 5}, "single")
        review.queue_comment(
            "bar.py",
            {"side": "RIGHT", "line": 8, "start_line": 5, "start_side": "RIGHT"},
            "range",
        )

        result = review.submit_review("REQUEST_CHANGES", body="please fix")

        self.assertEqual(result, {"id": 999, "state": "PENDING"})

        api_calls = [c for c in gh_runner.calls if c["args"][:2] == ["gh", "api"]]
        self.assertEqual(len(api_calls), 1)

        args = api_calls[0]["args"]
        self.assertEqual(
            args,
            [
                "gh",
                "api",
                "repos/octo/repo/pulls/42/reviews",
                "-X",
                "POST",
                "--input",
                "-",
            ],
        )

        body = json.loads(api_calls[0]["stdin"])
        self.assertEqual(
            body,
            {
                "event": "REQUEST_CHANGES",
                "body": "please fix",
                "comments": [
                    {
                        "path": "foo.py",
                        "line": 5,
                        "side": "RIGHT",
                        "body": "single",
                    },
                    {
                        "path": "bar.py",
                        "line": 8,
                        "side": "RIGHT",
                        "body": "range",
                        "start_line": 5,
                        "start_side": "RIGHT",
                    },
                ],
            },
        )

        self.assertEqual(review.drafts(), [])

    def test_invalid_verdict_asserts(self):
        review = _make_review(ScriptedGH(pr_view=json.dumps(_PR_VIEW)), ScriptedGit())
        review.resolve_pr()

        with self.assertRaises(AssertionError):
            review.submit_review("MERGE")


class ReplyAndResolveTest(unittest.TestCase):
    def test_reply_comment(self):
        gh_runner = ScriptedGH(
            graphql=json.dumps(
                {"data": {"addPullRequestReviewThreadReply": {"comment": {"id": "c9"}}}}
            )
        )
        review = _make_review(gh_runner, ScriptedGit())

        result = review.reply_comment("T1", "thanks")

        self.assertEqual(
            result, {"addPullRequestReviewThreadReply": {"comment": {"id": "c9"}}}
        )

        args = gh_runner.calls[0]["args"]
        query = args[args.index("-f") + 1]
        self.assertIn("addPullRequestReviewThreadReply", query)
        self.assertIn("id=T1", args)
        self.assertIn("body=thanks", args)

    def test_set_thread_resolved(self):
        cases = {
            "resolve": {
                "resolved": True,
                "starts_with": "resolveReviewThread",
            },
            "unresolve": {
                "resolved": False,
                "starts_with": "unresolveReviewThread",
            },
        }

        for name, case in cases.items():
            with self.subTest(name=name):
                gh_runner = ScriptedGH(
                    graphql=json.dumps(
                        {"data": {"thread": {"id": "T1", "isResolved": True}}}
                    )
                )
                review = _make_review(gh_runner, ScriptedGit())

                review.set_thread_resolved("T1", case["resolved"])

                args = gh_runner.calls[0]["args"]
                query = args[args.index("-f") + 1]
                mutation_body = query.split("mutation($id:ID!){", 1)[1].strip()
                self.assertTrue(mutation_body.startswith(case["starts_with"]))
                self.assertIn("id=T1", args)


if __name__ == "__main__":
    unittest.main()
