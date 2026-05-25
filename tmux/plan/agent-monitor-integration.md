# Agent Monitor Integration Plan

The tmux monitor is event-driven and agent-agnostic. Codex is the first producer; Pi, opencode, and Claude Code should integrate by writing the same tmux monitor records through the shared scripts.

## Current Architecture

```text
agent hook/event
  -> agent adapter, if needed
  -> scripts/agent-monitor-check.sh <agent-name> <event-name>
  -> tmux global monitor records
  -> optional macOS notification for attention-state transitions
  -> scripts/agent-status.sh renders the topbar
```

Tmux owns pane/window lifecycle cleanup, and agent events opportunistically clean up stale records from panes where the agent process was killed but the shell pane stayed open:

```text
tmux pane/window hook or next agent event
  -> scripts/agent-monitor-prune.sh
  -> stale monitor records removed
  -> status cache refreshed
```

The renderer does not inspect processes, capture pane text, or know agent-specific behavior.

## Shared Tmux Data Contract

Every agent instance is represented by these global tmux options:

```text
@agent_monitor_instances
@agent_monitor_<id>_name
@agent_monitor_<id>_state
@agent_monitor_<id>_label
@agent_monitor_<id>_pane
@agent_monitor_<id>_session_id
@agent_monitor_<id>_updated_at
```

Field meanings:

```text
id          stable monitor identity
name        agent family, such as codex, opencode, claude, pi
state       one of idle, running, needs-help, needs-attention
label       display label, normally the current tmux window name
pane        tmux pane id used for click navigation and pruning
session_id  optional upstream agent session id
updated_at  epoch seconds for timeout handling
```

Only the shared scripts should write this contract directly. Agent-specific hooks should call the public API instead.

## Public API

Future integrations should call:

```sh
~/dotfiles/tmux/scripts/agent-monitor-check.sh <agent-name> <event-name>
```

Examples:

```sh
agent-monitor-check.sh codex UserPromptSubmit
agent-monitor-check.sh opencode RunStart
agent-monitor-check.sh claude PermissionRequest
agent-monitor-check.sh pi Stop
```

The hook/event payload may be passed on stdin as JSON. The common script currently reads common fields such as:

```text
session_id
cwd
```

If an agent has a different payload shape, add a thin adapter that extracts or normalizes fields before calling the common script.

## Identity Rule

The monitor identity must not depend on the tmux window name, because users can rename windows while the agent instance remains the same.

Identity priority:

```text
AGENT_MONITOR_INSTANCE_ID -> TMUX_PANE -> session_id -> cwd basename -> agent name
```

Default behavior:

```text
one tmux pane = one monitor instance
```

For the uncommon case where one pane hosts multiple logical agents, the producer may set:

```sh
AGENT_MONITOR_INSTANCE_ID=<stable-id> agent-monitor-check.sh opencode RunStart
```

The tmux window name is display-only. It updates:

```text
@agent_monitor_<id>_label
```

and must never create a new instance.

## State Model

Keep the shared state set small:

```text
idle             gray
running          green
needs-help       red
needs-attention  blue
```

Current Codex mapping:

```text
SessionStart                 -> idle
UserPromptSubmit             -> running
PreToolUse                   -> running
PostToolUse                  -> running
PermissionRequest            -> needs-help
Stop                         -> needs-attention
unknown                      -> idle
```

Suggested mapping for other agents:

```text
start/session/resume         -> idle
prompt submitted/run start   -> running
tool start/tool end          -> running
permission/input required    -> needs-help
turn complete/stop           -> needs-attention
unknown                      -> idle
```

If another agent has richer states, map them down to this shared set before writing tmux records.

## Renderer Contract

[agent-status.sh](/Users/walkerw/dotfiles/tmux/scripts/agent-status.sh) should remain generic.

Renderer responsibilities:

```text
read @agent_monitor_instances
read each @agent_monitor_<id>_* record
apply needs-attention timeout decay
escape tmux format-sensitive label content
wrap valid pane-backed labels in range=pane|<pane-id>
render only the label, colored by effective state
write the rendered result to @agent_monitor_status during refresh
```

The display text is intentionally only:

```text
<window-label>
```

The agent name stays in metadata for future filtering, debugging, or agent-specific behavior, but it is not shown in the topbar.

The tmux status format should read the pre-rendered option:

```tmux
#{E:@agent_monitor_status}
```

Do not invoke the renderer through `#(...)` inside `status-format`. tmux caches `#(...)` command output and reruns it on `status-interval`, which introduces visible latency even when the hook path updates the cache immediately.

The renderer must not:

```text
scan processes
capture pane text
infer state from terminal output
contain agent-specific event mapping
```

## Mouse Navigation

Each pane-backed agent label is rendered with a tmux status range:

```text
#[range=pane|%pane_id]...#[norange]
```

The tmux config binds status clicks as:

```tmux
bind-key -n MouseDown1Status if -F "#{==:#{mouse_status_range},pane}" "select-pane -t =" "if -F '#{==:#{mouse_status_range},window}' 'select-window -t ='"
```

This lets users click an agent label to jump to its pane, while preserving normal window-list click behavior.

## Lifecycle Cleanup

Agent hooks cannot run after the agent pane/window is killed, so tmux must clean up stale records.

Configured hooks:

```tmux
set-hook -g pane-exited 'run-shell -b "~/dotfiles/tmux/scripts/agent-monitor-prune.sh"'
set-hook -g after-kill-pane 'run-shell -b "~/dotfiles/tmux/scripts/agent-monitor-prune.sh"'
set-hook -g after-kill-window 'run-shell -b "~/dotfiles/tmux/scripts/agent-monitor-prune.sh"'
```

[agent-monitor-prune.sh](/Users/walkerw/dotfiles/tmux/scripts/agent-monitor-prune.sh) should:

```text
list live panes with tmux list-panes -a -F '#{pane_id}'
read @agent_monitor_instances
deduplicate the instance list
remove records whose stored pane no longer exists
remove records whose pane exists but no longer has the recorded agent process
unset pruned @agent_monitor_<id>_* options
keep records without pane metadata, because explicit logical ids may not map to a pane
refresh the status cache and status line
```

When a pane disappears or its agent process is gone, the instance should be removed, not changed to idle, because the navigation target is no longer a live agent.

`agent-monitor-check.sh` should invoke prune before writing a new event. This handles the common user flow where a user kills the Codex process inside a still-open shell pane, then starts another agent instance elsewhere.

## Timeout And Refresh Policy

Configured timeout:

```tmux
set -g @agent_monitor_attention_timeout 300
```

Renderer behavior:

```text
needs-attention older than timeout -> render as idle
```

The stored state can remain `needs-attention`; timeout decay is a display concern.

After writes, `agent-monitor-check.sh` and `agent-monitor-prune.sh` refresh:

```text
agent-status.sh --refresh
tmux refresh-client -S
```

`agent-status.sh --refresh` updates both the filesystem cache and the tmux option:

```text
@agent_monitor_status
```

This keeps the widget responsive because `refresh-client -S` can redraw a tmux option immediately, without waiting for tmux to rerun a `#(...)` shell command.

## macOS Notifications

Attention states may notify the user when the frontmost macOS app is not a terminal/tmux app.

Notification script:

```text
scripts/agent-monitor-notify.sh <agent-name> <state> <label>
```

Notification states:

```text
needs-help       notify as "<label> needs help"
needs-attention  notify as "<label> finished"
```

Non-attention states must not notify.

`agent-monitor-check.sh` should call the notification script only when the state transitions into `needs-help` or `needs-attention`. Repeated hook calls with the same attention state should not repeatedly notify.

Configured options:

```tmux
set -g @agent_monitor_notify_enabled "on"
set -g @agent_monitor_notify_tmux_apps "Ghostty Terminal iTerm2 WezTerm kitty Alacritty"
```

The script checks the frontmost macOS application. If it matches `@agent_monitor_notify_tmux_apps`, it assumes the user is already at tmux and skips the notification.

## Adapter Pattern

Each new agent should get a small adapter only when its hook/event format differs from the common API.

Example future files:

```text
scripts/opencode-agent-event.sh
scripts/claude-agent-event.sh
scripts/pi-agent-event.sh
```

Each adapter should:

```text
read the agent hook payload from stdin/env/args
extract the event name
extract or pass through session_id/cwd when available
set AGENT_MONITOR_INSTANCE_ID only when pane identity is insufficient
call agent-monitor-check.sh <agent-name> <event-name>
never write tmux options directly
fail open so agent hooks do not break the host tool
```

Keep adapters thin. The shared tmux contract should remain owned by the common scripts.

## Remaining Integration Work

1. Move event mapping out of `agent-monitor-check.sh` once the second agent is added.

   Current Codex mapping is still in `state_for_event`. That is acceptable for one producer, but once opencode, Claude Code, or Pi is added, split mapping into an agent-aware layer.

2. Add per-agent adapters.

   Start with the agent that exposes the most reliable lifecycle hooks. Prefer real lifecycle events over process detection.

3. Add integration tests per adapter.

   Each adapter test should assert:

```text
event payload maps to the expected shared state
agent name is stored correctly
pane id remains the canonical default identity
window rename updates label only
permission/input event becomes needs-help
turn-finished event becomes needs-attention
```

4. Add manual tmux checks for mouse navigation.

   Automated tests assert the emitted tmux range syntax and config lines. Manual verification should confirm:

```text
clicking an agent label jumps to the target pane
clicking a normal window-list item still selects that window
killing an agent pane removes the label
renaming an agent window updates the label on the next hook event
```

## Test Coverage

Existing coverage should stay green:

```text
tests/agent-monitor-event.test.sh
tests/agent-monitor-notify.test.sh
tests/agent-monitor-prune.test.sh
tests/agent-status.test.sh
tests/codex-agent-event.test.sh
tests/tmux-conf.test.sh
```

Key behaviors covered:

```text
missing instance gets created
duplicate instance list is collapsed
same pane with different session ids stays one instance
window rename updates label without duplicating the instance
explicit AGENT_MONITOR_INSTANCE_ID overrides pane id
timeout decay works
refresh writes @agent_monitor_status
renderer does not scan panes, capture pane text, or inspect processes
labels escape tmux format syntax
dead pane records are pruned
attention states notify only when away from terminal apps
tmux config contains click and prune hooks
```

## Guiding Rule

Future agents integrate by producing lifecycle events into the shared tmux monitor contract. Do not teach the widget to inspect, parse, or infer each agent's runtime behavior.
