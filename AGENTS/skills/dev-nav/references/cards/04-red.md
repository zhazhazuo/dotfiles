# 04 Red

Phase gate: you cannot leave phase 4 without the artifact below.
Skill: `~/.pi/agent/git/github.com/obra/superpowers/skills/test-driven-development/SKILL.md`

## Enter

- You are implementing any feature or bugfix, before writing implementation code.

## Exit artifact

A test that fails for the stated reason, and the failure output that shows it failing. The output
is the artifact; a test you merely believe fails is not evidence.

## Earns its place

- **Prevents:** a test that passes for the wrong reason, because it was never watched failing.
- **Evidence:** the skill's own core principle states the measure exactly: "If you didn't watch the
  test fail, you don't know if it tests the right thing."

## Why it is a phase and not a suggestion

Without this phase, phase 8 has nothing to verify against. A test written after the code is a
description of what the code happens to do, so it cannot detect that the code does the wrong
thing.

## Not this card

- Phase 3 decided *what* to test. This phase writes the test.
- A test for code that already exists and is untested is `ripwire-write-tests` in phase 1, not
  this card. This card is only for a test that drives new implementation.
- If the test fails for a reason you cannot explain, you are in phase 6, not here.
- Fixing an existing failing test is phase 6.

## Handoff

Phase 5 consumes the failing test as the definition of done. Phase 8 consumes its passing output.
