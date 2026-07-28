#!/usr/bin/env bash
#
# tests/herdr-adapter.test.sh — herdr source adapter

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADAPTER="$ROOT_DIR/adapters/herdr.sh"
BIN="$ROOT_DIR/bin/agent-monitor"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export AGENT_MONITOR_STATE_DIR="$TMP_DIR/state"
export AGENT_MONITOR_FRONT_APP="Ghostty"
export FAKE_HERDR_SNAPSHOT="$TMP_DIR/snapshot.json"
unset TMUX_PANE || true

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
if [[ "${1:-}" == "api" && "${2:-}" == "snapshot" ]]; then
	cat "${FAKE_HERDR_SNAPSHOT:?}"
	exit 0
fi
exit 1
FAKE
for tool in sketchybar tmux; do
	printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_DIR/bin/$tool"
	chmod +x "$TMP_DIR/bin/$tool"
done
chmod +x "$TMP_DIR/bin/herdr"
export PATH="$TMP_DIR/bin:$PATH"

cat >"$FAKE_HERDR_SNAPSHOT" <<'JSON'
{"id":"cli:api:snapshot","result":{"snapshot":{
 "agents":[
  {"agent":"pi","agent_status":"working","cwd":"/work/sf","pane_id":"w2:p4","tab_id":"w2:t1"},
  {"agent":"pi","agent_status":"blocked","cwd":"/work/brain","pane_id":"w4:p2","tab_id":"w4:t1"},
  {"agent":"pi","agent_status":"done","cwd":"/work/wiki","pane_id":"w5:p1","tab_id":"w5:t1"},
  {"agent":"pi","agent_status":"idle","cwd":"/work/play","pane_id":"w6:p1","tab_id":"w6:t1"},
  {"agent":"pi","agent_status":"unknown","cwd":"/work/none","pane_id":"w7:p1","tab_id":"w7:t1"},
  {"agent":"pi","agent_status":"working","cwd":"/work/fallback","pane_id":"w8:p1","tab_id":"w8:t9"}
 ],
 "tabs":[
  {"tab_id":"w2:t1","label":"SF"},
  {"tab_id":"w4:t1","label":"BRAIN"},
  {"tab_id":"w5:t1","label":"WIKI"},
  {"tab_id":"w6:t1","label":"PLAY"},
  {"tab_id":"w7:t1","label":"NONE"}
 ]
}},"type":"session_snapshot"}
JSON

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

# ── status mapping via single events ─────────────────────────────────────
HERDR_PANE_ID="w2:p4" "$ADAPTER" pane.agent_status_changed
assert_jq "working -> running" '.agents["w2_p4"].state == "running"'
assert_jq "tab label used" '.agents["w2_p4"].label == "SF"'

HERDR_PANE_ID="w4:p2" "$ADAPTER" pane.agent_status_changed
assert_jq "blocked -> needs-help" '.agents["w4_p2"].state == "needs-help"'

HERDR_PANE_ID="w5:p1" "$ADAPTER" pane.agent_status_changed
assert_jq "done -> needs-attention" '.agents["w5_p1"].state == "needs-attention"'

HERDR_PANE_ID="w6:p1" "$ADAPTER" pane.agent_detected
assert_jq "idle -> idle" '.agents["w6_p1"].state == "idle"'

HERDR_PANE_ID="w7:p1" "$ADAPTER" pane.agent_status_changed
assert_jq "unknown -> not tracked" '.agents["w7_p1"] == null'

HERDR_PANE_ID="w8:p1" "$ADAPTER" pane.agent_status_changed
assert_jq "missing tab -> cwd basename label" '.agents["w8_p1"].label == "fallback"'

# ── unknown event removes a tracked agent ────────────────────────────────
HERDR_PANE_ID="w6:p1" "$ADAPTER" pane.agent_status_changed # idle, tracked
cat >"$FAKE_HERDR_SNAPSHOT" <<'JSON'
{"id":"cli:api:snapshot","result":{"snapshot":{"agents":[],"tabs":[]}},"type":"session_snapshot"}
JSON
HERDR_PANE_ID="w6:p1" "$ADAPTER" pane.agent_status_changed
assert_jq "agent gone from snapshot -> removed" '.agents["w6_p1"] == null'

# ── pane.closed removes ──────────────────────────────────────────────────
HERDR_PANE_ID="w2:p4" "$ADAPTER" pane.closed
assert_jq "pane.closed removes entry" '.agents["w2_p4"] == null'

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi
echo "all herdr adapter event tests passed"

# ── sync mode ────────────────────────────────────────────────────────────
rm -rf "$AGENT_MONITOR_STATE_DIR"
mkdir -p "$AGENT_MONITOR_STATE_DIR"
cat >"$AGENT_MONITOR_STATE_DIR/state.json" <<'JSON'
{"version":1,"agents":{
 "w9_p9":{"name":"herdr","state":"running","label":"STALE","pane":"w9:p9","session_id":"","updated_at":1},
 "%3":{"name":"pi","state":"running","label":"tmux","pane":"%3","session_id":"","updated_at":1}
}}
JSON

cat >"$FAKE_HERDR_SNAPSHOT" <<'JSON'
{"id":"cli:api:snapshot","result":{"snapshot":{
 "agents":[
  {"agent":"pi","agent_status":"working","cwd":"/work/sf","pane_id":"w2:p4","tab_id":"w2:t1"}
 ],
 "tabs":[{"tab_id":"w2:t1","label":"SF"}]
}},"type":"session_snapshot"}
JSON

"$ADAPTER" --sync
assert_jq "sync adds live agent" '.agents["w2_p4"].state == "running"'
assert_jq "sync removes stale herdr entry" '.agents["w9_p9"] == null'
assert_jq "sync keeps tmux agents" '.agents["%3"] != null'

# ── plugin dispatcher ────────────────────────────────────────────────────
rm -rf "$AGENT_MONITOR_STATE_DIR"
cat >"$FAKE_HERDR_SNAPSHOT" <<'JSON'
{"id":"cli:api:snapshot","result":{"snapshot":{
 "agents":[
  {"agent":"pi","agent_status":"blocked","cwd":"/work/brain","pane_id":"w4:p2","tab_id":"w4:t1"}
 ],
 "tabs":[{"tab_id":"w4:t1","label":"BRAIN"}]
}},"type":"session_snapshot"}
JSON

HERDR_PLUGIN_EVENT="pane.agent_status_changed" HERDR_PANE_ID="w4:p2" \
	"$ROOT_DIR/herdr-plugin/on-event.sh"
assert_jq "dispatcher routes event to adapter" '.agents["w4_p2"].state == "needs-help"'

HERDR_PLUGIN_EVENT="startup" "$ROOT_DIR/herdr-plugin/on-event.sh"
assert_jq "dispatcher startup runs sync" '.agents["w4_p2"] != null'

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi
echo "all herdr adapter and dispatcher tests passed"
