# Supervision without progress messages

Pull-based supervision means the parent inspects evidence at bounded events. It preserves a clean parent context without making the child invisible until completion.

Use report-only timeouts for every costly child, whether or not `agent_update` is enabled. When it is disabled, use filesystem evidence at those events. Do not enable progress messages to compensate for an unbounded brief.

## Set the detection boundary

Set `timeoutMs` to the first checkpoint budget when you call `agent_spawn`. This budget covers the first test edit and its failing run. Use 120000 ms for a small mapped test edit. Set a different budget when the first test needs a stated setup step. The timeout reports status and does not stop the child.

Use `wait: false` for a costly child, including a single coder. Do not call `agent_wait` immediately. End the turn and let the completion or timeout event wake the parent.

Each checkpoint needs an observable artifact. Use a new failing test, a reproduction log, a scoped diff, a command result, or a named output file. Elapsed time and token counts are diagnostic signals, not artifacts.

## Respond to a timeout

Use the timeout event's elapsed time, token count, and recent output. Inspect the named artifact or scoped worktree diff when the event leaves progress unclear.

If the artifact exists and the child follows the contract, re-arm `agent_steer` with only `timeoutMs`. Set it to the next checkpoint budget and end the turn.

If no artifact exists, send one bounded correction with `agent_steer`. Name the first test, first edit, and forbidden reads. Ask for the exact map contradiction when the child cannot start. Re-arm the first checkpoint once.

If the next deadline still has no artifact, stop the child. Treat token growth without an artifact as a contract failure. Revise the map or split the mission before more implementation spending.

Resume the retained session when its context remains focused. Use a fresh child when the retained session contains a long irrelevant reading history. Give the fresh child the corrected contract, not the old transcript.

## Recover from wrong work

Name the observed deviation and the required correction. Do not send generic encouragement or a request for more exploration. Stop the child when the correction changes a locked decision or expands the mission.

If the contract caused the deviation, fix the contract in the parent. Record a new revision and identify it during the resume or respawn.

## Accept the result

Inspect changed paths and run the acceptance commands in the main thread. Compare test counts with the baseline. Read every deviation against the mission.

Give a fresh reviewer the contract revision, baseline, scoped diff, and command evidence. Do not ask the reviewer to reconstruct the design history. Live model runs and broad suites remain separate gates when the contract excludes them.
