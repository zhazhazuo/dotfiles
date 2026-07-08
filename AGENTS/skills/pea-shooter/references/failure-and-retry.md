# Failure and retry

Load this file on the first report whose `status` is neither `success` nor `noop`.

## Read the report, then the log

Read the JSON report first.

Use the report's structured guidance before deciding to retry:

- `retryable`
- `suggested_actions`
- `last_successful_phase`
- `failure_reason`
- `agent_silent_seconds`

Open the full log at `.agent-runs/<run-id>.log` only when:

- the report's reason is not enough to act on,
- the agent's own output is needed to understand which file or line
  the wrapper failed on,
- the boundary violation lists files the agent did not expect to
  change.

Do not open the log on `success` or `noop` unless the JSON report is genuinely insufficient.

## `blocked` — fix the precondition, do not retry

`status: "blocked"` means the wrapper refused to run. Common reasons:

- usage error (missing argument) — fix the call, re-run.
- an `--allow` target does not exist — pick a different file.
- a `--create` target already exists — move it to `--allow` or remove it.
- a `--delete` target does not exist — fix the contract or file path.
- an invalid flag relationship — fix the file-set declaration and re-run.
- `agent` CLI not on `PATH` — install or export it; see
  [setup.md](setup.md).
- `jq` or `git` not on `PATH` — install the missing binary.
- not inside a git working tree — initialise git or use a
  different wrapper entry point.
- another wrapper run is in progress — wait for the lock file at
  `.agent-runs/edit.lock` to clear, using `lock_owner_pid`,
  `lock_owner_run_id`, and `lock_age_seconds` from the report.

Fix the precondition and re-run the same call. Do not change the edit
instruction.

## `project_validation_failed` — bounded diff is valid, project checks are not

`status: "project_validation_failed"` means the wrapper accepted the bounded
edit, but one or more declared project validations failed.

The next action is:

1. inspect `project_validation.results`,
2. identify the smallest bounded fix for the failing validation,
3. retry with the exact failure in the new instruction,
4. rerun the same declared validations.

Do not treat `project_validation_failed` as a transport error or a wrapper bug.

## `noop` — requested state already satisfied

`status: "noop"` means the caller opted into idempotent convergence with
`--allow-noop` or manifest `allow_noop`, and the wrapper finished with no
bounded diff to apply.

In shorthand: status: `noop`.

Use the report to confirm:

- `edits_applied == false`
- `missing_required_changes` may still name the untouched path
- `project_validation` shows whether any declared checks still ran

Do not retry the same call unless the no-op outcome itself was unexpected.

## `failed` — inspect, then issue a targeted retry

`status: "failed"` means the agent CLI exited non-zero. Open the
log. Find the first error the agent CLI emitted. Issue a new
wrapper call whose edit instruction names that error and asks for
the minimum change to address it:

```bash
./peashooter.sh \
  "src/example.ts" \
  "Fix this TypeScript error introduced by the previous edit: <exact error>. Preserve the intended behaviour and do not change unrelated code."
```

Do not paste the entire log into the next instruction. Quote the
specific error and the file/line.

## `timeout` — narrow the prompt or widen the budget

`status: "timeout"` means the agent CLI did not finish within
`--timeout-seconds` or `AGENT_TIMEOUT_SECONDS` (default `900`). Two responses:

- narrow the prompt so the agent CLI does less per call (split
  the edit across more calls),
- raise `AGENT_TIMEOUT_SECONDS` for the environment if the change
  is genuinely large.

Before retrying, inspect `.agent-runs/<run-id>.status.json` to see whether the
wrapper was still receiving agent output or whether the run had gone silent.

Do not paste a timeout message into a retry prompt.

## `validation_failed` — inspect the diff and decide

`status: "validation_failed"` means the agent CLI finished, but a
boundary or generic-validation check tripped. Two cases:

- exit `3` — `git diff --check` failed. Open
  `.agent-runs/<run-id>.diff-check.log` for the offending lines.
  The diff contains conflict markers or whitespace that policy rejects.
  Ask the subagent to re-emit the diff without the offending content,
  or fix it by hand if the file is small and obvious.
- exit `4` — one or more contract checks failed. Inspect the specific
  violation arrays first:

  - `boundary_violations` — modified paths outside `--allow`
  - `create_violations` — created paths outside `--create`
  - `delete_violations` — deleted paths outside `--delete`
  - `missing_required_changes` — paths declared in `--require-change` that did not change

  Then the agent must:

  1. inspect `git diff -- <file>` for each unexpected file,
  2. decide which hunks to keep (usually none — the wrapper contract
     was declared for a reason),
  3. revert the out-of-scope files (`git checkout -- <file>` or
     `git restore <file>`),
  4. if the failure was `missing_required_changes`, issue a narrower retry
     that explicitly fixes the missing path,
  5. keep the in-scope files as-is or, if the change is no longer
     correct without the rejected hunks, reset the whole edit.

Do not use destructive reset commands unless the working tree was clean
or the changes were checkpointed. Do not ask the subagent to "fix
everything."

## Retry budget

There is no fixed retry count. Each retry must change exactly one
variable from the previous call: the prompt, the target file, the
timeout, or the precondition. If none of those changes, stop and
re-plan before calling the wrapper again.
