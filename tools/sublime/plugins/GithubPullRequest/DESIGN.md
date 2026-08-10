# GithubPullRequest — Design & Interface Contracts

GitHub pull-request review inside Sublime Text 4. Transparent on startup; everything on-demand. Nothing happens until `GithubPullRequest: Load pull-request` runs.

## Core decisions

1. **Non-mutating diff.** The plugin NEVER mutates git. No `gh pr checkout`, no branch, no `reset`. The user is already on the PR branch (that is how the PR is inferred). The gutter diff is drawn with `view.set_reference_document(base_text)` against the merge-base blob, fetched with read-only `git show`. Only read-only git is ever used (`git show`, `git merge-base`, `git rev-parse`).
2. **Pending-review batching (server-backed).** Comments queue into a real GitHub PENDING review (via GraphQL), then submit together with a verdict (APPROVE / COMMENT / REQUEST_CHANGES). Because the queue lives on GitHub, drafts survive crashes/restarts (restored by `load_pending` on reload) and show on github.com until submitted. The local `_drafts` list is just a display mirror.
3. **Plugin-owned PR panel.** No Sublime API can badge the sidebar file tree, so a dedicated bottom output panel lists changed files with `+N -M` stats plus unresolved- and pending-comment counts, colored by a bundled syntax and navigable via `result_file_regex` (double-click / Enter / F4).

Deliberately out of scope: deleted-line phantoms and LEFT-side (deleted-line) comment authoring (tried, disliked in practice); a standalone quick-panel file list (folded into the bottom panel).

## Runtime constraints (BINDING for all modules)

- **Python 3.8-safe, stdlib only.** The Sublime plugin host is Python 3.8. No `match`, no `X | Y` type unions, no `list[int]` builtin generics in annotations (use `typing.List`), no walrus abuse. `requests` is forbidden (breaks on the host); all network I/O goes through `gh`.
- **Dual-import pattern** so tests run standalone AND inside Sublime:
  ```python
  try:
      from .diff import parse_unified_diff
  except ImportError:
      from diff import parse_unified_diff
  ```
- **`sublime` / `sublime_plugin` may be imported ONLY by the glue layer** (`plugin.py`, `anchors.py`). Every other module (`urls`, `diff`, `mapper`, `render`, `gh`, `review`, `state`, `repo`, `owners`, `layout`, `labels`, `panel`) must import neither, so it is testable with plain `python3 -m unittest`. When something needs a view, prefer duck-typing it (`repo.rel_path` only calls `view.file_name()`) over reaching for `sublime`.
- Tests: `unittest`, files named `*_test.py`, **dict-keyed table cases** (`cases = {"name": (...)}`), in the SAME module namespace (no separate test package). Run `python3 -m unittest discover -p '*_test.py'`, `ruff check .`, `ruff format .`, and `python3 -m py_compile plugin.py anchors.py` (the two `sublime` importers) in the package dir. `ruff.toml` pins `target-version = "py38"` so the linter never suggests syntax the plugin host cannot run — it is the ONLY thing enforcing that, since `.python-version` is 3.14 so the tests run on a current interpreter.

## GitHub coordinate model (READ THIS before touching mapper/review)

We author review comments with the modern REST fields (`line`/`side`):

- `side`: `"RIGHT"` (head/added side) or `"LEFT"` (base/deleted side).
- `line`: the line number on that side (1-based).
- `start_line` + `start_side`: for a multi-line comment, the first line of the range (`line` is the last). Omit both for a single-line comment.
- `path`: repo-relative file path.

Because the buffer holds the PR head file, a RIGHT-side comment on buffer row `R` (0-based) maps to `line = R + 1`. That identity only holds while the buffer matches the PR head commit, so `anchors` diffs against `SESSION.pr["head_oid"]` (NOT local `HEAD`, which may carry branch commits the PR lacks) and translates in both directions. The diff is needed to know which rows are _commentable_ (part of a hunk). Authoring is RIGHT-side only; LEFT (`side`) still appears on incoming threads for anchoring, but we never author on deleted lines.

---

## Interface contracts (LOCKED — implement exactly these signatures)

Dataclasses are fine (3.7+). Use `typing.Optional/List/Dict`. Keep every module import-light.

### `urls.py`

```python
def parse_pr_url(url: str) -> Optional[Dict]:
    """https://github.com/OWNER/REPO/pull/NUMBER[/...] ->
       {"owner": str, "repo": str, "number": int}, else None.
       Tolerates trailing slashes, /files, #discussion fragments, and enterprise hosts.
       The host is VALIDATED but not returned: nothing rebuilds a url from these parts,
       because resolve_pr keeps the PR's own url verbatim so the host survives."""
```

### `diff.py`

Every field below has a reader. Deliberately ABSENT, having been parsed and stored but read by nothing: `FileDiff.is_deleted` / `is_rename` (a deleted file is already `new_path is None`, and a rename is already `old_path != new_path`), plus `Hunk.old_start` / `old_count` / `new_count` / `header`, which cost memory per hunk for the whole session. The parser still needs all of them as locals to walk the body; it just does not retain them.

```python
@dataclass
class DiffLine:
    origin: str            # " " context | "+" added | "-" removed
    old_lineno: Optional[int]   # base-side line number (None for added lines)
    new_lineno: Optional[int]   # head-side line number (None for removed lines)
    content: str           # line text WITHOUT the leading origin char, no trailing newline

@dataclass
class Hunk:
    new_start: int         # head-side start line (panel.first_hunk_line navigates to it)
    lines: List[DiffLine]

@dataclass
class FileDiff:
    path: str              # canonical path (new_path if present else old_path)
    old_path: Optional[str]
    new_path: Optional[str]
    is_new: bool           # empty base blob -> all-green gutter
    is_binary: bool        # no reference document at all
    additions: int
    deletions: int
    hunks: List[Hunk]

def parse_unified_diff(text: str) -> List[FileDiff]:
    """Parse `gh pr diff` / `git diff` unified output. Handle: multiple files, `diff --git`
       headers, rename lines, `new file mode`, `Binary files ... differ`,
       `\\ No newline at end of file`, and multiple hunks per file."""
```

### `repo.py` / `owners.py` / `layout.py` / `labels.py` / `panel.py` (NO `sublime` import)

```python
# repo.py     read-only git + repo-relative paths
def git_root(path: str) -> Optional[str]: ...          # None outside a repo
def run_git(root: str, args: List[str]) -> Tuple[int, str]:
    """(returncode, stdout); (1, "") on any failure so callers only branch on the code."""
def rel_path(view) -> Optional[str]: ...               # duck-typed on view.file_name()
def abs_path(rel: str) -> str: ...

# owners.py   CODEOWNERS, best effort
def codeowners_map(root, paths, runner=None) -> Dict[str, str]:
    """ONE `codeowners -- <paths>` call. {} on any failure; '(unowned)' -> ''."""

# layout.py   compose-split geometry
def split_below_layout(layout: Dict, fraction: float = 0.7) -> Dict:
    """Add a full-width group below, existing groups scaled into the top `fraction`.
       Does not mutate the input."""

# labels.py   Conventional Comments picker
def label_tag(entry: Dict) -> str: ...                 # '💡 suggestion' | 'suggestion'
# The label SET is not here. GithubPullRequest.sublime-settings (`comment_labels`) is its
# only copy, since load_settings merges it under any User override; a Python default would
# just be a second one to keep in sync. Same for agent_command / agent_review_prompt, which
# plugin.py reads with no fallback. labels_test.py validates the packaged file.

# panel.py    changed-files panel TEXT (colouring is the syntax file's job)
def drafts_for_path(path) -> List[Tuple[int, Dict]]: ...   # (uid, draft), RIGHT side only
def first_hunk_line(path) -> int: ...                      # else 1
def first_comment_line(path) -> int:
    """Earliest unresolved thread or pending draft (multi-line counts from its START),
       else earliest thread, else first hunk."""
def files_panel_text(open_paths=frozenset(), to_buffer_line=_identity_line) -> Optional[str]:
    """None when no files changed. Rows begin with a fixed-width marker slot: '● ' when the
       path is in `open_paths` (open as a tab), two spaces otherwise, so the path column
       stays aligned and the marker never joins the `path:line` nav token.
       Every line emitted is a GitHub (head-commit) line; `to_buffer_line(path, line)`
       translates it to where it currently sits in the editor, so a click lands on the same
       row as the gutter icon after local edits. Defaults to identity (no views needed);
       plugin._files_panel_body injects the real one."""
```

### `mapper.py`

```python
def head_anchor(opcodes, start_row, end_row) -> Tuple[Optional[int], Optional[int], bool]:
    """Pure. difflib opcodes (committed file as `a`, live buffer as `b`) + a buffer row span
       -> (first_head_row, last_head_row, has_edit), or (None, None, has_edit) when the span
       covers no head line (a purely local insertion). `has_edit` drives suggestion prefill.
       A `delete` opcode is zero-width in the buffer (j1 == j2) so it can never satisfy a
       row-overlap test; it is matched as a position between rows instead."""

def head_row_to_buffer_row(opcodes, head_row: int) -> Optional[int]:
    """Pure. Where a head-commit row currently sits in the buffer; changed/removed head rows
       anchor to their block start. anchors.remap_head_row wraps this with the opcode cache."""

class LineMap:
    def __init__(self, file_diff: FileDiff) -> None: ...

    def is_commentable(self, row: int) -> bool:
        """True if buffer row (0-based, RIGHT/head side) is part of a hunk (added or context)."""

    def anchor_to_row(self, side: str, line: int) -> Optional[int]:
        """Thread's (side, line) -> 0-based HEAD-commit row. RIGHT: row = line - 1.
           LEFT: the head row of the hunk boundary the deleted line sits at.
           (`anchors.remap_head_row` then shifts this to the live buffer row.)
           EVERY caller must come through here, never `line - 1` directly: a thread's
           line is numbered on its OWN side, so the identity holds for RIGHT only. For
           some LEFT lines the two agree by coincidence, which is why the guard test
           picks the base line where they do not."""

    def comment_range(self, start_row: int, end_row: int) -> Optional[Dict]:
        """RIGHT-side (multi-line) comment payload for a buffer row span. Returns
           {"side": "RIGHT", "line": end_line, "start_line": start_line|omitted,
            "start_side": "RIGHT"|omitted}. None if the span has no commentable line.
            Single-line span -> no start_line/start_side keys. (`path` added by review.py.)
            The span is narrowed to commentable rows, so a multi-row selection can
            collapse to a single-line payload; plugin.py surfaces the effective range."""
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
       all text. An <a> keeps its href ONLY when http(s) (_safe_anchor); anything else becomes a
       bare <a>, text intact. That is a SECURITY gate, not cosmetics: a `subl:githubpullrequest?`
       href in a body is dispatched by plugin._handle_action before any browser check, so a click
       would fire a real discard/resolve/edit. Implemented via an html.parser.HTMLParser subclass."""

def suggestions_in(body: str) -> List[str]:
    """Ordered ```suggestion``` blocks in a RAW markdown body. Shared with plugin._apply_suggestion
       so the Nth Apply link maps to the Nth applied suggestion. MUST agree in count with the
       fence scan in _render_body; a fence's info string ends at the newline, so both require
       that newline and both rstrip (never strip) the lang. render_test compares the two counts."""

def thread_popup_html(thread: Dict) -> str:
    """Full minihtml doc for one review thread. Each comment: author, timestamp, and body — rendered
       from `body_html` via html_to_minihtml when present, else a minimal markdown fallback. Shows
       resolved/outdated tags and action links (Reply, Resolve/Unresolve, Open). For each
       ```suggestion``` block in the raw body, appends an 'Apply' action link. Comments are
       stacked by _stack so a thread reads as distinct comments, ruled apart but with no rule
       before the first nor after the last. Emits NO <style>; see popup()."""

def popup(sections: List[str]) -> str:
    """A whole popup document: build_style() ONCE, then the sections ruled apart.
       Sections (thread_popup_html / pending_html) must therefore not embed the stylesheet
       themselves — stacking would nest <style> inside a <div>. Used by
       plugin._show_threads_popup, since one line can carry several threads plus drafts."""

# _stack: the rule between stacked items is a `border-top` on the FOLLOWING block, never a
# standalone empty <div> — minihtml supports border-top-{width,style,color} but has no
# `height`, so an empty element has no box to draw on. <hr> is not an option: minihtml
# drops it silently (cost a round trip to learn).

def pending_html(drafts: List[Tuple[int, Dict]]) -> str:
    """Popup for locally-queued (unposted) draft comments. Each item is (uid, draft) where uid is
       the draft's stable id; renders the body and 'Edit' / 'Discard' action links keyed by that uid."""

def draft_badge(count: int) -> str:
    """Short status-bar fragment, e.g. '✎ 3 drafts' (plain text, not HTML). '' when count == 0."""

def encode_action(action: str, **params) -> str:
    """-> 'subl:githubpullrequest?action=<action>&<k>=<quote(v)>...'. Values urllib.parse.quote'd,
       keys sorted. Actions: reply, resolve, unresolve, open, apply_suggestion, discard."""

def decode_action(href: str) -> Optional[Dict]:
    """Inverse. -> {'action': str, **params(str values)} or None if not a githubpullrequest href."""

def action_int(action: Dict, key: str, default: Optional[int] = None) -> Optional[int]:
    """A decoded param as an int; None when absent (without a default) or not a number. Actions
       are read out of popup HTML, so a forged link can put anything in a uid: a bare int() on it
       raises inside Sublime's link callback. plugin._handle_action treats None as a no-op."""
````

#### The changed-files panel

`panel.py` builds the TEXT; `plugin.py` only creates the output panel and its settings; the colouring is `GithubPullRequestFiles.sublime-syntax`'s job. Two rows per file, each its own `result_file_regex` click target:

```
<marker>+N -M                       path:hunkline  <owners>
<marker>    (K unresolved) (P pending)  path:commentline
```

**The marker slot.** `● ` when the file is open as a tab in that window, two blanks otherwise, both the same width so the path column never shifts, and outside the `path:line` token so navigation still matches. `plugin._open_views` walks `window.views()`, so the cost follows the number of open tabs rather than the size of the PR. A real character is unavoidable: a `.sublime-syntax` can only assign scopes by matching TEXT. A zero-width one was tried and rejected, because Sublime renders format characters as their codepoint.

**Greying an open row** works by inheritance, not by a colour scheme. The syntax pushes a context on `^●` and scopes both the marker and that row's `path:line` token `comment.open-file.*`; every scheme dims anything under `comment.`, so a visited file recedes. Keep those scopes under `comment.` or they silently take the default foreground. No `.sublime-color-scheme` is shipped, deliberately: `font_style` (italic/bold) is the only thing a syntax cannot express, and scheme overrides merge by the ACTIVE scheme's NAME, so they stop applying the moment the user switches schemes.

**Colours** are picked so no two elements share a hue in Mariana, and are all foreground-only:

| Element                | Scope               | Hue              |
| ---------------------- | ------------------- | ---------------- |
| PR header              | `entity.name.class` | orange           |
| `+N`                   | `markup.inserted`   | green            |
| `-M`                   | `markup.deleted`    | red              |
| `(K unresolved)`       | `support.type`      | blue             |
| `(P pending)`          | `comment`           | grey             |
| CODEOWNERS (`\S*@\S+`) | `support.constant`  | mauve            |
| open row               | `comment.open-file` | grey (inherited) |

Mariana has no further distinct hue reachable by a scope (`orange3` is a true yellow, but no rule maps to it). Never use `invalid`, `markup.raw` or `diff.inserted` here: they set a BACKGROUND.

**Layout.** A blank line separates the header from the rows; the PR description (`pr["body"]`, CRLF- and trailing-blank normalised by `panel._description_lines`) trails them after another blank line, so it never pushes the rows out of view of a panel a few lines tall. That description is free text sharing the row rules, so an `@mention` in it is tinted mauve and a `host:port` in it is a (harmless) `result_file_regex` target; the header and marker rules are anchored tightly (`^PR #\d+ ·`, `^●(?= [+ ])`) so prose cannot be mistaken for a row. Owners come from a single `codeowners -- <all paths>` call at load (`owners.codeowners_map`, cached in `SESSION.owners_by_path`) and trail the `path:line` token, so alignment is kept and the no-longer-`$`-anchored `result_file_regex` still finds its target.

**`syntax_test.py` guards the drift** between the two files, which reference each other only by string and would fail with NO error: the marker character, the grey-by-inheritance scopes, the absence of a colour-scheme override, the un-anchored `+N -M` rule (it must not repaint a hyphen inside a path), and that every token rule still matches a row `panel.py` actually emits.

**Nav lines are head-commit lines.** Both targets (the file row's first hunk, the sub-row's first comment) are translated by `plugin._files_panel_body`, which builds the path→view map once (`_open_views`, shared with the marker) and runs each line through `anchors.remap_head_row`. A file that is not open keeps its head line: with no buffer, nothing can have drifted.

**Refreshing rewrites in place** (`github_pull_request_set_text` + restored `viewport_position`) rather than destroying and recreating, so a refresh never resets the scroll position nor re-runs `show_panel`. Because the panel outlives a load (only End review destroys it), `_files_panel` re-applies `result_base_dir` on every call: it depends on `SESSION.root`, so a second Load in the same window would otherwise keep resolving clicks against the previous repository.

**When it refreshes.** `on_load_async` and (deferred one tick) `on_pre_close`, so the markers track the tab set; and `on_modified_async` through the `_redraw_when_settled` debounce, so the nav lines and the gutter icons track local edits (before that debounce existed, icons only refreshed on save or on a tab switch). The debounce schedules one async timer per keystroke but acts only if `change_count` has not moved since, so a burst of typing costs ONE redraw rather than one per character. That matters because each redraw re-derives the head-to-buffer mapping, i.e. a `git show <head_oid>:<path>` plus a full diff — which is also why the timer is `set_timeout_async` and the redraw goes through `_redraw_all`; see the threading rule in AGENTS.md. It fires only for a loaded review and a path in `files_by_path`, which excludes the compose buffer and the panel itself (neither has a file name), so rewriting the panel cannot re-enter the handler.

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
        """`gh pr view [<number>] --json <fields>` -> parsed dict. Default fields (_PR_VIEW_FIELDS):
           number,title,baseRefName,url,state,headRefOid,body. headRefOid is NOT optional — every
           buffer<->PR line mapping is computed against it (see anchors._base_rev) — and body is
           what the files panel shows under the rows."""
```

`gh` NEVER runs `gh auth token`; it relies on gh's own credential store.

### `review.py` (service; NO `sublime` import)

```python
class CommentRejected(GHError):
    """GitHub answered 200 with `thread: null` and no `errors` array, meaning it refuses to
       anchor the comment (lines the PR diff does not carry). Permanent, unlike a plain
       GHError, so the comment is never kept in the local queue (see queue_comment /
       flush_local)."""

class Review:
    def __init__(self, gh: GH, cwd: str,
                 git_runner: Optional[Runner] = None) -> None:
        """git_runner runs read-only git (show/merge-base/rev-parse); injectable for tests."""

    # `head_oid` (headRefOid) is the revision GitHub's line numbers refer to; every
    # buffer<->PR mapping in anchors.py is computed against it, not local HEAD.
    def resolve_pr(self) -> Dict:
        """Infer the PR from the current branch via gh.pr_view(); derive owner/repo from the
           returned url. Returns
           {'number','title','base','state','owner','repo','url','head_oid','body'}.
           `url` is stored VERBATIM (not rebuilt from owner/repo/number) because only it
           carries the host, which is what keeps GitHub Enterprise working.
           `_load` refuses to load unless state == 'OPEN' (open/draft)."""

    def merge_base(self) -> str:
        """read-only `git merge-base HEAD origin/<base>` (fallback <base>). Cached."""

    def changed_files(self) -> List[Dict]:
        """Parse gh.pr_diff() -> [{'path','additions','deletions','is_binary','file_diff': FileDiff}]."""

    def review_threads(self) -> List[Dict]:
        """GraphQL pullRequest.reviewThreads (paginated). Each thread dict per the shape below.
           Fetched once at load; the caller keys them by path. reviewThreads DOES return the
           viewer's own pending draft threads, so any thread whose root comment state is PENDING
           is skipped here (it comes from load_pending instead, else it would show twice); that
           root comment is always on the first page, so the skip is pagination-independent.
           BOTH levels paginate: a nested connection is capped at 100 rows whatever the outer
           page asks for, so each thread's comments are completed by a follow-up query on the
           thread node (_THREAD_COMMENTS_QUERY via _all_comments)."""

    def base_blob(self, path: str) -> Optional[str]:
        """read-only `git show <merge_base>:<path>` -> text, or None (added file / not found)."""

    # --- server-backed draft queue (a real GitHub PENDING review) ---
    # State: _pr_node_id (GraphQL PR id), _pending_review_id (None until created),
    # _drafts (synced; each has a `comment_id`), and _local_comments (queued but not
    # yet synced because the API was unreachable — no comment_id, lost on crash).
    # Every draft carries a stable `uid` (monotonic); edit/discard key on it, not on
    # list position, so a popup action stays correct even if the queue shifts.

    def load_pending(self) -> None:
        """GraphQL: pullRequest.id + reviews(states:[PENDING]).
           Sets _pr_node_id; if a viewer-authored PENDING review exists, sets _pending_review_id
           and rebuilds _drafts from its comments. Resets _local_comments. Called once at load.
           Paginates BOTH the reviews connection (the viewer's can sit past page one) and that
           review's comments (_REVIEW_COMMENTS_QUERY): overflow drafts missing from the mirror
           stay live on GitHub with nothing able to edit or discard them. Stops at the first
           viewer-authored review, since there is only ever one."""

    def queue_comment(self, path: str, payload: Dict, body: str) -> None:
        """Try to sync (_sync_draft: lazy addPullRequestReview + addPullRequestReviewThread).
           On success -> _drafts (with comment_id). On GHError -> kept in _local_comments and
           GHError re-raised so the caller can notify (the comment is NOT lost). On
           CommentRejected (GitHub returned a null thread: it will not anchor these lines)
           -> NOT kept, re-raised: a retry would fail identically and block every submit."""

    def drafts(self) -> List[Dict]:
        """_drafts (synced) + _local_comments (unsynced), in that order."""

    def local_count(self) -> int: ...  # number of unsynced comments

    def flush_local(self) -> None:
        """Sync every _local_comment to the pending review. A CommentRejected one is DROPPED
           (never put back) and reported by raising CommentRejected after the rest flushed:
           re-queuing it would fail identically and wedge every later submit. On a transient
           GHError the already-synced ones stay in _drafts, the current one and those after it
           stay local, and it re-raises so a retry resumes where it stopped."""

    def discard_draft(self, uid: int) -> None:
        """Find the draft by uid. Synced -> deletePullRequestReviewComment (and
           deletePullRequestReview when _drafts empties; that delete is best-effort since
           removing the last comment already auto-removes the empty review); local -> drop."""

    def edit_draft(self, uid: int, body: str) -> None:
        """Find the draft by uid and change its body. Synced -> updatePullRequestReviewComment;
           local -> mirror only."""

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
  "line": Optional[int],     # line on `side` (NOT always head); may be None if outdated
  "original_line": Optional[int],
  "side": str,               # "RIGHT" | "LEFT" -- resolve through LineMap.anchor_to_row
  "start_line": Optional[int],
  "original_start_line": Optional[int],   # an outdated range keeps BOTH ends only here
  "is_resolved": bool,
  "is_outdated": bool,
  "url": str,
  "comments": [
    {"author": str, "body": str, "body_html": str, "created_at": str, "url": str}
  ],
}
```

`body` is raw markdown (used for suggestion extraction); `body_html` is GitHub's rendered HTML (fed to `render.html_to_minihtml`). `review_threads` fetches both via the GraphQL `bodyHTML` field.

---

## Glue layer (imports `sublime`)

- `state.py` — `SESSION` singleton (no `sublime` import, so it is unit-tested in `state_test.py` and is NOT part of the glue): `pr` meta, `threads_by_path`, `files` + `files_by_path`, `line_maps: Dict[str, LineMap]`, `review: Review`, `base_blob_cache` + `base_blob_pending` (paths a worker is already fetching, so two views on one file cannot each spawn a `git show`), `owners_by_path`, `root`, `active`. Plus `unresolved_count`, `pending_by_path`, and `file_entries_for_panel` (alphabetical, enriched with `unresolved` + `pending` + `owners` on COPIES, never writing through to `files`). `reset()` must leave every field empty: it is all `End review` relies on.
- `anchors.py` — the only module that knows where a comment sits in the buffer right now. `selection_to_head(view, start_row, end_row)` maps a selection buffer→head when authoring; `remap_head_row(view, head_row)` maps head→buffer for every placement (icons, popups, navigation, suggestion-apply), so icons track the right line even after local edits shift the buffer. `thread_rows` / `draft_rows` give a comment's whole covered span (github.com highlights the full range) while `thread_row` (its first row) stays the single navigation stop. Two caches: `view_opcodes` keyed on `change_count`, and thread rows additionally keyed on `_THREADS_STAMP` because `on_hover` hit-tests every thread on each mouse move. Invalidation is exposed as `bump_threads_stamp()` (called after the thread index is rebuilt), `forget_view(view_id)` and `clear_caches()`, since `global` cannot cross modules. `warm_opcodes(views)` fills the opcode cache and is WORKER-THREAD ONLY, for the reason below. The pure arithmetic it drives lives in `mapper.py`.
- `plugin.py` — commands + `GithubPullRequestListener`. All gh/git calls run through `sublime.set_timeout_async`; UI mutation (regions, popups, panels, status) back on the main thread via `set_timeout`.

  **The head-to-buffer mapping counts as I/O.** `anchors.view_opcodes` is a `git show` plus a full diff PER FILE, and every placement reads it, so a redraw spanning all open PR files must never start on the main thread. `_redraw_all(window, done_message)` is the single entry point: it warms the cache on the worker, then draws through `_main`. `_load` builds the session on the worker for the same reason (it is pure state, and `_build_session` has just cleared the caches, so drawing first would pay for every file). Deferred recomputation uses `set_timeout_async` (`_redraw_when_settled`, `_show_when_ready`). The full rule is in AGENTS.md.

  Decoration = `set_reference_document` diff (empty base for new files → all green)

  - blue thread gutter icons (`githubpullrequest.threads`) + purple draft gutter icons (`githubpullrequest.drafts`), placed through `anchors`, added with `sublime.HIDDEN` and deliberately NOT `PERSISTENT` (persistent regions are saved into the workspace, so quitting mid-review would restore icons with no session behind them and `End review` disabled). Popups (on hover, or when comment navigation lands on a commented line) render threads and pending drafts; action links dispatched through `render.decode_action`. Suggestion-apply edits the buffer via the internal `github_pull_request_replace_lines` TextCommand. The changed-files bottom panel is built here. Queue/discard/submit are network round-trips (server-backed drafts), so they run in `_async` workers with `GHError` handling. A queue that can't reach GitHub notifies but keeps the comment locally (no re-prompt). `End review` prompts `yes_no_cancel`: if there are unsent (local) comments, Submit to GitHub / Discard / Cancel (`flush_local` vs `clear_drafts`); otherwise, for the already-synced pending review, Keep on GitHub / Discard from GitHub / Cancel. Action links that are not plugin actions (or an `open` action) are handed to the browser only when they are `http(s)` — popup bodies come from comment HTML any PR participant can write. That is the LAST of three gates, not the only one: the sanitizer strips a non-`http(s)` href before it can ever look like an action (a `subl:githubpullrequest?` one in a body would be dispatched ahead of this check), and `_handle_action` validates each parameter (`render.action_int`, a required `id`) so a forged link is a no-op instead of an exception in the link callback.

- `.sublime-commands` — palette entries, captions prefixed `GithubPullRequest:` (match siblings). Two commands work WITHOUT a loaded review (`github_pull_request_review_in_tmux`, `github_pull_request_open_in_browser`); both resolve the repo through `_window_root` (session root, else `git_root` of the window's cwd). Open-in-browser prefers `SESSION.pr["url"]` (no round-trip) and otherwise falls back to `gh pr view --json url`; the url is stored verbatim by `resolve_pr` rather than rebuilt from owner/repo/number, because only it carries the host (GitHub Enterprise). It goes through `_open_external`, so a non-`http(s)` url is refused like any comment link.
- `GithubPullRequest.sublime-settings` — `auto_show_popup`, `show_gutter_icon`, `hide_outdated` (bool; drops outdated threads in `_index_threads` so all surfaces exclude them), `gutter_icon`, `conventional_comments` (bool), `comment_labels` (list of `{emoji?, label, description}`). When `conventional_comments` is on, `github_pull_request_add_comment` first shows a fuzzy quick panel of labels (plus a "(plain comment)" skip), then `_open_compose` opens a scratch buffer in a split **below** the file (`layout.split_below_layout` adds a full-width bottom group; existing groups shrink into the top 70%). The buffer is prefilled with `"<emoji> <label>: "` (or, when the commented line(s) carry the reviewer's own local uncommitted edits — buffer vs `git show <head_oid>:<path>` via `anchors.selection_to_head` — with `"<label>:\n```suggestion\n<edited line(s)>\n```"`, fence on its own line, for ANY label). The suggestion is SKIPPED when `comment_range` narrowed the payload: the block holds the whole selection, so GitHub would apply it over fewer lines than it covers and change code the comment is not anchored to. `anchors.selection_to_head` also maps the selected buffer rows onto the PR head-commit rows (walking the same diff, via the pure `mapper.head_anchor`) so the comment's `line`/`start_line` point at the head lines even when local edits shifted the buffer, keeping the suggestion applicable as-is. Locally DELETED lines count as edits too and pull their head lines into the range, which is what makes a "remove these lines" suggestion possible (they are zero-width in the buffer, so they are matched as a position between rows, not by row overlap). **Save** runs `github_pull_request_submit_comment` (bound in `Default.sublime-keymap`, context `setting.github_pull_request_compose`) which queues the whole buffer as the body; **closing without saving cancels**. `on_pre_close` restores the saved layout (`_restore_after_compose`) and refocuses the file for either path. The compose view carries `github_pull_request_compose` + a `context` (`{mode:"new", path, payload}`, `{mode:"edit", uid}`, or `{mode:"reply", thread_id}`) + source-id + orig-layout in its settings. The pending-popup **Edit** link reuses the split with `mode:"edit"` (prefilled with the current body; save updates it — server-side for synced drafts, mirror for local ones), and a thread **Reply** uses `mode:"reply"` (save posts via `reply_comment`, then `_reload_threads`). Only the review-summary prompt on submit still uses an input panel. Also `agent_command` (array, `["claude"]`) and `agent_review_prompt` (`{base}` placeholder) for the `github_pull_request_review_in_tmux` command, which `tmux split-window`s the attached session (auto-detected via `tmux list-sessions`) in the repo root running `<agent_command> <prompt>` (joined + `shlex.quote`d into one shell string, prompt last); base = loaded PR base else `git symbolic-ref refs/remotes/origin/HEAD`. No git mutation (tmux + read-only git only). This file is the ONLY copy of every default listed here: `plugin.py` reads them with no Python fallback, tolerating a string `agent_command` (`shlex.split`) and reporting a stray brace in the prompt rather than letting `str.format` raise in the worker.
- `Default.sublime-keymap` — binds Save (`super+s` / `ctrl+s`) to `github_pull_request_submit_comment`, scoped by `setting.github_pull_request_compose` so it only affects the compose buffer.
- `GithubPullRequestFiles.sublime-syntax` — colors the bottom panel (assigned to the output panel). Scope table and rationale in **The changed-files panel** above; that is the single description, do not restate it here.
- `ruff.toml` — pins the lint target to Python 3.8, selects its rule families EXPLICITLY (ruff's default is only `E4`/`E7`/`E9`/`F`, so an `extend-ignore` for anything outside that was muting a rule that had never run), and ignores what fights the constraints above, each with its reason.
- Installation into this dotfiles repo: `install_plugin "${TEXT_PKG}" "GithubPullRequest"` in `tools/sublime/init.sh`.
