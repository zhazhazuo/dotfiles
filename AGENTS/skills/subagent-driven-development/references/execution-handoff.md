# Execution handoff contract

An execution handoff is a bounded implementation brief derived from settled decisions. It sits between the design record and the code. It does not replace either one.

Store the contract with the task records under the repository's existing artifact convention. If no convention exists, use `.ai-artifacts/handoffs/<task>.md`. Record a revision, the baseline commit, and the worktree state. Increment the revision after each material change. Require the coder to name the revision in its result.

Keep the contract under 150 physical lines, including tables and code fences. Remove design rationale and restatements of settled history. One primary diff means one scoped change set across the mapped source and test paths.

Use `Status: draft` while fields remain unresolved. Before the spawn, complete preflight, replace every angle-bracket field, and set `Status: ready`. Never give a draft contract to a coder.

## Write the seven parts

Inline each locked decision and cite its source location. The citation supports audit and does not assign the source as reading. Do not make the coder open the design record unless a stop rule requires escalation.

Use this template and replace every angle-bracket field.

```markdown
# Execution handoff: <task>
Status: draft
Revision: <number or content hash>
Baseline commit: <full SHA>
Worktree state: <existing changes that affect this task>

## 1. Mission
Outcome: <one behavior or state change>
Primary artifact: <one diff, test file, report, or recorded result>
Non-goals: <excluded behavior, files, live runs, and broad verification>

## 2. Locked decisions
- <decision and source location>
- <decision and source location>

## 3. Code map
| Path | Symbol | Insertion point | Callers | Fixtures | Required change |
|---|---|---|---|---|---|
| <path> | <symbol> | <exact location> | <direct callers> | <test data> | <local change> |

## 4. Fail-first matrix
| Case | Test location | Command | Expected failure before the edit |
|---|---|---|---|
| <observable case> | <path and test name> | <exact command> | <assertion or reproduction> |

## 5. Execution sequence
First test: <test or reproduction to create or run>
First edit: <path, symbol, and intended edit>
Checkpoints: <ordered artifacts and commands>
Exploration budget: <time and maximum unmapped files>

## 6. Verification
Baseline: <commands, counts, and known failures>
Focused gates: <commands and expected results>
Evidence: <output, screenshots, counts, and artifact paths to capture>

## 7. Stop rules
Do not read: <design history, transcripts, unrelated suites, and paths>
Stop exploring when: <budget expires or the mapped evidence answers the question>
Stop and report when: <map conflict, open product decision, bad baseline, or scope growth>
Deviation record: <old map entry, observed tree, new entry, and reason>
```

Name one outcome. If the mission contains independent behavior changes, split the handoff. Keep deterministic code gates separate from live model runs. Give full-suite verification a later handoff when it has a different cost or owner.

The fail-first matrix names new cases to write and existing failures to reproduce. Use end-to-end tests by default. When isolated tests are necessary, write the failure cases before implementation. Record pre-existing failures so the coder does not own the wrong baseline.

When known failures remain, define the focused gate by test identity and count. The new cases must pass, and the remaining failures must equal the recorded baseline set. Do not claim a zero exit code for that gate. Record the actual exit code.

At planning time, name later live runs and broad suites as non-goals. Write their contracts when those gates start. Do not make the coder plan later handoffs.

## Complete the preflight

1. Record the full baseline commit and the existing worktree changes.
2. Make sure that every mapped path exists.
3. Make sure that every mapped symbol, insertion point, caller, and fixture matches the baseline and current worktree.
4. Run the baseline commands and record counts, exit codes, and known failures.
5. Make sure that the first test command selects the named cases.
6. Make sure that parallel children do not own overlapping files.
7. If preflight finds a stale map, revise the contract before the spawn.
8. Set `Status: ready` only after every field contains current repository evidence.

If uncommitted changes overlap the code map, stop. Establish a new baseline or map the changes explicitly. Do not make the coder discover the ambiguity.

## Start the coder

The do-not-read list excludes design history and unmapped paths. Do not forbid a mapped path that the task requires. Limit that path to the named symbol, insertion point, and direct dependencies. Name any exception explicitly.

The spawn prompt names the contract path, revision, first test, first edit, and checkpoint timeout. It does not repeat the design record.

```text
Execute execution handoff <path> at revision <revision>.
Start with <first test> and make <first edit>.
Do not read the paths in the contract stop rules.
If the tree contradicts the map, record the contradiction and follow the contract stop rule.
Return the changed paths, exact command results, and deviations.
```

A local code-map contradiction does not require a full stop when the repair stays inside the mission. Permit the smallest correction and require a deviation record. Stop when the contradiction changes product behavior, invalidates the mission, or requires an open decision.
