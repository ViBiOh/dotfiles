import re
from dataclasses import dataclass, field
from typing import List, Optional

_DIFF_GIT_RE = re.compile(r"^diff --git a/(.*) b/(.*)$")
_HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")
_BINARY_RE = re.compile(r"^Binary files (?:a/)?(.*) and (?:b/)?(.*) differ$")


@dataclass
class DiffLine:
    origin: str
    old_lineno: Optional[int]
    new_lineno: Optional[int]
    content: str


@dataclass
class Hunk:
    # Head-side start line only: the base-side start and both counts are needed while
    # parsing, but no consumer reads them back, and on a large PR every retained field is
    # multiplied by the number of hunks in the session.
    new_start: int
    lines: List[DiffLine] = field(default_factory=list)


@dataclass
class FileDiff:
    path: str
    old_path: Optional[str]
    new_path: Optional[str]
    is_new: bool
    is_binary: bool
    additions: int
    deletions: int
    hunks: List[Hunk] = field(default_factory=list)


def _new_file_state() -> dict:
    return {
        "old_path": None,
        "new_path": None,
        "is_new": False,
        "is_binary": False,
        "additions": 0,
        "deletions": 0,
        "hunks": [],
    }


def _strip_prefix(raw: str) -> Optional[str]:
    """Turn a `--- a/path` / `+++ b/path` payload into a repo-relative path.

    `/dev/null` (added/deleted side) becomes None; a leading `a/` or `b/` prefix
    is removed; a trailing tab-separated timestamp is dropped."""
    value = raw.split("\t", 1)[0].strip()

    if value == "/dev/null":
        return None

    if value.startswith(("a/", "b/")):
        value = value[2:]

    return value


def _build_file_diff(state: dict) -> FileDiff:
    old_path = state["old_path"]
    new_path = state["new_path"]

    if new_path is not None:
        path = new_path
    elif old_path is not None:
        path = old_path
    else:
        path = ""

    return FileDiff(
        path=path,
        old_path=old_path,
        new_path=new_path,
        is_new=state["is_new"],
        is_binary=state["is_binary"],
        additions=state["additions"],
        deletions=state["deletions"],
        hunks=state["hunks"],
    )


def parse_unified_diff(text: str) -> List[FileDiff]:
    """Parse `gh pr diff` / `git diff` unified output into a list of FileDiff.

    `\\ No newline at end of file` markers are skipped."""
    if not text:
        return []

    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()

    files: List[FileDiff] = []
    state: Optional[dict] = None
    hunk: Optional[Hunk] = None

    old_ln = 0
    new_ln = 0
    rem_old = 0
    rem_new = 0

    for line in lines:
        if line.startswith("diff --git "):
            if state is not None:
                files.append(_build_file_diff(state))

            state = _new_file_state()
            hunk = None
            rem_old = 0
            rem_new = 0

            match = _DIFF_GIT_RE.match(line)
            if match:
                state["old_path"] = match.group(1)
                state["new_path"] = match.group(2)

            continue

        if state is None:
            continue

        in_content = hunk is not None and (rem_old + rem_new) > 0

        if in_content:
            if line.startswith("\\"):
                continue

            origin = line[0] if line else " "
            content = line[1:] if line else ""

            if origin == "+":
                diff_line = DiffLine("+", None, new_ln, content)
                new_ln += 1
                rem_new -= 1
                state["additions"] += 1
            elif origin == "-":
                diff_line = DiffLine("-", old_ln, None, content)
                old_ln += 1
                rem_old -= 1
                state["deletions"] += 1
            else:
                diff_line = DiffLine(" ", old_ln, new_ln, content)
                old_ln += 1
                new_ln += 1
                rem_old -= 1
                rem_new -= 1

            hunk.lines.append(diff_line)
            continue

        hunk_match = _HUNK_RE.match(line)
        if hunk_match:
            new_start = int(hunk_match.group(3))

            hunk = Hunk(new_start=new_start, lines=[])
            state["hunks"].append(hunk)

            # An omitted count means 1 ("@@ -5 +5 @@"). The counts drive how many
            # following lines belong to the hunk, which is how the parser knows where
            # the body ends and the next file's headers begin.
            old_ln = int(hunk_match.group(1))
            new_ln = new_start
            rem_old = int(hunk_match.group(2)) if hunk_match.group(2) else 1
            rem_new = int(hunk_match.group(4)) if hunk_match.group(4) else 1
            continue

        if line.startswith("\\"):
            continue

        if line.startswith("new file mode"):
            state["is_new"] = True
        elif line.startswith("rename from "):
            state["old_path"] = line[len("rename from ") :].strip()
        elif line.startswith("rename to "):
            state["new_path"] = line[len("rename to ") :].strip()
        elif line.startswith("--- "):
            state["old_path"] = _strip_prefix(line[len("--- ") :])
        elif line.startswith("+++ "):
            state["new_path"] = _strip_prefix(line[len("+++ ") :])
        else:
            binary_match = _BINARY_RE.match(line)
            if binary_match:
                state["is_binary"] = True

    if state is not None:
        files.append(_build_file_diff(state))

    return files
