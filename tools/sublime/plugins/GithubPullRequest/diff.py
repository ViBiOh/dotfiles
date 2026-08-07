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
    old_start: int
    old_count: int
    new_start: int
    new_count: int
    header: str
    lines: List[DiffLine] = field(default_factory=list)


@dataclass
class FileDiff:
    path: str
    old_path: Optional[str]
    new_path: Optional[str]
    is_new: bool
    is_deleted: bool
    is_rename: bool
    is_binary: bool
    additions: int
    deletions: int
    hunks: List[Hunk] = field(default_factory=list)


def _new_file_state() -> dict:
    return {
        "old_path": None,
        "new_path": None,
        "is_new": False,
        "is_deleted": False,
        "is_rename": False,
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

    if value.startswith("a/") or value.startswith("b/"):
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
        is_deleted=state["is_deleted"],
        is_rename=state["is_rename"],
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
            old_start = int(hunk_match.group(1))
            old_count = int(hunk_match.group(2)) if hunk_match.group(2) else 1
            new_start = int(hunk_match.group(3))
            new_count = int(hunk_match.group(4)) if hunk_match.group(4) else 1

            hunk = Hunk(
                old_start=old_start,
                old_count=old_count,
                new_start=new_start,
                new_count=new_count,
                header=line,
                lines=[],
            )
            state["hunks"].append(hunk)

            old_ln = old_start
            new_ln = new_start
            rem_old = old_count
            rem_new = new_count
            continue

        if line.startswith("\\"):
            continue

        if line.startswith("new file mode"):
            state["is_new"] = True
        elif line.startswith("deleted file mode"):
            state["is_deleted"] = True
        elif line.startswith("rename from "):
            state["is_rename"] = True
            state["old_path"] = line[len("rename from ") :].strip()
        elif line.startswith("rename to "):
            state["is_rename"] = True
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
