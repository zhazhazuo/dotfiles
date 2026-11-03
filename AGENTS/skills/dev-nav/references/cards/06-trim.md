# 07 Trim

Repair phase: enter from any phase, typically after phase 5; leave by returning to the phase that
produced the suite.
Skill: `~/.agents/skills/prune-low-signal-tests/SKILL.md`

## Enter

- The repository carries many low-signal unit tests and E2E is the intended safety net.
- "Delete every test that wouldn't catch a real bug our E2E tests miss."
- Suites that assert mocks, tautologies, implementation details, or framework behavior.
- A migration to an E2E-first strategy is under way.

## Exit artifact

`test-prune-report.md`, in which every deletion carries two pieces of evidence: a fault the test
catches (question 1) and the E2E test that catches the same fault (question 2). Both are required
before a deletion is legal. E2E must be green before the prune starts and green after it.

## Earns its place

- **Prevents:** a suite that costs maintenance and catches nothing the E2E suite misses.
- **Evidence:** unmeasured at routing level. The skill supplies its own criterion, which is the
  measure: keep a unit test only if it catches a real bug that the E2E suite misses; otherwise
  delete it, converting its intent to E2E first when that intent guards a real bug.

## Delegation note

This is the one card whose trigger authorizes subagents without further instruction: the skill
explicitly supports fanning the work out across parallel scouts and writers. The parent keeps the
criterion, the arbitration, and the final acceptance. Every other card in this deck runs in the
current session unless the operator asks for delegation.

## Not this card

- Adding coverage to untested existing code is `ripwire-write-tests`.
- Fixing one failing test is phase 6.
- Never delete or weaken an E2E test. A guarded behavior with no user-visible seam is load-bearing;
  keep it and record why.

## Handoff

Return to whichever phase produced the suite, usually phase 5.
