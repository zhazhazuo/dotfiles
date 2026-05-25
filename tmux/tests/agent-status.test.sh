#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/agent-status.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

option_value() {
	case "$1" in
	@agent_status_enabled) printf '%s\n' "${AGENT_STATUS_ENABLED:-on}" ;;
	@agent_monitor_instances) printf '%s\n' "${AGENT_MONITOR_INSTANCES:-one two three four}" ;;
	@agent_monitor_attention_timeout) printf '%s\n' "${AGENT_MONITOR_ATTENTION_TIMEOUT:-300}" ;;
	@agent_monitor_one_name) printf 'codex\n' ;;
	@agent_monitor_one_state) printf 'running\n' ;;
	@agent_monitor_one_label) printf '#[evil]work\n' ;;
	@agent_monitor_one_pane) printf '%%1\n' ;;
	@agent_monitor_one_updated_at) printf '1000\n' ;;
	@agent_monitor_two_name) printf 'codex\n' ;;
	@agent_monitor_two_state) printf 'needs-help\n' ;;
	@agent_monitor_two_label) printf 'review\n' ;;
	@agent_monitor_two_pane) printf '%%2\n' ;;
	@agent_monitor_two_updated_at) printf '1000\n' ;;
	@agent_monitor_three_name) printf 'codex\n' ;;
	@agent_monitor_three_state) printf 'needs-attention\n' ;;
	@agent_monitor_three_label) printf 'ship\n' ;;
	@agent_monitor_three_pane) printf '%%3\n' ;;
	@agent_monitor_three_updated_at) printf '1000\n' ;;
	@agent_monitor_four_name) printf 'codex\n' ;;
	@agent_monitor_four_state) printf 'needs-attention\n' ;;
	@agent_monitor_four_label) printf 'old\n' ;;
	@agent_monitor_four_pane) printf '%%4\n' ;;
	@agent_monitor_four_updated_at) printf '600\n' ;;
	@thm_bg) printf 'default\n' ;;
	@thm_overlay_0) printf 'overlay\n' ;;
	@thm_green) printf 'green\n' ;;
	@thm_blue) printf 'blue\n' ;;
	@thm_red) printf 'red\n' ;;
	@agent_status_separator) printf '│\n' ;;
	*) return 0 ;;
	esac
}

case "$1" in
show-options)
	option_value "$3"
	;;
set-option)
	printf '%s\t%s\n' "$3" "$4" >>"${TMUX_SET_LOG:?}"
	;;
list-panes|capture-pane)
	printf 'not ok - renderer should not scan panes\n' >&2
	exit 1
	;;
*)
	exit 1
	;;
esac
FAKE_TMUX
chmod +x "$TMP_DIR/tmux"

cat >"$TMP_DIR/ps" <<'FAKE_PS'
#!/usr/bin/env bash
printf 'not ok - renderer should not inspect processes\n' >&2
exit 1
FAKE_PS
chmod +x "$TMP_DIR/ps"

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

PATH="$TMP_DIR:$PATH"
export AGENT_STATUS_NOW=1000
export TMUX_SET_LOG="$TMP_DIR/set-options.log"

actual="$("$SCRIPT" --once)"
expected='#[range=pane|%1]#[bg=default,fg=green] ##[evil]work#[norange]#[bg=default,fg=overlay,none] │ #[range=pane|%2]#[bg=default,fg=red] review#[norange]#[bg=default,fg=overlay,none] │ #[range=pane|%3]#[bg=default,fg=blue] ship#[norange]#[bg=default,fg=overlay,none] │ #[range=pane|%4]#[bg=default,fg=overlay] old#[norange]'
assert_equal "$expected" "$actual" "renders monitor records with event colors and timeout decay"

actual="$(AGENT_STATUS_ENABLED=off "$SCRIPT" --once)"
assert_equal "" "$actual" "prints nothing when disabled"

cache_file="$TMP_DIR/agent-status.cache"
printf 'cached status\n' >"$cache_file"
actual="$(TMUX_AGENT_STATUS_CACHE="$cache_file" "$SCRIPT")"
assert_equal "cached status" "$actual" "prints cached status immediately by default"

rm -f "$cache_file"
: >"$TMUX_SET_LOG"
TMUX_AGENT_STATUS_CACHE="$cache_file" "$SCRIPT" --refresh
actual="$(cat "$cache_file")"
assert_equal "$expected" "$actual" "refresh updates the status cache"
assert_equal "@agent_monitor_status	$expected" "$(tail -1 "$TMUX_SET_LOG")" "refresh updates tmux monitor status option"
