# Herdr Source for agent-monitor — Design

Date: 2026-07-28
Status: Approved (design)

## Purpose

Integrate herdr (terminal workspace manager for AI coding agents) into
agent-monitor as a new event source. Herdr becomes the source of truth for
agents that run inside herdr. Agents run only in herdr (no tmux), so no
deduplication against the tmux-based adapters is necessary; the existing
pi/codex/cursor adapters stay in place but dormant.

## Decisions (confirmed with user)

1. Herdr is the source of truth for agents inside herdr.
2. Agents run only in herdr — the tmux-based adapters stay silent.
3. The SketchyBar item label is the herdr **tab label** (fallback: cwd basename).
4. Click on a SketchyBar item runs `herdr agent focus <pane_id>`.

## Architecture

A new source adapter plus a small herdr plugin. Herdr pushes events;
agent-monitor core and sinks stay as they are.

```
herdr server ──plugin events──▶ herdr-plugin/on-event.sh
                                      │
                                      ▼
                          adapters/herdr.sh (normalize)
                                      │
                                      ▼
                    bin/agent-monitor reconcile herdr <Event> '<json>'
                                      │
                     ┌────────────────┼────────────────┐
                     ▼                ▼                ▼
              sinks/sketchybar   sinks/tmux       core/notify
```

The plugin lives at `agent-monitor/herdr-plugin/` and is registered with
`herdr plugin link <path>`. The link persists across herdr restarts via
herdr's `plugins.json` registry.

## State Mapping

The adapter maps herdr `agent_status` values to the existing generic events.
No core state-machine change is necessary.

| herdr status | generic event     | monitor state   | color |
|--------------|-------------------|-----------------|-------|
| `working`    | RunStart          | running         | green |
| `blocked`    | PermissionRequest | needs-help      | red   |
| `done`       | TurnComplete      | needs-attention | blue  |
| `idle`       | SessionStart      | idle            | gray  |
| `unknown`    | — (ignored)       | —               | —     |

- `pane.closed` → `agent-monitor remove <id>`.
- `pane.agent_detected` → reconcile with the pane's current status.
- `pane.agent_status_changed` → reconcile with the new status.

## Identity and Labels

- Identity: the herdr `pane_id` (e.g. `w2:p4`), sanitized to `w2_p4` for use
  as the state key and SketchyBar item suffix. The raw `pane_id` is stored in
  the agent record's `pane` field for the click action.
- Label: the herdr tab label for the pane's tab, resolved from
  `herdr api snapshot`. Fallback: cwd basename.

## Components

### New: `agent-monitor/adapters/herdr.sh`

- Called by `herdr-plugin/on-event.sh` with the herdr event name.
- Reads the event payload from `HERDR_PLUGIN_EVENT_JSON` and `HERDR_PANE_ID`.
- Normalizes herdr events to generic events per the mapping table and calls
  `agent-monitor reconcile herdr <Event> '<json>'` with
  `{pane_id, label, cwd}`.
- `pane.closed` → `agent-monitor remove <id>`.
- `--sync` mode: reads `herdr api snapshot`, reconciles every agent found,
  and removes tracked herdr agents whose panes no longer exist (or whose
  status is `unknown`).

### New: `agent-monitor/herdr-plugin/herdr-plugin.toml`

Manifest with:

- `[[startup]]` hook → full sync (`adapters/herdr.sh --sync` via the
  dispatcher).
- `[[events]]` on `pane.agent_status_changed`, `pane.agent_detected`,
  `pane.closed` → dispatcher.

### New: `agent-monitor/herdr-plugin/on-event.sh`

Single dispatcher invoked by the manifest. Resolves the repo root from its
own path, then calls `adapters/herdr.sh` with `$HERDR_PLUGIN_EVENT`
(`startup` → `--sync`).

### Changed: `core/reconcile.sh`

- `resolve_id`: accept `pane_id` from the event JSON (sanitized:
  `tr -c '[:alnum:]_' '_'`). Checked before the `session_id` fallback.
- `resolve_label`: prefer an explicit `label` field from the event JSON.
- Both changes are additive and backward compatible.

### Changed: `core/state.sh`

- `refresh_sinks` now lives in `core/state.sh` and exports
  `$STATE_DIR/state.tsv` atomically after each state write.
- `agent-monitor remove` refreshes sinks after removal.
- `sinks/sketchybar.sh` defaults `AGENT_MONITOR_STATE_FILE` to that path.

### Changed: `core/prune.sh`

- Skip agents whose `name` is `herdr`. Their pane ids are herdr pane ids,
  not tmux pane ids, so the tmux liveness check would wrongly delete them.
  Herdr agent lifecycle is handled by `pane.closed` and `--sync`.

### Changed: `sinks/sketchybar.sh`

- Click dispatch by pane id format:
  - `%…` → existing `tmux select-window/select-pane` behavior.
  - `w…:p…` → `herdr agent focus <pane_id>`.

### Changed: tests and docs

- New `agent-monitor/tests/herdr-adapter.test.sh`: status mapping, sync
  mode, `pane.closed` removal, unknown-status ignore.
- Extend `sketchybar/tests/agent-monitor.test.sh`: herdr item renders with
  the `herdr agent focus` click script; tmux items unchanged.
- Update `agent-monitor/README.md`: herdr source, state mapping, install
  step.

## Error Handling

- The adapter is tolerant: missing fields in the event JSON → label/status
  resolved from `herdr api snapshot`; total failure → exit 0 quietly (a bad
  hook must not pollute herdr's plugin log with crashes).
- `unknown` status and panes without agents are never tracked.
- Startup `--sync` heals any drift after a herdr restart or a missed event.
- Notifications (`core/notify.sh`) fire unchanged on transitions to
  `needs-help` / `needs-attention`.

## Install / Setup

```bash
herdr plugin link /Users/walkerw/dotfiles/agent-monitor/herdr-plugin
```

## Testing

- Adapter test: mapping table, `--sync`, `pane.closed` removal, unknown
  ignore.
- Sink test: herdr render cases; tmux cases unchanged.
- All existing test suites must pass unchanged (backward compatibility proof).
- Manual verification: `herdr api snapshot` vs `agent-monitor state` after
  link; click an item and confirm `herdr agent focus` jumps to the agent.
