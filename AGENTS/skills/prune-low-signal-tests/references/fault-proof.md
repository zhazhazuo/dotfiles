# Fault Proof

Both answers in the decision rule are proven by injecting a fault, not by reading the test.

## Baseline gate

1. Locate the E2E runner and its command. Record it verbatim in the report.
2. Run the **full** E2E suite once. It must be green before any probe.
3. If it is red or flaky, stop. Fix or quarantine the harness first — every later verdict depends on it.

## Cheap first pass (triage, not evidence)

Before any probe, statically map each candidate behavior to the E2E suite: grep the E2E sources for the surface
(route, CLI verb, rendered string, table, artifact). This orders the work and flags obvious misses.

- No E2E reference to the behavior → Q2 is probably *no* → convert candidate; probe to confirm.
- An E2E reference → probe to find whether it actually fails on the fault.

Static absence and static presence are both non-evidence: E2E can catch a behavior indirectly, and a grep hit can
be a name collision. Only the fault probe sets Q2.

A static miss does **not** force a conversion. If the behavior has no user-visible seam, the answer is keep and
record — see `e2e-conversion.md`. Do not fabricate an E2E test to satisfy a grep result.

## Guard proof (answers Q1)

Judge one test cluster at a time, not one test at a time.

1. Cluster the candidate tests by the production symbol/behavior they guard.
2. For each cluster, pick one representative fault and inject it into the production code.
3. Run the cluster's unit tests. Expect at least one to fail.
   - **Fails** → Q1 *yes*. Keep the fault available for the redundancy proof.
   - **Passes** → try a second, different fault. If still passes, Q1 *no* → delete the cluster.
4. Revert and confirm a clean diff before touching the next cluster.

### Fault menu

Choose the fault that is most likely to be caught if the test is real:

- flip a boundary comparison (`<` ↔ `<=`)
- off-by-one on an index or length
- swap a branch or drop an `else`
- return `null` / `undefined` / `0` / `""` instead of the value
- drop a side effect: skip the write, emit, publish, or delete
- reorder two statements
- remove an input validation
- change a default value
- break an error/exception mapping

## Redundancy proof (answers Q2)

With the Q1 fault **still injected**, run the E2E suite (the lane's focused subset is acceptable mid-flight;
the full suite runs at integration).

- **E2E fails** → Q2 *yes*. The unit test is redundant → delete it.
- **E2E passes** → Q2 *no*. E2E misses the fault → convert (see `e2e-conversion.md`).
- **E2E errors for an unrelated reason** → the probe is inconclusive. Fix the harness; if it stays inconclusive,
  keep the unit test and record "inconclusive" as the reason. Never delete on an inconclusive probe.

## Batching and cost

- One fault per cluster. Only split the cluster into per-test faults when the cluster fault is not caught by all
  tests that should catch it — that split is itself the finding (some tests in the cluster are decorative).
- A cluster of `N` tests collapses to at most two E2E runs: one to establish Q2, shared by the whole cluster.
- Mid-flight, run only the tests and E2E subset a lane owns. The full E2E suite runs once at integration.

## Record and revert

Record per cluster: fault patch, unit result before/after, E2E result before/after, and the verdict.

Use a patch file or `git stash` so the fault is reversible in one command. After every probe:

```bash
git diff --stat        # must show only the fault, or nothing after revert
```

Never leave a fault injected. Never run two lanes' probes against the same working copy of the same module —
serialize those probes or give each lane its own worktree.
