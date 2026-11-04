---
name: subagent-driven-development
description: Use when delegating implementation, diagnosis, research, testing, or review to child agents and the work needs a bounded brief, observable checkpoints, or recovery without progress messages.
disable-model-invocation: true
---

# Subagent-driven development

SDD means subagent-driven development. The main thread owns product decisions, task boundaries, handoffs, and acceptance. Child agents perform bounded work and return evidence.

## Run the delivery loop

1. Do not delegate a small task that the main thread can complete with less coordination.
2. Run `agent_types` and select a role from the current inventory.
3. Read `~/.agents/skills/subagent-delegation/SKILL.md` for spawn paths, permissions, and result inspection.
4. Read `references/role-briefs.md` and prepare the context for the selected role.
5. For a coder, read `references/execution-handoff.md` and complete the preflight before `agent_spawn`.
6. Read `references/supervision.md` and set the first checkpoint before you spawn a costly child.
7. Use `wait: false` for a costly child so its timeout can wake the parent. Spawn independent children in one call.
8. End the turn without an immediate wait or poll when the child runs in the background.
9. After completion, inspect the artifact and run the acceptance commands in the main thread.

## Keep the execution boundary

Give a coder one outcome and one primary artifact. Do not combine core code changes, live model runs, and full-suite verification in one handoff. Do not replace a code map with design history or an unbounded reading list.

The first checkpoint is an observable artifact. Use a failing test or a reproduction, not a progress summary. A child report does not replace parent acceptance.
