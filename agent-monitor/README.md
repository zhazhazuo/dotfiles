# agent-monitor

Event-driven agent status monitor. Hooks AI coding harnesses, syncs state to GUI surfaces.

## Architecture

```
SOURCES → CORE → SINKS

adapters/pi.sh ──┐
adapters/codex.sh ┤──▶ bin/agent-monitor reconcile ──▶ core/reconcile.sh
adapters/cursor.sh─┘           │
                               ▼
                      ~/.cache/agent-monitor/state.json
                               │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
             sinks/tmux    sinks/sketchy   sinks/future
```

## Usage

```bash
# Reconcile an event (called by adapters)
agent-monitor reconcile pi RunStart '{"cwd":"/tmp","session_id":"..."}'

# Prune dead agents
agent-monitor prune

# Print current state
agent-monitor state              # pretty-printed
agent-monitor state --json       # raw JSON
agent-monitor state --tsv        # TSV for legacy consumers

# Clear all state
agent-monitor clear
```

## State Store

`~/.cache/agent-monitor/state.json`:

```json
{
  "version": 1,
  "agents": {
    "%4": {
      "name": "pi",
      "state": "running",
      "label": "REPO-WIKI",
      "pane": "%4",
      "session_id": "...",
      "updated_at": 1784171938,
      "turn_completed_at": null
    }
  }
}
```

## States

| State | Color | Meaning |
|-------|-------|---------|
| `idle` | gray | Agent exists, not active |
| `running` | green | Agent is working |
| `needs-attention` | blue | Finished, needs review |
| `needs-help` | red | Blocked, needs input |

## Adding a New Agent

1. Create `adapters/<agent>.sh`
2. Normalize agent events to generic names
3. Call `agent-monitor reconcile <agent> <event> '<json>'`

## Adding a New UI

1. Create `sinks/<ui>.sh`
2. Read state with `agent-monitor state --json`
3. Render however you want

## Directory Structure

```
agent-monitor/
├── bin/
│   └── agent-monitor           # CLI entry point
├── core/
│   ├── state.sh                # JSON state read/write
│   ├── reconcile.sh            # event → state transition
│   ├── prune.sh                # dead agent cleanup
│   └── notify.sh               # macOS notifications
├── adapters/
│   ├── pi.sh                   # Pi extension adapter
│   ├── codex.sh                # Codex hook adapter
│   └── cursor.sh               # Cursor hook adapter
├── sinks/
│   ├── tmux-status.sh          # tmux topbar widget
│   └── sketchybar.sh           # SketchyBar items
├── tests/
│   ├── reconcile.test.sh
│   ├── state.test.sh
│   ├── pi-adapter.test.sh
│   └── tmux-status.test.sh
└── README.md
```
