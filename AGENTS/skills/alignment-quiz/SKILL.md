---
name: alignment-quiz
description: Use when a design or brainstorming session has produced a set of decisions and you need to verify the agent and the user are aligned before finalizing a document or transitioning to implementation.
disable-model-invocation: true
---

# Alignment Quiz

## Purpose

Verify that the agent and the user agree on a set of decisions before finalizing or implementing them. A mismatch caught now costs less than a mismatch caught after implementation.

## When to Use

- After a brainstorming or design session where decisions were made.
- Before finalizing a design doc, spec, or roadmap.
- Before transitioning from design to implementation (a gate).
- When the user asks to "quiz", "verify alignment", or "make sure we agree".

## Process

1. **Read the decisions.** Load the decision log, design doc, or the decisions from the session. Note each decision's stable ID if it has one.
2. **Select the subtle decisions.** Target the non-obvious decisions — especially where the user corrected the agent during the session. Skip obvious or trivial decisions. Aim for 6–10 questions. Read `references/writing-quiz-questions.md`.
3. **Write multiple-choice questions.** One question per targeted decision. Each has 3–4 options. Distractors must reflect common misconceptions, not random wrong answers. Keep each option a short label plus a one-line description so it fits the question tool's limits.
4. **Present the quiz with the question tool.** Use the structured question tool (for example `ask_user_question`) instead of plain text:
   - Batch up to 4 questions per call. Run multiple rounds until all questions are asked. Keep a running question number across rounds.
   - One decision per question. Use the `header` field for the decision ID or a short topic tag (max 16 characters).
   - Do NOT mark the correct answer as recommended, and do NOT always place it first. Shuffle the correct answer's position across questions. The quiz measures the user's understanding, so no option may hint at it.
   - Keep every question and option at the idea and consequence level. No file names, symbol names, or code-level details unless the decision itself is a code-level one. Implementation details belong in the implementation plan, not in an alignment check.
   - Fallback: if the question tool is unavailable or the user prefers plain text, present numbered questions and ask for answers in the form `1B, 2C, ...`.
5. **Score the answers.** Read the tool's structured answers. A custom text answer instead of an option is valid feedback — treat it as a mismatch to discuss, or as a correction to the quiz itself.
6. **Handle mismatches.** For each incorrect answer: state the correct answer, reference the decision ID, and explain why. Then ask: was this a slip, or a real disagreement? A slip → confirm alignment. A real disagreement → stop and revisit that decision before continuing.
7. **Report alignment.** State the final score (X/N aligned) and list any open mismatches. Do not finalize or implement while a real disagreement remains.

## Progressive Disclosure

- This root file routes the skill.
- `references/writing-quiz-questions.md` holds the detailed guidance on selecting decisions and writing questions and distractors. Load it at step 2.

## Constraints

- Target subtle decisions, not obvious ones.
- Distractors = misconceptions, never random.
- Question tool batches cap at 4 questions each. Split larger quizzes into rounds.
- Never flag or reorder options to favor the correct answer.
- Idea-level questions only: consequences and boundaries, not code paths or identifiers.
- A mismatch is a signal, not a failure. Never use it to judge the user; use it to find gaps.
- Reference every answer to its decision ID.
- Do not finalize or implement while a real disagreement is unresolved.
- Do not record the quiz result unless the user asks.
