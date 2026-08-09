# AGENTS.md — working on GithubPullRequest

Guidance for an AI agent (or human) extending this Sublime Text 4 plugin. Read `DESIGN.md` for the locked interface contracts and `README.md` for user-facing behavior.

## Golden rules

- **Never mutate git.** The whole point of this plugin is that it touches zero git state. Only read-only git is allowed: `git show`, `git merge-base`, `git rev-parse`. No checkout / branch / reset / add / commit — not at runtime, not in tests.
- **All network/git I/O goes through `gh`** (subprocess). Never read the token, never use `requests`/`urllib` for GitHub.
- **Keep the core `sublime`-free.** `urls.py`, `diff.py`, `mapper.py`, `render.py`, `gh.py`, `review.py`, `state.py` must not `import sublime`. Only `plugin.py` may. This keeps the core unit-testable headlessly.

## Architecture

Two layers:

**Pure-Python core** (no `sublime`, fully unit-tested):

| Module | Responsibility |
| --- | --- |
| `urls.py` | `parse_pr_url(url)` → `{host, owner, repo, number}`. |
| `diff.py` | `parse_unified_diff(text)` → `[FileDiff]` (hunks, per-line old/new numbers). |
| `mapper.py` | `LineMap(file_diff)`: buffer row ↔ GitHub `(side, line)` coords, `is_commentable`, `anchor_to_row`, `comment_range` (single + multi-line payloads). Duck-typed on `file_diff` (does NOT import `diff`). Plus the pure local-edit helpers `head_anchor` / `head_row_to_buffer_row`, which walk difflib opcodes (committed file vs live buffer); `plugin.py` owns the git/view I/O that produces those opcodes and decides suggestion prefill from the `has_edit` they return. |
| `render.py` | Pure minihtml builders: thread popup, pending popup, `bodyHTML`→minihtml sanitizer, suggestion extraction, `subl:githubpullrequest?...` action encode/decode. |
| `gh.py` | Injectable subprocess client: `api` (with JSON `--input -` bodies), `graphql`, `pr_diff`, `pr_view`. |
| `review.py` | Service composing the above: `resolve_pr`, `changed_files`, `review_threads` (GraphQL, paginated), `base_blob` (read-only `git show`), the server-backed draft queue (a real GitHub PENDING review — `load_pending`/`queue_comment`/`discard_draft`/`clear_drafts`/`flush_local`; `_drafts` are synced with `comment_id`s, `_local_comments` are unsynced fallbacks kept on API failure and flushed on submit), `submit_review`, `reply_comment`, `set_thread_resolved`. Raises `CommentRejected` (a `GHError`) when GitHub refuses to anchor a comment. |

**Sublime glue** (`plugin.py` + `state.py`, imports `sublime`, only `py_compile` + `ruff` checkable headlessly):

- `state.py` — the `SESSION` singleton (loaded PR, threads by path, line maps, base-blob cache, `Review` instance) + panel-entry enrichment (unresolved/pending counts).
- `plugin.py` — commands (`GithubPullRequest*Command`), the `GithubPullRequestListener`, decoration (reference-doc diff, thread + draft gutter icons), popups + action-link dispatch, the changed-files output panel, the async→main threading split.

### Threading

Every gh/git call runs under `_async(...)` (`sublime.set_timeout_async`). Every view/UI mutation is dispatched back with `_main(...)` (`sublime.set_timeout`). Deferred error lambdas must bind the message at creation time — `_main(lambda message=str(err): _error(message))` — because `except ... as err` unbinds `err` at block exit.

### GitHub coordinate model

Comments are authored with the modern REST fields: `side` (`RIGHT`=head, `LEFT`=base), `line`, and `start_line`/`start_side` for multi-line. The buffer holds PR **head**, so head row `R` ↔ line `R+1`; when the reviewer's local edits shift buffer rows, `_head_anchor` maps the selection back onto head rows before this holds. `mapper.comment_range` produces the payload from head rows; `review.queue_comment(path, payload, body)` stores it; `submit_review` posts `comments[]` in one `POST /pulls/{n}/reviews`.

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
