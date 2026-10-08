# 09 Review

Phase gate: you cannot leave phase 9 without the artifact below.
Skills, in order: `requesting-code-review`, then `receiving-code-review`.

- `~/.pi/agent/git/github.com/obra/superpowers/skills/requesting-code-review/SKILL.md`
- `~/.pi/agent/git/github.com/obra/superpowers/skills/receiving-code-review/SKILL.md`

## Enter

- A task or a major feature is complete, or the change is about to be merged.
- Review feedback has arrived and must be acted on.

## Exit artifact

An independent verdict, and each piece of feedback either accepted or rejected with evidence.
Neither half alone is an exit: a verdict with unaddressed feedback, or addressed feedback with no
independent verdict, is an incomplete phase.

## Earns its place

**`requesting-code-review`** — prevents a defect cascading past the branch. The reviewer receives
precisely crafted context for the evaluation, never your session history, so the review is of the
change rather than of your reasoning. Core principle: review early, review often; mandatory after
each task in subagent-driven development.

**`receiving-code-review`** — prevents performative agreement with, and blind implementation of,
review feedback. Core principle: "Verify before implementing. Ask before assuming. Technical
correctness over social comfort." Evidence: unmeasured; the failure is a wrong suggestion applied,
or a correct one dismissed to avoid friction.

## Not this card

- Phase 8 is the self-check on your own work; this phase is the independent one.
- Reviewing code you did not write, as an unfamiliar subsystem, is `ripwire-fresh-eyes` via
  `ripwire-router` (phase 1), not this card.

## Handoff

Phase 10 if the review taught something durable. Then `dev-flow-nav` for branch finishing and
merging.
