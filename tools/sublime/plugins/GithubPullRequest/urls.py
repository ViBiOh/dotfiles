import re
from typing import Dict, Optional
from urllib.parse import urlparse

_PR_PATH_RE = re.compile(r"^/([^/]+)/([^/]+)/pull/(\d+)(?:/.*)?$")


def parse_pr_url(url: str) -> Optional[Dict]:
    """https://github.com/OWNER/REPO/pull/NUMBER[/...] ->
    {"host": "github.com", "owner": str, "repo": str, "number": int}, else None.
    Tolerates trailing slashes, /files, #discussion fragments, query strings, and
    GitHub Enterprise hosts (e.g. github.mycorp.com). Returns None for non-PR URLs
    (issues, tree, blob), malformed input, and empty strings."""
    if not url or not isinstance(url, str):
        return None

    try:
        parsed = urlparse(url.strip())
    except ValueError:
        return None

    if parsed.scheme not in ("http", "https"):
        return None

    host = parsed.hostname
    if not host:
        return None

    match = _PR_PATH_RE.match(parsed.path)
    if not match:
        return None

    owner, repo, number = match.groups()

    return {
        "host": host,
        "owner": owner,
        "repo": repo,
        "number": int(number),
    }
