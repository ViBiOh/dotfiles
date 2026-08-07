import subprocess
from typing import Callable, Dict, List, Optional, Tuple

try:
    from .diff import parse_unified_diff
    from .gh import GHError
    from .urls import parse_pr_url
except ImportError:
    from diff import parse_unified_diff
    from gh import GHError
    from urls import parse_pr_url

_DEFAULT_TIMEOUT = 30

_VERDICTS = ("APPROVE", "COMMENT", "REQUEST_CHANGES")

Runner = Callable[..., Tuple[int, str, str]]
# runner(args, cwd, stdin=None) -> (returncode, stdout, stderr). Same shape as gh's
# Runner. Only read-only git is ever invoked here (show / merge-base / rev-parse).

_THREADS_QUERY = """query($owner:String!,$repo:String!,$number:Int!,$cursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      reviewThreads(first:100, after:$cursor){
        pageInfo{ hasNextPage endCursor }
        nodes{
          id isResolved isOutdated path line originalLine startLine diffSide
          comments(first:100){ nodes{ author{login} body bodyHTML createdAt url diffHunk state } }
        }
      }
    }
  }
}"""

_REPLY_MUTATION = """mutation($id:ID!,$body:String!){
  addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id, body:$body}){
    comment{ id url }
  }
}"""

_RESOLVE_MUTATION = """mutation($id:ID!){
  resolveReviewThread(input:{threadId:$id}){
    thread{ id isResolved }
  }
}"""

_UNRESOLVE_MUTATION = """mutation($id:ID!){
  unresolveReviewThread(input:{threadId:$id}){
    thread{ id isResolved }
  }
}"""

# The local draft queue is backed by a real GitHub PENDING review, so queued
# comments survive crashes/restarts and are visible on github.com until submitted.
_PENDING_QUERY = """query($owner:String!,$repo:String!,$number:Int!){
  viewer{ login }
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      id
      reviews(first:50, states:[PENDING]){
        nodes{
          id viewerDidAuthor
          comments(first:100){ nodes{ id path line startLine body } }
        }
      }
    }
  }
}"""

_ADD_REVIEW_MUTATION = """mutation($pr:ID!){
  addPullRequestReview(input:{pullRequestId:$pr}){
    pullRequestReview{ id }
  }
}"""

_ADD_THREAD_MUTATION = """mutation($rid:ID!,$path:String!,$line:Int!,$side:DiffSide!,$body:String!){
  addPullRequestReviewThread(input:{pullRequestReviewId:$rid, path:$path, line:$line, side:$side, body:$body}){
    thread{ comments(first:1){ nodes{ id } } }
  }
}"""

_ADD_THREAD_RANGE_MUTATION = """mutation($rid:ID!,$path:String!,$line:Int!,$side:DiffSide!,$startLine:Int!,$startSide:DiffSide!,$body:String!){
  addPullRequestReviewThread(input:{pullRequestReviewId:$rid, path:$path, line:$line, side:$side, startLine:$startLine, startSide:$startSide, body:$body}){
    thread{ comments(first:1){ nodes{ id } } }
  }
}"""

_DELETE_COMMENT_MUTATION = """mutation($id:ID!){
  deletePullRequestReviewComment(input:{id:$id}){
    pullRequestReviewComment{ id }
  }
}"""

_UPDATE_COMMENT_MUTATION = """mutation($id:ID!,$body:String!){
  updatePullRequestReviewComment(input:{pullRequestReviewCommentId:$id, body:$body}){
    pullRequestReviewComment{ id }
  }
}"""

_DELETE_REVIEW_MUTATION = """mutation($rid:ID!){
  deletePullRequestReview(input:{pullRequestReviewId:$rid}){
    pullRequestReview{ id }
  }
}"""

_SUBMIT_REVIEW_MUTATION = """mutation($rid:ID!,$event:PullRequestReviewEvent!,$body:String){
  submitPullRequestReview(input:{pullRequestReviewId:$rid, event:$event, body:$body}){
    pullRequestReview{ id state }
  }
}"""


def _default_git_runner(
    args: List[str],
    cwd: Optional[str],
    stdin: Optional[str] = None,
) -> Tuple[int, str, str]:
    proc = subprocess.run(
        args,
        cwd=cwd,
        input=stdin,
        capture_output=True,
        text=True,
        timeout=_DEFAULT_TIMEOUT,
    )

    return proc.returncode, proc.stdout, proc.stderr


class Review:
    def __init__(
        self,
        gh: object,
        cwd: str,
        git_runner: Optional[Runner] = None,
    ) -> None:
        self._gh = gh
        self._cwd = cwd
        self._git = git_runner if git_runner is not None else _default_git_runner

        self._pr = None
        self._merge_base = None
        self._drafts = []  # synced to the GitHub pending review (have comment_id)
        self._local_comments = []  # queued but not yet synced (network/API failure)
        self._pr_node_id = None
        self._pending_review_id = None
        self._next_uid = 0  # stable per-draft id (edit/discard key on it, not position)

    def _git_run(self, args: List[str]) -> Tuple[int, str, str]:
        return self._git(args, self._cwd)

    def resolve_pr(self) -> Dict:
        view = self._gh.pr_view()
        coords = parse_pr_url(view["url"]) or {}

        self._pr = {
            "number": view["number"],
            "title": view["title"],
            "base": view["baseRefName"],
            "state": view.get("state"),
            "owner": coords.get("owner"),
            "repo": coords.get("repo"),
        }

        return self._pr

    def merge_base(self) -> str:
        if self._merge_base is not None:
            return self._merge_base

        base = self._pr["base"]

        rc, out, _ = self._git_run(
            ["git", "merge-base", "HEAD", "origin/{}".format(base)]
        )

        if rc != 0:
            rc, out, _ = self._git_run(["git", "merge-base", "HEAD", base])

        if rc != 0:
            self._merge_base = base
        else:
            self._merge_base = out.strip()

        return self._merge_base

    def changed_files(self) -> List[Dict]:
        diff_text = self._gh.pr_diff(self._pr["number"])

        files = []
        for file_diff in parse_unified_diff(diff_text):
            files.append(
                {
                    "path": file_diff.path,
                    "additions": file_diff.additions,
                    "deletions": file_diff.deletions,
                    "is_binary": file_diff.is_binary,
                    "file_diff": file_diff,
                }
            )

        return files

    def review_threads(self) -> List[Dict]:
        threads = []
        cursor = None

        while True:
            variables = {
                "owner": self._pr["owner"],
                "repo": self._pr["repo"],
                "number": self._pr["number"],
            }
            if cursor is not None:
                variables["cursor"] = cursor

            data = self._gh.graphql(_THREADS_QUERY, variables)

            connection = data["repository"]["pullRequest"]["reviewThreads"]

            for node in connection["nodes"]:
                comments = node["comments"]["nodes"]
                if comments and comments[0].get("state") == "PENDING":
                    # The viewer's own not-yet-submitted draft. It is surfaced through
                    # the pending-review mirror (load_pending); skip it here so it does
                    # not also show up as a posted thread (which would double it).
                    continue

                threads.append(self._map_thread(node))

            page_info = connection["pageInfo"]
            if not page_info["hasNextPage"]:
                break

            cursor = page_info["endCursor"]

        return threads

    def _map_thread(self, node: Dict) -> Dict:
        comments = []
        for comment in node["comments"]["nodes"]:
            author = comment.get("author")
            login = author["login"] if author else "ghost"

            comments.append(
                {
                    "author": login,
                    "body": comment.get("body", ""),
                    "body_html": comment.get("bodyHTML", ""),
                    "created_at": comment.get("createdAt"),
                    "url": comment.get("url", ""),
                    "diff_hunk": comment.get("diffHunk"),
                }
            )

        url = comments[0]["url"] if comments else ""

        return {
            "id": node["id"],
            "path": node["path"],
            "line": node.get("line"),
            "original_line": node.get("originalLine"),
            "side": node.get("diffSide"),
            "start_line": node.get("startLine"),
            "is_resolved": node["isResolved"],
            "is_outdated": node["isOutdated"],
            "url": url,
            "comments": comments,
        }

    def base_blob(self, path: str) -> Optional[str]:
        merge_base = self.merge_base()

        rc, out, _ = self._git_run(["git", "show", "{}:{}".format(merge_base, path)])

        if rc != 0:
            return None

        return out

    def load_pending(self) -> None:
        """Fetch the PR node id and restore any existing PENDING review authored by
        the current user into the local draft mirror. Called once at load."""
        data = self._gh.graphql(
            _PENDING_QUERY,
            {
                "owner": self._pr["owner"],
                "repo": self._pr["repo"],
                "number": self._pr["number"],
            },
        )

        pull = data["repository"]["pullRequest"]
        self._pr_node_id = pull["id"]
        self._pending_review_id = None
        self._drafts = []
        self._local_comments = []

        for review in pull["reviews"]["nodes"]:
            if not review.get("viewerDidAuthor"):
                continue

            self._pending_review_id = review["id"]
            for comment in review["comments"]["nodes"]:
                # PullRequestReviewComment has no side field (it lives on the thread);
                # the plugin only authors RIGHT-side drafts, so restore them as RIGHT.
                draft = {
                    "comment_id": comment["id"],
                    "path": comment["path"],
                    "body": comment["body"],
                    "side": "RIGHT",
                    "line": comment.get("line"),
                }

                if comment.get("startLine"):
                    draft["start_line"] = comment["startLine"]
                    draft["start_side"] = draft["side"]

                draft["uid"] = self._new_uid()
                self._drafts.append(draft)

            break

    def _new_uid(self) -> int:
        uid = self._next_uid
        self._next_uid += 1

        return uid

    def _ensure_pending_review(self) -> str:
        if self._pending_review_id is None:
            data = self._gh.graphql(_ADD_REVIEW_MUTATION, {"pr": self._pr_node_id})
            self._pending_review_id = data["addPullRequestReview"]["pullRequestReview"][
                "id"
            ]

        return self._pending_review_id

    def _sync_draft(self, draft: Dict) -> None:
        """Add one draft to the GitHub pending review, stamping its comment_id.
        Raises GHError if the network/API is unavailable."""
        review_id = self._ensure_pending_review()

        variables = {
            "rid": review_id,
            "path": draft["path"],
            "line": draft["line"],
            "side": draft["side"],
            "body": draft["body"],
        }

        if "start_line" in draft:
            variables["startLine"] = draft["start_line"]
            variables["startSide"] = draft["start_side"]
            mutation = _ADD_THREAD_RANGE_MUTATION
        else:
            mutation = _ADD_THREAD_MUTATION

        data = self._gh.graphql(mutation, variables)
        nodes = data["addPullRequestReviewThread"]["thread"]["comments"]["nodes"]
        draft["comment_id"] = nodes[0]["id"] if nodes else None

    def queue_comment(self, path: str, payload: Dict, body: str) -> None:
        """Queue a comment. On a network/API failure the comment is kept in a local
        (unsynced) list instead of being lost, and GHError is re-raised so the caller
        can notify. Locals are flushed to GitHub on submit (or on end, on request)."""
        draft = {
            "uid": self._new_uid(),
            "path": path,
            "body": body,
            "side": payload["side"],
            "line": payload["line"],
        }
        if "start_line" in payload:
            draft["start_line"] = payload["start_line"]
            draft["start_side"] = payload["start_side"]

        try:
            self._sync_draft(draft)
        except GHError:
            self._local_comments.append(draft)
            raise

        self._drafts.append(draft)

    def drafts(self) -> List[Dict]:
        """All queued comments, synced first then local (unsynced)."""
        return list(self._drafts) + list(self._local_comments)

    def local_count(self) -> int:
        return len(self._local_comments)

    def flush_local(self) -> None:
        """Sync every local (unsynced) comment to the pending review. On failure the
        already-synced ones stay synced and the rest remain local; GHError re-raises."""
        pending = self._local_comments
        self._local_comments = []
        for index, draft in enumerate(pending):
            try:
                self._sync_draft(draft)
            except GHError:
                self._local_comments = pending[index:]
                raise

            self._drafts.append(draft)

    def _find_draft(self, uid: int):
        """(list, index, draft) for the draft with this uid, else (None, None, None).
        Keying on uid (not position) keeps edit/discard correct even if the queue
        shifts between when a popup is rendered and when its action fires."""
        for store in (self._drafts, self._local_comments):
            for index, draft in enumerate(store):
                if draft.get("uid") == uid:
                    return store, index, draft

        return None, None, None

    def discard_draft(self, uid: int) -> None:
        store, index, draft = self._find_draft(uid)
        if store is None:
            return

        if store is self._drafts and draft.get("comment_id"):
            self._gh.graphql(_DELETE_COMMENT_MUTATION, {"id": draft["comment_id"]})

        del store[index]
        if store is self._drafts and not self._drafts:
            self._delete_pending_review()

    def edit_draft(self, uid: int, body: str) -> None:
        """Change a draft's body. Synced drafts are updated on GitHub; local ones
        just update the mirror."""
        store, _, draft = self._find_draft(uid)
        if store is None:
            return

        if store is self._drafts and draft.get("comment_id"):
            self._gh.graphql(
                _UPDATE_COMMENT_MUTATION,
                {"id": draft["comment_id"], "body": body},
            )

        draft["body"] = body

    def clear_drafts(self) -> None:
        self._delete_pending_review()
        self._drafts = []
        self._local_comments = []

    def _delete_pending_review(self) -> None:
        if self._pending_review_id is None:
            return

        try:
            self._gh.graphql(_DELETE_REVIEW_MUTATION, {"rid": self._pending_review_id})
        except GHError:
            # Deleting a pending review's last comment already removes the now-empty
            # review, so its id may no longer resolve. Either way the desired end state
            # (no pending review) is reached, so treat this as done.
            pass

        self._pending_review_id = None

    def submit_review(self, verdict: str, body: str = "") -> Dict:
        assert verdict in _VERDICTS

        # Push any comments that never reached GitHub into the pending review first,
        # so they are part of the review being submitted (raises if still offline).
        self.flush_local()

        if self._pending_review_id is not None:
            result = self._gh.graphql(
                _SUBMIT_REVIEW_MUTATION,
                {"rid": self._pending_review_id, "event": verdict, "body": body},
            )
        else:
            # No queued comments: post a bare review (e.g. a plain APPROVE) via REST.
            path = "repos/{}/{}/pulls/{}/reviews".format(
                self._pr["owner"], self._pr["repo"], self._pr["number"]
            )
            result = self._gh.api(
                path, method="POST", input_obj={"event": verdict, "body": body}
            )

        self._drafts = []
        self._local_comments = []
        self._pending_review_id = None

        return result

    def reply_comment(self, thread_id: str, body: str) -> Dict:
        return self._gh.graphql(_REPLY_MUTATION, {"id": thread_id, "body": body})

    def set_thread_resolved(self, thread_id: str, resolved: bool) -> Dict:
        mutation = _RESOLVE_MUTATION if resolved else _UNRESOLVE_MUTATION

        return self._gh.graphql(mutation, {"id": thread_id})
