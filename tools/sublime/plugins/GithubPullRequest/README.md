# GithubPullRequest

Review GitHub pull requests without leaving Sublime Text 4. Transparent on startup, everything on demand: nothing happens until you run **GithubPullRequest: Load pull-request**, at which point the PR is inferred from your current git branch, its review threads are drawn on the files, changed files are listed in a panel, and you can add, batch, and submit review comments from the editor.

> [!NOTE] This plugin is **100% vibe-coded** — designed and written end to end through conversation with an AI agent (Claude). Every module has unit tests and the whole non-UI stack is exercised headlessly, but it has had little mileage in the wild. Treat it accordingly.

## Why it exists

The github.com review UI is fine, but jumping to the browser loses your editor: LSP, go-to-definition, syntax, your keybindings. This keeps the review where the code already is, and — deliberately — **never touches your git state**.

## Requirements

- Sublime Text 4 (uses `minihtml`, `set_reference_document`, phantomless popups).
- [`gh`](https://cli.github.com/) installed and authenticated (`gh auth login`). The plugin shells out to `gh`; it never reads your token. `gh` handles credentials and multi-org SAML SSO.
- You are **on the PR branch** when you load it. That is how the PR is inferred, and it is what makes the non-mutating diff work.

## Install

This plugin lives in a dotfiles repo and is symlinked into Sublime's `Packages/` by the repo's installer:

```sh
tools/sublime/init.sh
```

That runs `install_plugin "${TEXT_PKG}" "GithubPullRequest"`. To install manually, symlink or copy this directory into your Sublime `Packages/` folder as `GithubPullRequest`.

## Usage

Check out the PR branch (with your own git workflow), open the repo in Sublime, then from the command palette:

| Command | What it does |
| --- | --- |
| **Load pull-request (current branch)** | Infer the PR from the branch, fetch files + threads, open the changed-files panel. |
| **Load pull-request from URL** | Same, but paste a PR URL instead of inferring. |
| **Show changed files** | Bottom panel: aligned table of changed files with `+N` (green) `-M` (red) `(K unresolved)` (yellow) `(P pending)` (gray). Double-click / Enter / F4 opens the file at the relevant line. |
| **List all comments** | Cross-file quick-panel navigator of every thread; jumps to the file+line and shows the popup. |
| **Comment on line or selection** | Queue a review comment on the current line or multi-line selection (also on the right-click menu). First offers a fuzzy Conventional Comments label picker (skippable), then the body. Queued, not posted. |
| **Show comments on current line** | Show the thread / pending popup for the cursor's line. |
| **Next comment** / **Previous comment** | Jump between commented lines in the current file. |
| **Submit review** | Pick a verdict (Comment / Approve / Request changes) and post all queued comments in one review. |
| **Discard queued comments** | Drop the local draft queue. |
| **End review** | Clear all decorations, reference documents, and the panel. Git is untouched throughout. |

### In the editor once a PR is loaded

- **Diff** — the native gutter diff lights up per file via `set_reference_document` against the merge-base blob (read with read-only `git show`). Added files show all-green.
- **Threads** — unresolved threads get a blue gutter icon; hover (or _Show comments_) opens an HTML popup with the rendered comment bodies (GitHub's `bodyHTML` down-converted to minihtml), plus **Reply**, **Resolve/Unresolve**, **Open in browser**, and **Apply** for ` ```suggestion ` blocks.
- **Drafts** — queued comments get a purple gutter icon and a "pending" popup with a **Discard** link; the panel shows per-file and total pending counts.

## How it works (and what it will not do)

- **Non-mutating.** No `gh pr checkout`, no branch, no `reset`, no writes of any kind. Only read-only git (`git show`, `git merge-base`, `rev-parse`). Your branch, index, and stash are never touched.
- **Pending-review batching.** Comments queue locally and post together with a verdict, like github.com.
- **No sidebar badges.** There is no Sublime API to badge the sidebar file tree, so the changed-files list is the bottom panel (not the sidebar).

## Settings

`GithubPullRequest.sublime-settings`:

| Key | Default | Meaning |
| --- | --- | --- |
| `auto_show_popup` | `true` | Show the thread/draft popup on hover. |
| `show_gutter_icon` | `true` | Draw gutter icons for threads and drafts. |
| `gutter_icon` | `"bookmark"` | Icon name (`bookmark`, `dot`, `circle`) or a `Packages/...` png. |
| `conventional_comments` | `true` | Show the [Conventional Comments](https://conventionalcomments.org) label picker before typing a comment. |
| `comment_labels` | standard set | The labels offered by the picker (`{emoji, label, description}` list). `emoji` is optional and, when present, shows in the picker and prefixes the posted comment (`💡 suggestion: …`). Replace with your own. |

## Known limitations

- Assumes one PR at a time and that you are on its head branch.
- Large-PR API caps apply (`/pulls/{n}/files` caps at 3000 files; very large / binary files omit patches).
- Outdated-comment re-anchoring, reactions, viewed-file state, and CI-checks display are not implemented.

See `AGENTS.md` for architecture and how to work on it, and `DESIGN.md` for the locked interface contracts.
