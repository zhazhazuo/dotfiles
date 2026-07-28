#!/usr/bin/env bash
#
# tests/reconcile.test.sh — core reconcile identity/label behavior

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT_DIR/bin/agent-monitor"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export AGENT_MONITOR_STATE_DIR="$TMP_DIR/state"
export AGENT_MONITOR_FRONT_APP="Ghostty" # suppress macOS notifications
unset TMUX_PANE || true

# Neutralize sink side effects
mkdir -p "$TMP_DIR/bin"
for tool in sketchybar tmux; do
	printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_DIR/bin/$tool"
	chmod +x "$TMP_DIR/bin/$tool"
done
export PATH="$TMP_DIR/bin:$PATH"

fail=0
assert_jq() { # <description> <jq-filter>
	local desc="$1" filter="$2"
	if jq -e "$filter" "$AGENT_MONITOR_STATE_DIR/state.json" >/dev/null 2>&1; then
		echo "ok: $desc"
	else
		echo "FAIL: $desc"
		fail=1
	fi
}

# ── herdr pane_id identity + explicit label ──────────────────────────────
"$BIN" reconcile herdr RunStart '{"pane_id":"w2:p4","label":"SF","cwd":"/tmp/x"}'
assert_jq "pane_id becomes sanitized id" '.agents["w2_p4"] != null'
assert_jq "raw pane id stored in pane field" '.agents["w2_p4"].pane == "w2:p4"'
assert_jq "explicit label wins" '.agents["w2_p4"].label == "SF"'
assert_jq "state is running" '.agents["w2_p4"].state == "running"'
assert_jq "name is herdr" '.agents["w2_p4"].name == "herdr"'

# ── label fallback: cwd basename ─────────────────────────────────────────
"$BIN" reconcile herdr RunStart '{"pane_id":"w9:p1","cwd":"/tmp/proj"}'
assert_jq "label falls back to cwd basename" '.agents["w9_p1"].label == "proj"'

# ── backward compatibility ───────────────────────────────────────────────
"$BIN" reconcile pi RunStart '{"session_id":"sess-1","cwd":"/tmp/y"}'
assert_jq "session_id identity unchanged" '.agents["sess_1"] != null'

TMUX_PANE="%5" "$BIN" reconcile pi RunStart '{"cwd":"/tmp/z"}'
assert_jq "TMUX_PANE identity unchanged" '.agents["%5"] != null'

# ── TSV export on refresh ────────────────────────────────────────────────
TSV="$AGENT_MONITOR_STATE_DIR/state.tsv"
if [[ -f "$TSV" ]] && grep -q $'^w2_p4\therdr\trunning\tSF\tw2:p4' "$TSV"; then
	echo "ok: state.tsv exported with herdr row"
else
	echo "FAIL: state.tsv exported with herdr row"
	fail=1
fi

# ── remove refreshes sinks ───────────────────────────────────────────────
"$BIN" remove w2_p4 >/dev/null
if ! grep -q 'w2_p4' "$TSV"; then
	echo "ok: remove updates state.tsv"
else
	echo "FAIL: remove updates state.tsv"
	fail=1
fi

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi
echo "all reconcile tests passed"
