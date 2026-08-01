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

    def queue_comment(self, path: str, payload: Dict, body: str) -> None:
        draft = {
            "path": path,
            "body": body,
            "side": payload["side"],
            "line": payload["line"],
        }

        if "start_line" in payload:
            draft["start_line"] = payload["start_line"]
            draft["start_side"] = payload["start_side"]

        self._drafts.append(draft)

    def drafts(self) -> List[Dict]:
        return list(self._drafts)

    def discard_draft(self, index: int) -> None:
        del self._drafts[index]

    def clear_drafts(self) -> None:
        self._drafts = []

    def submit_review(self, verdict: str, body: str = "") -> Dict:
        assert verdict in _VERDICTS

        comments = []
        for draft in self._drafts:
            comment = {
                "path": draft["path"],
                "line": draft["line"],
                "side": draft["side"],
                "body": draft["body"],
            }

            if "start_line" in draft:
                comment["start_line"] = draft["start_line"]
                comment["start_side"] = draft["start_side"]

            comments.append(comment)

        payload = {
            "event": verdict,
            "body": body,
            "comments": comments,
        }

        path = "repos/{}/{}/pulls/{}/reviews".format(
            self._pr["owner"], self._pr["repo"], self._pr["number"]
        )

        result = self._gh.api(path, method="POST", input_obj=payload)

        self.clear_drafts()

        return result

    def reply_comment(self, thread_id: str, body: str) -> Dict:
        return self._gh.graphql(_REPLY_MUTATION, {"id": thread_id, "body": body})

    def set_thread_resolved(self, thread_id: str, resolved: bool) -> Dict:
        mutation = _RESOLVE_MUTATION if resolved else _UNRESOLVE_MUTATION

        return self._gh.graphql(mutation, {"id": thread_id})
