---
name: pea-shooter
description: use this skill when you need a subagent to do a task.
---

# Pea Shooter

Use this skill to hand off one focused bounded edit task to `~/.agents/skills/pea-shooter/peashooter.sh`.
Do not call the underlying `agent` CLI directly.

In Codex, run `peashooter.sh` outside the sandbox. The wrapper uses Cursor
`agent -p --yolo`, which is unreliable under `CODEX_SANDBOX=seatbelt`.

## When to Use

Use this skill when all of these are true:

- The task is already scoped.
- The target file set is already known.
- The task is a focused edit, refactor, or mechanical update with an explicit file boundary.
- The result can be checked with deterministic validation.
- The edit is large enough that subagent overhead is justified.

Do not use this skill for:

- planning or architecture work
- ambiguous bug diagnosis
- open-ended exploration or codebase Q&A
- non-file-edit work
- parallel or interleaved delegation
- 1-2 line micro-edits where direct patching is faster and clearer

## Required Flow

1. Load [references/wrapper-contract.md](references/wrapper-contract.md).
2. Load [references/prompting.md](references/prompting.md).
3. Prefer `--manifest` when the task already has explicit file boundaries and validation commands.
4. Prefer `--instruction-file` or manifest-carried instructions when rich text includes shell-sensitive characters.
5. Shape the task before invocation using the performance rules in this file.
6. Write a concrete one-line instruction for the target file set when the manifest does not already carry it.
7. Declare `--validate` checks up front when the correct project validation commands are already known.
8. Run `./peashooter.sh ...`.
9. Read the JSON report first.
10. When the run is long, inspect the status sidecar before opening the full log.
11. If `project_validation.status` is `skipped`, run the missing project checks from [references/validation.md](references/validation.md) or rerun with explicit validation declarations.
12. If the report status is not `success` or `noop`, load [references/failure-and-retry.md](references/failure-and-retry.md) and inspect the full log only if needed.

## Performance Rules

`pea-shooter` performs best when it is treated as a strict bounded executor, not a collaborator.

### 1. Give it one concrete outcome

Prefer one narrow result per run.

- Good: "Replace the Price group placeholder card with a form-backed pricing section."
- Bad: "Finish the create flow."

If a change naturally splits into route wiring, helper logic, render shell, validation, or follow-up cleanup, prefer separate runs.

### 2. Keep the file set explicit and minimal

The tighter the file boundary, the better the result.

- Prefer 1-4 files when possible.
- Only include optional companion files when the subagent may need them.
- Do not give broad directory-sized boundaries unless the task is truly mechanical across that whole set.

### 3. State the behavior to preserve

Name the existing behavior or API that must not move.

Examples:

- Preserve existing import/export flows.
- Preserve public exports and error messages.
- Preserve detail navigation behavior.

This reduces unnecessary rewrites and import churn.

### 4. State the architectural boundary

Tell the subagent what layer it is allowed to implement within.

Examples:

- Use the parent Ant `Form` as the source of truth.
- Do not reuse `CategoryDetailScreen`.
- Keep `index.tsx` render-only and `core.ts` orchestration-only.

If you do not specify the boundary, the subagent may invent a new one.

### 5. Name explicit non-goals

Spell out what must not happen.

Examples:

- Do not introduce a synthetic `markets` field.
- Do not modify `CreateCategoryModal`.
- Leave the Synonyms placeholder unchanged in this run.
- Do not touch tests outside the declared suite.

This is especially important when the repository contains nearby code that looks temptingly related.

### 6. Prefer local validation that already works

Use the smallest validation that can actually catch a regression in the bounded change.

Prefer:

- one Bun contract test file
- one focused pair of test files
- `git diff --check`

Avoid broad validations when they are known to be noisy or globally red in the repo. A repo-wide failing `tsc` run is a poor default validation for a narrow UI task.

### 7. Make intermediate states explicit when allowed

If the task intentionally leaves placeholders or defers later work, say so.

Examples:

- Leave pricing and synonyms placeholders unchanged.
- Add the helper now; the UI wiring comes in the next run.

This prevents overbuilding.

### 8. Split helper/test work from UI wiring when useful

When a task has both pure logic and UI orchestration, consider separate runs:

- helper + contract test
- component wiring
- follow-up validation or cleanup

This usually improves reliability more than giving the subagent one larger mixed task.

## Edit Instruction Template

A strong `pea-shooter` instruction usually contains these parts in one paragraph:

1. The exact task boundary.
2. The concrete change to make.
3. The behavior or API to preserve.
4. The architecture rule to follow.
5. The non-goals or exclusions.
6. The acceptance shape visible in the diff.

Example:

```text
Implement only Task 4 of the create-flow plan. Replace the Price group placeholder with a form-backed PricingFormSection bound to the parent Ant Form field pricingRows. Reuse the existing row interaction pattern, block duplicate (platform, market) rows, preserve the current page shell and class names, and leave the Synonyms placeholder unchanged.
```

## Usage Examples

Use legacy mode for a single existing file:

```bash
./peashooter.sh \
  "src/example.ts" \
  "Replace the deprecated helper with the new utility. Preserve behavior and exports."
```

Use bounded multi-file mode when one scoped change needs an explicit file set:

```bash
./peashooter.sh \
  --allow src/example.ts \
  --allow src/example.spec.ts \
  --require-change src/example.ts \
  -- \
  "Replace the deprecated helper with the new utility in example.ts and adjust the test only if needed. Preserve behavior and exports."
```

Use bounded creation when the task needs a new file:

```bash
./peashooter.sh \
  --allow src/example.ts \
  --create src/example-helper.ts \
  --require-change src/example.ts \
  --require-change src/example-helper.ts \
  -- \
  "Extract the shared helper from example.ts into example-helper.ts and update example.ts to consume it. Preserve runtime behavior and exports."
```

Use manifest mode when the planning step already knows the exact file and validation contract:

```bash
./peashooter.sh \
  --manifest task.json
```

Use instruction-file mode when the instruction contains shell-sensitive content:

```bash
./peashooter.sh \
  --allow src/example.ts \
  --require-change src/example.ts \
  --instruction-file task.txt
```

## Additional References

- [references/validation.md](references/validation.md): required after a successful wrapper run
- [references/batch-and-streaming.md](references/batch-and-streaming.md): load only when batching or monitoring progress
- [references/setup.md](references/setup.md): load only when prerequisites are missing
- [references/safety.md](references/safety.md): load when installing or auditing the wrapper
