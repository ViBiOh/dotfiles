---
name: go-review
description: Review Go code against the personal Go guidelines (concurrency and idioms). Use when asked to review, audit, or critique Go changes, or with /go-review.
---

# Go review

Review Go code for correctness and adherence to the personal Go guidelines.

## Guidelines source of truth

Read both files before reviewing and treat them as the standard:

- `~/.config/go/concurrency.md` (goroutine lifecycle, channels, close responsibility, bounded parallelism, data races, `sync`)
- `~/.config/go/tips_and_tricks.md` (declaration idioms, argument order, package layout, interfaces, errors, mutexes, tooling)

Also apply the Go rules already in `~/.config/AGENTS.md` (table-driven tests, `testify`, `t.Parallel()`, error wrapping style, `gofumpt -extra`, `golangci-lint`).

## Scope

Default to the current working changes only. Determine the diff read-only:

- `git diff origin/main...HEAD` for committed work on the branch
- `git diff` and `git status` for uncommitted work

Never run any mutable git command. If a target is given as an argument (a path, package, or ref), review that instead.

## What to check

- Goroutine termination: every goroutine has a well defined stop path (context, channel drain, timeout). Flag leaks.
- Channel close responsibility sits with the sender; no send on a closed channel; no close of a receive-only channel.
- Bounded concurrency: unbounded `go` in loops over external input; suggest worker pool or semaphore.
- Data races: shared state without synchronization; confirm tests run with `-race`.
- Interfaces accepted, structs returned; interfaces defined at the consumer, kept minimal.
- Errors are values: wrapped with `fmt.Errorf("doing X: %w", err)`, no `error`/`failed to` prefixes, no `panic` in library code.
- Argument order: `ctx context.Context` first, `error` last.
- Mutex hygiene: `defer Unlock`, pointer receivers, `RWMutex` only when justified.

## Output

Group findings by severity (blocking, should fix, nit). For each: `file:line`, the issue, and the concrete fix. Cite the relevant guideline section. Be concise. Do not edit files unless explicitly asked.
