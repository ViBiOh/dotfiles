# Agent Configuration

## Autonomy & Workflow Preferences

**Autonomy Level**: Balanced

- Use plan mode for complex tasks, architectural decisions, and multi-file changes
- Proceed directly on straightforward implementations
- Check in on key technical choices and design decisions
- Ask questions when clarification is needed

## Primary Use Cases

I primarily use AI agents for:

- **Feature development**: Building new functionality from scratch
- **Refactoring and optimization**: Improving code structure, performance, and maintainability
- **Code understanding and exploration**: Learning about codebases, explaining how things work

## Git Workflow

**CRITICAL**: Never perform any mutable git operation, no commit, add, push, stash, branch creation, reset, checkout, rebase, or any command that changes git state. Git is my safety net, don't touch it.

- Read-only git commands are fine (`git status`, `git log`, `git diff`, `git blame`, etc.)
- Focus on writing code and running tests only
- After completing work, I'll handle all git operations myself
- When comparing changes on the current branch against the default branch, always use `origin/<default_branch>` (e.g. `git diff origin/main...HEAD`) instead of the local `<default_branch>` ref to avoid picking up unrelated local commits as noise

## Docker

**CRITICAL**: Never perform any mutable docker operation, no run, build, pull, push, exec, start, stop, rm, rmi, prune, compose up/down, or any command that changes container, image, volume, or network state. Same for `podman`, `nerdctl`, `docker-compose`, and `colima`.

- Read-only docker commands are fine (`docker ps`, `docker images`, `docker logs`, `docker inspect`, `docker version`, etc.)
- After completing work, I'll handle all docker operations myself
- If a task needs a container built or started, give me the exact command and let me run it

## Kubernetes

**CRITICAL**: Never perform any mutable Kubernetes operation, no apply, create, delete, patch, edit, replace, scale, rollout, drain, cordon, taint, label, annotate, exec, cp, port-forward, or any command that changes cluster state. Same for `helm`, `kustomize` with apply, `k9s`, and `kubectx`/`kubectl config use-context`.

- Read-only commands are fine (`kubectl get`, `describe`, `logs`, `top`, `explain`, `diff`, `helm list`, `helm template`, etc.)
- After completing work, I'll handle all cluster operations myself
- If a task needs a change applied to a cluster, give me the exact command and let me run it

## Testing

**Automatic test execution**: Always run relevant tests after making code changes

- Automatically verify changes don't break existing functionality
- Run appropriate test commands based on project type (npm test, pytest, go test, etc.)
- Report test results before considering work complete
- This helps catch issues early before I commit changes

## Design Approach

- Before implementing, propose the approach and wait for approval. Do NOT start editing multiple files unprompted.
- Look at existing patterns/modules in the codebase first. Prefer shared modules over inline implementations.
- Never hardcode values that should be configurable. Never duplicate paths or logic.

## Build & Run

**CRITICAL**: Never use Bazel commands (bazel build, bazel test, bazel run, etc.)

- Always use the native tooling equivalent instead
- Go: `go build`, `go test`, `go run`
- Java/Kotlin: `gradle`, `maven`
- Python: `uv`, `uv run pytest`
- JavaScript/TypeScript: `npm`, `yarn`, `pnpm`
- Rust: `cargo build`, `cargo test`
- If unsure of the native equivalent, ask before running anything

## Go Conventions

All Go rules live in `~/.config/skills/go-review/SKILL.md`. When writing, modifying, or reviewing Go, read it first and follow it exactly.

## Markdown

- **Formatting**: After writing or modifying any `.md` file, always run `prettier --prose-wrap=never --write` on it
- **Links**: Never put backticks inside markdown link text (e.g. ``[`foo`](url)``). Jira does not render that syntax. Use plain text instead: `[foo](url)`.
- **Prose wrapping**: Never manually hard-wrap prose lines. Write paragraphs as single continuous lines and let the editor or renderer handle wrapping.

## Comments

- Comments must describe current behavior only, never compare to, reference, or argue with a previous version of the code
- No "before/after", "previously", "used to", "now we", "instead of", "removed X" style comments, git history covers that
- Only add a comment when the WHY of the current code is non-obvious
- Never write a package level doc comment (e.g. `// Package foo ...` above `package foo` in Go, or a module docstring at the top of a file in other languages). The code must be self-describing

## Code Quality Preferences

- Variables must have at least 3 characters; exceptions: `a`, `b` when identity is irrelevant (e.g. swap), `i`, `j`, `k` for index-based loops, and single-letter names established by language convention (e.g. `t` for `*testing.T` in Go, `r`/`w` for request/response in HTTP handlers)
- Avoid over-engineering, keep solutions simple and focused
- Don't add features beyond what was requested
- Only add error handling for scenarios that can actually occur
- Prefer editing existing files over creating new ones
- No unnecessary comments, docstrings, or type annotations unless requested
- Delete unused code completely, no backwards-compatibility hacks

## Jira Tickets

- Always use the Atlassian MCP server to fetch Jira tickets, never guess or rely on cached content
- When looking at a ticket, always fetch the parent ticket as well to get full context

## Communication Style

**CRITICAL** Never use the Em Dashes (—), En Dashes (–), Hyphens (-) or Double Hyphens (--) in answers

- Be concise and direct, short answers, straight to the point
- No verbose explanations or apologies
- No time estimates
- Focus on technical accuracy over validation
- Use code references with file:line format when discussing specific code
