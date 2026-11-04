---
name: interview-me
description: Use when the user asks to be grilled or interviewed about a plan, design, decision, or idea and wants each question to arrive as selectable options. Runs the grilling method through the ask_user_question tool.
disable-model-invocation: true
---

# Interview me

Read `~/.agents/skills/grilling/SKILL.md` and follow it. It defines the design tree, the frontier, and the round. This skill changes one thing: each round reaches the user through the `ask_user_question` tool.

## Send a round

- Send one `ask_user_question` call per round. Do not send a second call to finish the same round.
- Send 1 to 4 questions. The tool rejects a fifth.
- Give each question 2 to 4 options. If only one real answer exists, the question is a fact, so look it up.
- Put the recommended option first and end its label with "(Recommended)".
- Keep a label to five words. Put the trade-off in that option's description.
- Add `preview` to a question whose options are code, a config block, or a layout to compare. A preview works on a single-select question only.
- Set `multiSelect: true` when two answers can stand together.
- Word the question so that a choice of the recommended option means acceptance.
- Do not write an "Other" row. The tool appends a "Type something." row for free text.
- Do not restate the questions in prose beside the call.

## Order the frontier

A round holds at most four questions. If the frontier is wider, ask the four with the most unsettled branches behind them and keep the rest for the next round. A question that waits on another answer belongs to a later round, never to an option in this one.

## Read the answer

- A chosen option is a settled decision. Write it down, then push the frontier outward.
- A typed answer is a new decision. Take it as given, then derive its branches.
- Esc closes the questionnaire without an answer. The user declined this round. Report the frontier that remains and stop asking.
- Ask one follow-up only when an answer leaves a branch undecided. That follow-up belongs to the next round.

## Find facts yourself

Finding a fact is your job, never the user's. When a question waits on a file, a command result, or a library behaviour, dispatch a subagent with a fresh context to find it. Ask the rest of the frontier now, and hold only the questions downstream of that fact.

## End the interview

The interview ends when the frontier is empty. State the settled decisions as one list, then wait for the user to confirm shared understanding. Start no work before that confirmation.
