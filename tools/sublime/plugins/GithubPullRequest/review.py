import subprocess
from typing import Callable, Dict, List, Optional, Tuple

try:
    from .diff import parse_unified_diff
    from .urls import parse_pr_url
except ImportError:
    from diff import parse_unified_diff
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
          comments(first:100){ nodes{ author{login} body bodyHTML createdAt url diffHunk } }
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
        self._drafts = []
        self._pr_node_id = None
        self._pending_review_id = None

    def _git_run(self, args: List[str]) -> Tuple[int, str, str]:
        return self._git(args, self._cwd)

    def resolve_pr(self) -> Dict:
        view = self._gh.pr_view()
        coords = parse_pr_url(view["url"]) or {}

        self._pr = {
            "number": view["number"],
            "title": view["title"],
            "base": view["baseRefName"],
            "head": view["headRefName"],
            "head_oid": view["headRefOid"],
            "url": view["url"],
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

                self._drafts.append(draft)

            break

    def _ensure_pending_review(self) -> str:
        if self._pending_review_id is None:
            data = self._gh.graphql(_ADD_REVIEW_MUTATION, {"pr": self._pr_node_id})
            self._pending_review_id = data["addPullRequestReview"]["pullRequestReview"][
                "id"
            ]

        return self._pending_review_id

    def queue_comment(self, path: str, payload: Dict, body: str) -> None:
        review_id = self._ensure_pending_review()

        variables = {
            "rid": review_id,
            "path": path,
            "line": payload["line"],
            "side": payload["side"],
            "body": body,
        }

        draft = {
            "path": path,
            "body": body,
            "side": payload["side"],
            "line": payload["line"],
        }

        if "start_line" in payload:
            variables["startLine"] = payload["start_line"]
            variables["startSide"] = payload["start_side"]
            draft["start_line"] = payload["start_line"]
            draft["start_side"] = payload["start_side"]
            mutation = _ADD_THREAD_RANGE_MUTATION
        else:
            mutation = _ADD_THREAD_MUTATION

        data = self._gh.graphql(mutation, variables)
        nodes = data["addPullRequestReviewThread"]["thread"]["comments"]["nodes"]
        draft["comment_id"] = nodes[0]["id"] if nodes else None

        self._drafts.append(draft)

    def drafts(self) -> List[Dict]:
        return list(self._drafts)

    def discard_draft(self, index: int) -> None:
        draft = self._drafts[index]

        if draft.get("comment_id"):
            self._gh.graphql(_DELETE_COMMENT_MUTATION, {"id": draft["comment_id"]})

        del self._drafts[index]

        if not self._drafts:
            self.clear_drafts()

    def clear_drafts(self) -> None:
        if self._pending_review_id is not None:
            self._gh.graphql(_DELETE_REVIEW_MUTATION, {"rid": self._pending_review_id})

        self._drafts = []
        self._pending_review_id = None

    def submit_review(self, verdict: str, body: str = "") -> Dict:
        assert verdict in _VERDICTS

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
        self._pending_review_id = None

        return result

    def reply_comment(self, thread_id: str, body: str) -> Dict:
        return self._gh.graphql(_REPLY_MUTATION, {"id": thread_id, "body": body})

    def set_thread_resolved(self, thread_id: str, resolved: bool) -> Dict:
        mutation = _RESOLVE_MUTATION if resolved else _UNRESOLVE_MUTATION

        return self._gh.graphql(mutation, {"id": thread_id})
