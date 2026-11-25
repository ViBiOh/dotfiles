@~/.config/AGENTS.md

## Go review

When asked to review, audit, or critique Go code (or when "go-review" is mentioned), first read ~/.claude/skills/go-review/SKILL.md and follow it exactly.

## Go code changes

**CRITICAL**: The Go guidelines are mandatory, not advisory. The user wrote them with care, and every violation costs the user review time. Never skip a step below, and never report Go work as done without completing all of them.

1. **Before any Go edit**: your first Go action in a task, before planning the code, before the first Edit or Write on a `.go` file (tests and mocks included), is to read `~/.claude/skills/go-review/SKILL.md` and the two guideline files next to it. Reading it after writing the code does not count. If it was already read earlier in this conversation, re-read it after any context summary.
2. **While writing**: apply every rule in the skill on the first draft: comments only for a non obvious WHY, no doc comment restating a name, map based parallel tests, generated mocks only, initials receivers, blank lines between logical groups, errors wrapped with the action.
3. **Tooling**: run everything in the skill's Tooling section (`go fix`, `gofumpt -extra`, `golangci-lint`) and `go test -race`. Never use `bin/*` wrappers that start Bazel. If a tool is unavailable, say so explicitly in the report, never skip it silently.
4. **Review**: delegate a review to the go-reviewer subagent, passing only the list of changed files. Never narrow its scope or severity (no "blocking only", no "should fix only"), never describe the change as intended or correct, and never tell it what to skip.
5. **Findings**: fix every finding at every severity, nits included, unless it contradicts the user's explicit instruction. If a finding is not fixed, say which one and why.
6. **Report**: the steps above are mandatory, so never list them as done (no "checks", "guideline steps" or "tooling" section). Report only what is out of the ordinary, anything that deviates from the nominal behavior.

## Advisor

When an advisor model is available (`claude --model sonnet --advisor opus`), consult it at three moments: before locking in a plan, when the same error occurs twice, and before declaring a task done. Do not consult it on routine turns.

## Exploration

Delegate read-only exploration (mapping the repo, finding call sites, fetching API docs) to Haiku subagents, in parallel when independent, and keep the main session for decisions and edits.
