# Wrapper contract

The single contract between the agent and `peashooter.sh`. The agent must
treat this contract as the API; everything else is implementation detail.

## Invocation modes

### Legacy (single file)

```bash
./peashooter.sh <target-file> <edit-instruction>
```

Maps internally to:

- `target_files.allowed = [<target-file>]`
- `target_files.required_changes = [<target-file>]`
- `target_files.creatable = []`
- `target_files.deletable = []`

The target file must already exist. Both arguments are required.

## Execution environment

In Codex, run `peashooter.sh` unsandboxed. When `CODEX_SANDBOX=seatbelt`, the
wrapper blocks immediately because Cursor `agent -p --yolo` is not reliable in
that execution context.

### Bounded multi-file

```bash
./peashooter.sh \
  --manifest task.json \
  --allow src/a.ts \
  --allow src/b.ts \
  --create src/new.ts \
  --delete src/old.ts \
  --allow-noop \
  --require-change src/a.ts \
  --require-change src/new.ts \
  --instruction-file task.txt \
  --validation-kind bun-test \
  --validate "bun test ./src/a.test.ts" \
  --timeout-seconds 600
```

Flags:

| flag | repeatable | meaning |
| --- | --- | --- |
| `--allow <file>` | yes | existing file the agent may modify (**required** in bounded mode) |
| `--create <file>` | yes | new file the agent may create (must not exist yet) |
| `--delete <file>` | yes | existing file the agent may delete |
| `--allow-noop` | no | permit `noop` when the requested state is already satisfied and no bounded diff is needed |
| `--require-change <file>` | yes | file that must appear in the resulting diff |
| `--instruction-file <path>` | no | read the edit instruction verbatim from a file |
| `--validation-kind <kind>` | yes | kind for the next `--validate` command (`bun-test`, `bun-script`, `pnpm-test`, `tsc`, `shell`) |
| `--validate <command>` | yes | project validation command to run after wrapper validation passes |
| `--manifest <path>` | no | JSON file that declares the bounded file set, instruction, and validation commands |
| `--timeout-seconds <n>` | no | override `AGENT_TIMEOUT_SECONDS` (default `900`) |
| `--` | — | separates flags from the inline edit instruction |

Rules:

- bounded mode starts when the first argument is a flag (`--allow`, etc.).
- at least one `--allow` is required in bounded mode, either directly or via `--manifest`.
- exactly one instruction source must be provided: `--instruction-file`, text after `--`, or the manifest instruction.
- paths are literal file paths only — **no globs, no auto-discovery**.
- paths are resolved relative to the invocation directory and normalized to
  repo-root-relative form; absolute paths and `.`/`..` segments are blocked.
- the wrapper `cd`s to the repo root before running the agent and any
  `--validate` commands, so validation commands must be written repo-root-relative.
- a path cannot appear in more than one of `--allow`, `--create`, `--delete`.
- every `--require-change` path must also appear in `--allow`, `--create`, or `--delete`.
- `--allow` paths must exist; `--create` paths must not exist; `--delete` paths must exist.
- CLI file and validation flags override the manifest values when both are supplied.
- `--allow-noop` enables idempotent convergence; without it, missing required changes remain a contract failure.
- **renames are not supported** — a rename surfaces as a create plus a delete
  and fails the corresponding checks unless both paths are declared.
- **commits are not permitted** — if HEAD moves during the run, validation fails.

The agent must not invoke the underlying `agent` CLI directly. All
filesystem edits go through this wrapper.

## Project validation declarations

When `--validate` is declared, the wrapper runs those commands only after the
wrapper-side boundary and diff checks pass. Validation results land in
`project_validation`.

Kinds currently supported:

- `bun-test`
- `bun-script`
- `pnpm-test`
- `tsc`
- `shell`

If no validations are declared, `project_validation.status` is `skipped`.

The JSON report is the authoritative outcome model. The shell exit code mirrors
the JSON `status` and does not add second-channel semantics.

## Command pattern inside the wrapper

The wrapper invokes the agent CLI in print mode:

```bash
agent -p --yolo "<prompt>"
```

- `-p` / `--print` makes the command non-interactive.
- `--yolo` allows the agent to modify files without confirmation in the
  current wrapper environment.

The wrapper composes `<prompt>` from the allowed/creatable/deletable/required
file lists, the edit instruction, and a fixed set of constraints. The agent
does not compose the prompt itself.

## Post-run classification

Before launching the agent, the wrapper snapshots the entire worktree
(tracked + untracked, staged + unstaged, excluding `.agent-runs/`) as a git
tree object, and records HEAD. After the agent exits it snapshots again and
classifies with a content-aware tree diff:

```bash
git diff --no-renames --name-status <baseline-tree> <result-tree>
```

Because the comparison is against the baseline snapshot rather than HEAD,
pre-existing dirty files are neither hidden from the boundary check nor
falsely attributed to the run, and agent-side staging or commits cannot mask
changes.

Results land in:

- `changed_files` — files whose content changed during the run
- `created_files` — files created during the run
- `deleted_files` — files deleted during the run
- `renamed_files` — always empty; renames are reported as create + delete

## Validation checks

| check | field | passes when |
| --- | --- | --- |
| boundary | `validation.boundary_check` | every modified file is in `target_files.allowed` |
| create | `validation.create_check` | every created file is in `target_files.creatable` |
| delete | `validation.delete_check` | every deleted file is in `target_files.deletable` |
| required change | `validation.required_change_check` | every `target_files.required_changes` path appears in `changed_files`, `created_files`, or `deleted_files` |
| head | `validation.head_check` | HEAD did not move during the run (the agent made no commits) |
| diff hygiene | `validation.diff_check` | `git diff --check` passes over the run's own tree delta (pre-existing whitespace problems elsewhere cannot fail it) |

Any failed check yields `status: "validation_failed"` with exit `4` (contract)
or `3` (diff-check). Boundary/create/delete/required/head failures skip diff-check.

Violation detail fields on `validation_failed`:

- `boundary_violations` — modified outside the allowed list
- `create_violations` — created outside creatable list
- `delete_violations` — deleted outside deletable list
- `missing_required_changes` — required paths with no diff
- `baseline_head` / `result_head` — present on contract failures; differ when `head_check` failed

## JSON report

Exactly one JSON object is printed to stdout. The agent reads it first.

Success shape:

```json
{
  "status": "success",
  "run_id": "20260101-120000-12345",
  "target_files": {
    "allowed": ["src/a.ts", "src/b.ts"],
    "creatable": ["src/new.ts"],
    "deletable": ["src/old.ts"],
    "required_changes": ["src/a.ts", "src/new.ts"]
  },
  "changed_files": ["src/a.ts"],
  "created_files": ["src/new.ts"],
  "deleted_files": ["src/old.ts"],
  "files_modified": ["src/a.ts"],
  "files_created": ["src/new.ts"],
  "files_deleted": ["src/old.ts"],
  "renamed_files": [],
  "edits_applied": true,
  "diff_stat": " src/a.ts | 4 ++--\n 3 files changed, 2 insertions(+), 2 deletions(-)",
  "log_file": ".agent-runs/20260101-120000-12345.log",
  "legacy_mode": false,
  "validations_run": 1,
  "validations_passed": 1,
  "validations_failed": 0,
  "validation": {
    "boundary_check": "passed",
    "create_check": "passed",
    "delete_check": "passed",
    "required_change_check": "passed",
    "head_check": "passed",
    "diff_check": "passed"
  }
}
```

Common fields:

- `status` — see status values below.
- `run_id` — opaque ID; also the prefix of the log file.
- `target_files` — the bounded contract the wrapper enforced.
- `changed_files` / `created_files` / `deleted_files` / `renamed_files` — actual diff classification.
- `files_modified` / `files_created` / `files_deleted` — stable summary arrays for operator-facing automation.
- `edits_applied` — `true` when the wrapper produced a bounded net diff.
- `diff_stat` — `git diff --stat` between the baseline and result snapshots (the run's own changes only).
- `log_file` — path to the full agent log.
- `report_file` — copy of the final report written by the wrapper.
- `status_file` — lifecycle status sidecar updated while the wrapper is running.
- `legacy_mode` — `true` when invoked via the two-argument form.
- `phase` — lifecycle state (`starting`, `agent_running`, `validating_wrapper`, `waiting_project_validation`, `completed`).
- `started_at` / `updated_at` / `elapsed_seconds` / `timeout_seconds` — run timing metadata.
- `last_agent_output_at` / `agent_output_status` — heartbeat metadata for long-running calls.
- `validation.*` — per-check results; `diff_check: "failed"` reports also include `validation.diff_check_log`.
- `project_validation` — declared project-side validation results.
- `validations_run` / `validations_passed` / `validations_failed` — counts derived from `project_validation.results`.
- `created_files_patch` — patch-style preview for newly created files.
- `next_step_hint` / `safe_to_commit` / `review_created_files` — post-run guidance.
- `failure_reason` / `suggested_actions` / `retryable` / `last_successful_phase` — retry and diagnosis fields.
- `lock_status` / `lock_owner_pid` / `lock_owner_run_id` / `lock_age_seconds` — lock state and ownership details.
- `exit_code` — present on non-zero terminal outcomes.

Legacy success reports use the same `target_files` object shape with
`legacy_mode: true`.

Project validation shape:

```json
{
  "status": "passed",
  "results": [
    {
      "kind": "bun-test",
      "command": "bun test ./src/a.test.ts",
      "status": "passed",
      "exit_code": 0,
      "duration_seconds": 2
    }
  ]
}
```

## Status values

| status | meaning | exit code | agent action |
| --- | --- | --- | --- |
| `success` | agent finished; contract satisfied; `git diff --check` passed; project validation passed or was skipped. | `0` | inspect the diff and project validations, then continue. |
| `noop` | the requested state was already satisfied or no bounded diff was needed, and the caller explicitly allowed that outcome. | `0` | review state and continue; do not assume a code change occurred. |
| `project_validation_failed` | wrapper validation passed, but one or more declared project validations failed. | `5` | inspect failing validations, then issue a bounded follow-up fix. |
| `blocked` | preflight failed: usage, flag relationship, missing file, invalid instruction source, missing dependency, live lock, or not in a git tree. | `2` | fix the precondition; do not retry the same call unchanged. |
| `failed` | agent CLI exited non-zero. | original agent exit code | inspect the log, then issue a targeted retry. |
| `timeout` | agent exceeded `--timeout-seconds` or `AGENT_TIMEOUT_SECONDS`. | `124` | inspect the log; widen timeout or narrow the prompt. |
| `validation_failed` | agent finished but a contract or diff-check failed. | `3` (diff-check) or `4` (contract) | inspect violations; keep, revert, or reset per [failure-and-retry.md](failure-and-retry.md). |

Any status other than `success` or `noop` is incomplete. The agent must not
treat the edit as done.

## Where logs and reports land

- `.agent-runs/<run-id>.log` — full agent stdout and stderr.
- `.agent-runs/<run-id>.report.json` — copy of the JSON report written
  for debugging; the agent reads the one on stdout.
- `.agent-runs/<run-id>.status.json` — lifecycle status sidecar for long-running calls.
- `.agent-runs/<run-id>.diff-check.log` — output of `git diff --check`,
  present only on diff-check `validation_failed`.
- `.agent-runs/edit.lock` — JSON lock metadata that prevents two wrapper
  runs from interleaving and identifies the owner when blocked.

The `.agent-runs/` directory must not be committed. See
[safety.md](safety.md) for the gitignore entry.
