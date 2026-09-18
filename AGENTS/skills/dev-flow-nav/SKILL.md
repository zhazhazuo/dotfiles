---
name: dev-flow-nav
description: Use when the task involves brainstorming a new feature or idea before building, writing or executing an implementation plan, running subagent-driven or parallel-agent development, isolating work in a git worktree, finishing or merging a development branch, or reviewing a plan or idea against the before-you-build build gates.
---

# Dev flow skills router

Expand `~` to the home directory. Pick one row. Read that file with the read tool, then follow it.

| Task | Skill | File |
|---|---|---|
| New feature or component before building | brainstorming | `~/.pi/agent/git/github.com/obra/superpowers/skills/brainstorming/SKILL.md` |
| Have a spec or requirements for a multi-step task, before touching code | writing-plans | `~/.pi/agent/git/github.com/obra/superpowers/skills/writing-plans/SKILL.md` |
| Have a written implementation plan to execute in a separate session with review checkpoints | executing-plans | `~/.pi/agent/git/github.com/obra/superpowers/skills/executing-plans/SKILL.md` |
| Execute a plan with independent tasks in the current session (implementer + reviewer per task) | subagent-driven-development | `~/.pi/agent/git/github.com/obra/superpowers/skills/subagent-driven-development/SKILL.md` |
| Facing 2+ independent tasks without shared state or sequential dependencies | dispatching-parallel-agents | `~/.pi/agent/git/github.com/obra/superpowers/skills/dispatching-parallel-agents/SKILL.md` |
| Feature work needs isolation from current workspace, or before executing implementation plans | using-git-worktrees | `~/.pi/agent/git/github.com/obra/superpowers/skills/using-git-worktrees/SKILL.md` |
| Implementation complete, tests pass, deciding how to integrate the work | finishing-a-development-branch | `~/.pi/agent/git/github.com/obra/superpowers/skills/finishing-a-development-branch/SKILL.md` |
| Review a plan or idea against the before-you-build build gates before building | before-you-build | `~/.agents/skills/before-you-build/SKILL.md` |

## Notes

- These skills are package-owned (`git:github.com/obra/superpowers`) and silenced via `disable-model-invocation: true` in their frontmatter. A package update wipes that patch; the `skill-guard` extension re-applies it at session start, before pi scans skills. Packages are silent by default, so no whitelist entry is needed — `skillGuard.keepVisible` in `~/.pi/agent/settings.json` lists the exceptions. Run `/skill-guard` to re-check on demand.
- `using-superpowers` from the same package is the package's own bootstrap and is unrouted by design; the navigator system in `AGENTS.md` owns routing.
- The package's bootstrap extension is not loaded (settings `extensions: []`) — it injects session-wide routing guidance that duplicates this navigator.
