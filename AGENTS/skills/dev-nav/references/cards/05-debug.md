# 05 Debug

Repair phase: enter from any phase; leave by returning to the phase that produced the failure.
Skill: `~/.agents/skills/ripwire-find-bug/SKILL.md`

## Enter

- Any bug, test failure, or unexpected behavior, before proposing fixes.
- A phase produced a failure you cannot explain.

## Exit artifact

The root cause, stated, and the fix that addresses it. A fix without a stated cause is not an exit
from this phase.

## Earns its place

- **Prevents:** a symptom fix shipped as a root-cause fix.
- **Evidence:** unmeasured at routing level. The skill's own criterion is the measure: it ranks the
  code responsible for a symptom rather than a fix for it, and one clear hit plus one focused read
  is its exit condition. A fix with no stated cause is not an exit from this phase.

## Why it is a repair phase, not a step

A failure can surface in any phase: a red test you cannot explain (4), code that passes but does
the wrong thing (4), a scenario that describes the wrong behavior (3). Making Debug a phase in
sequence would let an unexplained failure be walked past. Making it re-entrant means the lifecycle
has one place to send every unexplained failure.

## Not this card

- A red test whose failure you understand is phase 4, not a bug.
- A named failing test you cannot explain is this card.
- Adding coverage to untested code is `ripwire-write-tests`.

## Handoff

Return to the phase that produced the failure. The fix itself normally belongs to phase 4, and it
still owes the failing test written first and the command output that proves the fix.
