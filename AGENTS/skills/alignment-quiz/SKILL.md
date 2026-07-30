---
name: alignment-quiz
description: Use when a design or brainstorming session has produced a set of decisions and you need to verify the agent and the user are aligned before finalizing a document or transitioning to implementation.
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
3. **Write multiple-choice questions.** One question per targeted decision. Each has 3–4 options. Distractors must reflect common misconceptions, not random wrong answers.
4. **Present the quiz.** Number the questions. List the options. Ask the user to answer (e.g., `1B, 2C, ...`).
5. **Score the answers.** For each question: mark correct or incorrect.
6. **Handle mismatches.** For each incorrect answer: state the correct answer, reference the decision ID, and explain why. Then ask: was this a slip, or a real disagreement? A slip → confirm alignment. A real disagreement → stop and revisit that decision before continuing.
7. **Report alignment.** State the final score (X/N aligned) and list any open mismatches. Do not finalize or implement while a real disagreement remains.

## Progressive Disclosure

- This root file routes the skill.
- `references/writing-quiz-questions.md` holds the detailed guidance on selecting decisions and writing questions and distractors. Load it at step 2.

## Constraints

- Target subtle decisions, not obvious ones.
- Distractors = misconceptions, never random.
- A mismatch is a signal, not a failure. Never use it to judge the user; use it to find gaps.
- Reference every answer to its decision ID.
- Do not finalize or implement while a real disagreement is unresolved.
- Do not record the quiz result unless the user asks.
