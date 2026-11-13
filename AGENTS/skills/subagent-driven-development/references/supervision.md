# Supervision without progress messages

Pull-based supervision means the parent inspects evidence at bounded events. It preserves a clean parent context without making the child invisible until completion.

Use report-only timeouts for every costly child, whether or not `agent_update` is enabled. When it is disabled, use filesystem evidence at those events. Do not enable progress messages to compensate for an unbounded brief. Do not require early progress logs.

## Set the detection boundary

Set `timeoutMs` to the first inspection interval when you call `agent_spawn`. Use 120000 ms for a small mapped
test edit and its failing run. Use 300000 ms for a coder with stated setup or orientation. Do not set `timeoutMs`
above 300000 ms. These values are inspection intervals, not deadlines. The timeout reports status and does not
stop the child.

Use `wait: false` for a background child, including a single coder. Spawn each independent child with
`wait: false`. Do not call `agent_wait` or poll immediately. End the turn and let the completion or timeout event
wake the parent.

Evidence falls into three classes:

- Liveness evidence comes from state, recent output, and turn or token growth. It shows activity, not progress.
- Progress evidence includes a reproduction, a failing test, a scoped diff, citations, or a command result.
- Acceptance evidence comes from parent inspection and gate output. A child report does not replace it.

Turn growth is not progress. A progress log is not progress. Researchers and reviewers need no file artifact.
Use their citations, findings, and unresolved questions as progress evidence.

## Respond to a timeout

Use the timeout event's elapsed time, token count, and recent output. Use `agent_status` for live state and
recent output. Reserve `agent_output` for completed children. Inspect the named evidence or scoped worktree diff
when the event leaves progress unclear.

Non-root agents address only their descendants. `/root` can inspect every tree.

If liveness evidence shows an active child within contract, re-arm `agent_steer` with only `timeoutMs`. Set the
next inspection interval. End the turn.

If you observe a named deviation, correct it immediately with `agent_steer`. Name the observed deviation and the
required correction. This rule applies before the first write and before the first timeout.

Stop the child for wrong scope, a blocked decision, repeated inactivity after correction, or explicit cancellation.
Token growth alone is not a reason to stop the child. Revise the map or split the mission when the contract blocks
progress.

After a stop, inspect the disk before you resume or replace the child. Edits remain on disk, and the session
remains available.
Resume the retained session when its context remains focused. Use `agent_steer` for review corrections and
related follow-up. This reuses the child's accumulated context and avoids a second orientation. Use a fresh child
when the retained session contains a long irrelevant reading history. Give the fresh child the corrected contract,
not the old transcript. Do not resume a child for unrelated work only to avoid fresh input.

## Recover from wrong work

Do not send generic encouragement or a request for more exploration. Do not wait for a timeout when you can
name a deviation. Stop the child when the correction changes a locked decision or expands the mission.

If the contract caused the deviation, fix the contract in the parent. Record a new revision and identify it during the resume or respawn.

## Accept the result

After completion, collect the final answer with `agent_output`. For file work, inspect the changed paths. Run the
acceptance commands in the main thread. Record the collection, path inspection, and gate output. Compare test
counts with the baseline. Read every deviation against the mission.

Give a fresh reviewer the contract revision, baseline, scoped diff, and command evidence. Do not ask the reviewer to reconstruct the design history. Live model runs and broad suites remain separate gates when the contract excludes them.
