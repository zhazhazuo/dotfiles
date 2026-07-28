# herdr-source

## Status
active

## Current State
- All 7 plan tasks complete and individually reviewed clean (commits 835d23b..ff9df41).
- Final whole-branch review package ready: .superpowers/sdd/2026-07-28-herdr-agent-monitor/review-835d23b..ff9df41.diff
- Live herdr plugin linked as `local.agent-monitor` (enabled, no warnings).
- Manual verification: `agent-monitor state` mirrors `herdr api snapshot` agents; tab labels render; SketchyBar sink exports `state.tsv`.
- Tests pass: `reconcile`, `prune`, `herdr-adapter`, `sketchybar/agent-monitor`.

## Key Decisions
- Herdr is source of truth for agents inside herdr; agents run only in herdr (no tmux dedup).
- Label = herdr tab label; click = `herdr agent focus <pane_id>`.
- Herdr plugin event hooks (approach A) over polling or socket daemon.
- `refresh_sinks` moved to `core/state.sh`, exports `state.tsv` atomically, and is called by `reconcile`, `remove`, `clear`, and `sync`.
- Work on `main` with explicit user consent (live dotfiles; worktree would break symlink paths).

## Open Questions
- None.

## Next
- Final whole-branch review and triage of deferred minors.
- If review is clean, finish with superpowers:finishing-a-development-branch.
