# AGENTS.md — working on GithubPullRequest

Guidance for an AI agent (or human) extending this Sublime Text 4 plugin. Read `DESIGN.md` for the locked interface contracts and `README.md` for user-facing behavior.

## Golden rules

- **Never mutate git.** The whole point of this plugin is that it touches zero git state. Only read-only git is allowed: `git show`, `git merge-base`, `git rev-parse`. No checkout / branch / reset / add / commit — not at runtime, not in tests.
- **All network/git I/O goes through `gh`** (subprocess). Never read the token, never use `requests`/`urllib` for GitHub.
- **Keep the core `sublime`-free.** Only `plugin.py` and `anchors.py` may `import sublime`. Everything else (`urls`, `diff`, `mapper`, `render`, `gh`, `review`, `state`, `repo`, `owners`, `layout`, `labels`, `panel`) must not, which keeps it unit-testable headlessly. When a helper needs a view, duck-type it (`repo.rel_path` only calls `view.file_name()`) instead of importing `sublime`.

## Architecture

Two layers:

**Pure-Python core** (no `sublime`, fully unit-tested):

| Module | Responsibility |
| --- | --- |
| `urls.py` | `parse_pr_url(url)` → `{host, owner, repo, number}`. |
| `diff.py` | `parse_unified_diff(text)` → `[FileDiff]` (hunks, per-line old/new numbers). |
| `mapper.py` | `LineMap(file_diff)`: buffer row ↔ GitHub `(side, line)` coords, `is_commentable`, `anchor_to_row`, `comment_range` (single + multi-line payloads). Duck-typed on `file_diff` (does NOT import `diff`). Plus the pure local-edit helpers `head_anchor` / `head_row_to_buffer_row`, which walk difflib opcodes (committed file vs live buffer), and the head-side span normalizers `thread_line` / `thread_start_line` / `thread_span` / `draft_span` / `payload_span` / `payload_range_label`. `anchors.py` owns the git/view I/O that produces the opcodes. |
| `repo.py` | Read-only git (`git_root`, `run_git`) + repo-relative path mapping (`rel_path`, `abs_path`). |
| `owners.py` | `codeowners_map(root, paths, runner=None)`: one `codeowners --` call for every path; degrades to `{}` on any failure. |
| `layout.py` | `split_below_layout(layout, fraction)`: the compose split's window-layout arithmetic. |
| `labels.py` | `DEFAULT_COMMENT_LABELS` + `label_tag(entry)` for the Conventional Comments picker. |
| `panel.py` | Text model for the changed-files panel: `files_panel_text(open_paths)`, `first_hunk_line`, `first_comment_line`, `drafts_for_path`. Reads `SESSION`; builds text only (colouring is the syntax file's job). Rows carry a fixed-width marker slot (`● ` when the file is open as a tab) so the path column stays aligned. |
| `render.py` | Pure minihtml builders: thread popup, pending popup, `bodyHTML`→minihtml sanitizer, suggestion extraction, `subl:githubpullrequest?...` action encode/decode. |
| `gh.py` | Injectable subprocess client: `api` (with JSON `--input -` bodies), `graphql`, `pr_diff`, `pr_view`. |
| `review.py` | Service composing the above: `resolve_pr`, `changed_files`, `review_threads` (GraphQL, paginated), `base_blob` (read-only `git show`), the server-backed draft queue (a real GitHub PENDING review — `load_pending`/`queue_comment`/`discard_draft`/`clear_drafts`/`flush_local`; `_drafts` are synced with `comment_id`s, `_local_comments` are unsynced fallbacks kept on API failure and flushed on submit), `submit_review`, `reply_comment`, `set_thread_resolved`. Raises `CommentRejected` (a `GHError`) when GitHub refuses to anchor a comment; such a comment is dropped rather than queued, by BOTH `queue_comment` and `flush_local` (re-queuing it would fail identically and wedge every later submit). |

`state.py` imports no `sublime` either: the `SESSION` singleton (loaded PR, threads by path, line maps, base-blob cache, `Review` instance) + panel-entry enrichment (unresolved/pending counts).

**Sublime glue** (imports `sublime`, only `py_compile` + `ruff` checkable headlessly):

- `anchors.py` — where a comment lives in the buffer RIGHT NOW. Owns the buffer↔head coordinate translation (`selection_to_head` for authoring, `remap_head_row` for placement), the covered-row helpers (`thread_rows` / `draft_rows` / `thread_row`), and both caches (`view_opcodes` keyed on `change_count`; thread rows also keyed on `_THREADS_STAMP`, invalidated via `bump_threads_stamp`, `forget_view`, `clear_caches` since `global` cannot cross modules). The pure arithmetic lives in `mapper.py` and is tested there.
- `plugin.py` — commands (`GithubPullRequest*Command`), the `GithubPullRequestListener`, decoration (reference-doc diff, thread + draft gutter icons), popups + action-link dispatch, the compose split, output-panel wiring, and the async→main threading split.

### Threading

Every gh/git call runs under `_async(...)` (`sublime.set_timeout_async`). Every view/UI mutation is dispatched back with `_main(...)` (`sublime.set_timeout`). Deferred error lambdas must bind the message at creation time — `_main(lambda message=str(err): _error(message))` — because `except ... as err` unbinds `err` at block exit.

### GitHub coordinate model

Comments are authored with the modern REST fields: `side` (`RIGHT`=head, `LEFT`=base), `line`, and `start_line`/`start_side` for multi-line. The buffer holds PR **head**, so head row `R` ↔ line `R+1`; when the reviewer's local edits shift buffer rows, `anchors.selection_to_head` maps the selection back onto head rows before this holds. `mapper.comment_range` produces the payload from head rows; `review.queue_comment(path, payload, body)` stores it; `submit_review` posts `comments[]` in one `POST /pulls/{n}/reviews`.

### gh variable typing (subtle, already bitten once)

`gh api graphql` variables: use `-F` only for ints (typed), `-f` for strings. `-F` coerces `@…` to a filename and numerics/`true`/`false` to typed literals, which corrupts string vars like comment bodies with @mentions, node ids, and owner/repo. See `gh.py:graphql`. JSON bodies for `api()` go through `--input -` and are unaffected.

## Conventions

- **Python 3.8-safe, stdlib only.** No `X | Y` unions, no builtin generics in annotations (`typing.List/Optional/Dict/Tuple`), no `match`, no `str.removeprefix`. The Sublime plugin host is 3.8, and `ruff.toml` pins `target-version = "py38"` so the linter enforces it (the repo-wide `.python-version` would otherwise make ruff suggest syntax the host cannot run).
- **Dual-import** in every module so tests run standalone and inside Sublime:
  ```python
  try:
      from .diff import parse_unified_diff
  except ImportError:
      from diff import parse_unified_diff
  ```
- **Tests**: `unittest`, files named `*_test.py`, in the same module namespace, dict-keyed table cases (`cases = {"name": (...)}` + `subTest`). Core modules mock `gh`/git via injected runners — never hit the network or real git.
- **Panel lines are head-commit lines.** Everything stored from GitHub (thread lines, draft lines, hunk starts) is numbered against the PR head commit, NOT the live buffer. Any surface that points at a line must translate through `anchors.remap_head_row` or it will be wrong the moment the reviewer edits the file: gutter icons do, and so does the files panel via the `to_buffer_line` injected by `plugin._files_panel_body`. `panel.py` cannot do it itself (translation needs a view, and that module stays `sublime`-free), hence the injection. The mapping also goes stale on every keystroke, so `on_modified_async` redraws both surfaces through the `_redraw_when_settled` debounce; do NOT redraw per edit, each one costs a `git show` plus a full diff.
- **Panel styling spans two files.** `panel.py` prefixes open-file rows with a `● ` marker (a syntax can only assign scopes by matching TEXT, so a real character is required; a zero-width one does NOT work, Sublime draws format characters as their codepoint), and the `.sublime-syntax` matches `^●` to grey that row's marker and path via `comment.open-file.*`. They reference each other only by string, so `syntax_test.py` asserts they agree; a rename in one alone loses the colour with NO error. The grey relies on the scope staying under `comment.`. Do not reach for `font_style` (italic/bold): it cannot come from a syntax, only from a colour scheme, and colour-scheme overrides merge by the ACTIVE scheme's name, so they break the moment the user switches schemes.
- **Deletions are zero-width in the buffer.** A difflib `delete` opcode has `j1 == j2`, so any `lo < hi` overlap test silently misses it. `mapper.head_anchor` treats a deletion as a position BETWEEN rows instead. Get this wrong and "propose removing these lines" stops working with no error at all.
- **GitHub can refuse a comment silently.** `addPullRequestReviewThread` answers HTTP 200 with `thread: null` and NO `errors` array when it will not anchor the comment (verified against the live API). Always check for the null; `review._sync_draft` turns it into `CommentRejected` so the comment cannot vanish into a `TypeError`.
- **Untrusted input.** Comment bodies and their rendered HTML come from anyone who can comment on the PR. `render.html_to_minihtml` whitelists tags and escapes all text; `plugin._open_external` refuses to hand any non-`http(s)` link to the browser. Keep both gates in place when adding popup content.
- **Naming**: command classes are `GithubPullRequest<Verb>Command`; Sublime derives the command id by snake_casing minus `Command` (e.g. `GithubPullRequestLoadCommand` → `github_pull_request_load`). Keep `.sublime-commands` and `run_command(...)` strings in sync.

## Checks (run all before finishing)

```sh
cd tools/sublime/plugins/GithubPullRequest
python3 -m unittest discover -p '*_test.py'   # core: must be green
ruff check .                                   # whole package
ruff format .
python3 -m py_compile plugin.py state.py       # glue: syntax only (imports sublime)
```

The glue (`plugin.py`, `state.py`) cannot be exercised outside Sublime — verify it by loading the package and driving a real PR. Watch: `set_reference_document` behavior on buffer edits, popup lifecycle, and gutter-icon anchoring after the buffer changes.

## Known minor issues / deferred (good first tasks)

- **Comments are limited to the diff's 3 lines of context.** GitHub only anchors a comment to a line the PR diff carries, so a buffer selection reaching into unchanged code is narrowed by `mapper.comment_range` (down to a single line if only one row qualifies). `plugin.py` reports the effective range in the compose tab title and a status message. Fetching a wider-context diff would not help: the API rejects out-of-hunk lines regardless.
- **base-blob caching**: a transient `git show` failure caches `None` for the file for the session, so its gutter diff won't retry until reload. Intentional (avoids re-spawning git on every activate); revisit if it bites.
- **Pending vs published threads**: the draft queue is a server-side PENDING review. `reviewThreads` DOES return the viewer's own pending draft threads, so `review_threads()` skips any thread whose root comment has `state == "PENDING"` (they are surfaced through the pending-review mirror instead); otherwise a draft would show twice — once as a blue thread and once as a purple draft. Deleting a pending review's last comment auto-removes the now-empty review, so `_delete_pending_review` tolerates a `deletePullRequestReview` that no longer resolves.
- Deferred features: outdated-comment re-anchoring, reactions, viewed-file state, CI-checks display, multiple concurrent PRs.

## Where things plug in

- New command → add a `GithubPullRequest<Verb>Command` in `plugin.py` and an entry in `.sublime-commands`.
- New gh/GraphQL call → add a method to `gh.py` or `review.py` with a mocked-runner test; call it from the glue under `_async`.
- New popup/panel content → build the string in `render.py` (pure, add a test); render it from `plugin.py`.
- Registration into the dotfiles installer lives in `tools/sublime/init.sh` (`install_plugin ... GithubPullRequest`).
