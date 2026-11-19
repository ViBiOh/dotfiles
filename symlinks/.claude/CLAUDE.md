@~/.config/AGENTS.md

## Go review

When asked to review, audit, or critique Go code (or when "go-review" is mentioned), first read ~/.claude/skills/go-review/SKILL.md and follow it exactly.

## Go code changes

After writing or modifying Go code, and before reporting the task as done, delegate a review to the go-reviewer subagent, passing the list of changed files. Fix blocking and should-fix findings, then report.

## Advisor

When an advisor model is available (`claude --model sonnet --advisor opus`), consult it at three moments: before locking in a plan, when the same error occurs twice, and before declaring a task done. Do not consult it on routine turns.

## Exploration

Delegate read-only exploration (mapping the repo, finding call sites, fetching API docs) to Haiku subagents, in parallel when independent, and keep the main session for decisions and edits.
