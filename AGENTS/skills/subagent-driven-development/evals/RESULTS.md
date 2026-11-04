# Session-lesson evaluation results

Date: 2026-11-04

## Method

Two fresh `architect` agents applied the skill to `evals/session-lesson.md`. Each agent read the root skill and its selected references. Neither agent edited the fixture or ran preflight because the repository paths are hypothetical.

The rubric measures handoff completeness and supervision behavior. It does not measure implementation speed or production token use.

## First run

The agent passed all 11 initial conditions and avoided all three failure conditions. It reported eight gaps:

1. No draft state before preflight.
2. Unclear meaning of one primary diff across source and test files.
3. No gate semantics for known failures and a nonzero exit code.
4. Unclear planning depth for later handoffs.
5. Possible conflict between forbidden reads and mapped paths.
6. Thin timeout guidance for the first failing test.
7. No fallback contract location.
8. Unclear wording for a single child.

The revisions added explicit rules for each gap. A 150-line limit also bounded the contract after the first run produced too much detail.

## Second run

The agent passed all 12 conditions and avoided all three failure conditions. Its draft contract used about 64 lines. It named the first failing test, first code edit, focused gate, exploration limit, and recovery cycle without reading design history.

The agent found five remaining clarity points. The final text addresses them:

- Costly single children use `wait: false` and report-only timeouts.
- The allow-list rule applies to sub-delegation orders.
- Report-only timeouts apply with or without `agent_update`.
- Locked decisions contain inline text and source citations.
- The line limit counts every physical line.

## Final static validation

The final files passed checks for frontmatter, silent invocation, the dotfiles symlink, local references, navigator routing, the evaluation rubric, banned modals, and semicolons. The root `SKILL.md` has 27 lines. `bash -n` passed for the updated development routing evaluation. `git diff --check` passed.

## Limits

No real coder executed the generated contract. The evaluation does not prove a faster first edit, fewer input tokens, or correct implementation. Measure those outcomes on the 1.2 and 1.3 handoffs with the first-artifact time, exploration volume, deviations, and acceptance evidence.

Repeat the model evaluation with `evals/session-lesson.md` after a material skill change.
