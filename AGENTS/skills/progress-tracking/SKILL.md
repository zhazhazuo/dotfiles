---
name: progress-tracking
description: The progress-file schema and procedure for session-to-session state transfer under ./.ai-artifacts/progress/. Invoked by the /seal command, and by ops-nav routing when a work unit must be recorded, updated, or archived. Do not use for chronological logging, debugging journals, or anything recoverable from git log.
disable-model-invocation: true
---

## First Principle

**A progress file is a state transfer mechanism, not a log.**

Git commits provide history — what changed, when, why at commit level. Progress files
provide understanding — why decisions were made, what is blocking, what comes next.
The two are complementary; a progress file must never duplicate `git log`.

## How this skill reaches you

Two paths, both mechanical:

- **`/seal`** dispatches this skill, then `distill-context`. This is the only way it
  is invoked — it declares `disable-model-invocation: true`, so you cannot call it
  yourself.
- **The injected `<progress-state>` block** states the canonical section names and
  asks you to keep the active file current when the state changes. That block is
  present on every model call; this file is not.

There is no `AGENTS.md` trigger line. An instruction the model skips 59% of the time
is a mechanism problem, and the mechanism now exists.

## Layout

```
./.ai-artifacts/progress/
  INDEX.md              # central registry — the first thing the reader resolves
  <work-unit>.md        # one state document per unit of work
```

Naming: kebab-case, no `progress-` prefix, self-documenting, max 50 chars.
`verify-mark.md`, not `feature.md`.

## INDEX.md Format

Pipe-delimited, machine-parseable, no alignment or borders:

```markdown
# Progress Index
# Format: <status> | <file> | <branches> | <summary>
# Status: active | completed | archived

active | verify-mark | main | CLI mark + mandatory SUGGEST
archived | npm-install-troubleshooting | main | Registry 404 + ENOTDIR fix
```

- `status`: `active` | `completed` | `archived`
- `file`: filename without `.md`
- `branches`: comma-separated git branches where the work is relevant; optional,
  updated when you notice a branch for that work — there is no automatic matching
- `summary`: one line, max 80 chars

A comment-only INDEX is valid and means no work is tracked. That is what the first
seal writes in a repository that has never used progress tracking.

## Progress File Format

Exactly these nine sections. The heading name **is** the schema.

```markdown
# <work-unit>

## Status
active | completed | archived

## Objective
What this unit of work is for. One or two lines.

## State
Where the work stands right now. Prefer bullets. Rewrite it; never append.

## Decisions
- Decision: the final state, not the history of reaching it

## Constraints
- What cannot be done, and what fixes it

## Assumptions
- What is taken as true and has not been verified

## Open Questions
- What the USER must answer (blockers)

## Next
- What the AGENT does next

## Context
History, reasoning, rejected options, pointers. Never injected — this is where detail
lives so the rest of the file stays small.
```

- **Open Questions** = what the user must answer. **Next** = what the agent does next.
  Never merge them — different consumers.
- **State** vs **Context**: `State` is the current position, readable in seconds.
  Everything explaining how it was reached belongs in `Context`.
- Keep the sections in this order. The reader emits them in tier order regardless, but
  a file that matches the schema reads correctly in a plain diff.
- No Commits section. If a decision hinges on a commit, reference its hash inline under
  `Decisions`.

## What the reader sees

The `state-handoff` extension injects this state into the next session's context as a
`<progress-state>` message at the head of the conversation, on every model call. It
injects **Tier 1 only**, under a hard cap.

| Tier | Sections | Injected |
|---|---|---|
| 1 | Status, Objective, State, Open Questions, Next | Always, capped at 400 tokens per file and 1,200 total |
| 2 | Decisions, Constraints, Assumptions | Only if the budget allows |
| 3 | Context | **Never** — a pointer is injected instead |

Two consequences for whoever writes the file:

- A file whose **Tier 1** exceeds 400 tokens is replaced by a SKIPPED pointer and a
  distillation warning. Put history and reasoning in `Context`, where it costs the
  block nothing.
- Anything the next session must act on **without opening the file** belongs in
  Tier 1. Tier 2 is a bonus; Tier 3 is a promise that someone will read the file.

The reading half is no longer your job. Previously a session-start instruction told
the agent to open this file and the progress directory; a session that ignored it
re-derived everything by reading source. The extension now puts the state in context
directly, and the block tells the reader to orient from it rather than re-read the
files it summarises.

## Legacy headings

Older files use other names. The reader resolves them, so nothing breaks:

```text
Current State      -> State
Key Decisions      -> Decisions
Current Decisions  -> Decisions
Execution Context  -> Context
Next Steps         -> Next
```

Matching is exact, then by synonym, then by **prefix against canonical names and
synonym keys, longest first** — a real file carried
`## Current State (2026-09-17 — PR #20 integration hardening)`, which exact matching
reported as unmapped and dropped live state from the block.

A heading that maps to nothing is preserved in the file and **named in the injected
block's footer**, so schema drift is visible rather than silent. Rename legacy
headings to the canonical name when you touch the file.

## Lifecycle

| State | When | Action |
|---|---|---|
| `active` | Work in progress | In INDEX; injected on every session start |
| `completed` | Spec done, tests pass | Final update; mark `completed` in INDEX |
| `archived` | Abandoned or superseded | Final update with reason (and successor file if superseded); mark `archived` in INDEX |

A `completed` or `archived` row is never injected. The file stays on disk as the
record of what happened.

## Update Discipline

Update the progress file after:

- A decision not in the spec
- A plan change or deviation
- A discovery that affects scope or direction
- A session boundary with work ongoing

Do NOT update after:

- Routine commands
- Temporary debugging
- Anything obvious from `git log`

**Keep State current: rewrite it to reflect now; do not append chronologically.**

Two failure modes to avoid, both observed:

- **Superseded options left in place.** The reader cannot tell which decision is
  live. Convert history into current state: `Decision: B`, not "we switched from A
  to B because".
- **Tier 1 swollen with reasoning.** The file is then replaced by a pointer and the
  next session gets less, not more. Move the reasoning to `Context`.
