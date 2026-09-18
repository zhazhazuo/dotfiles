---
name: before-you-build
description: Use when a plan, idea, proposal, or one-pager has been drafted and building is about to start, when the user asks to review a plan before you build — against the three constraints or build gates — or when an amended plan needs a re-check before it is built.
disable-model-invocation: true
---

# Before You Build

## Purpose

Review a plan or idea against the three build gates from Jordan Lord's "3 constraints before I build anything". The gates collapse the search space: they limit complexity, force leverage, and force identity. The closing rule is absolute — fail any gate and the plan is not built until it is amended and passes a full re-review.

## When to Use

- A plan, idea, proposal, spec, or one-pager exists and implementation is the next step.
- The user asks to check a plan against the three constraints, the build gates, or "should I build this".
- A plan was amended after a previous review and needs a re-check.

## Process

1. **Load the plan.** Read the one-pager, spec, or the plan text from the session. Judge the plan as written. If no one-pager exists, Gate 1 fails as UNREADY — continue to step 5 with that verdict.
2. **Run Gate 1 — One page or it doesn't get built.** Load `references/the-three-gates.md`. Check the one-pager exists, fits one page, and carries no fluff.
3. **Run Gate 2 — Core tech separable from the product.** Check the plan names reusable core tech that survives the product pivoting or dying.
4. **Run Gate 3 — One defining constraint shapes the product.** Check the plan names exactly one user-visible constraint that shapes the whole experience and sits front and centre in the one-pager.
5. **Report the verdict.** One line per gate: PASS, FAIL, or UNREADY, each citing evidence from the plan. Apply the closing rule: any FAIL or UNREADY means do not build.
6. **Remediate.** Gate 1 fails: draft or trim the one-pager with `references/one-pager-template.md`. Gate 2 or 3 fails: state the specific amendment the plan needs, or recommend dropping the idea if it cannot pass. Offer a full re-review after any amendment.

## Progressive Disclosure

- This root file routes the review.
- `references/the-three-gates.md` holds the gate definitions, checks, and fail signals. Load it at step 2.
- `references/one-pager-template.md` holds the one-pager skeleton. Load it only when Gate 1 fails for a missing or unusable one-pager.

## Constraints

- Judge the plan as written; never invent supporting evidence it does not contain.
- UNREADY means the artifact needed to judge the plan is missing; it blocks building the same as a FAIL.
- Every PASS cites concrete evidence from the plan; enthusiasm is not evidence.
- The closing rule is non-negotiable: fail any gate and the plan is not built.
- Re-run the full review after any amendment; a partial re-check is never a pass.
