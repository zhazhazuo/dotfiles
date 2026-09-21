# agent-monitor

Event-driven agent status monitor. Hooks AI coding harnesses, syncs state to GUI surfaces.

## Architecture

```
SOURCES → CORE → SINKS

adapters/herdr.sh ─┐
adapters/pi.sh ──┐ │
adapters/codex.sh ┤┤──▶ bin/agent-monitor reconcile ──▶ core/reconcile.sh
adapters/cursor.sh─┘┘          │
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
| `subagents-running` | orange | Main agent parked, background subagents still running |
| `needs-attention` | blue | Finished, needs review |
| `needs-help` | red | Blocked, needs input |

## Herdr Source

Herdr is the source of truth for agents running inside herdr. A herdr plugin
(`herdr-plugin/`) pushes `pane.agent_status_changed`, `pane.agent_detected`,
and `pane.closed` events to `adapters/herdr.sh`, plus a full snapshot sync on
herdr startup.

Status mapping: `working`→running, `blocked`→needs-help, `done`→needs-attention,
`idle`→idle, `unknown`→removed. Labels come from herdr tab labels. Clicking a
SketchyBar item for a herdr agent runs `herdr agent focus <pane_id>`.

### Subagent state (`subagents-running`)

When pi-subagents runs background subagents, it publishes pane display metadata:
`--state-label idle=done=working="⏳ N subagent(s) (names)"` alongside a
`summary` token, refreshed every 45s and cleared when the runs finish. A parked
main agent (`done`/`idle`) carrying that metadata is reported as
`subagents-running` (orange) instead of `needs-attention` (blue), and no
notification is sent. When the labels clear, the same event type fires and the
agent transitions to `needs-attention` — that is when you get the "finished"
notification.

Precedence: `blocked` → needs-help, `working` → running, otherwise a positive
subagent count → subagents-running, `done` → needs-attention, `idle` → idle.
Detection reads the state label for the pane's current status, then any label,
then the `summary` token, matching on "subagent" case-insensitively.

Because herdr expires pane metadata on its own TTL without emitting an event,
`agent-monitor prune` demotes a `subagents-running` agent whose heartbeat
(`subagents_checked_at`) is older than `AGENT_MONITOR_SUBAGENT_STALE_SECONDS`
(default 150) back to `needs-attention`. Herdr entries are otherwise skipped by
prune, so this is their only cleanup path there.

### Blocked on human input (`ask_user_question`)

While a Pi session waits for a reply to the `ask_user_question` tool, the pane
must read as blocked rather than `working`. Nothing in herdr's own Pi
integration emits that: `ask_user_question` (from
`@juicesharp/rpiv-ask-user-question`) publishes `rpiv:ask-user:blocked`
`{active}` around the questionnaire, but herdr only reacts to `herdr:blocked`.

The bridge lives in the Pi extension `pi/extensions/ask-user-attention.ts`
(symlinked into `~/.pi/agent/extensions/`), not in this repo's adapters. It
maps the rpiv event — with the first question text as the message — to
`herdr:blocked`, plus core `ui_prompt_start`/`ui_prompt_end` as a backstop for
any blocking extension prompt. Herdr then reports `agent_status=blocked`, which
`adapters/herdr.sh` maps to `PermissionRequest` → `needs-help` (red) with the
usual notification. The bridge is herdr- and TUI-only and collapses overlapping
signals into a single `herdr:blocked` pair, so herdr's counted contract is not
double-raised.

Install:

```bash
herdr plugin link /Users/walkerw/dotfiles/agent-monitor/herdr-plugin
```

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
│   ├── herdr.sh                # Herdr plugin adapter
│   ├── pi.sh                   # Pi extension adapter
│   ├── codex.sh                # Codex hook adapter
│   └── cursor.sh               # Cursor hook adapter
├── herdr-plugin/
│   ├── herdr-plugin.toml       # Plugin manifest
│   └── on-event.sh             # Event dispatcher
├── sinks/
│   ├── tmux-status.sh          # tmux topbar widget
│   └── sketchybar.sh           # SketchyBar items
├── tests/
│   ├── reconcile.test.sh
│   ├── prune.test.sh
│   └── herdr-adapter.test.sh
└── README.md
```
