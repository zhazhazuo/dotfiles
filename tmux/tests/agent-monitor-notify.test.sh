#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/agent-monitor-notify.sh"
TMP_DIR="$(mktemp -d)"
LOG="$TMP_DIR/notifications.log"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

case "$1" in
show-options)
	case "$3" in
	@agent_monitor_notify_enabled) printf '%s\n' "${AGENT_MONITOR_NOTIFY_ENABLED:-on}" ;;
	@agent_monitor_notify_tmux_apps) printf '%s\n' "${AGENT_MONITOR_NOTIFY_TMUX_APPS:-Ghostty Terminal iTerm2 WezTerm kitty Alacritty}" ;;
	*) exit 0 ;;
	esac
	;;
*)
	exit 1
	;;
esac
FAKE_TMUX
chmod +x "$TMP_DIR/tmux"

cat >"$TMP_DIR/osascript" <<'FAKE_OSASCRIPT'
#!/usr/bin/env bash

set -euo pipefail

if [[ "${1:-}" == "-e" ]]; then
	printf '%s\n' "${AGENT_MONITOR_FRONT_APP:-Safari}"
	exit 0
fi

printf '%s|%s\n' "${2:-}" "${3:-}" >>"${AGENT_MONITOR_NOTIFY_LOG:?}"
FAKE_OSASCRIPT
chmod +x "$TMP_DIR/osascript"

assert_equal() {
	local expected="$1"
	local actual="$2"
	local name="$3"

	if [[ "$actual" != "$expected" ]]; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'expected: %s\n' "$expected" >&2
		printf 'actual:   %s\n' "$actual" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

log_contents() {
	if [[ -r "$LOG" ]]; then
		cat "$LOG"
	fi
}

PATH="$TMP_DIR:$PATH"
export AGENT_MONITOR_NOTIFY_LOG="$LOG"

AGENT_MONITOR_FRONT_APP="Safari" "$SCRIPT" codex running work
assert_equal "" "$(log_contents)" "does not notify for non-attention states"

AGENT_MONITOR_FRONT_APP="Ghostty" "$SCRIPT" codex needs-help work
assert_equal "" "$(log_contents)" "does not notify while terminal app is frontmost"

AGENT_MONITOR_FRONT_APP="Safari" "$SCRIPT" codex needs-help work
assert_equal "work needs help|codex is waiting for input or permission." "$(log_contents)" "notifies needs-help while away from tmux"

: >"$LOG"
AGENT_MONITOR_FRONT_APP="Safari" "$SCRIPT" codex needs-attention work
assert_equal "work finished|codex needs your attention." "$(log_contents)" "notifies needs-attention while away from tmux"

: >"$LOG"
AGENT_MONITOR_NOTIFY_ENABLED="off" AGENT_MONITOR_FRONT_APP="Safari" "$SCRIPT" codex needs-help work
assert_equal "" "$(log_contents)" "respects disabled notification option"
