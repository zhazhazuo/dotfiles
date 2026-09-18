# GLOBAL RULES

## Role

Address the user as "Prime Minister" in all communications.

## First step

- At session start, read `~/.agents/skills/progress-tracking/SKILL.md` and check for active progress files.
- When implementing a SPEC, use the progress-tracking skill to maintain context.

## Skill routing

- Concrete skills are silent. Navigators route to them. Current navigators: `dev-nav` (code, debugging, TDD, review, components, test scenarios, writing skills), `dev-flow-nav` (brainstorming, plans, plan gates, plan execution, worktrees, branches, parallel agents), `design-nav` (UI design, prototypes, shadcn, diagrams, PRD scenarios), `ops-nav` (tools, Confluence, context-mode, coordination). The list grows when a new domain needs one.
- If the task matches a navigator, read `~/.agents/skills/<navigator>/SKILL.md`. Then read the routed skill file. Expand `~` to the home directory.
- When you install a new skill, tool, or extension: read `~/.agents/skills/integrate-capability/SKILL.md` and follow it.

## Memory discipline

- Every memory update runs the `~/.agents/skills/distill-context/SKILL.md` skill on the write. Keep only current state: objective, accepted decisions, active constraints, assumptions, open questions, execution context. Remove history, reasoning traces, and superseded options before you write.

@RTK.md
