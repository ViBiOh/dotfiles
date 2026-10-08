@~/.config/AGENTS.md

## Go review

When asked to review, audit, or critique Go code (or when "go-review" is mentioned), first read ~/.claude/skills/go-review/SKILL.md and follow it exactly.

## Go code changes

After writing or modifying Go code, and before reporting the task as done, delegate a review to the go-reviewer subagent, passing the list of changed files. Fix blocking and should-fix findings, then report.
