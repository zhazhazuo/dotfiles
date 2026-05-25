#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/agent-monitor-prune.sh"
TMP_DIR="$(mktemp -d)"
STORE="$TMP_DIR/options"

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

set_option() {
	local option="$1"
	local value="$2"
	local tmp="${store}.$$"

	touch "$store"
	awk -F '\t' -v key="$option" '$1 != key { print }' "$store" >"$tmp"
	printf '%s\t%s\n' "$option" "$value" >>"$tmp"
	mv "$tmp" "$store"
}

unset_option() {
	local option="$1"
	local tmp="${store}.$$"

	touch "$store"
	awk -F '\t' -v key="$option" '$1 != key { print }' "$store" >"$tmp"
	mv "$tmp" "$store"
}

case "$1" in
show-options)
	get_option "$3"
	;;
set-option)
	if [[ "${2:-}" == "-guq" ]]; then
		unset_option "$3"
	else
		set_option "$3" "${4:-}"
	fi
	;;
list-panes)
	printf '%%1\n%%2\n%%3\n'
	;;
display-message)
	case "$4" in
	%1) printf '/dev/ttys001\n' ;;
	%2) printf '/dev/ttys002\n' ;;
	%3) printf '/dev/ttys003\n' ;;
	*) exit 1 ;;
	esac
	;;
refresh-client)
	exit 0
	;;
*)
	exit 1
	;;
esac
FAKE_TMUX
chmod +x "$TMP_DIR/tmux"

cat >"$TMP_DIR/ps" <<'FAKE_PS'
#!/usr/bin/env bash

set -euo pipefail

tty=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	-t)
		tty="$2"
		shift 2
		;;
	*)
		shift
		;;
	esac
done

case "$tty" in
ttys001)
	printf 'zsh zsh\n'
	printf 'codex codex --model gpt-5\n'
	;;
ttys002)
	printf 'zsh zsh\n'
	;;
ttys003)
	printf 'zsh zsh\n'
	;;
*)
	exit 1
	;;
esac
FAKE_PS
chmod +x "$TMP_DIR/ps"

cat >"$TMP_DIR/agent-status.sh" <<'FAKE_STATUS'
#!/usr/bin/env bash
exit 0
FAKE_STATUS
chmod +x "$TMP_DIR/agent-status.sh"

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

cat >"$STORE" <<'OPTIONS'
@agent_monitor_instances	one two two three
@agent_monitor_one_name	codex
@agent_monitor_one_state	running
@agent_monitor_one_label	work
@agent_monitor_one_pane	%1
@agent_monitor_one_session_id	session-1
@agent_monitor_one_updated_at	100
@agent_monitor_two_name	codex
@agent_monitor_two_state	running
@agent_monitor_two_label	dead
@agent_monitor_two_pane	%2
@agent_monitor_two_session_id	session-2
@agent_monitor_two_updated_at	100
@agent_monitor_three_name	codex
@agent_monitor_three_state	running
@agent_monitor_three_label	logical
@agent_monitor_three_pane	
@agent_monitor_three_session_id	session-3
@agent_monitor_three_updated_at	100
OPTIONS

"$SCRIPT"

assert_equal "one three" "$(tmux show-options -gqv @agent_monitor_instances)" "removes dead panes or stopped processes and deduplicates instances"
assert_equal "" "$(tmux show-options -gqv @agent_monitor_two_name)" "unsets pruned name"
assert_equal "" "$(tmux show-options -gqv @agent_monitor_two_state)" "unsets pruned state"
assert_equal "codex" "$(tmux show-options -gqv @agent_monitor_one_name)" "keeps live pane record"
assert_equal "codex" "$(tmux show-options -gqv @agent_monitor_three_name)" "keeps records without pane metadata"
