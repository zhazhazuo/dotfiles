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

# ── stale subagent demotion ──────────────────────────────────────────────
# herdr entries are skipped by the tmux sweep, so an abandoned orange is only
# cleaned up by the heartbeat check.
NOW=$(date +%s)
export AGENT_MONITOR_SUBAGENT_STALE_SECONDS=150
cat >"$AGENT_MONITOR_STATE_DIR/state.json" <<JSON
{"version":1,"agents":{
 "w3_p47":{"name":"herdr","state":"subagents-running","label":"AI-Report","pane":"w3:p47","session_id":"","updated_at":100,"subagents_count":1,"subagents_checked_at":$((NOW - 300))},
 "w4_p11":{"name":"herdr","state":"subagents-running","label":"FRESH","pane":"w4:p11","session_id":"","updated_at":100,"subagents_count":1,"subagents_checked_at":$((NOW - 10))},
 "w5_p12":{"name":"herdr","state":"subagents-running","label":"NOHEARTBEAT","pane":"w5:p12","session_id":"","updated_at":100},
 "w6_p13":{"name":"herdr","state":"needs-attention","label":"BLUE","pane":"w6:p13","session_id":"","updated_at":100}
}}
JSON

"$BIN" prune
assert_jq "stale parked agent demoted to needs-attention" '.agents["w3_p47"].state == "needs-attention"'
assert_jq "stale demotion clears the count" '.agents["w3_p47"].subagents_count == 0'
assert_jq "fresh heartbeat survives prune" '.agents["w4_p11"].state == "subagents-running"'
assert_jq "missing heartbeat is treated as abandoned" '.agents["w5_p12"].state == "needs-attention"'
assert_jq "needs-attention untouched" '.agents["w6_p13"].state == "needs-attention"'

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi
echo "all prune tests passed"
