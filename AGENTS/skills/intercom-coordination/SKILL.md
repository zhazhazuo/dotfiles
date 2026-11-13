---
name: intercom-coordination
disable-model-invocation: true
description: Use when this session must message, ask, or hand work to another local pi session with the intercom tool, when `/peer` names a target, or when an inbound peer message needs a reply.
---

# Peer coordination

Message another pi session on this machine with the `intercom` tool. `/peer <session> <task>` puts
the target and the task into this session. The rules below choose the action and shape the message.

API detail, delivery receipts, config, and extension channels are in the skill that ships with the
package: `~/.pi/agent/npm/node_modules/pi-intercom/skills/pi-intercom/SKILL.md`. Read it when the
call is not covered here. That file matches the installed version.

## Choose the action

| Action | Cost | Use |
|---|---|---|
| `send` | Returns after delivery | A task, a finding, or a notification. The default. |
| `ask` | Blocks until the reply, 10 minutes by default | The answer decides the next step. |
| `reply` | Returns after delivery | An inbound message needs an answer. |
| `pending` | Returns at once | Several inbound asks wait, and the target is unclear. |
| `handover` | One model call to summarize this session | The work moves to another session. |
| `cancel` | Returns at once | A message already sent must be withdrawn. |

## Find the target

- Run `intercom({ action: "list" })` when a name was read earlier and may have changed.
- `ask` needs a connected session. `send` reaches a recently disconnected named session through the
  broker mailbox.
- Name this session with `/alias <name>` so peers can address it. The name persists with the session.

## Write the message

- State the task, the files to read, the current state, and what a reply must contain.
- Put one task in one message. Send a second message for a second task.
- Name the outcome: "Confirm the field name in src/api/types.ts", not "thoughts?".
- Add `attachments` with `type: "snippet"` or `type: "file"` when the peer would otherwise guess.
  The attachment content reaches the agent.

## Answer a peer

- An inbound message renders with a reply hint. In the triggered turn, call
  `intercom({ action: "reply", message })`. It targets that sender and message automatically.
- A later reply falls back to the single unresolved inbound ask. With several, run
  `intercom({ action: "pending" })` and pass `to`.
- A `send` made while exactly one inbound ask is pending is treated as that ask's answer.

## Read a failure

- `send` reports success only after the receiver confirms within 5 seconds. Otherwise delivery is
  `unknown` and `retryable`. The message can still arrive. Do not resend at once.
- `ask` fails immediately for a disconnected target, and times out after 10 minutes. Set
  `PI_INTERCOM_ASK_TIMEOUT_MS` to change the limit.
- No retry is automatic. A retry is a new authored message, optionally linked with `retryOf`. To
  replace a held message, pass `supersedes` with the old message ID.
- `intercom({ action: "cancel", messageId })` drops a held message. An injected message keeps
  running and reports `cancellation_requested`.
- One outbound `ask` at a time. A second one is refused.

## Move the work

- `intercom({ action: "handover", to, message })` summarizes this session with the current model
  and sends the summary plus the next task. The receiver is told to check the claims against the
  repository.
- Handover rejects `attachments`, `replyTo`, `supersedes`, and `retryOf`.

## Child sessions

- A pi-subagents child that received bridge metadata gets `contact_supervisor` instead of free
  choice. `need_decision` and `interview_request` block. `progress_update` does not.
- The supervisor answers with `intercom({ action: "reply" })`. For an interview, the answer is JSON
  in the shape `{ "responses": [{ "id": "...", "value": ... }] }`.
