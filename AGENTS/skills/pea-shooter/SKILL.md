---
name: pea-shooter
description: use this skill when you need a subagent to do a update task.
---

# Pea Shooter

Use this skill to hand off one focused bounded edit task to `./peashooter.sh`.
Do not call the underlying `agent` CLI directly.

In Codex, run `peashooter.sh` outside the sandbox. The wrapper uses Cursor
`agent -p --yolo`, which is unreliable under `CODEX_SANDBOX=seatbelt`.

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
3. Prefer `--manifest` when the task already has explicit file boundaries and validation commands.
4. Write a concrete one-line instruction for the target file set when the manifest does not already carry it.
5. Declare `--validate` checks up front when the correct project validation commands are already known.
4. Run `./peashooter.sh ...`.
6. Read the JSON report first.
7. When the run is long, inspect the status sidecar before opening the full log.
8. If `project_validation.status` is `skipped`, run the missing project checks from [references/validation.md](references/validation.md) or rerun with explicit validation declarations.
9. If the report is not `success` or `project_validation.status` is `failed`, load [references/failure-and-retry.md](references/failure-and-retry.md) and inspect the full log only if needed.

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

## Additional References

- [references/validation.md](references/validation.md): required after a successful wrapper run
- [references/batch-and-streaming.md](references/batch-and-streaming.md): load only when batching or monitoring progress
- [references/setup.md](references/setup.md): load only when prerequisites are missing
- [references/safety.md](references/safety.md): load when installing or auditing the wrapper
