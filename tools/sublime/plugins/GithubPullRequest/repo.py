"""Repository access: read-only git plus repo-relative path mapping.

Only read-only git is ever run (`rev-parse`, `show`); the plugin never mutates git
state. No ``sublime`` import, so everything here is unit-testable."""

import os
import subprocess
from typing import List, Optional, Tuple

try:
    from .state import SESSION
except ImportError:
    from state import SESSION

_TIMEOUT = 5


def git_root(path: str) -> Optional[str]:
    """Repository root containing `path`, or None when it is not inside a repo."""
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=path,
            stderr=subprocess.STDOUT,
            timeout=_TIMEOUT,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    return out.decode("utf-8").strip()


def run_git(root: str, args: List[str]) -> Tuple[int, str]:
    """(returncode, stdout) of a read-only git command run in `root`. Returns
    (1, "") on any failure, so callers only branch on the code."""
    try:
        proc = subprocess.run(
            ["git", *args], cwd=root, capture_output=True, text=True, timeout=_TIMEOUT
        )
    except (OSError, subprocess.SubprocessError):
        return 1, ""

    return proc.returncode, proc.stdout


def rel_path(view) -> Optional[str]:
    """Repo-relative, forward-slash path for a view's file, or None when it has no
    file or sits outside the loaded repository. Duck-typed on ``view.file_name()``."""
    file_name = view.file_name()
    if not file_name or not SESSION.root:
        return None

    rel = os.path.relpath(file_name, SESSION.root)
    if rel.startswith(".."):
        return None

    return rel.replace(os.sep, "/")


def abs_path(rel: str) -> str:
    return os.path.join(SESSION.root, rel.replace("/", os.sep))
