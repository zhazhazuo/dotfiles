---
name: dev-flow-nav
description: Use when the task involves spawning or delegating to a child agent in pi, running subagent-driven or parallel-agent development, or authoring or gating a one-pager against the three build gates before building.
---

# Dev flow skills router

Expand `~` to the home directory. Pick one row. Read that file with the read tool, then follow it.

| Task | Skill | File |
|---|---|---|
| Any `agent_spawn`: pick the spawn path, prove the child's context, read the type's allow list, and inspect the result | subagent-delegation | `~/.agents/skills/subagent-delegation/SKILL.md` |
| Delegate bounded implementation, diagnosis, research, testing, or review with role context, a coder handoff, or supervision without progress messages | subagent-driven-development | `~/.agents/skills/subagent-driven-development/SKILL.md` |
| Author or gate a one-pager before building (three build gates) | one-pager-gate | `~/.agents/skills/one-pager-gate/SKILL.md` |

## Removed on 2026-10-28

The `git:github.com/obra/superpowers` package left this machine. Seven rows pointed into it, and
the package directory is gone:

| Lost skill | Moment that lost its route |
|---|---|
| `brainstorming` | a new feature or component, before building |
| `writing-plans` | a spec or requirements set for a multi-step task, before code |
| `executing-plans` | executing a written plan in a separate session with review checkpoints |
| `subagent-driven-development` | a plan with independent tasks, implementer plus reviewer per task |
| `dispatching-parallel-agents` | two or more independent tasks with no shared state |
| `using-git-worktrees` | isolating feature work from the current workspace |
| `finishing-a-development-branch` | deciding how to integrate work whose tests pass |

Subagent-driven development now routes to a local `subagent-driven-development` skill. Parallel
dispatch folds into `subagent-delegation`. The other five moments have no installed replacement:
pre-build design, plan writing, plan execution, worktree isolation, and branch finishing now run
from `AGENTS.md` and the operator's instruction alone.

`conformance-kit` and `grilling` are installed and cover parts of the design-before-build moment.
Neither is routed here: `ops-nav` owns `grilling`, and `conformance-kit` has no navigator row, so
`integrate-capability` decides where it belongs.

## Notes

- `using-superpowers` and the package's bootstrap extension are gone with the package. The
  navigator system in `AGENTS.md` owns routing.
- Every routed path was verified to exist on 2026-10-28. If one is missing, re-resolve before
  routing around it, and correct this table in the same session.
