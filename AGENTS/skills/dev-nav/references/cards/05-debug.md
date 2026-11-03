# 06 Debug

Repair phase: enter from any phase; leave by returning to the phase that produced the failure.
Skill: `~/.pi/agent/git/github.com/obra/superpowers/skills/systematic-debugging/SKILL.md`

## Enter

- Any bug, test failure, or unexpected behavior, before proposing fixes.
- A phase produced a failure you cannot explain.

## Exit artifact

The root cause, stated, and the fix that addresses it. A fix without a stated cause is not an exit
from this phase.

## Earns its place

- **Prevents:** a symptom fix shipped as a root-cause fix.
- **Evidence:** the skill's own iron law is the measure: "ALWAYS find root cause before attempting
  fixes. Symptom fixes are failure."

## Why it is a repair phase, not a step

A failure can surface in any phase: a red test you cannot explain (4), code that passes but does
the wrong thing (5), a claim that does not hold up (8). Making Debug a phase in sequence would let
an unexplained failure be walked past. Making it re-entrant means the lifecycle has one place to
send every unexplained failure.

## Not this card

- A red test whose failure you understand is phase 4, not a bug.
- A named failing test you cannot explain is this card.
- Adding coverage to untested code is `ripwire-write-tests`.

## Handoff

Return to the phase that produced the failure. The fix itself normally belongs to phase 5, and it
still owes phase 4's failing test and phase 8's evidence.
