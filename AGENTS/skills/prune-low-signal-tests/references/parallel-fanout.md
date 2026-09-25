# Parallel Fanout

Lane partition, prompt contract, aggregation, and the final report.

## Authorization and ownership

The task instructs fanout ("fan the work out across parallel subagents"). The parent keeps the criterion,
arbitration, and final acceptance; it does not outsource the decision.

- One lane per **source seam** (module / package / service). Never round-robin by file.
- **Disjoint file sets.** Never two writers on one test file. If two lanes would touch one file, merge them.
- One writer per worktree/cwd.

## Phases

1. **Recon — parent, direct.** Runners, unit/integration/E2E partition, E2E command, green baseline, lane map.
2. **Classify — read-only scouts, fanned out.** One scout per lane. Scouts must not edit anything.
3. **Convert + delete — writers, isolated worktrees, fanned out.** One writer per lane, inside its own files only.
4. **Review — fresh-context reviewer** on the aggregate diff against the criterion and the attached evidence.
5. **Integrate — parent.** Merge lanes, run the full E2E suite once, write the report.

Launch classification scouts together, then writers together. Do not let a writer start before its lane's
classification is complete, and do not let any lane delete before its converting E2E scenario is proven red on
the fault and green after revert.

## Per-lane prompt contract

Give every child a compact meta-prompt with these fields; distinctness comes from the seam, not the file list:

- **Objective** — prune the unit tests in `<seam>` per the two questions.
- **Repo / cwd / ref** — explicit paths; a writer gets its own worktree.
- **Authority** — scouts read-only; writers may edit only their lane's files, and may not touch the E2E
  harness's shared helpers without parent approval.
- **Criterion** — both questions verbatim, and the keep/delete/convert table.
- **Baseline** — the E2E command and the recorded green baseline.
- **Method** — the fault menu, and "convert then delete", not "delete then hope".
- **Output** — the verdict table plus a report fragment.
- **Stop / ask** — red baseline, ambiguous seam, no user-observable path, shared-helper change needed.

## Verdict table

Each lane returns one row per candidate test or cluster:

```text
| test | guarded behavior | Q1 real bug | Q2 E2E catches | verdict | evidence |
```

- `Q1 real bug` — `no` or `yes: <fault injected>`
- `Q2 E2E catches` — `n/a`, or `yes: <e2e test name that failed on the fault>`, or `no`
- `verdict` — `keep`, `delete`, or `convert`
- `evidence` — probe record reference, or `kept: not E2E-observable — <why>`

A `yes` without a demonstrated fault is invalid. Reject the row and re-probe.

## Aggregation

The parent, not a child, does this:

- Merge fragments; dedupe faults injected in more than one lane.
- Enforce the global gate: full E2E suite green after all lanes land.
- Check for orphaned fixtures, dead helpers, and test-only production seams left by deletions.
- Reject any deletion whose two evidence items are missing.
- Write `test-prune-report.md`.

## Report artifact

`test-prune-report.md` is the repeatable, verifiable output. Sections:

1. **Recon** — runners, unit/integration/E2E partition, exact E2E command, baseline result and duration.
2. **Lanes** — the lane map and file ownership.
3. **Verdicts** — the merged verdict table with evidence per row.
4. **Conversions added** — new E2E scenarios, each linked to the unit test(s) it replaces.
5. **Deletions** — deleted tests/files, with the fault and E2E evidence for each.
6. **Retained unit tests** — kept tests and why (real bug + E2E misses; or not E2E-observable).
7. **Final counts** — before/after unit and E2E test counts.
8. **Verification** — full E2E run result after integration, with the command to reproduce.

## Anti-patterns

- Overlapping writers, or a clone prompt with only the file list swapped.
- A scout that edits, or a writer that deletes before its conversion is proven.
- Declaring done on a lane-green without the full E2E gate.
- Probing two lanes against one working copy of the same module.
- Shipping a report whose `yes` cells have no fault reference.
