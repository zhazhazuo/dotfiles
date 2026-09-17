# subagent-indicator

## Status
active

## Current State
- New monitor state `subagents-running` (orange) distinguishes "main agent parked,
  background subagents still running" from `needs-attention` (blue).
- Implemented end to end for the herdr path: core mapping, herdr adapter
  detection, prune demotion, sketchybar + tmux sinks, README, tests.
- Verified live: `w3_p47` moved `idle` -> `subagents-running` with
  `subagents_count=1`, and the SketchyBar item rendered `<AI-Report>` in
  `0xffd29922`.
- All suites pass: agent-monitor (reconcile 16, herdr-adapter 29, prune 7) and
  sketchybar agent-monitor (7).

## Key Decisions
- Signal source is herdr pane display metadata (`state_labels`, fallback
  `tokens.summary`) published by pi-subagents; the adapter previously dropped it.
- Detection is event-driven: herdr emits `pane.agent_status_changed` on
  state-label changes even when `agent_status` is unchanged, and does so for the
  clear too, so leaving orange needs no poller. `pane.updated` is NOT a valid
  plugin hook event (`unknown event 'pane.updated'`), so token-only changes stay
  invisible to plugins — harmless because pi-subagents always sends labels too.
- Precedence: blocked -> needs-help, working -> running, else subagent count > 0
  -> subagents-running, done -> needs-attention, idle -> idle.
- Entering orange does not notify. Finishing the last subagent transitions to
  needs-attention and notifies — the deferred "your turn" ping.
- Staleness: `subagents_checked_at` heartbeat (refreshed by the 45s republish,
  without bumping `updated_at` so the sinks do not reshuffle); prune demotes an
  abandoned orange to needs-attention after `AGENT_MONITOR_SUBAGENT_STALE_SECONDS`
  (default 150).
- Scope is herdr only. The pi extension stays TMUX-gated: enabling it inside
  herdr would create a second writer for the same pane identity.
- tmux orange uses the theme's `@thm_peach`; orange deliberately does not decay.

## Open Questions
- None.

## Next
- Watch one real subagent run finish and confirm orange -> blue plus the
  notification fires on the label-clear event.
- Optional, not started: tmux parity via pi-subagents' `subagent:async-started` /
  `subagent:async-complete` event bus; `herdr integration install pi` (installed
  v8 is outdated vs v9) as a separate change.
