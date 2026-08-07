import json
import subprocess
from typing import Callable, Dict, List, Optional, Tuple

_DEFAULT_TIMEOUT = 30

_PR_VIEW_FIELDS = [
    "number",
    "title",
    "baseRefName",
    "url",
    "state",
]


class GHError(Exception):
    """Raised when a `gh` invocation exits non-zero. The message includes stderr."""


Runner = Callable[..., Tuple[int, str, str]]
# runner(args, cwd, stdin=None) -> (returncode, stdout, stderr). `args` is the full
# command list starting with "gh". `stdin` is piped to the process when set (used for
# `gh api --input -` JSON bodies). The default runner shells out via subprocess.


def _default_runner(
    args: List[str],
    cwd: Optional[str],
    stdin: Optional[str] = None,
) -> Tuple[int, str, str]:
    try:
        proc = subprocess.run(
            args,
            cwd=cwd,
            input=stdin,
            capture_output=True,
            text=True,
            timeout=_DEFAULT_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        return 124, "", "gh timed out after {}s".format(_DEFAULT_TIMEOUT)
    except OSError as err:
        # gh missing / not executable / other exec failure.
        return 127, "", str(err)

    return proc.returncode, proc.stdout, proc.stderr


def _maybe_json(stdout: str) -> object:
    try:
        return json.loads(stdout)
    except (ValueError, TypeError):
        return stdout


class GH:
    def __init__(
        self,
        cwd: Optional[str] = None,
        runner: Optional[Runner] = None,
    ) -> None:
        self._cwd = cwd
        self._runner = runner if runner is not None else _default_runner

    def _run(
        self,
        args: List[str],
        stdin: Optional[str] = None,
    ) -> Tuple[int, str, str]:
        return self._runner(args, self._cwd, stdin)

    def api(
        self,
        path: str,
        method: str = "GET",
        fields: Optional[Dict] = None,
        input_obj: Optional[object] = None,
    ) -> object:
        args = ["gh", "api", path]

        if method != "GET":
            args += ["-X", method]

        if fields:
            for key, value in fields.items():
                args += ["-f", "{}={}".format(key, value)]

        stdin = None
        if input_obj is not None:
            args += ["--input", "-"]
            stdin = json.dumps(input_obj)

        returncode, stdout, stderr = self._run(args, stdin)

        if returncode != 0:
            raise GHError(stderr)

        return _maybe_json(stdout)

    def graphql(
        self,
        query: str,
        variables: Optional[Dict] = None,
    ) -> object:
        args = ["gh", "api", "graphql", "-f", "query={}".format(query)]

        if variables:
            for key, value in variables.items():
                # `-F` gives gh a typed field (needed for Int/Boolean vars), but it
                # also coerces strings: a value starting with "@" is read as a file
                # and pure-numeric / true / false / null become typed literals. So
                # string vars (comment bodies with @mentions, owner/repo, node ids,
                # cursors) must go through `-f`, which is always a raw string.
                flag = "-F" if isinstance(value, int) else "-f"
                args += [flag, "{}={}".format(key, value)]

        returncode, stdout, stderr = self._run(args)

        if returncode != 0:
            raise GHError(stderr)

        payload = json.loads(stdout)

        if isinstance(payload, dict) and payload.get("errors"):
            raise GHError(json.dumps(payload["errors"]))

        if isinstance(payload, dict) and "data" in payload:
            return payload["data"]

        return payload

    def pr_diff(self, number: Optional[int] = None) -> str:
        args = ["gh", "pr", "diff"] + ([str(number)] if number else [])

        returncode, stdout, stderr = self._run(args)

        if returncode != 0:
            raise GHError(stderr)

        return stdout

    def pr_view(
        self,
        number: Optional[int] = None,
        fields: Optional[List[str]] = None,
    ) -> Dict:
        fields = fields if fields else _PR_VIEW_FIELDS

        args = (
            ["gh", "pr", "view"]
            + ([str(number)] if number else [])
            + ["--json", ",".join(fields)]
        )

        returncode, stdout, stderr = self._run(args)

        if returncode != 0:
            raise GHError(stderr)

        return json.loads(stdout)
