# herdr-source

## Status
active

## Current State
- Spec: agent-monitor/docs/superpowers/specs/2026-07-28-herdr-agent-monitor-design.md (committed)
- Plan: agent-monitor/docs/superpowers/plans/2026-07-28-herdr-agent-monitor.md (committed, 7 tasks)
- Execution: subagent-driven (pea-shooter implementer + pi reviewer), on main, BASE=835d23b
- Ledger: .superpowers/sdd/2026-07-28-herdr-agent-monitor/progress.md
- No task started yet.

## Key Decisions
- Herdr is source of truth for agents inside herdr; agents run only in herdr (no tmux dedup).
- Label = herdr tab label; click = `herdr agent focus <pane_id>`.
- Herdr plugin event hooks (approach A) over polling or socket daemon.
- Planning discovery: refresh_sinks never wrote state.tsv in production and `agent-monitor remove` did not refresh sinks — plan Task 2 repairs both.
- Work on main with explicit user consent (live dotfiles; worktree would break symlink paths).

## Open Questions
- None.

## Next
- Execute plan Tasks 1-7 in order; per task: peashooter run → controller commit → review package → pi reviewer → fix loop if needed.
