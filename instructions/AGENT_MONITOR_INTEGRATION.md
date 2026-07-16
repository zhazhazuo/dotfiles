# Agent Monitor Integration Guide

How to wire a new CLI coding agent into the shared tmux/SketchyBar agent monitor.

## What This System Does

When your agent is running inside a tmux pane, the monitor shows its state as a colored pill in the tmux status bar and SketchyBar. It also sends macOS notifications when the agent needs help or finishes a turn and you're not looking at the terminal.

```
┌───────────────────────────── tmux status bar ────────────────────────────────┐
│   dev │  zsh │  ~/project │     ‹work›  ‹review›    │ 1 2 3 │  󰖳        │
│                                        ↑ green    ↑ red                     │
│                                   (your agent)  (your agent)                │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Architecture

```
Your agent (hook/event)
  │
  │  stdin JSON: {"session_id":"...", "cwd":"...", ...}
  ▼
agent-monitor-check.sh <your-agent-name> <event-name>
  │
  ├─► writes tmux global options  (@agent_monitor_<id>_state, ...)
  ├─► sends macOS notification     (on attention-state transition)
  ├─► prunes stale records         (dead panes/processes)
  └─► refreshes renderers          (tmux status + SketchyBar)
```

**Tmux owns the data.** SketchyBar reads a TSV file exported by the tmux module. You only need to integrate with the tmux scripts.

## Quick Start

### Step 1: Pick your agent name

A short lowercase identifier used as the `name` field in records:

```
codex    pi    opencode    claude    aider
```

Pick one that's unique and stable.

### Step 2: Decide event names

Map your agent's lifecycle events to one of these **generic event names**:

| Generic event name | Meaning | Resulting state |
|---|---|---|
| `SessionStart` | Agent session created or resumed | `idle` |
| `SessionResume` | Agent session resumed | `idle` |
| `PromptSubmit` | User submitted a prompt | `running` |
| `RunStart` | Agent started executing | `running` |
| `ToolStart` | Agent started a tool call | `running` |
| `ToolEnd` | Agent finished a tool call | `running` |
| `PermissionRequest` | Agent needs permission | `needs-help` |
| `InputRequired` | Agent is waiting for user input | `needs-help` |
| `TurnComplete` | Agent finished a turn | `needs-attention` |
| `Stop` | Agent stopped / session ended | `needs-attention` |

If your agent has unique event names (e.g. `AgentStart` instead of `RunStart`), you have two options:

- **Option A (preferred):** Translate in your adapter before calling the script. Map your names to the generic names above.
- **Option B:** Add agent-specific mappings to `agent-monitor-check.sh`. Avoid this unless you maintain the dotfiles repo. It adds coupling and the plan calls for keeping the core script generic.

### Step 3: Supply JSON context on stdin

The script reads a JSON object from stdin. Provide at minimum:

```json
{
  "session_id": "optional-upstream-session-id",
  "cwd": "/path/to/working/directory"
}
```

Fields the script reads:

| Field | Used for | Required? |
|---|---|---|
| `session_id` | Identity fallback, stored as metadata | No |
| `cwd` | Identity fallback, label fallback | No |
| `tool_name` | Codex-specific state mapping (legacy) | No |
| `tool_input.sandbox_permissions` | Codex-specific state mapping (legacy) | No |

Even if you don't have these fields, **always pipe a valid JSON object** (at least `{}`) to keep the stdin contract consistent.

### Step 4: Call the script

```bash
printf '{"session_id":"%s","cwd":"%s"}' "$SESSION_ID" "$PWD" \
  | ~/dotfiles/tmux/scripts/agent-monitor-check.sh myagent RunStart
```

Arguments:
1. Your agent name (from Step 1)
2. The event name (from Step 2)

The script must run **inside the tmux pane** where your agent lives. It reads `$TMUX_PANE` from the environment.

### Step 5: Refresh on state changes

Call the script on every meaningful lifecycle event. At minimum:

1. When the agent starts → `SessionStart`
2. When the user submits a prompt → `PromptSubmit` or `RunStart`
3. When the agent needs permission or input → `PermissionRequest` or `InputRequired`
4. When the agent finishes a turn → `TurnComplete` or `Stop`

More events = more responsive status. The script is cheap (writes a few tmux options, forks once for prune/notify).

## Identity Rules

Each agent instance gets a **stable monitor ID**. The ID determines which record gets updated on each event.

### Default: one pane = one instance

If you don't set anything special, `$TMUX_PANE` (e.g. `%9`) becomes the instance ID. All events from that pane update the same record.

This is correct for 99% of cases.

### Override: explicit instance ID

If one pane can host multiple logical agent sessions, set the env var before calling:

```bash
AGENT_MONITOR_INSTANCE_ID="my-special-id" \
  agent-monitor-check.sh myagent RunStart
```

The ID is sanitized (only `[a-zA-Z0-9_]` allowed, everything else → `_`). Pick a stable value that survives across your agent's lifecycle.

### What must NOT create a new instance

- Changing the tmux window name (`label` is display-only, never identity)
- Changing the working directory
- Starting a new session in the same pane (unless you set `AGENT_MONITOR_INSTANCE_ID`)

### Identity resolution order

```
AGENT_MONITOR_INSTANCE_ID (env var)
  → TMUX_PANE (env var, set by tmux)
  → session_id (from stdin JSON)
  → cwd basename (from stdin JSON)
  → agent name (last resort)
```

## State Model

Four states, rendered with distinct colors:

| State | tmux color | SketchyBar color | When |
|---|---|---|---|
| `idle` | gray (`@thm_overlay_0`) | `#aaaaaa` | Agent is available, no active work |
| `running` | green (`@thm_green`) | `#238636` | Agent is executing (tools, thinking) |
| `needs-help` | red (`@thm_red`) | `#c0392b` | Agent is blocked waiting for input/permission |
| `needs-attention` | blue (`@thm_blue`) | `#1f6feb` | Agent finished a turn; decays to `idle` after 300s |

### Timeout decay

`needs-attention` → displayed as `idle` after `@agent_monitor_attention_timeout` seconds (default 300). The stored state stays `needs-attention` — only the renderers decay it. This means if a new event fires, the transition logic still sees the previous `needs-attention` and works correctly.

### macOS notifications

The system sends notifications only when the state **transitions** into `needs-help` or `needs-attention`. Notifications are **suppressed** when the frontmost macOS app is a terminal app (Ghostty, Terminal, iTerm2, WezTerm, kitty, Alacritty — configurable via `@agent_monitor_notify_tmux_apps`).

Repeated events with the same attention state don't re-notify (the script checks the previous state before notifying).

## The Adapter Pattern

If your agent's hook system emits events in a different format than the generic names, write a thin adapter script.

### Adapter template

```bash
#!/usr/bin/env bash
# ~/dotfiles/tmux/scripts/myagent-agent-event.sh
# Adapter: MyAgent hook events → tmux agent monitor

set +e +u  # fail open — don't break the agent

event_name="${1:-}"
# If no arg, try to read from stdin JSON (e.g. hook_event_name field)
if [[ -z "$event_name" ]]; then
  input="$(cat 2>/dev/null || true)"
  event_name="$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)"
  printf '%s' "$input" | \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agent-monitor-check.sh" myagent "$event_name" >/dev/null 2>&1 || true
  exit 0
fi

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agent-monitor-check.sh" myagent "$event_name" >/dev/null 2>&1 || true
exit 0
```

### Adapter rules

1. **Be thin.** Only normalize event names and pass through session metadata. Don't write tmux options directly.
2. **Fail open.** Use `set +e +u`. If the monitor script fails, your agent must continue unaffected.
3. **Pass JSON through.** If your agent's hook already emits JSON with `session_id` and `cwd`, pipe it directly. If not, construct a minimal payload.
4. **Never block.** Redirect to `/dev/null` or background it if your agent's hook system is synchronous.

### If your agent has no hook system

Some agents don't expose lifecycle hooks. Alternatives (in order of preference):

1. **Wrap the agent binary** — a shell function/script that calls the monitor before/after invocation
2. **Shell preexec/precmd hooks** — detect agent process in the pane and update state
3. **Process polling** — a periodic script that checks `ps` for the agent process (worst option, adds latency)

## Integration Checklist

- [ ] Choose a stable agent name
- [ ] Map your lifecycle events to generic event names
- [ ] Write the adapter script (if needed) or call `agent-monitor-check.sh` directly
- [ ] Wire the calls into your agent's hook/event system
- [ ] Test: start agent → status shows green `running`
- [ ] Test: agent needs input → status shows red `needs-help`
- [ ] Test: agent finishes → status shows blue `needs-attention` (decays to idle after 5 min)
- [ ] Test: rename tmux window → label updates, no duplicate instance
- [ ] Test: kill agent pane → label disappears from status bar
- [ ] Test (macOS): switch to browser → receive notification on attention transition
- [ ] Test (macOS): stay in terminal → no notification

## Reference

### Script paths

All paths relative to `~/dotfiles/tmux/scripts/`:

| Script | Purpose |
|---|---|
| `agent-monitor-check.sh` | **Public API.** Ingest an event, write tmux records. |
| `agent-monitor-prune.sh` | Remove records for dead panes/processes. |
| `agent-monitor-state.sh` | Export records to TSV file for SketchyBar. |
| `agent-monitor-notify.sh` | Send macOS notification for attention states. |
| `agent-status.sh` | Render records into tmux status format. |
| `agent-monitor-list-items.sh` | Print current records (debugging). |
| `agent-monitor-delete-items.sh` | Remove records by ID (debugging). |

### Tmux options reference

| Option | Type | Default | Purpose |
|---|---|---|---|
| `@agent_monitor_instances` | space-separated IDs | — | Active instance list |
| `@agent_monitor_<id>_name` | string | — | Agent family name |
| `@agent_monitor_<id>_state` | string | `idle` | One of idle/running/needs-help/needs-attention |
| `@agent_monitor_<id>_label` | string | — | Display label (window name) |
| `@agent_monitor_<id>_pane` | string | — | Tmux pane ID for click-targeting |
| `@agent_monitor_<id>_session_id` | string | — | Upstream agent session ID |
| `@agent_monitor_<id>_updated_at` | epoch | — | Last event timestamp |
| `@agent_monitor_attention_timeout` | seconds | `300` | needs-attention decay timeout |
| `@agent_monitor_notify_enabled` | on/off | `on` | Enable macOS notifications |
| `@agent_monitor_notify_tmux_apps` | space-separated | `Ghostty Terminal iTerm2 WezTerm kitty Alacritty` | Apps that suppress notifications |
| `@agent_monitor_status` | string | — | Pre-rendered status bar content (set by agent-status.sh) |
| `@agent_status_enabled` | on/off | `on` | Enable status bar widget |
| `@agent_status_separator` | string | `│` | Separator between agent labels |

### Environment variables

| Variable | Purpose |
|---|---|
| `TMUX_PANE` | Set by tmux; used as the default instance identity |
| `AGENT_MONITOR_INSTANCE_ID` | Override the instance identity |
| `AGENT_MONITOR_NOW` | Override current epoch (for testing) |
| `AGENT_MONITOR_STATE_FILE` | Override TSV state file path |
| `AGENT_MONITOR_FRONT_APP` | Override frontmost app name (for testing) |

### Debugging

List current monitor records:

```bash
~/dotfiles/tmux/scripts/agent-monitor-list-items.sh
```

Delete a specific record:

```bash
~/dotfiles/tmux/scripts/agent-monitor-delete-items.sh <id>
```

Inspect tmux options directly:

```bash
tmux show-options -g | grep agent_monitor
```

Check the TSV bridge file:

```bash
cat ~/.cache/agent-monitor/agent-monitor.$(id -u).tsv
```

### Running the tests

```bash
cd ~/dotfiles/tmux
./tests/agent-monitor-event.test.sh    # Core event ingestion
./tests/agent-monitor-prune.test.sh    # Lifecycle cleanup
./tests/agent-monitor-state.test.sh    # TSV export
./tests/agent-monitor-notify.test.sh   # macOS notifications
./tests/agent-status.test.sh           # Status bar rendering
./tests/codex-agent-event.test.sh      # Codex adapter
./tests/cursor-agent-event.test.sh    # Cursor CLI adapter
./tests/pi-agent-event.test.sh         # Pi integration
```

```bash
cd ~/dotfiles/sketchybar
./tests/agent-monitor.test.sh          # SketchyBar rendering
```

All tests use fake tmux/sketchybar binaries and a fake option store — no real tmux session needed.

## Example: Cursor CLI (`agent`)

The Cursor CLI is integrated via user hooks in `~/.cursor/hooks.json`. The hook script `~/.cursor/hooks/agent-monitor.sh` forwards lifecycle events to `tmux/scripts/cursor-agent-event.sh`.

### Wiring

`hooks.json` registers `./hooks/agent-monitor.sh` on coarse lifecycle events only: `sessionStart`, `sessionEnd`, `beforeSubmitPrompt`, `preToolUse`, `beforeShellExecution`, `beforeMCPExecution`, `subagentStart`, and `stop`. High-frequency hooks such as `afterAgentThought` are intentionally excluded.

The adapter:

- maps Cursor hook names to generic monitor events
- stores `session_id → TMUX_PANE` at `sessionStart` in `@cursor_agent_session_<id>_pane`
- resolves later events by `session_id` (supports multiple concurrent `agent` sessions)
- uses agent name `cursor` in monitor records
- deletes the monitor record on `sessionEnd` instead of leaving a stale pill

### Event mapping

| Cursor hook | Generic event | State |
|---|---|---|
| `sessionStart` | `SessionStart` | `idle` |
| `beforeSubmitPrompt` | `PromptSubmit` | `running` |
| `preToolUse`, shell/MCP hooks, `subagentStart` | `ToolStart` | `running` |
| `afterAgentResponse`, `afterAgentThought`, `subagentStop` | `ToolEnd` | `running` |
| `stop` | `TurnComplete` | `needs-attention` |
| `sessionEnd` | *(delete record)* | removed |

### Debugging

```bash
~/dotfiles/tmux/scripts/agent-monitor-list-items.sh
cat ~/.cache/agent-monitor/agent-monitor.$(id -u).tsv
```

Cursor uses two ids in hook JSON: `session_id` (CLI session) and `conversation_id` (transcript). The adapter stores pane mappings for both. SketchyBar reads the shared TSV at `~/.cache/agent-monitor/agent-monitor.<uid>.tsv` (not `$TMPDIR`).

### Performance

Cursor monitor hooks are intentionally coarse and synchronous:

- Only lifecycle hooks update the monitor (`sessionStart`, `beforeSubmitPrompt`, `preToolUse`, `stop`, etc.)
- `afterAgentThought` / `afterAgentResponse` do **not** update the monitor
- `agent-monitor-check.sh` skips prune/refresh when state is unchanged (e.g. repeated `ToolStart` while already `running`)
- Prune runs only on `SessionStart` and `TurnComplete` / `Stop`

## Example: Integrating "Aider"

Assume Aider emits shell hooks: `aider_start`, `aider_prompt`, `aider_blocked`, `aider_done`.

### Adapter script (`tmux/scripts/aider-agent-event.sh`)

```bash
#!/usr/bin/env bash
# Aider hook events → tmux agent monitor

set +e +u

event="${1:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Map Aider event names to generic names
case "$event" in
  aider_start)   generic="SessionStart" ;;
  aider_prompt)  generic="RunStart" ;;
  aider_blocked) generic="InputRequired" ;;
  aider_done)    generic="TurnComplete" ;;
  *)             generic="$event" ;;
esac

# If Aider sets these env vars, use them; otherwise build minimal JSON
session_id="${AIDER_SESSION_ID:-}"
cwd="${AIDER_WORKDIR:-$PWD}"

printf '{"session_id":"%s","cwd":"%s"}' "$session_id" "$cwd" \
  | "$script_dir/agent-monitor-check.sh" aider "$generic" >/dev/null 2>&1 || true
```

### Aider hook config (`~/.aider.conf.yml` or similar)

```yaml
hooks:
  start:   ~/dotfiles/tmux/scripts/aider-agent-event.sh aider_start
  prompt:  ~/dotfiles/tmux/scripts/aider-agent-event.sh aider_prompt
  blocked: ~/dotfiles/tmux/scripts/aider-agent-event.sh aider_blocked
  done:    ~/dotfiles/tmux/scripts/aider-agent-event.sh aider_done
```

That's it. No changes to the core scripts, no tmux config changes. The monitor picks up the new agent automatically.

## What NOT to Do

- **Don't write tmux options directly.** Always go through `agent-monitor-check.sh`. It handles deduplication, pruning, notification, and refresh.
- **Don't use window name as identity.** Users rename windows. The monitor tolerates this.
- **Don't depend on synchronous execution.** Your agent's hook might be on the critical path. Use `> /dev/null 2>&1 || true` and don't wait for the script.
- **Don't notify on every event.** The monitor only notifies on state *transitions* into attention states. If you call the script repeatedly with `needs-help`, the user only gets one notification.
- **Don't put agent-specific logic in the renderer.** The renderers (`agent-status.sh`, `agent_monitor.sh`) are generic. They read state, color it, format it. They don't know about individual agents.
