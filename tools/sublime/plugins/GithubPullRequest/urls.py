import re
from typing import Dict, Optional
from urllib.parse import urlparse

_PR_PATH_RE = re.compile(r"^/([^/]+)/([^/]+)/pull/(\d+)(?:/.*)?$")


def parse_pr_url(url: str) -> Optional[Dict]:
    """https://github.com/OWNER/REPO/pull/NUMBER[/...] ->
    {"owner": str, "repo": str, "number": int}, else None.
    Tolerates trailing slashes, /files, #discussion fragments, query strings, and
    GitHub Enterprise hosts (e.g. github.mycorp.com). Returns None for non-PR URLs
    (issues, tree, blob), malformed input, and empty strings.

    The host is validated but not returned: nothing rebuilds a URL from these parts (the
    PR's own url is kept verbatim by review.resolve_pr precisely so the host survives)."""
    if not url or not isinstance(url, str):
        return None

    try:
        parsed = urlparse(url.strip())
    except ValueError:
        return None

    if parsed.scheme not in ("http", "https"):
        return None

    if not parsed.hostname:
        return None

    match = _PR_PATH_RE.match(parsed.path)
    if not match:
        return None

    owner, repo, number = match.groups()

    return {
        "owner": owner,
        "repo": repo,
        "number": int(number),
    }
