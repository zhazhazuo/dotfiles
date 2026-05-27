#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/agent-monitor-state.sh"
TMP_DIR="$(mktemp -d)"
STORE="$TMP_DIR/options"
STATE_FILE="$TMP_DIR/agent-state.tsv"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

store="${TMUX_OPTION_STORE:?}"

get_option() {
	local option="$1"
	awk -F '\t' -v key="$option" '$1 == key { value = $2 } END { if (value != "") print value }' "$store" 2>/dev/null || true
}

case "$1" in
show-options)
	get_option "$3"
	;;
*)
	exit 1
	;;
esac
FAKE_TMUX
chmod +x "$TMP_DIR/tmux"

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
export TMUX_OPTION_STORE="$STORE"
export AGENT_MONITOR_STATE_FILE="$STATE_FILE"

cat >"$STORE" <<'OPTIONS'
@agent_monitor_instances	one two
@agent_monitor_attention_timeout	300
@agent_monitor_one_name	codex
@agent_monitor_one_state	running
@agent_monitor_one_label	work
@agent_monitor_one_pane	%1
@agent_monitor_one_session_id	session-1
@agent_monitor_one_updated_at	100
@agent_monitor_two_name	pi
@agent_monitor_two_state	needs-help
@agent_monitor_two_label	review branch
@agent_monitor_two_pane	%2
@agent_monitor_two_session_id	session-2
@agent_monitor_two_updated_at	120
OPTIONS

"$SCRIPT" --refresh

expected=$'id\tname\tstate\tlabel\tpane\tsession_id\tupdated_at\none\tcodex\trunning\twork\t%1\tsession-1\t100\ntwo\tpi\tneeds-help\treview branch\t%2\tsession-2\t120'
assert_equal "$expected" "$(cat "$STATE_FILE")" "exports monitor records as normalized TSV"
assert_equal "$expected" "$("$SCRIPT" --print)" "prints shared state file"

cat >"$STORE" <<'OPTIONS'
@agent_monitor_instances	one two
@agent_monitor_attention_timeout	300
@agent_monitor_one_name	codex
@agent_monitor_one_state	needs-attention
@agent_monitor_one_label	stale
@agent_monitor_one_pane	%1
@agent_monitor_one_session_id	session-1
@agent_monitor_one_updated_at	600
@agent_monitor_two_name	codex
@agent_monitor_two_state	needs-attention
@agent_monitor_two_label	fresh
@agent_monitor_two_pane	%2
@agent_monitor_two_session_id	session-2
@agent_monitor_two_updated_at	900
OPTIONS

AGENT_MONITOR_STATE_NOW=1000 "$SCRIPT" --refresh
expected=$'id\tname\tstate\tlabel\tpane\tsession_id\tupdated_at\none\tcodex\tidle\tstale\t%1\tsession-1\t600\ntwo\tcodex\tneeds-attention\tfresh\t%2\tsession-2\t900'
assert_equal "$expected" "$(cat "$STATE_FILE")" "decays old attention records to idle for shared consumers"

printf '@agent_monitor_instances\t\n' >"$STORE"
"$SCRIPT" --refresh
assert_equal $'id\tname\tstate\tlabel\tpane\tsession_id\tupdated_at' "$(cat "$STATE_FILE")" "writes header when no agents are active"
