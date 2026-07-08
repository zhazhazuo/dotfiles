# Validation

The wrapper runs only generic checks. Project-specific checks run after
the wrapper exits `success`, `noop`, or `project_validation_failed`.

## What the wrapper already checks

- the underlying `agent` CLI exit code,
- the bounded file contract: modified, created, deleted, and required-change paths stay inside the declared file sets,
- `git diff --check` over the run's own tree delta,
- a single concurrent wrapper run, enforced by a lock file.

These checks catch common wrapper-level failures. They do not verify
that the edit is correct for the project.

## What the agent must run after a `success` or `noop` report

```bash
git diff -- src/example.ts src/example.spec.ts
```

Read the diff. Confirm:

- the change matches the instruction in
  [prompting.md](prompting.md),
- the change does not include accidental whitespace, comment, or
  import churn outside the declared file set and named scope,
- no secrets, tokens, or environment-specific paths leaked in.

Then run the project's own checks. Pick the ones that are appropriate
for the change:

```bash
npm test
npm run lint
npm run typecheck
npm run build
```

The agent chooses. The rule is: every project check that would catch a
regression in the modified code must run before the agent considers
the edit done. There is no fixed list.

When the correct checks are already known, prefer declaring them up front at
wrapper invocation time with `--validate` (and `--validation-kind` when useful)
or via a manifest. The wrapper will then report those results in
`project_validation`.

If a check has an expected-but-unrelated diff (a snapshot update, a
generated file, a lockfile, formatter output), the agent must extend
the wrapper contract up front with `--allow` / `--create` / `--delete`,
or run a separate targeted wrapper call. The wrapper rejects out-of-scope
changes as `validation_failed`.

## Wrapper-side vs. project-side validation

| check | where it runs | who owns it |
| --- | --- | --- |
| agent exit code | wrapper | wrapper |
| bounded file contract | wrapper | wrapper |
| `git diff --check` | wrapper | wrapper |
| concurrent edit lock | wrapper | wrapper |
| tests | project | agent |
| lint, formatter | project | agent |
| type check, build | project | agent |
| snapshot, generated files | project | agent |
| integration, smoke | project | agent |

If `project_validation.status` is `skipped`, the task is still incomplete from
an orchestration perspective even though the wrapper returned `status: "success"`
or `status: "noop"`.
Either run the missing checks manually or rerun the wrapper with explicit
validation declarations.

If `status` is `noop`, inspect `edits_applied`. A no-op run means the bounded
state was already acceptable or no net diff was needed; it does not imply that
source files changed.

If `status` is `project_validation_failed`, treat the wrapper run as incomplete
even though the bounded diff itself was valid. Use the reported project
validation failures as the next bounded repair target.

## When a project check fails

Do not ask the agent CLI to "fix everything." Identify the smallest edit
that addresses the failure, then issue another wrapper call with the
exact file and exact failure in the instruction. See
[failure-and-retry.md](failure-and-retry.md) for the retry shape.
