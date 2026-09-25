---
name: prune-low-signal-tests
description: Use when a repository carries many low-signal unit tests and the E2E suite is the intended safety net — "this repo is full of low-signal unit tests", "delete every test that wouldn't catch a real bug our E2E tests miss", "our unit tests only assert mocks", "move test coverage to E2E", "fan the test pruning out across parallel subagents".
disable-model-invocation: true
---

# Prune low-signal tests into E2E

Job: reduce a unit-test suite to the tests that earn their place, and carry every
guarded behavior the E2E suite misses into an E2E scenario.

The criterion is the skill:

> Keep a unit test only if it catches a real bug that the E2E suite misses.
> Otherwise delete it — converting its intent to E2E first when that intent guards a real bug.

## When to use

- A repo has many low-signal unit tests and E2E is the intended safety net.
- "Delete every test that wouldn't catch a real bug our E2E tests miss."
- Suites that assert mocks, tautologies, implementation details, or framework behavior.
- Migrating to an E2E-first testing strategy.

Not for: adding coverage to untested code (use `ripwire-write-tests`), or fixing one failing test.

## Two questions per test

1. **Does it guard a real bug class?** A plausible defect, not a tautology, mock echo, or implementation detail.
2. **Does the E2E suite already catch that bug class?**

| Q1 real bug | Q2 E2E catches | Action |
|---|---|---|
| no | — | delete |
| yes | yes | delete (redundant) |
| yes | no | convert to E2E, then delete |

Both answers need evidence: a fault the test catches (Q1) and the same fault caught by E2E (Q2).
No fault found that the test catches means Q1 is no — delete without converting.

## Process

1. **Recon (parent, no delegation).** Find the runners; separate unit / integration / E2E; record the exact
   unit and E2E commands; run the E2E suite and record duration and a green baseline. Never probe on a red baseline.
2. **Partition lanes** by source seam (module / package / service), with disjoint file sets.
3. **Classify (parallel read-only scouts).** Each lane returns a verdict per test with both answers and evidence.
4. **Convert then delete (parallel writers, isolated worktrees, one writer per file).** Write the E2E
   scenarios for the convert list, prove each catches its fault, then delete the redundant unit tests.
5. **Integrate and prove (parent; fresh-context reviewer on the aggregate diff).** Full E2E green, no
   orphaned fixtures, every deletion traced to evidence.
6. **Emit the report artifact** `test-prune-report.md` (see `references/parallel-fanout.md`).

Delegation here is authorized by the task itself ("fan the work out across parallel subagents").
The parent keeps the criterion, arbitration, and final acceptance.

## Failure guards

- Never delete or weaken an E2E test (no skips, no loosened assertions, no retries to hide flake).
- A test whose guarded behavior has no user-visible seam is load-bearing: keep it and record why.
  Do not delete it to make E2E "the only suite".
- Delete a unit test only when both evidence items are attached to it.
- Never leave a fault injected; confirm a clean diff before moving to the next probe.

## Progressive disclosure

- Classification rule, low-signal catalog, edge cases → `references/keep-delete-convert.md`
- Guard proof, redundancy proof, fault injection, batching → `references/fault-proof.md`
- Lifting a unit-test intent to an E2E scenario → `references/e2e-conversion.md`
- Lane partition, scout/writer prompt contract, aggregation, report → `references/parallel-fanout.md`
