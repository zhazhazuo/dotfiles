#!/usr/bin/env bash
#
# tests/prune.test.sh — prune must skip herdr agents

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT_DIR/bin/agent-monitor"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export AGENT_MONITOR_STATE_DIR="$TMP_DIR/state"
export AGENT_MONITOR_FRONT_APP="Ghostty"
mkdir -p "$AGENT_MONITOR_STATE_DIR"

# Fake tmux: only pane %1 is alive
mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/tmux" <<'FAKE'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then
	printf '%%1\n'
	exit 0
fi
exit 0
FAKE
chmod +x "$TMP_DIR/bin/tmux"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_DIR/bin/sketchybar"
chmod +x "$TMP_DIR/bin/sketchybar"
export PATH="$TMP_DIR/bin:$PATH"

cat >"$AGENT_MONITOR_STATE_DIR/state.json" <<'JSON'
{"version":1,"agents":{
 "%1":{"name":"pi","state":"running","label":"live","pane":"%1","session_id":"","updated_at":100},
 "%99":{"name":"pi","state":"running","label":"dead","pane":"%99","session_id":"","updated_at":100},
 "w2_p4":{"name":"herdr","state":"running","label":"SF","pane":"w2:p4","session_id":"","updated_at":100}
}}
JSON

"$BIN" prune

fail=0
assert_jq() {
	local desc="$1" filter="$2"
	if jq -e "$filter" "$AGENT_MONITOR_STATE_DIR/state.json" >/dev/null 2>&1; then
		echo "ok: $desc"
	else
		echo "FAIL: $desc"
		fail=1
	fi
}

assert_jq "dead tmux pane pruned" '.agents["%99"] == null'
assert_jq "herdr agent kept despite non-tmux pane id" '.agents["w2_p4"] != null'

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi
echo "all prune tests passed"
