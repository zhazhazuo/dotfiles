#!/usr/bin/env bash
#
# Adapter: Cursor hook events → tmux agent monitor generic events.
#
# Called by ~/.cursor/hooks/agent-monitor.sh with:
#   $1      = Cursor hook event name (e.g. "sessionStart", "preToolUse", "stop")
#   stdin   = the raw Cursor hook JSON payload

set +e +u # fail open — never break the host application

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
event="${1:-}"

# ── Read the raw Cursor JSON from stdin ──────────────────────────────────
input="$(cat 2>/dev/null || true)"

# ── Map Cursor hook events to generic events ──────────────────────────────
case "$event" in
sessionStart) generic="RunStart" ;;
sessionEnd) generic="TurnComplete" ;;
beforeSubmitPrompt) generic="PromptSubmit" ;;
preToolUse | beforeMCPExecution | beforeShellExecution | subagentStart)
	generic="ToolStart"
	;;
afterAgentResponse | afterAgentThought | subagentStop)
	generic="ToolEnd"
	;;
stop) generic="TurnComplete" ;;
*) generic="$event" ;;
esac

# ── Normalise Cursor JSON → monitor JSON ─────────────────────────────────
session_id=""
cwd=""
if [[ -n "$input" ]] && command -v jq >/dev/null 2>&1; then
	session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
	cwd="$(printf '%s' "$input" | jq -r '.workspace_roots[0] // empty' 2>/dev/null)"
elif [[ -n "$input" ]]; then
	session_id="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
	cwd="$(printf '%s' "$input" | sed -n 's/.*"workspace_roots"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

# ── Detect the tmux pane where the cursor-agent process lives ────────────
detect_tmux_pane() {
	local agent_pid agent_tty pane_lines pane_id
	# Find the MOST RECENT cursor-agent process (tail -1, not head -1,
	# because pgrep returns oldest first and we want the latest)
	agent_pid="$(pgrep -f 'cursor-agent/index.js' 2>/dev/null | tail -1)"
	[[ -z "$agent_pid" ]] && agent_pid="$(pgrep -f '/cursor-agent/' 2>/dev/null | grep -v grep | grep -v hooks | tail -1)"

	[[ -z "$agent_pid" ]] && return 1
	agent_tty="$(ps -p "$agent_pid" -o tty= 2>/dev/null | tr -d ' ')"
	[[ -z "$agent_tty" || "$agent_tty" == "??" ]] && return 1

	if command -v tmux >/dev/null 2>&1; then
		pane_lines="$(tmux list-panes -a -F '#{pane_id} #{pane_tty}' 2>/dev/null)"
		pane_id="$(printf '%s\n' "$pane_lines" | grep "/dev/${agent_tty}$" | awk '{print $1}')"
		if [[ -n "$pane_id" ]]; then
			printf '%s' "$pane_id"
			return 0
		fi
	fi
	return 1
}

# ── Resolve identity ─────────────────────────────────────────────────────
# If TMUX_PANE is inherited (Cursor hooks in a tmux pane), use it directly.
# Only fall back to pane detection when it's NOT inherited.
detected_pane=""
if [[ -z "${TMUX_PANE:-}" ]]; then
	detected_pane="$(detect_tmux_pane)"
	if [[ -n "$detected_pane" ]]; then
		export TMUX_PANE="$detected_pane"
	fi
fi

# If still no TMUX_PANE, set a stable identity from workspace_roots[0].
agent_is_dead=false
if [[ -z "${TMUX_PANE:-}" && -z "${AGENT_MONITOR_INSTANCE_ID:-}" ]]; then
	if [[ -n "$detected_pane" ]]; then
		: # should not reach here, but safety
	elif [[ -n "$cwd" ]]; then
		export AGENT_MONITOR_INSTANCE_ID="cursor-$(basename "$cwd")"
	else
		agent_is_dead=true
	fi
fi

# Skip events from a dead agent entirely.
if [[ "$agent_is_dead" == true ]]; then
	exit 0
fi

# ── Build monitor-compatible JSON payload ────────────────────────────────
if [[ -n "$cwd" || -n "$session_id" ]]; then
	payload="$(jq -n --arg sid "$session_id" --arg cwd "$cwd" \
		'{session_id: $sid, cwd: $cwd}' 2>/dev/null)" || payload="$input"
else
	payload="$input"
fi

# ── State guard: prevent late events from overwriting terminal states ────
# Cursor fires beforeSubmitPrompt RIGHT AFTER stop (not a real user prompt).
# Block ALL events when in terminal states — only sessionStart (new session)
# can start a fresh state.
skip_event=false
if command -v tmux >/dev/null 2>&1; then
	inst_id="${AGENT_MONITOR_INSTANCE_ID:-${TMUX_PANE:-}}"
	[[ -z "$inst_id" && -n "$session_id" ]] && inst_id="$session_id"
	[[ -z "$inst_id" && -n "$cwd" ]] && inst_id="$(basename "$cwd")"
	[[ -z "$inst_id" ]] && inst_id="agent"
	inst_id="$(printf '%s' "$inst_id" | tr -c '[:alnum:]_' '_' | sed 's/^_*//; s/_*$//')"

	current_st="$(tmux show-options -gqv "@agent_monitor_${inst_id}_state" 2>/dev/null || true)"
	case "$current_st" in
	needs-attention | needs-help)
		case "$generic" in
		RunStart) ;;          # allow: new session starting
		TurnComplete) ;;      # allow: another terminal event (idempotent)
		*) skip_event=true ;; # block everything else
		esac
		;;
	esac
fi

# ── Call the shared monitor (backgrounded to avoid hook timeout) ────────
if [[ "$skip_event" != true ]]; then
	# Background the call so the hook returns immediately.
	# The hook has a 3-second timeout; agent-monitor-check.sh takes ~3s.
	printf '%s' "${payload:-{\}}" | "$script_dir/agent-monitor-check.sh" agent "$generic" >/dev/null 2>&1 &
fi

exit 0
