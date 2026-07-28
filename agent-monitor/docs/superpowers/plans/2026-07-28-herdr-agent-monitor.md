# Herdr Source for agent-monitor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make herdr the event source of truth for agent-monitor so herdr agents render in SketchyBar (and tmux) with click-to-focus via `herdr agent focus`.

**Architecture:** A herdr plugin (`herdr-plugin/`) pushes herdr events (`pane.agent_status_changed`, `pane.agent_detected`, `pane.closed`) and a startup sync into a new `adapters/herdr.sh`, which normalizes herdr `agent_status` values to the existing generic events and calls `agent-monitor reconcile herdr …`. Core and sinks get small additive changes only.

**Tech Stack:** bash, jq, POSIX sh (sink), herdr plugin manifest (TOML), SketchyBar.

**Spec:** `docs/superpowers/specs/2026-07-28-herdr-agent-monitor-design.md`

## Global Constraints

- State mapping: `working→RunStart`, `blocked→PermissionRequest`, `done→TurnComplete`, `idle→SessionStart`, `unknown` → ignore/remove. No core state-machine changes.
- Label = herdr **tab label**; fallback = cwd basename.
- Click for herdr panes = `herdr agent focus <pane_id>`; tmux panes (`%…`) keep the existing tmux click script.
- Herdr pane ids (`w2:p4`) are sanitized to `w2_p4` for state keys / item names; the raw id is stored in the `pane` field.
- `prune` must never touch agents named `herdr`.
- All existing tests must pass unchanged.
- Tests must export `AGENT_MONITOR_FRONT_APP=Ghostty` (suppresses real macOS notifications) and put fake `herdr`/`sketchybar`/`tmux` binaries first on `PATH`.
- Test style: plain bash with `assert` helpers, `mktemp -d` + `trap … EXIT`, like `sketchybar/tests/agent-monitor.test.sh`.
- All work happens in `/Users/walkerw/dotfiles/agent-monitor` (repo root below), except Task 6's test file in `/Users/walkerw/dotfiles/sketchybar`.

---

### Task 1: Core identity and label support in reconcile.sh

**Files:**
- Modify: `core/reconcile.sh` (functions `resolve_id`, `resolve_label`)
- Test: `tests/reconcile.test.sh` (new)

**Interfaces:**
- Consumes: existing `agent-monitor reconcile <agent> <event> <json>` CLI.
- Produces: event JSON may now carry `pane_id` (becomes the sanitized agent id) and `label` (preferred display label). Later tasks rely on: id of `{"pane_id":"w2:p4"}` = `w2_p4`, stored `pane` field = raw `w2:p4`.

- [ ] **Step 1: Write the failing test**

Create `tests/reconcile.test.sh`:

```bash
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

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi
echo "all reconcile tests passed"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/reconcile.test.sh`
Expected: FAIL on "pane_id becomes sanitized id" (id resolves to `x`, the cwd basename, today) and on "explicit label wins".

- [ ] **Step 3: Implement the changes**

In `core/reconcile.sh`, add a `pane_id` step to `resolve_id`, after the `TMUX_PANE` step and before the `session_id` step:

```bash
	# 2.5. Explicit pane_id in event JSON (herdr)
	local pane_id
	pane_id=$(printf '%s' "$json" | jq -r '.pane_id // empty' 2>/dev/null)
	if [[ -n "$pane_id" ]]; then
		printf '%s' "$pane_id" | tr -c '[:alnum:]_' '_'
		return 0
	fi
```

In `core/reconcile.sh`, add explicit-label preference at the top of `resolve_label` (before the tmux window-name lookup):

```bash
	# Explicit label in event JSON wins (herdr tab label)
	label=$(printf '%s' "$json" | jq -r '.label // empty' 2>/dev/null)
	if [[ -n "$label" ]]; then
		printf '%s' "$label"
		return 0
	fi
```

(`resolve_label` already declares `local label`; the new block reuses it.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/reconcile.test.sh`
Expected: PASS — "all reconcile tests passed"

- [ ] **Step 5: Commit**

```bash
git add core/reconcile.sh tests/reconcile.test.sh
git commit -m "feat: accept pane_id and label in reconcile event JSON"
```

---

### Task 2: Sink refresh pipeline — single refresh_sinks, TSV export, remove refreshes

**Files:**
- Modify: `core/state.sh` (add `refresh_sinks`)
- Modify: `core/reconcile.sh` (delete its `refresh_sinks` copy)
- Modify: `core/prune.sh` (delete its `refresh_sinks` copy)
- Modify: `bin/agent-monitor` (`cmd_remove` calls `refresh_sinks`)
- Test: `tests/reconcile.test.sh` (extend)

**Interfaces:**
- Consumes: `print_tsv`, `ensure_state_dir`, `STATE_DIR` (all already in `state.sh`).
- Produces: `refresh_sinks` (defined once in `state.sh`, available to anything sourcing it). Side effect: every refresh atomically writes `$STATE_DIR/state.tsv` — the file the SketchyBar sink reads (Task 6). `agent-monitor remove <id>` now refreshes sinks.

- [ ] **Step 1: Extend the test (failing)**

Append to `tests/reconcile.test.sh`, before the final `fail` check:

```bash
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
```

Run: `bash tests/reconcile.test.sh`
Expected: FAIL on both new assertions (`state.tsv` does not exist).

- [ ] **Step 2: Implement**

Add to the end of `core/state.sh`:

```bash
# ── Sink Refresh ─────────────────────────────────────────────────────────

# Refresh all sinks after a state change. Single definition, used by
# reconcile.sh, prune.sh, and bin/agent-monitor.
refresh_sinks() {
	local core_dir sinks_dir tsv_tmp
	core_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	sinks_dir="${core_dir}/../sinks"

	# Export TSV for the SketchyBar sink (atomic write)
	ensure_state_dir
	tsv_tmp="${STATE_DIR}/state.tsv.$$"
	print_tsv >"$tsv_tmp"
	mv "$tsv_tmp" "${STATE_DIR}/state.tsv"

	if [[ -x "${sinks_dir}/tmux-status.sh" ]]; then
		"${sinks_dir}/tmux-status.sh" --refresh 2>/dev/null || true
	fi

	if command -v sketchybar >/dev/null 2>&1; then
		(sketchybar --trigger agent_monitor_update 2>/dev/null || true) &
	fi

	tmux refresh-client -S 2>/dev/null || true
}
```

In `core/reconcile.sh`: delete the entire `refresh_sinks()` function and its `# ── Sink Refresh ──` header comment (the `refresh_sinks` call inside `reconcile()` stays — it now resolves to `state.sh`'s version).

In `core/prune.sh`: delete the entire `refresh_sinks()` function including its `# Also export for use by reconcile.sh` comment.

In `bin/agent-monitor`, change `cmd_remove` to refresh after removal:

```bash
cmd_remove() {
	local id="${1:?agent id required}"

	source "${CORE_DIR}/state.sh"
	if [[ -z "$(get_agent "$id")" ]]; then
		echo "Agent $id not found."
		return 1
	fi
	remove_agent "$id"
	refresh_sinks
	echo "Removed agent $id."
}
```

- [ ] **Step 3: Run tests**

Run: `bash tests/reconcile.test.sh`
Expected: PASS — "all reconcile tests passed"

- [ ] **Step 4: Commit**

```bash
git add core/state.sh core/reconcile.sh core/prune.sh bin/agent-monitor tests/reconcile.test.sh
git commit -m "feat: unify refresh_sinks, export state.tsv, refresh on remove"
```

---

### Task 3: prune.sh skips herdr agents

**Files:**
- Modify: `core/prune.sh` (`prune` loop)
- Test: `tests/prune.test.sh` (new)

**Interfaces:**
- Consumes: `refresh_sinks` from `state.sh` (Task 2).
- Produces: agents with `name == "herdr"` are never pruned by the tmux liveness check.

- [ ] **Step 1: Write the failing test**

Create `tests/prune.test.sh`:

```bash
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
```

Run: `bash tests/prune.test.sh`
Expected: FAIL on "herdr agent kept" (today prune deletes it — `w2:p4` is not in the tmux pane list).

- [ ] **Step 2: Implement**

In `core/prune.sh`, inside the `prune()` loop, right after `name=$(get_field "$id" "name")` and before the empty-pane skip:

```bash
		# Herdr agents use herdr pane ids, not tmux panes. Their lifecycle
		# is handled by pane.closed events and adapters/herdr.sh --sync.
		[[ "$name" == "herdr" ]] && continue
```

- [ ] **Step 3: Run tests**

Run: `bash tests/prune.test.sh && bash tests/reconcile.test.sh`
Expected: both PASS

- [ ] **Step 4: Commit**

```bash
git add core/prune.sh tests/prune.test.sh
git commit -m "fix: prune skips herdr agents"
```

---

### Task 4: adapters/herdr.sh

**Files:**
- Create: `adapters/herdr.sh` (chmod +x)
- Test: `tests/herdr-adapter.test.sh` (new)

**Interfaces:**
- Consumes: `agent-monitor reconcile/remove` (Tasks 1–2), `herdr api snapshot` (JSON shape: `.result.snapshot.agents[]` with `pane_id`, `tab_id`, `agent_status`, `cwd`; `.result.snapshot.tabs[]` with `tab_id`, `label`). Env from the plugin host: `HERDR_PANE_ID`, `HERDR_PLUGIN_EVENT_JSON`.
- Produces: `adapters/herdr.sh <event>` and `adapters/herdr.sh --sync`, used by `herdr-plugin/on-event.sh` (Task 5).

- [ ] **Step 1: Write the failing test**

Create `tests/herdr-adapter.test.sh`:

```bash
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
	echo "(sync tests run separately)"
	exit 1
fi
echo "all herdr adapter event tests passed"
```

Run: `bash tests/herdr-adapter.test.sh`
Expected: FAIL immediately — `adapters/herdr.sh` does not exist.

- [ ] **Step 2: Implement the adapter**

Create `adapters/herdr.sh`:

```bash
#!/usr/bin/env bash
#
# agent-monitor/adapters/herdr.sh — Herdr source adapter
#
# Called by herdr-plugin/on-event.sh with a herdr event name, or with
# --sync for a full reconcile from the herdr snapshot.
#
# Herdr agent_status → generic event mapping:
#   working → RunStart        blocked → PermissionRequest
#   done    → TurnComplete    idle    → SessionStart
#   unknown / missing → remove (agent gone or not an agent pane)

set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${ADAPTER_DIR}/../bin/agent-monitor"

command -v herdr >/dev/null 2>&1 || exit 0

sanitize_id() {
	printf '%s' "$1" | tr -c '[:alnum:]_' '_'
}

map_status() {
	case "$1" in
	working) printf 'RunStart' ;;
	blocked) printf 'PermissionRequest' ;;
	done) printf 'TurnComplete' ;;
	idle) printf 'SessionStart' ;;
	*) return 1 ;;
	esac
}

snapshot() {
	herdr api snapshot 2>/dev/null || true
}

remove_pane() {
	"$BIN" remove "$(sanitize_id "$1")" >/dev/null 2>&1 || true
}

# Reconcile one herdr pane from a snapshot.
# Usage: reconcile_pane <snapshot_json> <pane_id>
reconcile_pane() {
	local snap="$1" pane_id="$2"
	local entry status event tab_id label cwd

	entry=$(printf '%s' "$snap" | jq -c --arg pid "$pane_id" \
		'first(.result.snapshot.agents[]? | select(.pane_id == $pid)) // empty')

	if [[ -z "$entry" ]]; then
		# Pane has no agent (anymore) — drop any tracked entry.
		remove_pane "$pane_id"
		return 0
	fi

	status=$(printf '%s' "$entry" | jq -r '.agent_status // "unknown"')
	if ! event=$(map_status "$status"); then
		remove_pane "$pane_id"
		return 0
	fi

	tab_id=$(printf '%s' "$entry" | jq -r '.tab_id // empty')
	label=$(printf '%s' "$snap" | jq -r --arg tid "$tab_id" \
		'first(.result.snapshot.tabs[]? | select(.tab_id == $tid) | .label) // empty' 2>/dev/null || true)
	cwd=$(printf '%s' "$entry" | jq -r '.cwd // empty')

	"$BIN" reconcile herdr "$event" "$(jq -nc \
		--arg pid "$pane_id" --arg label "$label" --arg cwd "$cwd" \
		'{pane_id: $pid, label: $label, cwd: $cwd}')"
}

event_pane_id() {
	local pane_id="${HERDR_PANE_ID:-}"
	if [[ -z "$pane_id" ]]; then
		pane_id=$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON:-{\}}" |
			jq -r '.pane_id // empty' 2>/dev/null || true)
	fi
	printf '%s' "$pane_id"
}

do_event() {
	local event="$1" pane_id snap

	pane_id=$(event_pane_id)
	[[ -z "$pane_id" ]] && exit 0

	case "$event" in
	pane.closed)
		remove_pane "$pane_id"
		;;
	pane.agent_status_changed | pane.agent_detected)
		snap=$(snapshot)
		[[ -z "$snap" ]] && exit 0
		reconcile_pane "$snap" "$pane_id"
		;;
	esac
}

do_sync() {
	local snap pid id raw_pane known tracked

	snap=$(snapshot)
	[[ -z "$snap" ]] && exit 0

	# Reconcile every current agent
	for pid in $(printf '%s' "$snap" | jq -r '.result.snapshot.agents[]?.pane_id'); do
		reconcile_pane "$snap" "$pid"
	done

	# Remove tracked herdr agents that are gone or no longer agents
	tracked=$("$BIN" state --json | jq -r \
		'.agents | to_entries[] | select(.value.name == "herdr") | "\(.key)\t\(.value.pane // "")"')
	while IFS=$'\t' read -r id raw_pane; do
		[[ -z "$id" ]] && continue
		known=$(printf '%s' "$snap" | jq -r --arg pid "$raw_pane" \
			'[.result.snapshot.agents[]? | select(.pane_id == $pid and .agent_status != "unknown")] | length')
		if [[ "$known" == "0" ]]; then
			"$BIN" remove "$id" >/dev/null 2>&1 || true
		fi
	done <<<"$tracked"
}

case "${1:---sync}" in
--sync | startup)
	do_sync
	;;
*)
	do_event "$1"
	;;
esac
```

Run: `chmod +x adapters/herdr.sh && bash tests/herdr-adapter.test.sh`
Expected: PASS — "all herdr adapter event tests passed"

- [ ] **Step 3: Add the sync-mode test**

Append to `tests/herdr-adapter.test.sh`, replacing the final echo block:

```bash
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

if [[ "$fail" -ne 0 ]]; then
	exit 1
fi
echo "all herdr adapter tests passed"
```

Run: `bash tests/herdr-adapter.test.sh`
Expected: PASS — "all herdr adapter tests passed"

- [ ] **Step 4: Commit**

```bash
git add adapters/herdr.sh tests/herdr-adapter.test.sh
git commit -m "feat: herdr source adapter with event and sync modes"
```

---

### Task 5: herdr plugin (manifest + dispatcher) and live link

**Files:**
- Create: `herdr-plugin/herdr-plugin.toml`
- Create: `herdr-plugin/on-event.sh` (chmod +x)
- Test: extend `tests/herdr-adapter.test.sh` (dispatcher case)

**Interfaces:**
- Consumes: `adapters/herdr.sh` (Task 4). Herdr injects `HERDR_PLUGIN_EVENT` (`startup` or the event name), `HERDR_PLUGIN_EVENT_JSON`, `HERDR_PANE_ID`.
- Produces: a linkable plugin at `herdr-plugin/`; herdr runs `on-event.sh` for startup and each subscribed event.

- [ ] **Step 1: Write the failing dispatcher test**

Append to `tests/herdr-adapter.test.sh`:

```bash
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
```

Run: `bash tests/herdr-adapter.test.sh`
Expected: FAIL — `herdr-plugin/on-event.sh` does not exist.

- [ ] **Step 2: Implement the plugin**

Create `herdr-plugin/herdr-plugin.toml`:

```toml
id = "local.agent-monitor"
name = "Agent Monitor"
version = "0.1.0"
min_herdr_version = "0.7.0"
description = "Feed herdr agent status into agent-monitor (SketchyBar and tmux)."
platforms = ["macos", "linux"]

[[startup]]
command = ["./on-event.sh"]

[[events]]
on = "pane.agent_status_changed"
command = ["./on-event.sh"]

[[events]]
on = "pane.agent_detected"
command = ["./on-event.sh"]

[[events]]
on = "pane.closed"
command = ["./on-event.sh"]
```

Create `herdr-plugin/on-event.sh`:

```bash
#!/usr/bin/env bash
#
# herdr-plugin/on-event.sh — dispatcher for herdr plugin hooks.
# Herdr sets HERDR_PLUGIN_EVENT ("startup" or the event name),
# HERDR_PLUGIN_EVENT_JSON, and (for pane events) HERDR_PANE_ID.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER="${SCRIPT_DIR}/../adapters/herdr.sh"

case "${HERDR_PLUGIN_EVENT:-startup}" in
startup)
	exec "$ADAPTER" --sync
	;;
*)
	exec "$ADAPTER" "$HERDR_PLUGIN_EVENT"
	;;
esac
```

Run: `chmod +x herdr-plugin/on-event.sh && bash tests/herdr-adapter.test.sh`
Expected: PASS — "all herdr adapter and dispatcher tests passed"

- [ ] **Step 3: Link the plugin into the live herdr server and verify**

```bash
herdr plugin link /Users/walkerw/dotfiles/agent-monitor/herdr-plugin
cat ~/.config/herdr/plugins.json | jq '.[] | select(.plugin_id == "local.agent-monitor") | {plugin_id, enabled, warnings}'
agent-monitor state
herdr api snapshot | jq -r '.result.snapshot.agents[] | "\(.pane_id) \(.agent_status)"'
```

Expected: no `warnings` (unknown event names would appear here); `agent-monitor state` lists one entry per herdr agent with matching states. Focus changes in herdr (make an agent work, let one finish) must appear in `agent-monitor state` within a second.

- [ ] **Step 4: Commit**

```bash
git add herdr-plugin/ tests/herdr-adapter.test.sh
git commit -m "feat: herdr plugin manifest and event dispatcher"
```

---

### Task 6: SketchyBar sink — herdr click dispatch + default TSV path

**Files:**
- Modify: `sinks/sketchybar.sh`
- Test: `/Users/walkerw/dotfiles/sketchybar/tests/agent-monitor.test.sh` (extend; runs against the sink via the `plugins/agent_monitor.sh` symlink)

**Interfaces:**
- Consumes: `$STATE_DIR/state.tsv` written by `refresh_sinks` (Task 2); `pane` field values (`%…` tmux, `w…:p…` herdr).
- Produces: sink reads `${XDG_CACHE_HOME:-$HOME/.cache}/agent-monitor/state.tsv` when `AGENT_MONITOR_STATE_FILE` is unset; herdr rows get `click_script=herdr agent focus <pane>`.

- [ ] **Step 1: Write the failing test**

Append to `/Users/walkerw/dotfiles/sketchybar/tests/agent-monitor.test.sh`:

```bash
cat >"$STATE_FILE" <<'STATE'
id	name	state	label	pane	session_id	updated_at
w2_p4	herdr	running	SF	w2:p4		100
one	codex	running	work	%1	session-1	90
STATE
: >"$SET_LOG"
"$SCRIPT"
expected=$'--set agent_monitor drawing=off\n--add item agent_monitor.w2_p4 center\n--set agent_monitor.w2_p4 drawing=on icon.drawing=off label=SF label.color=0xffffffff background.drawing=on background.color=0xff238636 background.corner_radius=5 background.height=20 click_script=herdr agent focus w2:p4\n--add item agent_monitor.one center\n--set agent_monitor.one drawing=on icon.drawing=off label=work label.color=0xffffffff background.drawing=on background.color=0xff238636 background.corner_radius=5 background.height=20 click_script=tmux select-window -t %1; tmux select-pane -t %1'
assert_equal "$expected" "$(cat "$SET_LOG")" "herdr rows get herdr focus click, tmux rows unchanged"
```

Run: `bash /Users/walkerw/dotfiles/sketchybar/tests/agent-monitor.test.sh`
Expected: FAIL on the new case (today the herdr row renders with the tmux click script).

- [ ] **Step 2: Implement**

In `sinks/sketchybar.sh`, change the STATE_FILE default:

```sh
STATE_FILE="${AGENT_MONITOR_STATE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/agent-monitor/state.tsv}"
```

Replace the CLICK_SCRIPT block:

```sh
    CLICK_SCRIPT=""
    case "$pane" in
        %*)
            CLICK_SCRIPT="tmux select-window -t $pane; tmux select-pane -t $pane"
            ;;
        w*:p*)
            CLICK_SCRIPT="herdr agent focus $pane"
            ;;
    esac
```

(Empty or unrecognized pane values keep the existing no-click-script path.)

- [ ] **Step 3: Run tests**

Run: `bash /Users/walkerw/dotfiles/sketchybar/tests/agent-monitor.test.sh`
Expected: PASS — all old cases and the new herdr case.

- [ ] **Step 4: Commit (both repos)**

```bash
cd /Users/walkerw/dotfiles/agent-monitor && git add sinks/sketchybar.sh && git commit -m "feat: sketchybar sink herdr focus click and default state.tsv path"
cd /Users/walkerw/dotfiles/sketchybar && git add tests/agent-monitor.test.sh && git commit -m "test: herdr agent monitor render case"
```

---

### Task 7: README, cleanup, and end-to-end verification

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-07-28-herdr-agent-monitor-design.md` (add TSV export + remove-refresh under "Changed" components, discovered during planning)

- [ ] **Step 1: Update README.md**

In the architecture diagram, add the herdr source line above the pi adapter:

```
adapters/herdr.sh ─┐
adapters/pi.sh ──┐ │
adapters/codex.sh ┤┤──▶ bin/agent-monitor reconcile ──▶ core/reconcile.sh
adapters/cursor.sh─┘┘           │
```

Add a `## Herdr Source` section after `## States`:

```markdown
## Herdr Source

Herdr is the source of truth for agents running inside herdr. A herdr plugin
(`herdr-plugin/`) pushes `pane.agent_status_changed`, `pane.agent_detected`,
and `pane.closed` events to `adapters/herdr.sh`, plus a full snapshot sync on
herdr startup.

Status mapping: `working`→running, `blocked`→needs-help, `done`→needs-attention,
`idle`→idle, `unknown`→removed. Labels come from herdr tab labels. Clicking a
SketchyBar item for a herdr agent runs `herdr agent focus <pane_id>`.

Install:

```bash
herdr plugin link /Users/walkerw/dotfiles/agent-monitor/herdr-plugin
```
```

Update the directory-structure listing to include `adapters/herdr.sh`, `herdr-plugin/`, and `tests/`.

In the spec file, under "Changed: core/reconcile.sh" area, add a short subsection noting: `refresh_sinks` now lives in `core/state.sh`, exports `$STATE_DIR/state.tsv` atomically, and `agent-monitor remove` refreshes sinks; `sinks/sketchybar.sh` defaults `AGENT_MONITOR_STATE_FILE` to that path.

- [ ] **Step 2: Clear stale tmux-era state and run everything**

```bash
agent-monitor clear
bash tests/reconcile.test.sh
bash tests/prune.test.sh
bash tests/herdr-adapter.test.sh
bash /Users/walkerw/dotfiles/sketchybar/tests/agent-monitor.test.sh
herdr plugin unlink local.agent-monitor 2>/dev/null; herdr plugin link /Users/walkerw/dotfiles/agent-monitor/herdr-plugin
agent-monitor state
```

Expected: all four test suites pass; `agent-monitor state` mirrors `herdr api snapshot` agents.

- [ ] **Step 3: Manual end-to-end check**

1. Watch `agent-monitor state` while one herdr agent works → `running` (green pill in SketchyBar).
2. Let a turn finish → `needs-attention` (blue) + macOS notification when the terminal is not frontmost.
3. Click the pill → herdr jumps to that agent; pill turns gray (`idle`) after focus.
4. Close an agent pane in herdr → pill disappears.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-07-28-herdr-agent-monitor-design.md
git commit -m "docs: herdr source in README and spec refresh-pipeline notes"
```

---

## Self-Review Notes

- Spec coverage: state mapping (T4), tab label (T1+T4), click focus (T6), pane.closed removal (T4), startup sync (T4+T5), prune guard (T3), identity (T1), README (T7). The refresh-pipeline gap (state.tsv never written in production; `remove` not refreshing) was found during planning and is covered by T2; the spec is updated in T7.
- Type consistency: `refresh_sinks`, `reconcile_pane`, `remove_pane`, `sanitize_id`, `map_status`, `do_sync`, `do_event`, `event_pane_id` are used consistently across tasks. Sanitized id rule (`tr -c '[:alnum:]_' '_'`) is identical in `reconcile.sh` and `adapters/herdr.sh`.
