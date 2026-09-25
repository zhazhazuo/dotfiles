# Keep / Delete / Convert

The decision rule, the low-signal catalog, and the cases that look deletable but are not.

## The two questions

For every unit test (or parameterized case), answer with evidence:

1. **Q1 — real bug class?** Name a plausible defect this test would fail on. If you cannot name one, Q1 is
   *no* and the test guards nothing observable. Do not accept "it documents the code" or "it raises
   coverage" as a bug class.
2. **Q2 — does E2E already catch it?** Inject the Q1 fault and run the E2E suite. If E2E fails, Q2 is *yes*.

| Q1 real bug | Q2 E2E catches | Action |
|---|---|---|
| no | — | delete |
| yes | yes | delete (redundant) |
| yes | no | convert to E2E, then delete |

Evidence is mandatory for a `yes`. A `yes` asserted without a demonstrated fault is a guess — treat it as *no*
and delete, because the criterion is literally "would catch a real bug".

## Low-signal catalog (delete without conversion)

- **Mock echo** — asserts the mock was called, or that the code returns what the mock was told to return.
- **Tautology** — asserts a constant against itself; asserts the language or framework (type has a field,
  getter returns the field, default value equals the default).
- **Mirror test** — asserts a constant, config, or limit equals the same literal it was declared as ("protocol
  limits are the single source of truth"). It fails only when the value changes on purpose, so it cannot catch a
  defect: whoever changes the constant changes the test. Real bug class: none.
- **Implementation detail** — asserts private structure, internal call counts/order, log strings, that a
  private helper was invoked, or which branch was taken internally.
- **Duplicate** — the same behavior asserted elsewhere, or a strict subset of a neighboring test.
- **Snapshot bloat** — large unreviewed snapshots that fail on any unrelated change.
- **DI/config description** — "the container wires X to Y". One smoke E2E covers the whole graph.
- **Trivial data** — construct a record and assert its own fields back.

## Looks deletable, is not (keep, or convert carefully)

- **Pure algorithms with branch-heavy logic and no user surface** — date parsing, money rounding, encoders,
  schedulers. Often no E2E seam can reach the input space; converting produces a fake E2E. Keep and record.
- **Input-domain edges E2E cannot reach** — injection payloads, unicode, overflow, malformed bytes, 64-bit ids.
  Keep; note that E2E cannot supply the input.
- **Documented regressions** — a test citing a ticket/issue for a real past bug. Treat as Q1 *yes* unless an E2E
  scenario reproduces that exact ticket; convert by replaying the ticket at a user-visible seam.
- **Seam/contract tests** — tests that drive one module against a real (or wire-level) boundary are not unit
  tests. Keep them; they are the cheap version of what you are converting to.
- **Architecture / boundary tests** — assertions over the import graph, layering, or dependency direction. A
  violation is a real defect class (cycles, layering breaks) with no E2E surface. Keep and record.
- **Property/invariant tests** — keep when the invariant is real (money never negative, ordering stable,
  idempotent retry). Convert only if the property is observable end-to-end.

## Boundary calls

- **Integration tests hitting real DB/FS/network** — treat as E2E-adjacent. Count their coverage when answering
  Q2, but do not delete them under this skill's unit-test mandate.
- **Parameterized tests** — classify per case; keep the surviving cases, delete the trivial ones. A table of 40
  cases where 3 guard real bugs becomes 3 tests, not 40.
- **Test-only production seams** — if a method exists only so a unit test can reach it, plan its removal with the
  test. Record it in the report as a seam cleanup, not a test deletion.

## Rules

- Deletion requires the fault proof from `fault-proof.md`. Absence of a proof is itself the low-signal signal.
- "The E2E suite should cover this later" is not Q2 *yes* and not a reason to delete. Convert first, delete after.
- Never delete a whole file in one step: same-file tests have independent verdicts.
