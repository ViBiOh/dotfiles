#!/usr/bin/env python3
import glob
import json
import os
import re
import subprocess
import sys

CODE_EXTENSIONS = (
    "go|py|ts|tsx|js|jsx|proto|yaml|yml|json|bzl|bazel|sh|rs|java|kt|sql|csv|toml|tf|hcl|rb|c|h|cc|cpp"
)
# A token right after `>` or `}` is the tail of a placeholder path such as `<cloud>_resolvers.go`.
FILE_TOKEN = re.compile(rf"(?<![\w/.>}}-])([\w./-]*[\w-]\.(?:{CODE_EXTENSIONS}))(?!\w|\.\w)")
LINE_SUFFIX = re.compile(r"^:\d+(?:-\d+)?")
LINK = re.compile(r"\[([^\]]*)\]\(([^)]*)\)")
BACKTICK_IN_LINK_TEXT = re.compile(r"\[[^\]]*`[^\]]*\]\(")
GITHUB_BLOB = re.compile(r"https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/([^#)\s]+)(?:#L(\d+))?")
DASHES = re.compile(r"[–—]")
INLINE_CODE = re.compile(r"`[^`]*`")
ABSOLUTE_PATH = re.compile(r"(?<![\w.])(/(?:home|Users|tmp|opt|srv|workspace)[^\s'\"`;|&()<>:*]*)")


def git(root, *args):
    result = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    if result.returncode != 0:
        return None

    return result.stdout.strip()


def string_values(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from string_values(item)
    elif isinstance(value, list):
        for item in value:
            yield from string_values(item)


def transcript_paths(transcript):
    """Yields absolute paths found in tool calls of the session and of its subagents."""
    if not transcript or not os.path.isfile(transcript):
        return

    files = [transcript]
    files += glob.glob(os.path.join(transcript.removesuffix(".jsonl"), "subagents", "**", "*.jsonl"), recursive=True)
    for path in files:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                try:
                    content = (json.loads(line).get("message") or {}).get("content")
                except ValueError:
                    continue

                if not isinstance(content, list):
                    continue

                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        for text in string_values(block.get("input", {})):
                            yield from ABSOLUTE_PATH.findall(text)


def explored_roots(md_path, payload):
    """Git repos the session actually explored, which are the only valid link targets."""
    roots, seen_dirs = [], set()
    starts = [os.path.dirname(md_path), payload.get("cwd", "")]
    for path in [*starts, *transcript_paths(payload.get("transcript_path", ""))]:
        directory = path if os.path.isdir(path) else os.path.dirname(path)
        if not directory or directory in seen_dirs or not os.path.isdir(directory):
            continue

        seen_dirs.add(directory)
        if any(directory == root or directory.startswith(root + "/") for root in roots):
            continue

        top = git(directory, "rev-parse", "--show-toplevel")
        if top and top not in roots:
            roots.append(top)

    return roots


def repo_info(root):
    match = re.search(r"github\.com[:/](.+?)(?:\.git)?$", git(root, "remote", "get-url", "origin") or "")

    return {"root": root, "sha": git(root, "rev-parse", "HEAD"), "slug": match.group(1) if match else None}


def file_lines(root, ref, path, cache={}):
    """Returns the line count of path at ref, or None when the commit or the file is missing."""
    key = (root, ref, path)
    if key not in cache:
        content = git(root, "show", f"{ref}:{path}")
        cache[key] = None if content is None else content.count("\n") + 1

    return cache[key]


def check_link(link_text, url, infos):
    match = GITHUB_BLOB.match(url)
    owner, repo, ref, path, line = match.groups()
    slug = f"{owner}/{repo}"

    # Repos not explored in this session have nothing local to check against, and shared paths
    # such as .github/CODEOWNERS would otherwise match an unrelated explored repo.
    same_name = [info for info in infos if info["slug"].split("/")[1] == repo]
    if not same_name:
        return None

    target = next((info for info in same_name if info["slug"] == slug), None)
    if target is None:
        return f"{slug} is not the remote of the explored {repo} checkout, use {same_name[0]['slug']}"

    if not os.path.isfile(os.path.join(target["root"], path)):
        holders = [info for info in infos if os.path.isfile(os.path.join(info["root"], path))]
        if not holders:
            return f"{path} does not exist in {slug}"

        return f"{path} is not in {slug}, it lives in {holders[0]['slug']}; use https://github.com/{holders[0]['slug']}/blob/{holders[0]['sha']}/{path}#L<line>"

    if line is None:
        return f"{url} has no #L anchor; append #L<line> and put :<line> in the link text"

    count = file_lines(target["root"], ref, path)
    if count is None:
        return f"{ref} does not hold {path} in {slug}; pin to the explored HEAD {target['sha']}"

    if int(line) > count:
        return f"{path}#L{line} is past the end of the file ({count} lines at {ref[:12]})"

    if f":{line}" not in link_text:
        return f"link text [{link_text}] does not show :{line} from its #L{line} anchor"

    return None


def locate(token, infos):
    found = []
    for info in infos:
        root = info["root"]
        if "/" in token and os.path.isfile(os.path.join(root, token)):
            found.append((info, token))
            continue

        pattern = f"*{token}" if "/" in token else f"*/{os.path.basename(token)}"
        listing = git(root, "ls-files", pattern, os.path.basename(token)) or ""
        for path in listing.splitlines()[:5]:
            found.append((info, path))

    return found


def scan(md_path, infos):
    text = open(md_path, encoding="utf-8").read()

    backtick_links, missing_refs, dashes, bad_links = [], [], [], []
    in_fence = False
    for number, raw in enumerate(text.splitlines(), 1):
        if raw.lstrip().startswith("```"):
            in_fence = not in_fence
            continue

        if in_fence:
            continue

        if BACKTICK_IN_LINK_TEXT.search(raw):
            backtick_links.append(f"  line {number}: {raw.strip()[:140]}")

        for link_text, url in LINK.findall(raw):
            if GITHUB_BLOB.match(url):
                problem = check_link(link_text, url, infos)
                if problem:
                    bad_links.append(f"  line {number}: {problem}")

        # Link targets are checked above; drop them so their URL paths are not reported twice.
        without_urls = LINK.sub(lambda m: m.group(1), raw)
        for match in FILE_TOKEN.finditer(without_urls):
            if LINE_SUFFIX.match(without_urls[match.end():]):
                continue

            # Bare names on a line marked **external** belong to another repo and collide with unrelated local files.
            if "**external**" in raw and "/" not in match.group(1):
                continue

            # Files absent from every explored repo are external or not created yet, so no line can be checked.
            matches = locate(match.group(1), infos)
            if not matches:
                continue

            missing_refs.append(f"  line {number}: {match.group(1)} has no line number ({len(matches)} matching files, first ones below)")
            for info, path in matches[:3]:
                missing_refs.append(f"    candidate: https://github.com/{info['slug']}/blob/{info['sha']}/{path}#L<line>")

        if DASHES.search(INLINE_CODE.sub("", raw)):
            dashes.append(f"  line {number}: {raw.strip()[:140]}")

    return backtick_links, missing_refs, dashes, bad_links


def main():
    payload = json.load(sys.stdin)
    md_path = payload.get("tool_input", {}).get("file_path", "")
    if not md_path.endswith(".md") or not os.path.isfile(md_path):
        return 0

    subprocess.run(["prettier", "--prose-wrap=never", "--log-level=warn", "--write", md_path], capture_output=True)

    infos = [info for info in map(repo_info, explored_roots(md_path, payload)) if info["slug"]]
    backtick_links, missing_refs, dashes, bad_links = scan(md_path, infos)
    if not (backtick_links or missing_refs or dashes or bad_links):
        return 0

    out = [f"Markdown guideline violations in {md_path} (prettier --prose-wrap=never was already applied):"]
    if bad_links:
        out.append("")
        out.append("file:line links that do not match the explored repo, commit or line:")
        out.extend(bad_links)

    if missing_refs:
        out.append("")
        out.append("Code references without file:line. Open each file, pick the exact line the sentence is about, and rewrite as [path:line](permalink#Lline):")
        out.extend(missing_refs)

    if backtick_links:
        out.append("")
        out.append("Backticks inside link text (Jira does not render them), use plain text:")
        out.extend(backtick_links)

    if dashes:
        out.append("")
        out.append("Em or en dashes in prose, rephrase without them:")
        out.extend(dashes)

    print("\n".join(out), file=sys.stderr)

    return 2


if __name__ == "__main__":
    sys.exit(main())
