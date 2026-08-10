import json
import unittest

try:
    from .gh import GH, GHError
    from .review import CommentRejected, Review
except ImportError:
    from gh import GH, GHError
    from review import CommentRejected, Review


_PR_VIEW = {
    "number": 42,
    "title": "Add feature",
    "baseRefName": "main",
    "headRefName": "feature",
    "headRefOid": "deadbeef",
    "url": "https://github.com/octo/repo/pull/42",
    "state": "OPEN",
    "body": "Adds the thing.\r\n\r\nFixes #7.\n",
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
                        "originalStartLine": None,
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
                        "startLine": None,
                        "originalStartLine": 8,
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

        return 1, "", f"unexpected gh call: {args}"


class ScriptedGit:
    """A git runner that dispatches canned (rc, stdout, stderr) by args match."""

    def __init__(self, responses=None):
        self._responses = responses or {}
        self.calls = []

    def __call__(self, args, cwd, stdin=None):
        self.calls.append(args)

        if "merge-base" in args:
            ref = args[-1]
            key = f"merge-base:{ref}"
            if key in self._responses:
                return self._responses[key]

        if "show" in args:
            key = f"show:{args[-1]}"
            if key in self._responses:
                return self._responses[key]

        return 1, "", f"unexpected git call: {args}"


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
                self.assertEqual(result["owner"], "octo")
                self.assertEqual(result["repo"], "repo")
                self.assertEqual(result["state"], "OPEN")
                # kept verbatim so the host survives (GitHub Enterprise)
                self.assertEqual(result["url"], "https://github.com/octo/repo/pull/42")
                # the revision every line mapping is computed against
                self.assertEqual(result["head_oid"], "deadbeef")
                # stored raw; the panel is what normalises CRLF and trailing blanks
                self.assertEqual(result["body"], "Adds the thing.\r\n\r\nFixes #7.\n")


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
        self.assertIsNone(first["start_line"])
        self.assertFalse(first["is_resolved"])
        self.assertEqual(first["url"], "https://github.com/octo/repo/pull/42#c1")
        self.assertEqual(first["comments"][0]["author"], "alice")

        second = threads[1]
        self.assertEqual(second["id"], "T2")
        self.assertEqual(second["side"], "LEFT")
        self.assertIsNone(second["line"])
        self.assertEqual(second["original_line"], 10)
        # An outdated multi-line thread keeps its range only on the original_* fields;
        # both ends must survive the mapping or the range collapses to a single line.
        self.assertIsNone(second["start_line"])
        self.assertEqual(second["original_start_line"], 8)
        self.assertTrue(second["is_resolved"])
        self.assertTrue(second["is_outdated"])
        self.assertEqual(second["comments"][0]["author"], "ghost")

    def test_skips_viewer_pending_draft_threads(self):
        # A not-yet-submitted draft comes back from reviewThreads with state PENDING;
        # it must be skipped here (it is shown via the pending-review mirror instead).
        page = {
            "repository": {
                "pullRequest": {
                    "reviewThreads": {
                        "pageInfo": {"hasNextPage": False, "endCursor": None},
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
                                            "author": {"login": "octo"},
                                            "body": "draft",
                                            "createdAt": "2026-01-01T00:00:00Z",
                                            "url": "",
                                            "diffHunk": "",
                                            "state": "PENDING",
                                        }
                                    ]
                                },
                            },
                            {
                                "id": "T2",
                                "isResolved": False,
                                "isOutdated": False,
                                "path": "foo.py",
                                "line": 4,
                                "originalLine": 4,
                                "startLine": None,
                                "diffSide": "RIGHT",
                                "comments": {
                                    "nodes": [
                                        {
                                            "author": {"login": "alice"},
                                            "body": "posted",
                                            "createdAt": "2026-01-01T00:00:00Z",
                                            "url": "",
                                            "diffHunk": "",
                                            "state": "SUBMITTED",
                                        }
                                    ]
                                },
                            },
                        ],
                    }
                }
            }
        }
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[json.dumps({"data": page})],
        )
        review = _make_review(gh_runner, ScriptedGit())
        review.resolve_pr()

        threads = review.review_threads()

        self.assertEqual([t["id"] for t in threads], ["T2"])

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


def _wrap(data):
    return json.dumps({"data": data})


_PENDING_EMPTY = _wrap(
    {
        "viewer": {"login": "octo"},
        "repository": {"pullRequest": {"id": "PR1", "reviews": {"nodes": []}}},
    }
)
_ADD_REVIEW = _wrap({"addPullRequestReview": {"pullRequestReview": {"id": "REV1"}}})
_DELETE_COMMENT = _wrap(
    {"deletePullRequestReviewComment": {"pullRequestReviewComment": {"id": "C1"}}}
)
_DELETE_REVIEW = _wrap(
    {"deletePullRequestReview": {"pullRequestReview": {"id": "REV1"}}}
)
_SUBMIT = _wrap(
    {
        "submitPullRequestReview": {
            "pullRequestReview": {"id": "REV1", "state": "PENDING"}
        }
    }
)
# A GraphQL error payload makes gh.graphql raise GHError (simulates API/network down).
_GRAPHQL_ERROR = json.dumps({"errors": [{"message": "network unavailable"}]})
# GitHub answers 200 with a null thread and no errors when it refuses to anchor a
# comment (a line the PR diff does not carry). Verified against the real API.
_ADD_THREAD_REFUSED = _wrap({"addPullRequestReviewThread": {"thread": None}})


def _add_thread(comment_id):
    return _wrap(
        {
            "addPullRequestReviewThread": {
                "thread": {"comments": {"nodes": [{"id": comment_id}]}}
            }
        }
    )


def _graphql_queries(gh_runner):
    """The `query=` payloads of every graphql call, in order."""
    out = []
    for call in gh_runner.calls:
        if "graphql" not in call["args"]:
            continue
        for arg in call["args"]:
            if arg.startswith("query="):
                out.append(arg)

    return out


def _loaded_review(gh_runner):
    review = _make_review(gh_runner, ScriptedGit())
    review.resolve_pr()
    review.load_pending()

    return review


class LoadPendingTest(unittest.TestCase):
    def test_restores_drafts_from_pending_review(self):
        pending = _wrap(
            {
                "viewer": {"login": "octo"},
                "repository": {
                    "pullRequest": {
                        "id": "PR1",
                        "reviews": {
                            "nodes": [
                                {
                                    "id": "REV1",
                                    "viewerDidAuthor": True,
                                    "comments": {
                                        "nodes": [
                                            {
                                                "id": "C1",
                                                "path": "foo.py",
                                                "line": 5,
                                                "startLine": None,
                                                "body": "restored one",
                                            },
                                            {
                                                "id": "C2",
                                                "path": "bar.py",
                                                "line": 8,
                                                "startLine": 5,
                                                "body": "restored range",
                                            },
                                        ]
                                    },
                                }
                            ]
                        },
                    }
                },
            }
        )
        gh_runner = ScriptedGH(pr_view=json.dumps(_PR_VIEW), graphql_pages=[pending])
        review = _loaded_review(gh_runner)

        self.assertEqual(
            review.drafts(),
            [
                {
                    "uid": 0,
                    "comment_id": "C1",
                    "path": "foo.py",
                    "body": "restored one",
                    "side": "RIGHT",
                    "line": 5,
                },
                {
                    "uid": 1,
                    "comment_id": "C2",
                    "path": "bar.py",
                    "body": "restored range",
                    "side": "RIGHT",
                    "line": 8,
                    "start_line": 5,
                    "start_side": "RIGHT",
                },
            ],
        )

    def test_no_pending_review_leaves_empty(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW), graphql_pages=[_PENDING_EMPTY]
        )
        review = _loaded_review(gh_runner)

        self.assertEqual(review.drafts(), [])


class DraftQueueTest(unittest.TestCase):
    def test_queue_creates_review_then_thread(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY, _ADD_REVIEW, _add_thread("C1")],
        )
        review = _loaded_review(gh_runner)

        review.queue_comment("foo.py", {"side": "RIGHT", "line": 5}, "hi")

        self.assertEqual(
            review.drafts(),
            [
                {
                    "uid": 0,
                    "path": "foo.py",
                    "body": "hi",
                    "side": "RIGHT",
                    "line": 5,
                    "comment_id": "C1",
                }
            ],
        )
        queries = _graphql_queries(gh_runner)
        self.assertTrue(any("addPullRequestReview(" in q for q in queries))
        self.assertTrue(any("addPullRequestReviewThread(" in q for q in queries))

    def test_second_queue_reuses_review(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _add_thread("C1"),
                _add_thread("C2"),
            ],
        )
        review = _loaded_review(gh_runner)

        review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")
        review.queue_comment(
            "b.py",
            {"side": "RIGHT", "line": 8, "start_line": 5, "start_side": "RIGHT"},
            "range",
        )

        self.assertEqual(len(review.drafts()), 2)
        self.assertEqual(review.drafts()[1]["start_line"], 5)
        # addPullRequestReview created exactly once.
        queries = _graphql_queries(gh_runner)
        self.assertEqual(sum(1 for q in queries if "addPullRequestReview(" in q), 1)

    def test_drafts_returns_copy(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY, _ADD_REVIEW, _add_thread("C1")],
        )
        review = _loaded_review(gh_runner)
        review.queue_comment("foo.py", {"side": "RIGHT", "line": 1}, "b")

        got = review.drafts()
        got.append("mutated")

        self.assertEqual(len(review.drafts()), 1)

    def test_discard_deletes_comment(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _add_thread("C1"),
                _add_thread("C2"),
                _DELETE_COMMENT,
            ],
        )
        review = _loaded_review(gh_runner)
        review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")
        review.queue_comment("b.py", {"side": "RIGHT", "line": 2}, "two")

        review.discard_draft(review.drafts()[0]["uid"])

        self.assertEqual(len(review.drafts()), 1)
        self.assertEqual(review.drafts()[0]["path"], "b.py")
        self.assertTrue(
            any(
                "deletePullRequestReviewComment(" in q
                for q in _graphql_queries(gh_runner)
            )
        )

    def test_discard_last_deletes_review(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _add_thread("C1"),
                _DELETE_COMMENT,
                _DELETE_REVIEW,
            ],
        )
        review = _loaded_review(gh_runner)
        review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")

        review.discard_draft(review.drafts()[0]["uid"])

        self.assertEqual(review.drafts(), [])
        self.assertTrue(
            any("deletePullRequestReview(" in q for q in _graphql_queries(gh_runner))
        )

    def test_discard_last_tolerates_missing_review(self):
        # Deleting the last pending comment auto-removes the empty review on GitHub, so
        # the follow-up deletePullRequestReview may fail to resolve. Discard must still
        # succeed (no raise, mirror cleared) rather than surfacing that as an error.
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _add_thread("C1"),
                _DELETE_COMMENT,
                _GRAPHQL_ERROR,  # deletePullRequestReview: review already gone
            ],
        )
        review = _loaded_review(gh_runner)
        review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")

        review.discard_draft(review.drafts()[0]["uid"])

        self.assertEqual(review.drafts(), [])

    def test_clear_deletes_review(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _add_thread("C1"),
                _DELETE_REVIEW,
            ],
        )
        review = _loaded_review(gh_runner)
        review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")

        review.clear_drafts()

        self.assertEqual(review.drafts(), [])
        self.assertTrue(
            any("deletePullRequestReview(" in q for q in _graphql_queries(gh_runner))
        )


class SubmitReviewTest(unittest.TestCase):
    def test_submit_pending_review(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY, _ADD_REVIEW, _add_thread("C1"), _SUBMIT],
        )
        review = _loaded_review(gh_runner)
        review.queue_comment("foo.py", {"side": "RIGHT", "line": 5}, "single")

        result = review.submit_review("REQUEST_CHANGES", body="please fix")

        self.assertEqual(
            result["submitPullRequestReview"]["pullRequestReview"]["state"], "PENDING"
        )
        self.assertEqual(review.drafts(), [])
        self.assertTrue(
            any("submitPullRequestReview(" in q for q in _graphql_queries(gh_runner))
        )

    def test_submit_without_drafts_uses_rest(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY],
            api=json.dumps({"id": 999, "state": "APPROVED"}),
        )
        review = _loaded_review(gh_runner)

        result = review.submit_review("APPROVE", body="lgtm")

        self.assertEqual(result, {"id": 999, "state": "APPROVED"})

        api_calls = [
            c
            for c in gh_runner.calls
            if c["args"][:2] == ["gh", "api"] and "graphql" not in c["args"]
        ]
        self.assertEqual(len(api_calls), 1)
        self.assertEqual(
            api_calls[0]["args"],
            [
                "gh",
                "api",
                "repos/octo/repo/pulls/42/reviews",
                "--method",
                "POST",
                "--input",
                "-",
            ],
        )
        self.assertEqual(
            json.loads(api_calls[0]["stdin"]), {"event": "APPROVE", "body": "lgtm"}
        )

    def test_invalid_verdict_raises(self):
        review = _make_review(ScriptedGH(pr_view=json.dumps(_PR_VIEW)), ScriptedGit())
        review.resolve_pr()

        with self.assertRaises(ValueError):
            review.submit_review("MERGE")


class RefusedCommentTest(unittest.TestCase):
    """GitHub returns a null thread (200, no errors) when it will not anchor a
    comment. That must surface as CommentRejected, not crash on the null, and must
    NOT join the local queue: retrying it would fail identically and block submit."""

    def _refused_review(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY, _ADD_REVIEW, _ADD_THREAD_REFUSED],
        )

        return _loaded_review(gh_runner)

    def test_null_thread_raises_comment_rejected(self):
        review = self._refused_review()

        with self.assertRaises(CommentRejected):
            review.queue_comment(
                "a.py",
                {"side": "RIGHT", "line": 11, "start_line": 7, "start_side": "RIGHT"},
                "body",
            )

    def test_rejected_comment_is_not_queued(self):
        review = self._refused_review()

        with self.assertRaises(CommentRejected):
            review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "body")

        self.assertEqual(review.drafts(), [])
        self.assertEqual(review.local_count(), 0)

    def test_rejection_message_names_the_lines(self):
        cases = {
            "single line": ({"side": "RIGHT", "line": 4}, "line 4"),
            "range": (
                {"side": "RIGHT", "line": 11, "start_line": 7, "start_side": "RIGHT"},
                "lines 7-11",
            ),
        }

        for name, (payload, expected) in cases.items():
            with self.subTest(name):
                review = self._refused_review()
                with self.assertRaises(CommentRejected) as caught:
                    review.queue_comment("a.py", payload, "body")

                self.assertIn(expected, str(caught.exception))
                self.assertIn("a.py", str(caught.exception))

    def test_is_a_gherror_so_existing_handlers_still_catch_it(self):
        self.assertTrue(issubclass(CommentRejected, GHError))

    def _review_with_one_local_comment(self, *later_pages):
        """A review holding one local (unsynced) comment: the queue attempt failed
        transiently, so it waits to be flushed on submit."""
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY, _ADD_REVIEW, _GRAPHQL_ERROR]
            + list(later_pages),
        )
        review = _loaded_review(gh_runner)

        with self.assertRaises(GHError):
            review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")

        self.assertEqual(review.local_count(), 1)

        return review

    def test_flush_drops_rejected_comment_instead_of_requeueing_it(self):
        # Regression: CommentRejected is a GHError, so a bare `except GHError` in
        # flush_local put the refused comment back in the local queue. Every later
        # submit then hit the same refusal and the review could never be submitted.
        review = self._review_with_one_local_comment(_ADD_THREAD_REFUSED)

        with self.assertRaises(CommentRejected):
            review.flush_local()

        self.assertEqual(review.local_count(), 0)
        self.assertEqual(review.drafts(), [])

    def test_submit_succeeds_on_retry_after_a_rejection(self):
        review = self._review_with_one_local_comment(_ADD_THREAD_REFUSED, _SUBMIT)

        with self.assertRaises(CommentRejected):
            review.submit_review("COMMENT", body="done")

        # The poison is gone, so the next submit goes through.
        review.submit_review("COMMENT", body="done")

        self.assertEqual(review.local_count(), 0)

    def test_flush_keeps_good_comments_and_drops_only_the_refused_one(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _GRAPHQL_ERROR,  # first queue -> local
                _GRAPHQL_ERROR,  # second queue -> local
                _ADD_THREAD_REFUSED,  # flush: first is refused
                _add_thread("C2"),  # flush: second is accepted
            ],
        )
        review = _loaded_review(gh_runner)

        for line, body in ((1, "refused"), (2, "kept")):
            with self.assertRaises(GHError):
                review.queue_comment("a.py", {"side": "RIGHT", "line": line}, body)

        with self.assertRaises(CommentRejected):
            review.flush_local()

        self.assertEqual(review.local_count(), 0)
        self.assertEqual([draft["body"] for draft in review.drafts()], ["kept"])

    def test_transient_failure_after_a_rejection_keeps_the_rest_local(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _GRAPHQL_ERROR,  # first queue -> local
                _GRAPHQL_ERROR,  # second queue -> local
                _ADD_THREAD_REFUSED,  # flush: first refused (dropped)
                _GRAPHQL_ERROR,  # flush: second fails transiently (stays local)
            ],
        )
        review = _loaded_review(gh_runner)

        for line, body in ((1, "refused"), (2, "retry me")):
            with self.assertRaises(GHError):
                review.queue_comment("a.py", {"side": "RIGHT", "line": line}, body)

        with self.assertRaises(GHError):
            review.flush_local()

        # Only the transient one is retained; the refused one is not resurrected.
        self.assertEqual(review.local_count(), 1)
        self.assertEqual([draft["body"] for draft in review.drafts()], ["retry me"])


class LocalFallbackTest(unittest.TestCase):
    def _queue_one_locally(self, gh_runner):
        review = _loaded_review(gh_runner)
        with self.assertRaises(GHError):
            review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")

        return review

    def test_queue_failure_keeps_comment_local(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY, _ADD_REVIEW, _GRAPHQL_ERROR],
        )
        review = self._queue_one_locally(gh_runner)

        self.assertEqual(review.local_count(), 1)
        drafts = review.drafts()
        self.assertEqual(len(drafts), 1)
        self.assertNotIn("comment_id", drafts[0])  # never synced
        self.assertEqual(drafts[0]["path"], "a.py")

    def test_submit_flushes_local_first(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _GRAPHQL_ERROR,  # queue's addThread fails -> local
                _add_thread("C1"),  # flush_local re-adds it on submit
                _SUBMIT,
            ],
        )
        review = self._queue_one_locally(gh_runner)

        review.submit_review("COMMENT", body="done")

        self.assertEqual(review.local_count(), 0)
        self.assertEqual(review.drafts(), [])
        queries = _graphql_queries(gh_runner)
        self.assertTrue(any("addPullRequestReviewThread(" in q for q in queries))
        self.assertTrue(any("submitPullRequestReview(" in q for q in queries))

    def test_submit_reraises_when_flush_fails(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _GRAPHQL_ERROR,  # queue fails -> local
                _GRAPHQL_ERROR,  # flush during submit still fails
            ],
        )
        review = self._queue_one_locally(gh_runner)

        with self.assertRaises(GHError):
            review.submit_review("COMMENT")

        self.assertEqual(review.local_count(), 1)  # kept, not lost

    def test_discard_local_comment(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY, _ADD_REVIEW, _GRAPHQL_ERROR],
        )
        review = self._queue_one_locally(gh_runner)

        review.discard_draft(review.drafts()[0]["uid"])  # the local comment

        self.assertEqual(review.drafts(), [])
        self.assertEqual(review.local_count(), 0)

    def test_edit_local_comment_no_server_call(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[_PENDING_EMPTY, _ADD_REVIEW, _GRAPHQL_ERROR],
        )
        review = self._queue_one_locally(gh_runner)
        before = len(_graphql_queries(gh_runner))

        review.edit_draft(review.drafts()[0]["uid"], "reworded")

        self.assertEqual(review.drafts()[0]["body"], "reworded")
        # local (unsynced) edit must not hit the API
        self.assertEqual(len(_graphql_queries(gh_runner)), before)

    def test_edit_synced_comment_updates_on_server(self):
        gh_runner = ScriptedGH(
            pr_view=json.dumps(_PR_VIEW),
            graphql_pages=[
                _PENDING_EMPTY,
                _ADD_REVIEW,
                _add_thread("C1"),
                _wrap(
                    {
                        "updatePullRequestReviewComment": {
                            "pullRequestReviewComment": {"id": "C1"}
                        }
                    }
                ),
            ],
        )
        review = _loaded_review(gh_runner)
        review.queue_comment("a.py", {"side": "RIGHT", "line": 1}, "one")

        review.edit_draft(review.drafts()[0]["uid"], "one, reworded")

        self.assertEqual(review.drafts()[0]["body"], "one, reworded")
        self.assertTrue(
            any(
                "updatePullRequestReviewComment(" in q
                for q in _graphql_queries(gh_runner)
            )
        )


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
        query = args[args.index("--raw-field") + 1]
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
                query = args[args.index("--raw-field") + 1]
                mutation_body = query.split("mutation($id:ID!){", 1)[1].strip()
                self.assertTrue(mutation_body.startswith(case["starts_with"]))
                self.assertIn("id=T1", args)


if __name__ == "__main__":
    unittest.main()
