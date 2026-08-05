# GithubPullRequest — Design & Interface Contracts

GitHub pull-request review inside Sublime Text 4. Transparent on startup; everything on-demand. Nothing happens until `PR: Load pull-request` runs.

## Superseding decisions (this session)

1. **Non-mutating diff.** The plugin NEVER mutates git. No `gh pr checkout`, no branch, no `reset`. The user is already on the PR branch (that is how the PR is inferred). The gutter diff is drawn with `view.set_reference_document(base_text)` against the merge-base blob, fetched with read-only `git show`. Only read-only git is ever used (`git show`, `git merge-base`, `git rev-parse`).
2. **Pending-review batching (server-backed).** Comments queue into a real GitHub PENDING review (via GraphQL), then submit together with a verdict (APPROVE / COMMENT / REQUEST_CHANGES). Because the queue lives on GitHub, drafts survive crashes/restarts (restored by `load_pending` on reload) and show on github.com until submitted. The local `_drafts` list is just a display mirror.
3. **Plugin-owned PR panel.** No Sublime API can badge the sidebar file tree, so a dedicated bottom output panel lists changed files with `+N -M` stats plus unresolved- and pending-comment counts, colored by a bundled syntax and navigable via `result_file_regex` (double-click / Enter / F4).

Also removed since the first draft: deleted-line phantoms and LEFT-side (deleted-line) comment authoring (disliked in practice); the standalone quick-panel file list (folded into the bottom panel). Added: local **draft** comments shown with a distinct purple gutter icon and a pending popup.

## Runtime constraints (BINDING for all modules)

- **Python 3.8-safe, stdlib only.** The Sublime plugin host is Python 3.8. No `match`, no `X | Y` type unions, no `list[int]` builtin generics in annotations (use `typing.List`), no walrus abuse. `requests` is forbidden (breaks on the host); all network I/O goes through `gh`.
- **Dual-import pattern** so tests run standalone AND inside Sublime:
  ```python
  try:
      from .diff import parse_unified_diff
  except ImportError:
      from diff import parse_unified_diff
  ```
- **`sublime` / `sublime_plugin` may be imported ONLY by the glue layer** (`plugin.py`, `state.py`). The core (`urls`, `diff`, `mapper`, `render`, `gh`, `review`) must import neither, so it is testable with plain `python3 -m unittest`.
- Tests: `unittest`, files named `*_test.py`, **dict-keyed table cases** (`cases = {"name": (...)}`), in the SAME module namespace (no separate test package). Run `python3 -m unittest discover -p '*_test.py'`, `ruff check .`, `ruff format .` in the package dir.

## GitHub coordinate model (READ THIS before touching mapper/review)

We author review comments with the modern REST fields, NOT the legacy `position`:

- `side`: `"RIGHT"` (head/added side) or `"LEFT"` (base/deleted side).
- `line`: the line number on that side (1-based).
- `start_line` + `start_side`: for a multi-line comment, the first line of the range (`line` is the last). Omit both for a single-line comment.
- `path`: repo-relative file path.

Because the buffer holds the PR head file, a RIGHT-side comment on buffer row `R` (0-based) maps to `line = R + 1`. The diff is needed to know which rows are _commentable_ (part of a hunk). Authoring is RIGHT-side only; LEFT (`side` still appears on incoming threads for anchoring, but we never author on deleted lines). `position` is computed best-effort only as a fallback.

---

## Interface contracts (LOCKED — implement exactly these signatures)

Dataclasses are fine (3.7+). Use `typing.Optional/List/Dict`. Keep every module import-light.

### `urls.py`

```python
def parse_pr_url(url: str) -> Optional[Dict]:
    """https://github.com/OWNER/REPO/pull/NUMBER[/...] ->
       {"host": "github.com", "owner": str, "repo": str, "number": int}, else None.
       Tolerates trailing slashes, /files, #discussion fragments, and enterprise hosts."""
```

### `diff.py`

```python
@dataclass
class DiffLine:
    origin: str            # " " context | "+" added | "-" removed
    old_lineno: Optional[int]   # base-side line number (None for added lines)
    new_lineno: Optional[int]   # head-side line number (None for removed lines)
    position: int          # 1-based position within this file's patch (GitHub legacy position)
    content: str           # line text WITHOUT the leading origin char, no trailing newline

@dataclass
class Hunk:
    old_start: int
    old_count: int
    new_start: int
    new_count: int
    header: str            # full "@@ -a,b +c,d @@ ctx" line
    lines: List[DiffLine]

@dataclass
class FileDiff:
    path: str              # canonical path (new_path if present else old_path)
    old_path: Optional[str]
    new_path: Optional[str]
    is_new: bool
    is_deleted: bool
    is_rename: bool
    is_binary: bool
    additions: int
    deletions: int
    hunks: List[Hunk]

def parse_unified_diff(text: str) -> List[FileDiff]:
    """Parse `gh pr diff` / `git diff` unified output. Handle: multiple files, `diff --git`
       headers, rename lines, `new file mode` / `deleted file mode`, `Binary files ... differ`,
       `\\ No newline at end of file`, and multiple hunks per file. `position` counts every line
       after the file's first `@@` (hunk-header lines included), continuing across hunks, per
       GitHub's rule."""
```

### `mapper.py`

```python
class LineMap:
    def __init__(self, file_diff: FileDiff) -> None: ...

    def is_commentable(self, row: int) -> bool:
        """True if buffer row (0-based, RIGHT/head side) is part of a hunk (added or context)."""

    def anchor_to_row(self, side: str, line: int) -> Optional[int]:
        """Thread's (side, line) -> 0-based buffer row to place its gutter icon / popup.
           RIGHT: row = line - 1. LEFT: the buffer row of the hunk boundary the deleted line sits at."""

    def comment_range(self, start_row: int, end_row: int) -> Optional[Dict]:
        """RIGHT-side (multi-line) comment payload for a buffer row span. Returns
           {"path"? no, "side": "RIGHT", "line": end_line, "start_line": start_line|omitted,
            "start_side": "RIGHT"|omitted, "position": int|None}. None if the span has no
            commentable line. Single-line span -> no start_line/start_side keys."""
```

Note: `path` is added by the caller (review.py), not the mapper.

### `render.py` (pure minihtml; NO `sublime` import)

````python
def build_style() -> str:
    """<style> block using color-scheme vars (var(--greenish), var(--bluish), var(--redish),
       var(--yellowish), var(--purplish), var(--foreground), var(--background)). See
       SublimeGit/blame.py for the var pattern."""

def html_to_minihtml(body_html: str) -> str:
    """Down-convert GitHub's rendered `bodyHTML` to the minihtml subset: keep/remap a whitelist of
       tags (p, strong/b, em/i, code, pre, a[href], ul/ol/li, blockquote, h1-6, span, div, del/s,
       kbd, sub/sup), drop the rest keeping their text, strip <script>/<style>, <img> -> [alt],
       task-list <input type=checkbox> -> checkbox glyph, preserve <pre> newlines as <br>, escape
       all text. Implemented via an html.parser.HTMLParser subclass."""

def suggestions_in(body: str) -> List[str]:
    """Ordered ```suggestion``` blocks in a RAW markdown body. Shared with plugin._apply_suggestion
       so the Nth Apply link maps to the Nth applied suggestion."""

def thread_popup_html(thread: Dict) -> str:
    """Full minihtml doc for one review thread. Each comment: author, timestamp, and body — rendered
       from `body_html` via html_to_minihtml when present, else a minimal markdown fallback. Shows
       resolved/outdated tags and action links (Reply, Resolve/Unresolve, Open). For each
       ```suggestion``` block in the raw body, appends an 'Apply' action link."""

def pending_html(drafts: List[Tuple[int, Dict]]) -> str:
    """Popup for locally-queued (unposted) draft comments. Each item is (index_in_drafts, draft);
       renders the body and a 'Discard' action link keyed by that index."""

def draft_badge(count: int) -> str:
    """Short status-bar fragment, e.g. '✎ 3 drafts' (plain text, not HTML). '' when count == 0."""

def encode_action(action: str, **params) -> str:
    """-> 'subl:githubpullrequest?action=<action>&<k>=<quote(v)>...'. Values urllib.parse.quote'd,
       keys sorted. Actions: reply, resolve, unresolve, open, apply_suggestion, discard."""

def decode_action(href: str) -> Optional[Dict]:
    """Inverse. -> {'action': str, **params(str values)} or None if not a githubpullrequest href."""
````

The bottom file panel is built in `plugin.py`: a file row `+N -M  path:hunkline  <owners>` and, when the file has comments, an indented `(K unresolved) (P pending)  path:commentline` row. Owners come from a single `codeowners -- <all paths>` call at load (`_codeowners_map`, cached in `SESSION.owners_by_path`); they trail the `path:line` nav token so column alignment is preserved and `result_file_regex` (no longer `$`-anchored) still finds the target. Colored by `GithubPullRequestFiles.sublime-syntax`, not by `render.py`.

### `gh.py` (injectable subprocess client; NO `sublime` import)

```python
class GHError(Exception): ...

Runner = Callable[..., Tuple[int, str, str]]
# runner(args, cwd, stdin=None) -> (returncode, stdout, stderr). Default uses subprocess with a
# timeout; `stdin` is piped to the process (used for `gh api --input -` JSON bodies).

class GH:
    def __init__(self, cwd: Optional[str] = None, runner: Optional[Runner] = None) -> None: ...

    def api(self, path: str, method: str = "GET", fields: Optional[Dict] = None,
            input_obj: Optional[object] = None) -> object:
        """`gh api <path> [-X METHOD] [-f k=v]`. When input_obj is given, json.dumps it and send via
           `--input -` (used for nested bodies like the reviews `comments[]` array). Parse stdout
           JSON (raw string if not JSON). Raise GHError with stderr on non-zero exit."""

    def graphql(self, query: str, variables: Optional[Dict] = None) -> object:
        """`gh api graphql -f query=...` plus each variable as a field. IMPORTANT: int vars use `-F`
           (typed), string vars use `-f` (raw) — `-F` would coerce `@mentions` to filenames and
           numeric/true/false strings to typed literals, corrupting bodies/ids/owner/repo. Unwrap
           the top-level {'data': ...}; raise GHError if the payload has an `errors` array."""

    def pr_diff(self, number: Optional[int] = None) -> str:
        """`gh pr diff [<number>]` -> raw unified diff text."""

    def pr_view(self, number: Optional[int] = None, fields: Optional[List[str]] = None) -> Dict:
        """`gh pr view [<number>] --json <fields>` -> parsed dict. Default fields:
           number,title,baseRefName,headRefName,headRefOid,url,author,body,state."""
```

`gh` NEVER runs `gh auth token`; it relies on gh's own credential store.

### `review.py` (service; NO `sublime` import)

```python
class Review:
    def __init__(self, gh: GH, cwd: str,
                 git_runner: Optional[Runner] = None) -> None:
        """git_runner runs read-only git (show/merge-base/rev-parse); injectable for tests."""

    def resolve_pr(self) -> Dict:
        """Infer the PR from the current branch via gh.pr_view(); derive owner/repo from the
           returned url. Returns {'number','title','base','head','head_oid','url','state',
           'owner','repo'}. `_load` refuses to load unless state == 'OPEN' (open/draft)."""

    def merge_base(self) -> str:
        """read-only `git merge-base HEAD origin/<base>` (fallback <base>). Cached."""

    def changed_files(self) -> List[Dict]:
        """Parse gh.pr_diff() -> [{'path','additions','deletions','is_binary','file_diff': FileDiff}]."""

    def review_threads(self) -> List[Dict]:
        """GraphQL pullRequest.reviewThreads (paginated). Each thread dict per the shape below.
           Fetched once at load; the caller keys them by path. (Submitted threads only — pending
           review comments are NOT here; they come from load_pending.)"""

    def base_blob(self, path: str) -> Optional[str]:
        """read-only `git show <merge_base>:<path>` -> text, or None (added file / not found)."""

    # --- server-backed draft queue (a real GitHub PENDING review) ---
    # State: _pr_node_id (GraphQL PR id), _pending_review_id (None until created),
    # _drafts (synced; each has a `comment_id`), and _local_comments (queued but not
    # yet synced because the API was unreachable — no comment_id, lost on crash).

    def load_pending(self) -> None:
        """One GraphQL query: viewer.login + pullRequest.id + reviews(states:[PENDING]).
           Sets _pr_node_id; if a viewer-authored PENDING review exists, sets _pending_review_id
           and rebuilds _drafts from its comments. Resets _local_comments. Called once at load."""

    def queue_comment(self, path: str, payload: Dict, body: str) -> None:
        """Try to sync (_sync_draft: lazy addPullRequestReview + addPullRequestReviewThread).
           On success -> _drafts (with comment_id). On GHError -> kept in _local_comments and
           GHError re-raised so the caller can notify (the comment is NOT lost)."""

    def drafts(self) -> List[Dict]:
        """_drafts (synced) + _local_comments (unsynced), in that order."""

    def local_count(self) -> int: ...  # number of unsynced comments

    def flush_local(self) -> None:
        """Sync every _local_comment to the pending review. On failure the already-synced
           ones stay in _drafts and the rest stay local; GHError re-raises."""

    def discard_draft(self, index: int) -> None:
        """Index into drafts() (synced first, then local). Synced -> deletePullRequestReviewComment
           (and deletePullRequestReview when _drafts empties); local -> just drop it."""

    def clear_drafts(self) -> None:
        """deletePullRequestReview when one exists; clear _drafts + _local_comments + id."""

    def submit_review(self, verdict: str, body: str = "") -> Dict:
        """verdict in {APPROVE, COMMENT, REQUEST_CHANGES}. flush_local() first (so unsent
           comments join the review; raises if still offline). Then submitPullRequestReview
           with a pending review, else a bare REST POST review. Clears everything."""

    def reply_comment(self, thread_id: str, body: str) -> Dict:
        """GraphQL addPullRequestReviewThreadReply (or REST reply-to-comment)."""

    def set_thread_resolved(self, thread_id: str, resolved: bool) -> Dict:
        """GraphQL resolveReviewThread / unresolveReviewThread."""
```

Thread dict shape (produced by `review_threads`, consumed by `render.thread_popup_html`):

```python
{
  "id": str,                 # GraphQL thread node id (for resolve/reply)
  "path": str,
  "line": Optional[int],     # head-side line (RIGHT); may be None if outdated
  "original_line": Optional[int],
  "side": str,               # "RIGHT" | "LEFT"
  "start_line": Optional[int],
  "is_resolved": bool,
  "is_outdated": bool,
  "url": str,
  "comments": [
    {"author": str, "body": str, "body_html": str, "created_at": str, "url": str, "diff_hunk": str}
  ],
}
```

`body` is raw markdown (used for suggestion extraction); `body_html` is GitHub's rendered HTML (fed to `render.html_to_minihtml`). `review_threads` fetches both via the GraphQL `bodyHTML` field.

---

## Glue layer (Wave 3, imports `sublime`)

- `state.py` — `SESSION` singleton: `pr` meta, `threads_by_path`, `files` + `files_by_path`, `line_maps: Dict[str, LineMap]`, `review: Review`, `base_blob_cache`, `root`/`cwd`, `active`. Plus `unresolved_count`, `pending_by_path`, and `file_entries_for_panel` (alphabetical, enriched with `unresolved` + `pending` counts).
- `plugin.py` — commands + `GithubPullRequestListener`. All gh/git calls run through `sublime.set_timeout_async`; UI mutation (regions, popups, panels, status) back on the main thread via `set_timeout`. Decoration = `set_reference_document` diff (empty base for new files → all green)
  - blue thread gutter icons (`githubpullrequest.threads`) + purple draft gutter icons (`githubpullrequest.drafts`). Popups (hover or command) render threads and pending drafts; action links dispatched through `render.decode_action`. Suggestion-apply edits the buffer via the internal `github_pull_request_replace_lines` TextCommand. The changed-files bottom panel is built here. Queue/discard/submit are now network round-trips (server-backed drafts), so they run in `_async` workers with `GHError` handling. A queue that can't reach GitHub notifies but keeps the comment locally (no re-prompt). `End review` prompts `yes_no_cancel`: if there are unsent (local) comments, Submit to GitHub / Discard / Cancel (`flush_local` vs `clear_drafts`); otherwise, for the already-synced pending review, Keep on GitHub / Discard from GitHub / Cancel.
- `Context.sublime-menu` — right-click entry running `github_pull_request_add_comment` (enabled only when a PR is active).
- `.sublime-commands` — palette entries, captions prefixed `GithubPullRequest:` (match siblings).
- `GithubPullRequest.sublime-settings` — `auto_show_popup`, `show_gutter_icon`, `hide_outdated` (bool; drops outdated threads in `_index_threads` so all surfaces exclude them), `gutter_icon`, `conventional_comments` (bool), `comment_labels` (list of `{emoji?, label, description}`). When `conventional_comments` is on, `github_pull_request_add_comment` first shows a fuzzy quick panel of labels (plus a "(plain comment)" skip); the chosen label is prefixed as `"<emoji> <label>: "` (emoji omitted if absent) to the typed subject before queuing. Also `claude_review_prompt` (`{base}` placeholder) for the `github_pull_request_review_in_tmux` command, which `tmux split-window`s the attached session (auto-detected via `tmux list-sessions`) in the repo root running `claude "$(cat <prompt-file>)"` interactively; base = loaded PR base else `git symbolic-ref refs/remotes/origin/HEAD`. No git mutation (tmux + read-only git only).
- `GithubPullRequestFiles.sublime-syntax` — colors the bottom panel (assigned to the output panel): `+N` green / `-M` red (markup.inserted/deleted), `(K unresolved)` yellow (markup.changed), `(P pending)` dimmed (comment), CODEOWNERS blue (entity.name.function, matched as `\S*@\S+`). Foreground-only scopes so there is no background fill.

## Build waves

1. Parallel: `urls`, `diff`, `mapper`, `render`, `gh` (+ `*_test.py`). Headless-verifiable.
2. `review` (+ tests) composing Wave 1.
3. Glue (`state`, `plugin`, menus, commands, settings). `py_compile` + `ruff` only.
4. Wire `install_plugin "${TEXT_PKG}" "GithubPullRequest"` into `tools/sublime/init.sh`; final lint sweep.
