---
name: pea-shooter
description: Use when delegating a discrete, already-scoped file-edit task to a CLI subagent with deterministic post-run validation.
---

# Pea Shooter

Use this skill to hand off one focused bounded edit task to `./peashooter.sh`.
Do not call the underlying `agent` CLI directly.

## When to Use

Use this skill when all of these are true:

- The task is already scoped.
- The target file set is already known.
- The task is a focused edit, refactor, or mechanical update with an explicit file boundary.
- The result can be checked with deterministic validation.

Do not use this skill for:

- planning or architecture work
- ambiguous bug diagnosis
- open-ended exploration or codebase Q&A
- non-file-edit work
- parallel or interleaved delegation

## Required Flow

1. Load [references/wrapper-contract.md](references/wrapper-contract.md).
2. Load [references/prompting.md](references/prompting.md).
3. Write a concrete one-line instruction for the target file set.
4. Run `./peashooter.sh ...`.
5. Read the JSON report first.
6. If the report is `success`, run project-level validation from [references/validation.md](references/validation.md).
7. If the report is not `success`, load [references/failure-and-retry.md](references/failure-and-retry.md) and inspect the full log only if needed.

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

## Additional References

- [references/validation.md](references/validation.md): required after a successful wrapper run
- [references/batch-and-streaming.md](references/batch-and-streaming.md): load only when batching or monitoring progress
- [references/setup.md](references/setup.md): load only when prerequisites are missing
- [references/safety.md](references/safety.md): load when installing or auditing the wrapper
