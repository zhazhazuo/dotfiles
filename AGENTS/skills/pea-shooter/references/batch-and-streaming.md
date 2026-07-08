# Batch editing and streaming

Two patterns the agent may need when one edit is not enough. Both are
load-on-demand; if the agent is making a single focused edit, this
file can be skipped.

## Batch editing

The agent picks the file list first, then calls the wrapper once per
file (or once per tightly-related group). The wrapper does not batch
internally; each call is a self-contained terminal-status cycle.

```bash
for file in "$@"; do
  ./peashooter.sh \
    "$file" \
    "Add missing JSDoc comments for exported functions. Do not change runtime behaviour."
done
```

For repository-wide operations, generate the file list with the
agent's normal tools first. A `find` is fine, but the agent must
verify the list before the loop runs:

```bash
find src -name "*.ts" -print0 | while IFS= read -r -d '' file; do
  ./peashooter.sh \
    "$file" \
    "Convert eligible var declarations to const or let. Do not change behaviour."
done
```

Rules for batch runs:

- One narrow instruction, reused across files, is fine. The agent
  should expect each call to take seconds to a few minutes; long
  batch runs should set `AGENT_TIMEOUT_SECONDS` per environment.
- The agent must inspect each report before issuing the next call. A
  `validation_failed` or `project_validation_failed` mid-batch means the loop
  must stop and the failure must be triaged — not retried blindly.
- Different files usually need different instructions. Reusing the
  same instruction across files with different shapes is the
  leading cause of `validation_failed` reports.
- When one logical change spans several files, prefer one bounded
  multi-file call with explicit `--allow` / `--create` / `--delete`
  flags over a loop of partially coupled single-file edits.

Prefer multiple narrow wrapper calls over one broad instruction.

## Streaming

The wrapper prints a compact JSON report and exits. The agent does
not need streaming for normal edits.

Streaming is only relevant when the wrapper itself needs progress
monitoring, heartbeats, or timeout logic. That code lives inside the
wrapper; the agent does not change to enable it.

For long-running calls, inspect the status sidecar at
`.agent-runs/<run-id>.status.json` before opening the full log. The sidecar is
the wrapper's lifecycle summary and includes wrapper-observable phase,
heartbeat timestamps, elapsed time, timeout budget, and lock state.

If a future version of the wrapper exposes streamed output, the
invocation will look like:

```bash
agent -p --force \
  --output-format stream-json \
  --stream-partial-output \
  "Edit src/parser.ts only. Split parseInput into smaller helpers while preserving behaviour."
```

The agent should not consume every streamed message. The wrapper
summarises progress internally and returns the same compact final
report plus the status sidecar. Streaming is for the wrapper's
bookkeeping, not for the agent's.

The sidecar reports only states the wrapper can directly observe, such as
`starting`, `acquiring_lock`, `agent_running`, `validating_wrapper`,
`validating_project`, and `completed`. It does not guess at subagent-internal
states such as "planning" or "editing".

## Concurrency

The wrapper is single-flight. The lock file at
`.agent-runs/edit.lock` stores structured owner metadata and blocks a second
wrapper run while the first is in progress. If the agent needs two edits in
parallel, the correct move is two wrapper calls, sequentially, not two
concurrently — the boundary check assumes one edit at a time.
