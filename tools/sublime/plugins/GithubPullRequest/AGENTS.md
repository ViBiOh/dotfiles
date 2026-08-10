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
| `urls.py` | `parse_pr_url(url)` → `{owner, repo, number}`. The host is validated but not returned: nothing rebuilds a URL from the parts (`resolve_pr` keeps the PR's own url verbatim so Enterprise hosts survive). |
| `diff.py` | `parse_unified_diff(text)` → `[FileDiff]` (hunks, per-line old/new numbers). Carries only the fields something reads: `FileDiff{path, old_path, new_path, is_new, is_binary, additions, deletions, hunks}`, `Hunk{new_start, lines}`, `DiffLine{origin, old_lineno, new_lineno, content}`. Do not re-add `is_deleted` / `is_rename` / hunk counts / hunk header "for completeness": they were parsed, stored, asserted in tests, and read by nobody, and a `Hunk` field costs memory per hunk for the whole session. |
| `mapper.py` | `LineMap(file_diff)`: buffer row ↔ GitHub `(side, line)` coords, `is_commentable`, `anchor_to_row`, `comment_range` (single + multi-line payloads). Duck-typed on `file_diff` (does NOT import `diff`). Plus the pure local-edit helpers `head_anchor` / `head_row_to_buffer_row`, which walk difflib opcodes (committed file vs live buffer), and the head-side span normalizers `thread_line` / `thread_start_line` / `thread_span` / `draft_span` / `payload_span` / `payload_range_label`. `anchors.py` owns the git/view I/O that produces the opcodes. |
| `repo.py` | Read-only git (`git_root`, `run_git`) + repo-relative path mapping (`rel_path`, `abs_path`). |
| `owners.py` | `codeowners_map(root, paths, runner=None)`: one `codeowners --` call for every path; degrades to `{}` on any failure. |
| `layout.py` | `split_below_layout(layout, fraction)`: the compose split's window-layout arithmetic. |
| `labels.py` | `label_tag(entry)` for the Conventional Comments picker. The label set itself lives ONLY in `GithubPullRequest.sublime-settings`; `load_settings` merges it under any User override, so a Python default would just be a second copy to keep in sync. Same for `agent_command` / `agent_review_prompt`. `labels_test.py` validates the packaged file instead. |
| `panel.py` | Text model for the changed-files panel: `files_panel_text(open_paths)`, `first_hunk_line`, `first_comment_line`, `drafts_for_path`. Reads `SESSION`; builds text only (colouring is the syntax file's job). Rows carry a fixed-width marker slot (`● ` when the file is open as a tab) so the path column stays aligned. |
| `render.py` | Pure minihtml builders: thread popup, pending popup, `bodyHTML`→minihtml sanitizer (which keeps an `href` only when it is http(s), see **Untrusted input**), suggestion extraction, `subl:githubpullrequest?...` action encode/decode plus `action_int` for reading a parameter that a forged link could have filled with anything. |
| `gh.py` | Injectable subprocess client: `api` (with JSON `--input -` bodies), `graphql`, `pr_diff`, `pr_view`. |
| `review.py` | Service composing the above: `resolve_pr`, `changed_files`, `review_threads` (GraphQL, paginated at BOTH levels — see **Nested connections are capped**), `base_blob` (read-only `git show`), the server-backed draft queue (a real GitHub PENDING review — `load_pending`/`queue_comment`/`discard_draft`/`clear_drafts`/`flush_local`; `_drafts` are synced with `comment_id`s, `_local_comments` are unsynced fallbacks kept on API failure and flushed on submit), `submit_review`, `reply_comment`, `set_thread_resolved`. Raises `CommentRejected` (a `GHError`) when GitHub refuses to anchor a comment; such a comment is dropped rather than queued, by BOTH `queue_comment` and `flush_local` (re-queuing it would fail identically and wedge every later submit). |

`state.py` imports no `sublime` either: the `SESSION` singleton (loaded PR, threads by path, line maps, base-blob cache + its in-flight path set, `Review` instance) + panel-entry enrichment (unresolved/pending counts). Unit-tested in `state_test.py`; `reset` must leave every field empty, since that is all `End review` relies on.

**Sublime glue** (imports `sublime`, only `py_compile` + `ruff` checkable headlessly):

- `anchors.py` — where a comment lives in the buffer RIGHT NOW. Owns the buffer↔head coordinate translation (`selection_to_head` for authoring, `remap_head_row` for placement), the covered-row helpers (`thread_rows` / `draft_rows` / `thread_row`), and both caches (`view_opcodes` keyed on `change_count`; thread rows also keyed on `_THREADS_STAMP`, invalidated via `bump_threads_stamp`, `forget_view`, `clear_caches` since `global` cannot cross modules). `warm_opcodes(views)` fills the opcode cache from a worker thread; see **Threading**. The pure arithmetic lives in `mapper.py` and is tested there.
- `plugin.py` — commands (`GithubPullRequest*Command`), the `GithubPullRequestListener`, decoration (reference-doc diff, thread + draft gutter icons), popups + action-link dispatch, the compose split, output-panel wiring, and the async→main threading split.

### Threading

Every gh/git call runs under `_async(...)` (`sublime.set_timeout_async`). Every view/UI mutation is dispatched back with `_main(...)` (`sublime.set_timeout`). Deferred error lambdas must bind the message at creation time — `_main(lambda message=str(err): _error(message))` — because `except ... as err` unbinds `err` at block exit.

**The head-to-buffer mapping is git, so it counts as I/O.** `anchors.view_opcodes` runs a `git show` (5s timeout) plus a full `difflib` pass, per file. Everything that places something on a line reads it: gutter icons, popups, navigation, and the panel's nav lines. So a redraw that walks every open PR file must NOT start from a `_main` callback, or it blocks the UI once per file — with a guaranteed-cold cache right after a load, since `_build_session` clears it. The rule:

- **`_redraw_all(window, done_message)` is the only way to redraw everything, and it is WORKER-THREAD ONLY.** It calls `anchors.warm_opcodes(_pr_views())` on that thread, then dispatches the drawing to `_main`, where every lookup is a cache hit. `_load`, `_reload_threads`, `_mutate_then_refresh` and the submit-comment worker all go through it. `_load` also builds the session on the worker (pure state) precisely so the warm can happen before anything draws.
- Anything user-initiated that needs the mapping for many files (the files-panel command) warms it in an `_async` worker first.
- Deferred timers that recompute it use `set_timeout_async`, not `set_timeout`: see `_redraw_when_settled` and `_show_when_ready`.
- The per-view listener hooks (`on_load_async`, `on_activated_async`, `on_post_save_async`) are already on the async thread and can call `_decorate_view` directly. `on_hover` and the commands that read a single view (add comment, next/prev) run on the main thread and rely on that decoration having warmed the cache.

`sublime.windows()` / `window.views()` / `view.substr` are read-only and safe from a worker; only mutation has to go back to `_main`.

### GitHub coordinate model

Comments are authored with the modern REST fields: `side` (`RIGHT`=head, `LEFT`=base), `line`, and `start_line`/`start_side` for multi-line. The buffer holds PR **head**, so head row `R` ↔ line `R+1`; when the reviewer's local edits shift buffer rows, `anchors.selection_to_head` maps the selection back onto head rows before this holds. `mapper.comment_range` produces the payload from head rows; `review.queue_comment(path, payload, body)` stores it, syncing it into the server-side PENDING review immediately (`addPullRequestReviewThread`); `submit_review` then submits that review by node id (`submitPullRequestReview`), or, with nothing queued, posts a bare review through `POST /pulls/{n}/reviews`. There is no batched `comments[]` REST call.

**Only RIGHT is authored, but LEFT arrives.** A thread's `line`/`start_line` are numbered on ITS OWN side, so a LEFT-side thread's numbers are base-side. Anything turning a thread line into a row must go through `line_map.anchor_to_row(side, line)` (as `anchors._compute_thread_rows` and `plugin._apply_suggestion` do). `line - 1` is the RIGHT-side identity only; it silently lands on an unrelated row for LEFT threads, and for some lines it coincidentally agrees, so one passing example proves nothing (`mapper_test.test_a_left_line_can_anchor_away_from_line_minus_one`).

### Nested connections are capped

GraphQL returns at most 100 rows of a NESTED connection regardless of the outer page, so paginating only the outer one silently truncates. `reviewThreads`/`reviews` are paginated by their own cursor loop, and each thread's / the pending review's `comments` by a follow-up query on the node itself (`_THREAD_COMMENTS_QUERY`, `_REVIEW_COMMENTS_QUERY`, driven by `Review._all_comments`). A truncated pending review is the worse of the two: the overflow drafts stay live on GitHub while the mirror cannot see them, so nothing can edit or discard them.

### gh variable typing (subtle, already bitten once)

`gh api graphql` variables: use `-F` only for ints (typed), `-f` for strings. `-F` coerces `@…` to a filename and numerics/`true`/`false` to typed literals, which corrupts string vars like comment bodies with @mentions, node ids, and owner/repo. See `gh.py:graphql`. JSON bodies for `api()` go through `--input -` and are unaffected.

## Conventions

- **Python 3.8-safe, stdlib only.** No `X | Y` unions, no builtin generics in annotations (`typing.List/Optional/Dict/Tuple`), no `match`, no `str.removeprefix`. The Sublime plugin host is 3.8. Nothing at runtime enforces that: `.python-version` says 3.14 so the tests run on a current interpreter, and `ruff.toml`'s `target-version = "py38"` is the ONLY guard (it is what stops `UP` from suggesting syntax the host cannot run). Do not drop it, and do not assume a passing test run means host-compatible.
- **`ruff.toml` selects its rules explicitly.** Ruff's default is only `E4`/`E7`/`E9`/`F`, so `extend-ignore` entries for anything else are inert — `PLW1510` and `FA100` were being "muted" while never enabled, and the package was linted far more thinly than these checks claimed. The `select` list is now explicit and the ignores each carry their reason. If you add an ignore, confirm its family is selected.
- **Dual-import** in every module so tests run standalone and inside Sublime:
  ```python
  try:
      from .diff import parse_unified_diff
  except ImportError:
      from diff import parse_unified_diff
  ```
- **Tests**: `unittest`, files named `*_test.py`, in the same module namespace, dict-keyed table cases (`cases = {"name": (...)}` + `subTest`). Core modules mock `gh`/git via injected runners — never hit the network or real git.
- **Diff the buffer against the PR HEAD COMMIT, never local `HEAD`.** `LineMap` decides what is commentable from `gh pr diff`, whose line numbers are relative to the PR head. Any commit on the branch the PR does not have (unpushed, amended, or made after opening the PR) shifts local HEAD away from it, and then every mapped line is off: comments land on the wrong line, or a line that IS in the diff is rejected as "the pull request does not change these lines". `anchors._base_rev` returns `SESSION.pr["head_oid"]` (from `pr_view`'s `headRefOid`) and only falls back to `HEAD` when unknown. Do not "simplify" it back to `HEAD`.
- **Panel lines are head-commit lines.** Everything stored from GitHub (thread lines, draft lines, hunk starts) is numbered against the PR head commit, NOT the live buffer. Any surface that points at a line must translate through `anchors.remap_head_row` or it will be wrong the moment the reviewer edits the file: gutter icons do, and so does the files panel via the `to_buffer_line` injected by `plugin._files_panel_body`. `panel.py` cannot do it itself (translation needs a view, and that module stays `sublime`-free), hence the injection. The mapping also goes stale on every keystroke, so `on_modified_async` redraws both surfaces through the `_redraw_when_settled` debounce; do NOT redraw per edit, each one costs a `git show` plus a full diff.
- **Panel styling spans two files.** `panel.py` prefixes open-file rows with a `● ` marker (a syntax can only assign scopes by matching TEXT, so a real character is required; a zero-width one does NOT work, Sublime draws format characters as their codepoint), and the `.sublime-syntax` matches `^●` to grey that row's marker and path via `comment.open-file.*`. They reference each other only by string, so `syntax_test.py` asserts they agree; a rename in one alone loses the colour with NO error. The grey relies on the scope staying under `comment.`. Do not reach for `font_style` (italic/bold): it cannot come from a syntax, only from a colour scheme, and colour-scheme overrides merge by the ACTIVE scheme's name, so they break the moment the user switches schemes.
- **Deletions are zero-width in the buffer.** A difflib `delete` opcode has `j1 == j2`, so any `lo < hi` overlap test silently misses it. `mapper.head_anchor` treats a deletion as a position BETWEEN rows instead. Get this wrong and "propose removing these lines" stops working with no error at all.
- **GitHub can refuse a comment silently.** `addPullRequestReviewThread` answers HTTP 200 with `thread: null` and NO `errors` array when it will not anchor the comment (verified against the live API). Always check for the null; `review._sync_draft` turns it into `CommentRejected` so the comment cannot vanish into a `TypeError`.
- **minihtml is a small subset. Check the reference before using a tag or property:** <https://www.sublimetext.com/docs/minihtml.html>. Do not infer support from other packages emitting something (LSP emits `<hr>`, ineffectively). What the reference actually allows:
  - **Tags**: `html head style body h1`-`h6` `div p ul ol li b strong i em u big small a code var tt img`. **`<hr>` is NOT supported** and is dropped silently, drawing nothing — this cost a round trip. Rules are drawn with `border-top-*` hung on a block that HAS content (there is no `height`, so an empty element has no box to draw on); see `render._stack` / `render.popup`. `<table>`, `<input>`, `<button>` are explicitly unimplemented. Attributes: `class id style href title`; `href` protocols `http: https: subl:`.
  - **CSS**: `display margin* padding* border*` (incl. `border-top-{width,style,color}`, `style` only `none`/`solid`) `border-radius* background-color color font-family font-size font-style font-weight line-height text-decoration text-align white-space position top right bottom left list-style-type`. No `width`/`height`. Prefer `rem` units: they follow the user's `font_size` and do not cascade. Selector lists (`.a, .b { }`) are NOT documented as supported, so do not collapse two rules that way; give each class its own rule or drop the redundant one.
  - **Colors**: `color(<c> alpha()|a()|saturation()|lightness()|blend()|blenda()|min-contrast())`, plus hex/rgb/rgba/hsl/hsla/hwb. Predefined vars: `--background --foreground --accent --redish --orangish --yellowish --greenish --cyanish --bluish --purplish --pinkish` (no grey; dim with `color(var(--foreground) alpha(...))`). `var()` cannot supply part of a multi-value property like `margin`.
  - The sanitizer's own allow-list for GitHub `bodyHTML` is `render._ALLOWED`. It is deliberately WIDER than the tag list above: GitHub emits `blockquote pre s span kbd sub sup` and remapping each to a supported equivalent would flatten real structure, so they are passed through and minihtml drops the ones it does not know while keeping their text. When adding one, check it is at worst inert.
- **Untrusted input.** Comment bodies and their rendered HTML come from anyone who can comment on the PR. THREE gates, all required:
  1. `render.html_to_minihtml` whitelists tags and escapes all text.
  2. `render._safe_anchor` keeps an `href` only when it is `http(s)`. This is the one that is easy to miss: popup action links travel as `subl:githubpullrequest?...` hrefs, and `plugin._handle_action` dispatches those BEFORE any browser check, so a body carrying one would turn a click into a real discard / resolve / edit. Every genuine action link is built locally by `encode_action` and never parsed out of a body, so nothing legitimate needs an href here. Do not rely on GitHub's own markdown sanitizer stripping the scheme.
  3. `plugin._open_external` refuses to hand any non-`http(s)` link to the browser. Action PARAMETERS are equally untrusted: read numeric ones with `render.action_int` (None on garbage) and treat a missing id as a no-op, rather than letting `int()` raise inside Sublime's link callback.
- **Gutter regions are never `PERSISTENT`.** Sublime saves persistent regions into the workspace, so quitting with a review loaded would restore the icons on the next start with no session behind them — and `End review` is disabled without one, so there would be no way to clear them. `sublime.HIDDEN` alone is right; every path that shows a PR file redecorates it anyway.
- **Naming**: command classes are `GithubPullRequest<Verb>Command`; Sublime derives the command id by snake_casing minus `Command` (e.g. `GithubPullRequestLoadCommand` → `github_pull_request_load`). Keep `.sublime-commands` and `run_command(...)` strings in sync.

## Checks (run all before finishing)

```sh
cd tools/sublime/plugins/GithubPullRequest
python3 -m unittest discover -p '*_test.py'   # core: must be green
ruff check .                                   # whole package
ruff format .
python3 -m py_compile plugin.py anchors.py     # glue: syntax only (imports sublime)
```

The glue (`plugin.py`, `anchors.py` — NOT `state.py`, which imports no `sublime` and is unit-tested in `state_test.py`) cannot be exercised outside Sublime. Verify it by loading the package and driving a real PR. Watch: `set_reference_document` behavior on buffer edits, popup lifecycle, gutter-icon anchoring after the buffer changes, and that a load with several PR files open does not stall the UI (the threading rule above).

## Known minor issues / deferred (good first tasks)

- **Comments are limited to the diff's 3 lines of context.** GitHub only anchors a comment to a line the PR diff carries, so a buffer selection reaching into unchanged code is narrowed by `mapper.comment_range` (down to a single line if only one row qualifies). `plugin.py` reports the effective range in the compose tab title and a status message. Fetching a wider-context diff would not help: the API rejects out-of-hunk lines regardless. A narrowed payload also suppresses the `suggestion` prefill: the block's content is the whole selection, so applying it over a smaller anchored range would change lines the comment does not cover.
- **base-blob caching**: a transient `git show` failure caches `None` for the file for the session, so its gutter diff won't retry until reload. Intentional (avoids re-spawning git on every activate); revisit if it bites. `SESSION.base_blob_pending` separately guards against two views on the same path each spawning a fetch; its `apply` decorates every view on the path so a clone does not have to wait for its own activate.
- **Fence regexes must agree.** `render._SUGGESTION_RE` and the `lang == "suggestion"` test in `_render_body` have to count the same blocks, or the Nth Apply link applies the wrong one or a dead one. A fence's info string runs to the END of the fence line, so BOTH require the newline (with it optional, `_SUGGESTION_RE` read "``suggestion js" as a suggestion by swallowing the rest of the line) and the lang is `rstrip`ped, not `strip`ped ("`` suggestion" is not one). `render_test.SuggestionCountAgreementTest` compares the two counts over a table of spellings; extend it rather than either regex alone.
- **Pending vs published threads**: the draft queue is a server-side PENDING review. `reviewThreads` DOES return the viewer's own pending draft threads, so `review_threads()` skips any thread whose root comment has `state == "PENDING"` (they are surfaced through the pending-review mirror instead); otherwise a draft would show twice — once as a blue thread and once as a purple draft. The skip reads the FIRST comment, which is always on the first page, so it is unaffected by comment pagination. Deleting a pending review's last comment auto-removes the now-empty review, so `_delete_pending_review` tolerates a `deletePullRequestReview` that no longer resolves.
- **`clear_drafts` trusts that tolerance:** `_delete_pending_review` swallows every `GHError`, so a genuinely failed delete (auth, network) still clears the local mirror and leaves the pending review on GitHub. Reloading the PR restores it, so nothing is lost, but the status message overstates what happened.
- Deferred features: outdated-comment re-anchoring, reactions, viewed-file state, CI-checks display, multiple concurrent PRs.

## Where things plug in

- New command → add a `GithubPullRequest<Verb>Command` in `plugin.py` and an entry in `.sublime-commands`.
- New gh/GraphQL call → add a method to `gh.py` or `review.py` with a mocked-runner test; call it from the glue under `_async`.
- New popup/panel content → build the string in `render.py` (pure, add a test); render it from `plugin.py`.
- Registration into the dotfiles installer lives in `tools/sublime/init.sh` (`install_plugin ... GithubPullRequest`).
