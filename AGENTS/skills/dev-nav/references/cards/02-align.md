# 02 Align

Phase gate: you cannot leave phase 2 without the artifact below.
Skill: `~/.agents/skills/alignment-quiz/SKILL.md`

## Enter

- A brainstorming or design session produced a set of decisions.
- A design doc, spec, or roadmap is about to be finalized.
- You are transitioning from design to implementation, and this is the gate.
- The human asks to "quiz", "verify alignment", or "make sure we agree".

## Exit artifact

A score, X/N aligned, plus the list of open mismatches. A real disagreement stops the change:
do not finalize and do not implement while one remains.

## Earns its place

- **Prevents:** finalizing a document, or starting implementation, on decisions the human never
  ratified.
- **Evidence:** unmeasured. The failure is a disagreement discovered after implementation, where
  the correction cost is the whole change. The skill's own claim is the cost argument: a mismatch
  caught now costs less than a mismatch caught after implementation.

## The rule that makes it work

The human's answers are the evidence. The quiz must not hint at the correct answer, so no option
may be marked recommended and the correct answer's position is shuffled across questions. Target
the subtle decisions, especially where the human corrected you during the session. Keep questions
at the idea and consequence level: no file names or symbol names unless the decision itself is
code-level.

## Not this card

- Not for a one-line factual question.
- Not a substitute for the human authoring their own artifact. `one-pager-gate` (via
  `dev-flow-nav`) judges a one-pager the human wrote; it never writes it.

## Handoff

Phase 3 consumes the ratified decision set. QA scenarios derive from decisions, so an unratified
decision produces scenarios for the wrong behavior.
