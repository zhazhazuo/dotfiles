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
  {"agent":"pi","agent_status":"working","cwd":"/work/fallback","pane_id":"w8:p1","tab_id":"w8:t9"},
  {"agent":"pi","agent_status":"done","cwd":"/work/subs","pane_id":"w9:p1","tab_id":"w9:t1",
   "state_labels":{"idle":"⏳ 1 subagent (sdd-implementer)","done":"⏳ 1 subagent (sdd-implementer)","working":"⏳ 1 subagent (sdd-implementer)"},
   "tokens":{"summary":"⏳ 1 subagent (sdd-implementer)"}},
  {"agent":"pi","agent_status":"idle","cwd":"/work/many","pane_id":"w9:p2","tab_id":"w9:t2",
   "state_labels":{"idle":"⏳ 3 subagents (a, b, c)"}},
  {"agent":"pi","agent_status":"working","cwd":"/work/busy","pane_id":"w9:p3","tab_id":"w9:t3",
   "state_labels":{"working":"⏳ 1 subagent (a)"}},
  {"agent":"pi","agent_status":"blocked","cwd":"/work/stuck","pane_id":"w9:p4","tab_id":"w9:t4",
   "state_labels":{"blocked":"⏳ 1 subagent (a)"}},
  {"agent":"pi","agent_status":"done","cwd":"/work/tokenonly","pane_id":"w9:p5","tab_id":"w9:t5",
   "tokens":{"summary":"⏳ 2 subagents (a, b)"}},
  {"agent":"pi","agent_status":"done","cwd":"/work/indexer","pane_id":"w9:p6","tab_id":"w9:t6",
   "state_labels":{"done":"indexing"},"tokens":{"summary":"indexing"}}
 ],
 "tabs":[
  {"tab_id":"w2:t1","label":"SF"},
  {"tab_id":"w4:t1","label":"BRAIN"},
  {"tab_id":"w5:t1","label":"WIKI"},
  {"tab_id":"w6:t1","label":"PLAY"},
  {"tab_id":"w7:t1","label":"NONE"},
  {"tab_id":"w9:t1","label":"SUBS"},
  {"tab_id":"w9:t2","label":"MANY"},
  {"tab_id":"w9:t3","label":"BUSY"},
  {"tab_id":"w9:t4","label":"STUCK"},
  {"tab_id":"w9:t5","label":"TOKENONLY"},
  {"tab_id":"w9:t6","label":"INDEXER"}
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

# ── subagent state: parked main agent, workers still running ─────────────
HERDR_PANE_ID="w9:p1" "$ADAPTER" pane.agent_status_changed
assert_jq "done + subagent labels -> subagents-running" '.agents["w9_p1"].state == "subagents-running"'
assert_jq "subagent count stored" '.agents["w9_p1"].subagents_count == 1'
assert_jq "heartbeat recorded" '.agents["w9_p1"].subagents_checked_at > 0'

HERDR_PANE_ID="w9:p2" "$ADAPTER" pane.agent_detected
assert_jq "idle + subagent labels -> subagents-running" '.agents["w9_p2"].state == "subagents-running"'
assert_jq "plural count parsed" '.agents["w9_p2"].subagents_count == 3'

HERDR_PANE_ID="w9:p3" "$ADAPTER" pane.agent_status_changed
assert_jq "working wins over subagent labels" '.agents["w9_p3"].state == "running"'

HERDR_PANE_ID="w9:p4" "$ADAPTER" pane.agent_status_changed
assert_jq "blocked wins over subagent labels" '.agents["w9_p4"].state == "needs-help"'

HERDR_PANE_ID="w9:p5" "$ADAPTER" pane.agent_status_changed
assert_jq "summary token alone detects subagents" '.agents["w9_p5"].state == "subagents-running"'

HERDR_PANE_ID="w9:p6" "$ADAPTER" pane.agent_status_changed
assert_jq "unrelated metadata does not fake subagents" '.agents["w9_p6"].state == "needs-attention"'

# ── repeated report refreshes keep a parked agent alive ──────────────────
# pi-subagents republishes its labels every 45s. That is a no-op transition
# (still subagents-running), but it must refresh the heartbeat — otherwise
# prune would demote a working session as abandoned, and the sinks must not
# see updated_at move (they sort on it).
OLD=$(( $(date +%s) - 400 ))
jq --argjson ts "$OLD" '.agents["w9_p2"].subagents_checked_at = $ts | .agents["w9_p2"].updated_at = 123' \
	"$AGENT_MONITOR_STATE_DIR/state.json" >"$AGENT_MONITOR_STATE_DIR/tmp.json"
mv "$AGENT_MONITOR_STATE_DIR/tmp.json" "$AGENT_MONITOR_STATE_DIR/state.json"

HERDR_PANE_ID="w9:p2" "$ADAPTER" pane.agent_status_changed
assert_jq "refresh keeps the parked state" '.agents["w9_p2"].state == "subagents-running"'
assert_jq "refresh renews the heartbeat" ".agents[\"w9_p2\"].subagents_checked_at > $OLD"
assert_jq "refresh leaves updated_at alone" '.agents["w9_p2"].updated_at == 123'

AGENT_MONITOR_SUBAGENT_STALE_SECONDS=150 "$BIN" prune
assert_jq "refreshed parked agent survives prune" '.agents["w9_p2"].state == "subagents-running"'

# ── exiting the subagent state ───────────────────────────────────────────
cat >"$FAKE_HERDR_SNAPSHOT" <<'JSON'
{"id":"cli:api:snapshot","result":{"snapshot":{
 "agents":[
  {"agent":"pi","agent_status":"done","cwd":"/work/subs","pane_id":"w9:p1","tab_id":"w9:t1"}
 ],
 "tabs":[{"tab_id":"w9:t1","label":"SUBS"}]
}},"type":"session_snapshot"}
JSON
HERDR_PANE_ID="w9:p1" "$ADAPTER" pane.agent_status_changed
assert_jq "labels cleared -> needs-attention" '.agents["w9_p1"].state == "needs-attention"'
assert_jq "count reset on exit" '.agents["w9_p1"].subagents_count == 0'

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
