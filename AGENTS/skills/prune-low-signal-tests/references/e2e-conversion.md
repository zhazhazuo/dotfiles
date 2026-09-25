# Converting a Unit Test's Intent to E2E

A conversion replaces one or more unit tests with one E2E scenario that fails on the same fault.

## Pick the seam

Choose the **lowest user-visible seam** that the guarded behavior crosses:

- HTTP endpoint or RPC method
- CLI invocation and its stdout/exit code
- rendered UI behavior (visible text, disabled state, redirect, error message)
- produced artifact (file, row, emitted message, queue payload)
- public API called from outside the module

Drive the real system at that seam. Do not stub the boundary the behavior lives on — a converted test that
mocks the same collaborator the unit test mocked is the same low-signal test wearing an E2E label.

## Scenario shape

```text
given  <real state set up through real entry points>
when   <one user-level trigger>
then   <one observable outcome>
```

- One scenario = one assertion. Split compound expectations.
- Reuse the existing E2E harness, fixtures, and helpers. Do not build a parallel harness.
- Name the scenario after the behavior, not the deleted test.
- If the intent is a boundary condition, drive the boundary through the seam (empty list, max length, duplicate
  submit, expiry) — not by calling the internal function.

## Prove the conversion

1. Inject the Q1 fault from `fault-proof.md`.
2. Run the new E2E scenario. It **must fail**. A passing new scenario proves nothing.
3. Revert the fault. The scenario must pass.
4. Delete the replaced unit tests only after steps 1–3 pass.

## When conversion is impossible

If no user-visible seam can reach the behavior (internal invariant, unreachable input domain, algorithm edge),
do **not** fabricate an E2E test that cannot fail on the fault. Keep the unit test and record:

```text
kept: not E2E-observable — <behavior> — <why no seam reaches it>
```

This is a legitimate outcome. Forcing a fake E2E to hit a "no unit tests" target destroys the signal.

## Assertion quality

- No `assert response.ok` as the only assertion — assert the behavior.
- No sleeps; wait on a condition or the observable output.
- No retries to mask flake; fix or report the flake.
- Assert on the outcome, not on side-channel internals (no log scraping, no mock call counts).
