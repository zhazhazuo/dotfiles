---
name: dev-nav
description: >
  Use when the task writes, changes, debugs, or verifies code, or when you must know
  which dev skill governs the phase you are in. Claims the dev lifecycle: Orient, Align, Specify,
  Implement, Debug, Trim. Covers code navigation and impact, deciding before building, deriving QA
  scenarios from a spec, naming code for search, restructuring React or Vue components, mocking a
  missing API, root-cause debugging, and pruning low-signal tests. The outer delivery flow
  (delegation, one-pager gating) routes through dev-flow-nav.
---

# Dev lifecycle card book

Expand `~` to the home directory.

The lifecycle is the primary object. Name your phase first, then follow every skill attached to
it. A phase is a gate: leaving it without its exit artifact is a defect, not a shortcut.

## The lifecycle

A code change moves through six phases. `Debug` and `Trim` are repair phases and you can enter
them from any phase.

| # | Phase | You are in this phase when | Exit artifact |
|---|---|---|---|
| 1 | Orient | you are about to change code you have not mapped, or must answer a question about code | a map: the symbols, the seams, and the reuse candidate for each thing you will write |
| 2 | Align | decisions exist that the human has not ratified, or a document or implementation is about to be finalized | the human's own restatement of each decision, or a recorded objection |
| 3 | Specify | the change's observable behavior is not written down | QA scenarios with stable S-identifiers, each traceable to its source |
| 4 | Implement | the behavior is specified, or the change is not test-coverable | code that passes the test you wrote first, with names one search resolves |
| 5 | Debug | any phase produced an unexplained failure | the root cause stated, and the fix that addresses it |
| 6 | Trim | the suite carries tests that cannot catch a real bug the E2E suite misses | those tests deleted or converted, with the E2E gap closed |

## Where to enter

Enter at the phase whose trigger matches the request. Do not start at 1 by default. Phase 1 is
for changing code you have not mapped, not for every task: naming a symbol you can already
locate, adding a test to a known target, or answering a question about code you just read does
not need a map.

Enter at 1 when the request names code you must change and you do not yet know its seams, its
dependencies, or whether the symbol already exists.

## The cycle

Once inside, you move `1 → 6` in order, and you leave each phase only with its exit artifact.
`5` and `6` are entered from wherever the failure or the low-signal test appeared; when you leave
either, return to the phase that produced it.

The deck no longer amends itself. Phase 10 held that feedback edge until `writing-skills` left the
machine (see Removed). When a run teaches something this deck should carry, edit this file or add
the card in the same session that learned it. Without that edit each task resets to the same
baseline.

## Boundaries that get confused

- **Test-first is a standing rule in `AGENTS.md`, not a phase.** The deck carried it as phase 4
  until `test-driven-development` left the machine. The rule still holds: write the failing test
  first, watch it fail, then implement.
- **A test for code that already exists and is untested is `ripwire-write-tests` in phase 1.**
  The test-first rule applies to behavior you are about to add, and to nothing else.
- **Review is not a phase here.** An independent verdict on a finished branch is a delegation
  job: `subagent-delegation` through `dev-flow-nav`. Your own check before a claim is phase 4's
  exit artifact plus the command output behind it.

## The deck

Read the card for your phase, then every skill it names whose condition matches. Phase 4 lists
three skills and usually only one or two apply; a skill whose condition does not match does not
get read. `Prevents` is what the card must be able to prove, not decoration.

| # | Phase | Skills, in order | Prevents | Card |
|---|---|---|---|---|
| 1 | Orient | `ripwire-router` | Writing a symbol that already exists; reading ten files to learn one fact | [01](references/cards/01-orient.md) |
| 2 | Align | `alignment-quiz` | Finalizing a document, or starting implementation, on decisions the human never ratified | [02](references/cards/02-align.md) |
| 3 | Specify | `context-to-qa-scenarios` | "What do we need to test" answered from memory, with no traceable identifier | [03](references/cards/03-specify.md) |
| 4 | Implement | **Always** `write-discoverable-code`; **only when the target is a React/Vue component** `structuring-ui-components`; **only when the endpoint does not exist yet** `api-mock` | An export one search cannot find; render markup tangled with state; local work blocked on an API that does not exist | [04](references/cards/04-implement.md) |
| 5 | Debug | `ripwire-find-bug` | A symptom fix shipped as a root-cause fix | [05](references/cards/05-debug.md) |
| 6 | Trim | `prune-low-signal-tests` | A suite that costs maintenance and catches nothing the E2E suite misses | [06](references/cards/06-trim.md) |

Every skill must be followed, not considered. If a card's trigger does not match, name the phase
you are actually in and read that card instead.

## Removed on 2026-10-28

The `git:github.com/obra/superpowers` package left this machine. Six skills the deck routed to went
with it, and nothing under `~/.agents/skills` supplies them. The deck shrank rather than pretending
a neighbour does the job.

| Lost skill | Phase that died | What the deck now says instead |
|---|---|---|
| `test-driven-development` | Red | Test-first is a standing rule in `AGENTS.md`, stated in Boundaries. |
| `verification-before-completion` | Verify | No phase. The claim test is the command output itself; `ripwire-change-check` and `ripwire-quality-bar` cover the diff and the quality delta without a phase. |
| `requesting-code-review` | Review | No phase. `subagent-delegation` through `dev-flow-nav` is the independent-verdict route. |
| `receiving-code-review` | Review | No phase. Nothing installed now governs how feedback is judged. |
| `writing-skills` | Codify | No phase. `author-high-quality-skills` covers a local skill file, not the lesson that earns one. |
| `systematic-debugging` | Debug survived | Re-pointed to `ripwire-find-bug`, which owns the same moment and is installed. |

Re-admit a lost phase only through the four admission tests below, and only when an installed
skill passes them.

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
  `structuring-ui-components`, `api-mock`, `ripwire-find-bug`.
- **Judged by the skill's own stated criterion rather than a number:** `prune-low-signal-tests`,
  which states a pass/fail condition an operator can check.

The routing fixture in `evals/` measures which card fires, not whether a card's rule holds. A card
whose evidence line can only be justified in words is a candidate for eviction until someone
measures it.

## Handoffs

- **Before 1 and after 6** (delegation, one-pager gate): `dev-flow-nav`.
- **1** routes into the ripwire family. `ripwire-change-check` and `ripwire-quality-bar` are diff
  checks with no phase of their own: reach `ripwire-change-check` when a merge is near, and
  `ripwire-quality-bar` before you call a restructure done.
- **4** here is component *code structure*. Visual design, prototypes, and shadcn route to
  `design-nav`.
- Delegation for **2**: do not route to `council-mode`. It is not installed on this machine (there
  is no `pi-subagents` package and no `council-mode` skill anywhere under `~/.pi`), so there is
  nothing to route to. For one delegated task, use `pea-shooter` through `ops-nav`.

## Notes

- Every routed path was verified to exist on 2026-10-28. If one is missing, a package moved:
  re-resolve before routing around it, and correct this deck in the same session.
