# Session-lesson evaluation

## Realistic task

A settled design requires code-built facets in a page renderer. The coder must change `renderPage` in `src/render/page.ts`, call `buildFacets` from `src/render/facets.ts`, and add cases to `test/page-render.test.ts` with `fixtures/page-map.json`. Existing tests have two known failures. The acceptance command is `npm test -- page-render`.

The previous brief told the coder to read the task record, previous frontend run, renderer, rule module, acceptance suite, map contract, and fixture scripts. It also included a live model absorb, a page run, and the full suite. The coder consumed 624000 input tokens in 603 seconds without a file change. A steering message started the edits.

Prepare a coder handoff and supervision plan. Do not implement the feature.

## Pass conditions

The result must contain:

1. One rendering outcome, one primary diff, and explicit non-goals.
2. Locked decisions with source locations.
3. A code map with the named paths, symbols, insertion points, callers, and fixture.
4. A fail-first matrix with exact cases, commands, and expected failures.
5. A first test, first edit, and observable checkpoints.
6. Baseline counts, the two known failures, focused gates, and required evidence.
7. A do-not-read list, an exploration budget, stop rules, and a deviation record.
8. Fields for a revision and full baseline commit, with preflight of every path and symbol.
9. The live absorb, page run, and full suite named as separate later gates.
10. A report-only first-checkpoint timeout and one bounded correction cycle before a stop.
11. Parent acceptance and a fresh reviewer with the contract, diff, and evidence.
12. A contract under 150 lines without design rationale or restated history.

Fail the result if it gives the coder the original reading list. Fail it if a progress summary counts as the first checkpoint. Fail it if the coder must reconstruct the implementation sequence.

## Repeat the evaluation

Give the realistic task and the root `SKILL.md` to a fresh agent. Permit only the reference files that the root selects. The paths are hypothetical, so the agent must not run preflight. Score every pass condition against the produced handoff and supervision plan. Record missing or ambiguous instructions, revise the skill, and repeat the same task.
