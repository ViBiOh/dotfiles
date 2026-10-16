# Delegation prompt templates

Adapt these; don't fill them in mechanically. Every prompt should stand on its own, since the agent has none of your context.

## Investigation (read-only)

```
<One-line goal>. This is read-only research: don't push, merge, comment, edit config or touch production.

Context:
- What the user asked: "<quote>".
- Identifiers: <repo / branch / PR URLs / commit SHAs / job ids / file paths / log locations>.
- Known so far: <facts with sources>.
- My hypothesis (unconfirmed): <...>. Prove or disprove it; don't assume it.

Please establish, with evidence:
1. <question 1>
2. <question 2>
3. <a targeted test or query that would settle it, if one exists>

If you find <the thing that would change a deadline or a deploy>, tell me immediately with the evidence and the
smallest fix, before doing anything else. Otherwise reply with: verdict first, then evidence (file:line, commands,
numbers), then anything you couldn't resolve. Clean up any build servers or temporary worktrees you start.
```

## Fix, test and open a PR

```
Please prepare <fix> as a DRAFT PR, so it's ready if the user wants it in before <deadline>. Leave <other PRs> alone.

Scope: <the minimal change>. Don't change <adjacent older behavior>; that's a separate change. Code comments
describe the current code, with no "previously/originally" narration.

Mechanics:
- New branch <prefix/name> from fresh <origin/default>, in its own worktree <path convention>.
- Run locally before pushing: <specific suites> plus anything covering the touched path. Run the formatter.
  Shut down build servers when done.
- Commit signed, with the user's commit conventions. Push, then open a DRAFT PR using the repo template, with
  title <...>, the ticket link at the top, a short why/what/exposure section, and links to <related PRs>.
- Run <post-PR housekeeping, e.g. mark generated files viewed, open in browser>.

Reply with the PR URL, the local test results, and the diff size in non-test lines. Don't undraft or merge it.
```

## Verification of something already done

```
New verification task: <the user's concern, quoted>. This is read-only plus local tests; don't push unless I ask.

Please establish:
1. How <behavior> worked before <change range> (cite code).
2. Whether each of <changes> preserves it exactly, with these specific suspects: <list>.
3. A targeted test that exercises <the risky interaction>, run on (a) before, (b) current, (c) <candidate>.
   Outputs must be identical apart from <known, intended differences>.

If you find a real bug in what's already merged, tell me immediately with the evidence and the smallest fix.
Otherwise send a concise report: how it works, what each change does to it, the test you ran, and its results.
```

## Resume after a stall

```
You stalled on <timeout/outage> right after <last thing it reported>. Current state: <what's on disk / pushed /
open: worktree status, files present, PR state>.

Please continue from there: <remaining steps, in order>. Don't redo <steps already done>. Then reply with <deliverable>.
```

## Background measurement or long data pull (often a script, not an agent)

Prefer a background command when the work is a known script:

- Write output to a file in the job's scratch directory, and errors to a separate file.
- Make sure any cache or resume behavior means a rerun only fetches new data.
- When it finishes, read the summary lines and restate the numbers yourself.

## Example status messages

Answer first, then what needs the user, then pending:

> **<PR> fixes a real bug, not a cosmetic one.** <Earlier change> made <output> vary from run to run, and sometimes drop <amount>. It's merged but not deployed; it would ship in <next deploy>. Scope: <who and which
> cases>. Severity: medium. Fix cost: about zero perf. **Decision:** land it before <deploy>? If yes, it needs a reviewer today. I'm preparing it as a draft either way.

One line when nothing changed:

> No change: 8511 is still waiting on the shard rerun; nothing needs you.

Open items only, when asked "what's left":

| PR         | What it does | Waiting on                          |
| ---------- | ------------ | ----------------------------------- |
| <full URL> | <one line>   | <review / CI / the user's decision> |
