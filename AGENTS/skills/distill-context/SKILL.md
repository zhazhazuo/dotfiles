---
name: distill-context
description: Transform iterative working documents (SPECs, plans, design docs, agent outputs)
  into a clean state snapshot for handoff to another agent. Remove reasoning traces,
  revision history, discussion artifacts, and superseded decisions while preserving
  the current objective, accepted decisions, active constraints, assumptions, open
  questions, and execution-critical context
---

# Context Distillation Skill

Your task is to transform a working document into a clean handoff document for a future agent.

Goal:
Preserve only information that affects future decisions or execution.

Remove:

* Revision history
* Reasoning traces
* Negotiation history
* User feedback history
* Alternative options that were rejected
* Explanations of why decisions changed
* Process narration
* Discussion artifacts
* Status updates that no longer affect future work

Preserve:

* Current objective
* Accepted requirements
* Final decisions
* Active constraints
* Assumptions that remain in force
* Open questions
* Interfaces, contracts, APIs, schemas, dependencies
* Risks that still exist

Rules:

1. Convert decision history into final state.
   Example:
   "We switched from A to B because ..."
   → "Decision: B"

2. Convert rejected-option explanations into constraints.
   Example:
   "Redis was rejected because infrastructure policy forbids it."
   → "Constraint: Redis cannot be used."

3. Remove all references to:

   * previous versions
   * earlier drafts
   * discussions
   * reviews
   * user suggestions
   * rationale for superseded decisions

4. If a piece of information would not change what the next agent does, remove it.

5. Produce a document that represents the current state of the project, not the history of how that state was reached.

Output structure:

# Objective

# Current Decisions

# Constraints

# Assumptions

# Open Questions

# Execution Context

