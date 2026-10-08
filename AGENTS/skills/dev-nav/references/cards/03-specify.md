# 03 Specify

Phase gate: you cannot leave phase 3 without the artifact below.
Skill: `~/.agents/skills/context-to-qa-scenarios/SKILL.md`

## Enter

- A feature, fix, or phase needs test coverage.
- A context document (PRD, proposal, Jira bug description) changed, and scenarios need a refresh.
- Someone asks "what do we need to test" for a feature or fix.

## Exit artifact

A behavior-driven QA scenario list in which every scenario carries a stable `S-N` identifier
traceable back to the plain scenarios document. The skill's own output format is the checklist:
scenarios by category, coverage, blockers, open questions.

## Earns its place

- **Prevents:** coverage answered from memory, with no traceable identifier, so a spec change
  cannot refresh the test set and the tests silently diverge from what was specified.
- **Evidence:** unmeasured at routing level. The traceability mechanism is the measure: the QA
  layer sits on top of the plain scenarios doc, and every checkbox links to an `S-N`.

## Dependency

This card requires the companion plain scenarios document to already exist; step 0 of the skill
locates it and is marked required. If it does not exist, that is a phase 3 blocker, not a licence
to improvise scenarios from the spec directly. `context-to-plain-scenarios` (via `design-nav`)
produces it.

## Not this card

- Adding coverage to untested existing code is `ripwire-write-tests`, not this.
- Deleting low-signal tests is phase 7.

## Handoff

Phase 4 consumes the scenarios as the specification of the failing tests.
