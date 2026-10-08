---
name: dev-nav
description: >
  Use when the task writes, changes, debugs, reviews, or verifies code, or when you must know
  which dev skill governs the phase you are in. Claims the dev lifecycle: Orient, Align, Specify,
  Red, Implement, Debug, Trim, Verify, Review, Codify. Covers code navigation and impact, deciding
  before building, deriving QA scenarios from a spec, test-driven development, naming code for
  search, restructuring React or Vue components, mocking a missing API, root-cause debugging,
  pruning low-signal tests, evidence before claiming done, requesting and receiving code review,
  and capturing a lesson as a skill. The outer delivery flow (brainstorming, plans, worktrees,
  branch finishing) routes through dev-flow-nav.
---

# Dev lifecycle card book

Expand `~` to the home directory.

The lifecycle is the primary object. Name your phase first, then follow every skill attached to
it. A phase is a gate: leaving it without its exit artifact is a defect, not a shortcut.

## The lifecycle

A code change moves through ten phases. `Debug` and `Trim` are repair phases and you can enter
them from any phase.

| # | Phase | You are in this phase when | Exit artifact |
|---|---|---|---|
| 1 | Orient | you are about to change code you have not mapped, or must answer a question about code | a map: the symbols, the seams, and the reuse candidate for each thing you will write |
| 2 | Align | decisions exist that the human has not ratified, or a document or implementation is about to be finalized | the human's own restatement of each decision, or a recorded objection |
| 3 | Specify | the change's observable behavior is not written down | QA scenarios with stable S-identifiers, each traceable to its source |
| 4 | Red | those scenarios have no failing test | a test that fails for the stated reason, and its failure output |
| 5 | Implement | a failing test exists, or the change is not test-coverable | code that passes, with names one search resolves |
| 6 | Debug | any phase produced an unexplained failure | the root cause stated, and the fix that addresses it |
| 7 | Trim | the suite carries tests that cannot catch a real bug the E2E suite misses | those tests deleted or converted, with the E2E gap closed |
| 8 | Verify | you are about to claim done, fixed, or passing | the command output that proves the claim |
| 9 | Review | the change is complete and unmerged | an independent verdict, and each piece of feedback accepted or rejected with evidence |
| 10 | Codify | the work taught something the next agent would otherwise re-derive | an amended or new skill |

## Where to enter

Enter at the phase whose trigger matches the request. Do not start at 1 by default. Phase 1 is
for changing code you have not mapped, not for every task: naming a symbol you can already
locate, adding a test to a known target, or answering a question about code you just read does
not need a map.

Enter at 1 when the request names code you must change and you do not yet know its seams, its
dependencies, or whether the symbol already exists.

## The cycle

Once inside, you move `1 → 10` in order, and you leave each phase only with its exit artifact.
`6` and `7` are entered from wherever the failure or the low-signal test appeared; when you leave
either, return to the phase that produced it. `10` amends this deck, so the next run's phase 1
starts from a better deck than the last one. That feedback edge is the loop that compounds agent
ability; without it each task resets to the same baseline.

## Boundaries that get confused

- **8 is your own check before you state a claim; 9 is an independent reviewer before a merge.**
  "Check my work" with no reviewer named is 8. Name the reviewer, or ask for one, and it is 9.
- **4 writes the failing test that drives new code. A test for code that already exists and is
  untested is `ripwire-write-tests` in phase 1**, not phase 4. The test-first rule applies to
  behavior you are about to add, and to nothing else.

## The deck

Read the card for your phase, then every skill it names whose condition matches. Phase 5 lists
three skills and usually only one or two apply; a skill whose condition does not match does not
get read. `Prevents` is what the card must be able to prove, not decoration.

| # | Phase | Skills, in order | Prevents | Card |
|---|---|---|---|---|
| 1 | Orient | `ripwire-router` | Writing a symbol that already exists; reading ten files to learn one fact | [01](references/cards/01-orient.md) |
| 2 | Align | `alignment-quiz` | Finalizing a document, or starting implementation, on decisions the human never ratified | [02](references/cards/02-align.md) |
| 3 | Specify | `context-to-qa-scenarios` | "What do we need to test" answered from memory, with no traceable identifier | [03](references/cards/03-specify.md) |
| 4 | Red | `test-driven-development` | A test that passes for the wrong reason, because it was never watched failing | [04](references/cards/04-red.md) |
| 5 | Implement | **Always** `write-discoverable-code`; **only when the target is a React/Vue component** `structuring-ui-components`; **only when the endpoint does not exist yet** `api-mock` | An export one search cannot find; render markup tangled with state; local work blocked on an API that does not exist | [05](references/cards/05-implement.md) |
| 6 | Debug | `systematic-debugging` | A symptom fix shipped as a root-cause fix | [06](references/cards/06-debug.md) |
| 7 | Trim | `prune-low-signal-tests` | A suite that costs maintenance and catches nothing the E2E suite misses | [07](references/cards/07-trim.md) |
| 8 | Verify | `verification-before-completion` | A success claim with no command output behind it | [08](references/cards/08-verify.md) |
| 9 | Review | `requesting-code-review`, then `receiving-code-review` | A defect cascading past the branch; performative agreement with review feedback | [09](references/cards/09-review.md) |
| 10 | Codify | `writing-skills` | The same lesson re-derived by the next agent | [10](references/cards/10-codify.md) |

Every skill must be followed, not considered. If a card's trigger does not match, name the phase
you are actually in and read that card instead.

## What earns a place here

A skill is admitted to the deck only if all four hold. This is the test to apply to every new
capability, and the reason each existing card is on the deck.

1. **It owns a moment.** No other card fires on the same trigger. Two cards on one trigger merge.
2. **It has an exit artifact.** Something the next card, or a reviewer, can consume. No artifact,
   no card.
3. **It states what it prevents.** A named failure, not "be careful". Cite a measurement when one
   exists; where none exists the card says `unmeasured` and gives the failure in words.
4. **It is not derivable.** "Write clean code" and "test your work" are not skills. If the rule can
   be produced from first principles on demand, it does not earn a card.

Eviction follows admission. When a new capability is integrated, re-run all four tests against the
row it duplicates. Retire a card when its skill is superseded or its artifact becomes a phase's
default. A merged card keeps the surviving skill and names the absorbed one in its reference.

## Evidence status

Admission test 3 requires a card to cite a measurement or admit it has none. The debt is listed
here so it cannot be quietly forgotten.

- **Measured:** `write-discoverable-code` (1-word exported names are globally unique 61% of the
  time, 3-word 96%, 4+ 98%, on a ~700k-line monorepo) and `ripwire-router` (name-exact recall@1
  ~99% against ~77% generic).
- **Unmeasured, justified in words only:** `alignment-quiz`, `context-to-qa-scenarios`,
  `structuring-ui-components`, `api-mock`, `requesting-code-review`, `receiving-code-review`.
- **Judged by the skill's own stated criterion rather than a number:** `test-driven-development`,
  `systematic-debugging`, `verification-before-completion`, `prune-low-signal-tests`,
  `writing-skills`. Each of these states a pass/fail condition an operator can check.

The routing fixture in `evals/` measures which card fires, not whether a card's rule holds. A card
whose evidence line can only be justified in words is a candidate for eviction until someone
measures it.

## Handoffs

- **Before 1 and after 9** (idea, plan, worktree, branch finish, merge): `dev-flow-nav`.
- **1** routes into the ripwire family. `ripwire-change-check` also serves **8** as a second
  opinion, and `ripwire-quality-bar` serves **5** when the change is a restructure.
- **5** here is component *code structure*. Visual design, prototypes, and shadcn route to
  `design-nav`.
- Delegation for **2** and **9**: do not route to `council-mode`. It is not installed on this
  machine (there is no `pi-subagents` package and no `council-mode` skill anywhere under `~/.pi`),
  so there is nothing to route to. For one delegated task, use `pea-shooter` through `ops-nav`.

## Notes

- Six routed skills are package-owned (`git:github.com/obra/superpowers`) and silenced via
  `disable-model-invocation: true`. This deck owns their phase, entry, and exit; never edit their
  bodies, because a package update reverts them. The `skill-guard` extension re-applies the flag
  at session start; run `/skill-guard` to re-check.
- The routed paths were verified to exist when this deck was written. If one is missing, the
  package moved: re-resolve before routing around it.
