# Role briefs

Match the task to the current `agent_types` inventory. Role names and permissions can differ between configurations. Read the selected type description before you write the prompt.

Use a fresh root path for building, research, and review. Inherited conversation adds settled history and competing instructions. Include the current task facts in the brief instead.

## Select the context

| Role | Delegate when | Give the child | Require in the result |
|---|---|---|---|
| `architect` | Product behavior or task boundaries remain open | The problem, constraints, settled decisions, evidence, and exact questions | A decision, alternatives, consequences, and verifiable task boundaries |
| `researcher` | Facts or code locations are missing | One question, source scope, recency rules, search budget, and non-goals | Citations or paths, facts, contradictions, and unknowns |
| `tdd` | Behavior needs tests before implementation | Acceptance scenarios, fixture map, test runner, baseline, and failure conditions | Focused failing tests, commands, output, and the reason for each failure |
| `coder` | The design is settled and the code map is current | The execution handoff contract and no unrelated design history | The diff, command evidence, and recorded deviations |
| `debugger` | A failure needs diagnosis without a patch | One reproduction, expected and actual behavior, baseline, and suspect paths | Root cause, evidence, and the smallest repair boundary |
| `reviewer` | A scoped diff needs adversarial acceptance | Baseline, diff, contract, acceptance criteria, test evidence, and deviations | Findings with severity and location, plus unverified claims |
| `tasker` | A mechanical job has clear acceptance | Exact paths, one operation, limits, and the acceptance command | The requested artifact and command evidence |
| `browser` | Acceptance needs a real user interface | URL, starting state, one user flow, and expected visible evidence | Screenshots or snapshots, observed results, and failed steps |
| `writer` | A document needs drafting from settled facts | Audience, voice, source facts, artifact path, and length limit | The document and a list of unresolved facts |
| `refiner` | One skill needs feedback recorded | Verbatim feedback, skill path, and the triggering moment | The recorded feedback and its location |

Researchers and reviewers need no file artifact. Judge their results from the citations, paths, findings,
contradictions, and unknowns that the task requires. Do not require a diff from a read-only role.

## Bound each role

State what the role must not do. A researcher does not edit. A debugger does not patch. A reviewer does not implement. A coder does not reopen locked decisions or run live acceptance unless the contract names that work.

Set a search budget for research and a reproduction budget for diagnosis. Set a diff scope for review. Set the execution handoff for code. A role description alone does not bound the work.

Keep each spawn prompt short. Point to the versioned brief. Name the immediate action. State the stop rule.
Do not paste the parent conversation into the prompt.

Give a coder the full execution handoff through the referenced contract. Do not replace that handoff with the
short spawn prompt. The prompt names the contract path, revision, first test, first edit, and inspection interval.
