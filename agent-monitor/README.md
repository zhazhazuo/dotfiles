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
                               ▼
                       sinks/sketchybar
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
      "turn_completed_at": null,
      "seen": 0
    }
  }
}
```

`seen` is 1 when the user has looked at a finished result, and 0 otherwise. A
state change sets it back to 0, so the next run asks again.

## States

| State | Color | Meaning |
|-------|-------|---------|
| `idle` | gray | Agent exists, not active |
| `running` | green | Agent is working |
| `subagents-running` | orange | Main agent parked, background subagents still running |
| `needs-attention` | blue | Finished, needs review |
| `needs-help` | red | Blocked, needs input |

Only `needs-help` and `needs-attention` show the agent name in the SketchyBar item, wrapped in angle brackets. Every other state draws a dot in the state color, so a row of concurrent agents stays short.

A seen `needs-attention` agent also draws a dot, in the idle grey. The
result was reviewed, so the item stops asking. `needs-help` is never seen this
way: a blocked agent asks a question, and looking at the question does not
answer it.

## Rex Source

Rex publishes per-block program status over OSC 7501. Two sources carry it:

- `~/.cache/rex/listing.json`, kept current by the listing daemon. It holds
the state and the focused pane of every block, and `listing.json.alive` is
touched every half minute. The adapter reads the file when the beat is under
90 seconds old, so state costs one read instead of a rex process per block.
- The server API (`session.list`, `session.view`, and
`com.superlogical.terminal.program_status`) for a stopped daemon, plus
`rex events --all --json` for changes as they happen.

A finished run counts as seen when its pane is focused in the active window of
the session the app displays. The app records that session under
`Workspace.lastFocusedSession` in
`~/Library/Preferences/com.superlogical.rex.plist`, and rewrites it on every
switch. Focus changes arrive as `session_view_changed`, which carries a revision
and nothing else, so the adapter re-reads the listing when one arrives.

Rex has no acknowledged flag, and the Raycast Rex extension does not read one:
it keeps its own record of which results it has shown. This adapter therefore
derives seen from focus instead, and the two views can disagree.

`blocked` becomes needs-help, which is the red item. For a pi questionnaire
that report depends on a patched package, because pi raises `blocked` only for
a UI component that declares one: see `pi/patches/`, and
`tests/rex-blocked.test.sh`, which drives the state end to end.

## Latency

A program's report reaches the bar in about 1.1 s, measured from the escape
sequence to the SketchyBar item: 0.8 s to the store and 0.3 s to the bar. The
same measurement read 3.1-3.4 s before the changes below, and one state change
cost 1.0 s of shell work.

| Change | Saved |
|---|---|
| The tmux sink is gone; SketchyBar is the only sink | 0.35 s per change |
| A status or title event answers from the listing, not two rex CLI calls | 0.55 s per event |
| The store write is one jq pass instead of eight | 0.24 s per change |
| An event is matched on the raw line, so an ignored tick costs no process | one process pair per ignored line |

The listing read is 0.03 s against 0.29 s for one rex CLI call, which is why
the event path prefers it. The remaining 1.1 s is the store write, the sink's
sixteen `sketchybar` calls, and the delay before Rex delivers the event.

## Herdr Source

Herdr is the source of truth for agents running inside herdr. A herdr plugin
(`herdr-plugin/`) pushes `pane.agent_status_changed`, `pane.agent_detected`,
and `pane.closed` events to `adapters/herdr.sh`, plus a full snapshot sync on
herdr startup.

Status mapping: `working`→running, `blocked`→needs-help, `done`→needs-attention,
`idle`→idle, `unknown`→removed. Labels come from herdr tab labels. Clicking a
SketchyBar item for a herdr agent runs `herdr agent focus <pane_id>`.

### Subagent state (`subagents-running`)

While background subagents run, the subagent publisher sets pane display
metadata: `--state-label idle=done=working="⏳ N subagent(s) (names)"` alongside
a `summary` token, refreshed every 45s and cleared when the runs finish. A parked
main agent (`done`/`idle`) carrying that metadata is reported as
`subagents-running` (orange) instead of `needs-attention` (blue), and no
notification is sent. When the labels clear, the same event type fires and the
agent transitions to `needs-attention` — that is when you get the "finished"
notification.

Two publishers speak this contract:

- the legacy `pi-subagents` package, from Herdr-detectable child Pi processes;
- `pi-subagent-manager`, which runs its threads **in-process** and publishes
  nothing to Herdr. Its labels come from the local bridge
  `pi/extensions/herdr-subagents-running.ts`, which replays the manager's
  `pi-subagent:registry:v1` session journal (one base snapshot, then a delta per
  change) and reports `⏳ N subagent(s) (names) · m:ss`. The journal must be
  replayed: a version 2 delta names only the threads that changed, so the newest
  entry alone is not a thread list. The elapsed clock is deliberate: Herdr only
  re-emits `pane.agent_status_changed` when the pane presentation actually
  differs, and that re-emission is what refreshes the heartbeat below. The
  bridge repeats a clear once, because Herdr announces the change before
  `herdr api snapshot` stops listing the labels and the adapter reads the
  snapshot.

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
│   └── sketchybar.sh           # SketchyBar items
├── tests/
│   ├── reconcile.test.sh
│   ├── prune.test.sh
│   └── herdr-adapter.test.sh
└── README.md
```
