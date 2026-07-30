# Writing Quiz Questions

How to select decisions and write questions and distractors that find real misalignment.

## Select Decisions to Quiz

- Target decisions where the user corrected the agent during the session. Those are where misalignment hides.
- Target decisions with non-obvious consequences (e.g., "X implies Y").
- Target decisions that overturn a prior design or a common default.
- Skip decisions that merely record a fact or an obvious preference.
- Aim for 6–10 questions. Fewer for small sessions; more for large ones.

## Write the Question

- State the question as a concrete scenario, not an abstract definition.
- Test the consequence or the boundary, not the label.
  - Bad: "What is the state called?" (tests the label)
  - Good: "The agent finds unresolved questions and sets `needs_review`. What does this mean?" (tests the consequence)

## Write the Options

- One correct answer.
- 2–3 distractors.
- Each distractor is a plausible misconception — the wrong way someone might interpret the decision.
- Common misconception patterns to use as distractors:
  - **The opposite** of the decision (e.g., "the agent gates handoff" when the decision is "advisory").
  - **A common default** the decision overturns (e.g., "auto-repair everything" when the decision is "repair only structural breaks").
  - **An over-generalization** (e.g., "skip any skill" when the decision is "skip only structural skills").
  - **A confusion with a related concept** (e.g., "call core skills directly" when the decision is "re-enter via update mode").

## After Scoring

- For an incorrect answer, always explain the correct answer with a reference to the decision ID (e.g., "see D1/D3").
- Ask "slip or real disagreement?" — do not assume either.
- If a real disagreement surfaces, revisit that decision in the session before continuing the quiz or finalizing.
