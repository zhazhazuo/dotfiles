# herdr-source

## Status
completed

## Current State
- All 7 plan tasks completed and individually reviewed clean (commits 835d23b..5f2b475).
- Final whole-branch review and re-review clean; one final review fix applied (tolerate invalid/non-JSON herdr snapshot).
- All 4 test suites pass: reconcile, prune, herdr-adapter, sketchybar/agent-monitor.
- Live herdr plugin `local.agent-monitor` linked (enabled, no warnings); state mirrors snapshot.
- Pre-existing unrelated dirty files/deletions in dotfiles repo remain untouched.

## Key Decisions
- Herdr is source of truth for agents inside herdr; agents run only in herdr (no tmux dedup).
- Label = herdr tab label; click = `herdr agent focus <pane_id>`.
- Herdr plugin event hooks (approach A) over polling or socket daemon.
- `refresh_sinks` moved to `core/state.sh`, exports `state.tsv` atomically, and is called by `reconcile`, `remove`, `clear`, and `sync`.
- Work on `main` with explicit user consent (live dotfiles; worktree would break symlink paths).

## Open Questions
- None.

## Next
- Integration decision by user (merge/push/keep as-is).
- Update ledger and delete SDD workspace after integration.
