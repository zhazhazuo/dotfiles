#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/plugins/agent_monitor.sh"
TMP_DIR="$(mktemp -d)"
STATE_FILE="$TMP_DIR/agent-state.tsv"
SET_LOG="$TMP_DIR/sketchybar-set.log"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/sketchybar" <<'FAKE_SKETCHYBAR'
#!/usr/bin/env bash

set -euo pipefail

if [[ "${1:-}" == "--query" ]]; then
	exit 1
fi

printf '%s\n' "$*" >>"${SKETCHYBAR_SET_LOG:?}"
FAKE_SKETCHYBAR
chmod +x "$TMP_DIR/sketchybar"

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
export AGENT_MONITOR_STATE_FILE="$STATE_FILE"
export AGENT_MONITOR_SKETCHYBAR_CACHE="$TMP_DIR/items.cache"
export SKETCHYBAR_SET_LOG="$SET_LOG"
export NAME="agent_monitor"

cat >"$STATE_FILE" <<'STATE'
id	name	state	label	pane	session_id	updated_at
one	codex	running	work	%1	session-1	100
three	codex	idle	docs	%3	session-3	90
two	pi	needs-help	review	%2	session-2	120
STATE

"$SCRIPT"
expected=$'--set agent_monitor drawing=off\n--add item agent_monitor.two center\n--set agent_monitor.two drawing=on icon.drawing=off label=review label.color=0xffffffff background.drawing=on background.color=0xffc0392b background.corner_radius=5 background.height=20 click_script=tmux select-window -t %2; tmux select-pane -t %2\n--add item agent_monitor.one center\n--set agent_monitor.one drawing=on icon.drawing=off label=work label.color=0xffffffff background.drawing=on background.color=0xff238636 background.corner_radius=5 background.height=20 click_script=tmux select-window -t %1; tmux select-pane -t %1\n--add item agent_monitor.three center\n--set agent_monitor.three drawing=on icon.drawing=off label=docs label.color=0xffaaaaaa background.drawing=off background.color=0x00000000 background.corner_radius=5 background.height=20 click_script=tmux select-window -t %3; tmux select-pane -t %3'
assert_equal "$expected" "$(cat "$SET_LOG")" "renders workspace-style items per agent state"

cat >"$STATE_FILE" <<'STATE'
id	name	state	label	pane	session_id	updated_at
one	codex	running	work	%1	session-1	100
two	pi	needs-attention	ship	%2	session-2	120
STATE
: >"$SET_LOG"
"$SCRIPT"
expected=$'--remove agent_monitor.three\n--set agent_monitor drawing=off\n--add item agent_monitor.two center\n--set agent_monitor.two drawing=on icon.drawing=off label=ship label.color=0xffffffff background.drawing=on background.color=0xff1f6feb background.corner_radius=5 background.height=20 click_script=tmux select-window -t %2; tmux select-pane -t %2\n--add item agent_monitor.one center\n--set agent_monitor.one drawing=on icon.drawing=off label=work label.color=0xffffffff background.drawing=on background.color=0xff238636 background.corner_radius=5 background.height=20 click_script=tmux select-window -t %1; tmux select-pane -t %1'
assert_equal "$expected" "$(cat "$SET_LOG")" "removes stale items and keeps per-agent colors"

cat >"$STATE_FILE" <<'STATE'
id	name	state	label	pane	session_id	updated_at
one	codex	running	work	%1	session-1	100
STATE
: >"$SET_LOG"
"$SCRIPT"
expected=$'--remove agent_monitor.two\n--set agent_monitor drawing=off\n--add item agent_monitor.one center\n--set agent_monitor.one drawing=on icon.drawing=off label=work label.color=0xffffffff background.drawing=on background.color=0xff238636 background.corner_radius=5 background.height=20 click_script=tmux select-window -t %1; tmux select-pane -t %1'
assert_equal "$expected" "$(cat "$SET_LOG")" "renders running state"

cat >"$STATE_FILE" <<'STATE'
id	name	state	label	pane	session_id	updated_at
one	codex	idle	docs	%1	session-1	100
STATE
: >"$SET_LOG"
"$SCRIPT"
assert_equal "--set agent_monitor drawing=off
--add item agent_monitor.one center
--set agent_monitor.one drawing=on icon.drawing=off label=docs label.color=0xffaaaaaa background.drawing=off background.color=0x00000000 background.corner_radius=5 background.height=20 click_script=tmux select-window -t %1; tmux select-pane -t %1" "$(cat "$SET_LOG")" "renders idle state in gray"

printf 'id\tname\tstate\tlabel\tpane\tsession_id\tupdated_at\n' >"$STATE_FILE"
: >"$SET_LOG"
"$SCRIPT"
assert_equal "--remove agent_monitor.one
--set agent_monitor drawing=off" "$(cat "$SET_LOG")" "hides item when no agents are active"
