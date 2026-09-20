---
name: progress-tracking
description: Maintain session-to-session state transfer for spec implementation work via progress state documents under ./.ai-artifacts/progress/. Use when implementing a SPEC, at session start before any planning or implementation, when the user references prior work without specifying current state, when recording a decision not in the spec, or when completing or archiving a work unit. Do not use for chronological logging, debugging journals, or anything recoverable from git log.
disable-model-invocation: true
---

## First Principle

**A progress file is a state transfer mechanism, not a log.**

Git commits provide history — what changed, when, why at commit level. Progress files provide understanding — why decisions were made, what is blocking, what comes next. The two are complementary; a progress file must never duplicate `git log`.

## Layout

```
./.ai-artifacts/progress/
  INDEX.md              # central registry — always read first
  <work-unit>.md        # one state document per unit of work
```

Naming: kebab-case, no `progress-` prefix, self-documenting, max 50 chars. `verify-mark.md`, not `feature.md`.

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
- `branches`: comma-separated git branches where the work is relevant; optional, updated when the agent notices a branch for that work — no automatic matching
- `summary`: one line, max 80 chars

## Progress File Format

Exactly five sections:

```markdown
# <work-unit>

## Status
active | completed | archived

## Current State
Free-form, prefer bullets. Where the work stands right now.

## Key Decisions
- Decision: rationale

## Open Questions
- What the USER must answer (blockers)

## Next
- What the AGENT does next
```

- **Open Questions** = what the user must answer. **Next** = what the agent does next. Never merge them — different consumers.
- No Commits section. If a decision hinges on a specific commit, reference its hash inline under Key Decisions.

## Lifecycle

| State | When | Action |
|---|---|---|
| `active` | Work in progress | In INDEX; read on session start |
| `completed` | Spec done, tests pass | Final update; mark `completed` in INDEX |
| `archived` | Abandoned or superseded | Final update with reason (and successor file if superseded); mark `archived` in INDEX |

## Session Restore Procedure

Trigger: session start, or user references prior work without current state.

1. `git branch --show-current`
2. Read `./.ai-artifacts/progress/INDEX.md` (if absent, no progress state exists — proceed without it)
3. Read only `active` files relevant to the current work
4. Summarize key decisions, open questions, and next steps before planning or implementing

Target: under 500 tokens for a typical project (2–3 active files).

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

Keep Current State current: rewrite it to reflect *now*; do not append chronologically.

## AGENTS.md Contract

AGENTS.md holds trigger lines only; this skill is the single source of truth for format, naming, lifecycle, and procedure:

```markdown
**IMPLEMENT MODE REQUIREMENTS**
- When implementing a <SPEC>, use the progress-tracking skill to maintain context.
- At session start, check for active progress files per the progress-tracking skill.
```
