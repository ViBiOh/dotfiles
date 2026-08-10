"""CODEOWNERS lookup via the external `codeowners` binary.

Best effort: the binary is optional, so every failure degrades to "no owners known"
rather than breaking the review. No ``sublime`` import; the subprocess runner is
injectable for tests, matching the pattern in gh.py / review.py."""

import subprocess
from typing import Callable, Dict, List, Optional, Tuple

_TIMEOUT = 10

Runner = Callable[..., Tuple[int, str, str]]
# runner(args, cwd) -> (returncode, stdout, stderr)


def _default_runner(args: List[str], cwd: Optional[str]) -> Tuple[int, str, str]:
    proc = subprocess.run(
        args, cwd=cwd, capture_output=True, text=True, timeout=_TIMEOUT
    )

    return proc.returncode, proc.stdout, proc.stderr


def codeowners_map(
    root: str,
    paths: List[str],
    runner: Optional[Runner] = None,
) -> Dict[str, str]:
    """path -> owners string, resolved for every path in ONE call. Empty on any
    failure (binary missing, non-zero exit). '(unowned)' collapses to ''."""
    if not paths:
        return {}

    run = runner if runner is not None else _default_runner

    try:
        returncode, stdout, _ = run(["codeowners", "--", *paths], root)
    except (OSError, subprocess.SubprocessError):
        return {}

    if returncode != 0:
        return {}

    owners = {}
    for line in stdout.splitlines():
        parts = line.split()
        if not parts:
            continue

        path = parts[0]
        names = parts[1:]
        if names == ["(unowned)"]:
            names = []

        owners[path] = " ".join(names)

    return owners
