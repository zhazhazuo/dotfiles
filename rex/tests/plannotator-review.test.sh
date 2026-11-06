#!/usr/bin/env bash
#
# tests/plannotator-review.test.sh — the Plannotator review hand-off
#
# The wrapper is exercised through two fakes: a plannotator-tui that keeps its
# annotations in a file and adds one when "reviewed", and a rex that records the
# calls the wrapper makes. The paste payload is the contract that matters, so
# each case asserts on it rather than on the wrapper's output.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$ROOT_DIR/scripts/plannotator-review.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export TUI_STATE="$TMP_DIR/annotations.md"
export REX_CALLS="$TMP_DIR/rex-calls.txt"
export PANE_TEXT="$TMP_DIR/pane-text.txt"
mkdir -p "$TMP_DIR/bin"
: >"$REX_CALLS"

failures=0
assert_equal() {
	local expected="$1" actual="$2" name="$3"
	if [[ "$actual" != "$expected" ]]; then
		printf 'not ok - %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual" >&2
		failures=$((failures + 1))
		return 1
	fi
	printf 'ok - %s\n' "$name"
}

assert_contains() {
	local needle="$1" haystack="$2" name="$3"
	if [[ "$haystack" != *"$needle"* ]]; then
		printf 'not ok - %s\n  missing: %s\n  in:      %s\n' "$name" "$needle" "$haystack" >&2
		failures=$((failures + 1))
		return 1
	fi
	printf 'ok - %s\n' "$name"
}

# A plannotator-tui stand-in: --export prints the annotation store, any other
# call is a review that adds one annotation.
cat >"$TMP_DIR/bin/plannotator-tui" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
state=${TUI_STATE:?}
case "${1:-}" in
--export)
	cat "$state"
	;;
*)
	next=$(grep -c '^## Annotation [0-9]' "$state" || true)
	printf '## Annotation %d (line 1)\nComment on: "Rotate the token"\n> Rotation on a privilege change logs people out.\n' "$((next + 1))" >>"$state"
	;;
esac
FAKE
chmod +x "$TMP_DIR/bin/plannotator-tui"
export PLANNOTATOR_TUI="$TMP_DIR/bin/plannotator-tui"

# A rex stand-in: records the API payloads and answers capture from a fixture.
cat >"$TMP_DIR/bin/rex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
api)
	shift
	[[ "${1:-}" == "call" ]] || exit 1
	shift
	printf '%s\n' "${@: -1}" >>"${REX_CALLS:?}"
	;;
capture)
	cat "${PANE_TEXT:?}"
	;;
esac
FAKE
chmod +x "$TMP_DIR/bin/rex"
export PATH="$TMP_DIR/bin:$PATH"

doc="$TMP_DIR/plan.md"
printf '# Plan\n\nRotate the token on every privilege change.\n' >"$doc"

# ── An existing annotation is not sent again ───────────────────────────────

printf '# Annotations on plan.md\n\n## Annotation 1 (line 3)\nComment on: "old"\n> earlier note\n' >"$TUI_STATE"
: >"$REX_CALLS"
"$WRAPPER" "$doc" session:1 block:1 >/dev/null 2>&1

payload=$(cat "$REX_CALLS")
assert_contains '"type":"paste"' "$payload" "a review delivers one paste" || true
assert_contains 'Rotate the token' "$payload" "the paste holds the new annotation" || true
assert_equal "1" "$(grep -c . "$REX_CALLS")" "one paste call per review" || true

if [[ "$payload" == *"earlier note"* ]]; then
	printf 'not ok - the paste must not repeat an older annotation\n' >&2
	failures=$((failures + 1))
else
	printf 'ok - the paste leaves older annotations out\n'
fi

# ── A review with no annotation sends nothing ──────────────────────────────

cat >"$TMP_DIR/bin/plannotator-tui" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "--export" ]] && cat "${TUI_STATE:?}"
exit 0
FAKE
chmod +x "$TMP_DIR/bin/plannotator-tui"
: >"$REX_CALLS"
"$WRAPPER" "$doc" session:1 block:1 >/dev/null 2>&1
assert_equal "" "$(cat "$REX_CALLS")" "a review without annotations sends nothing" || true

# ── Pane mode snapshots the target block ───────────────────────────────────

printf 'REVIEW-ME-PANE-TEXT\n' >"$PANE_TEXT"
sed -i '' 's/^\[\^\]//' /dev/null 2>/dev/null || true
cat >"$TMP_DIR/bin/plannotator-tui" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
--export)
	cat "${TUI_STATE:?}"
	;;
*)
	cp "$1" "${TUI_SEEN_DOC:?}"
	next=$(grep -c '^## Annotation [0-9]' "$TUI_STATE" || true)
	printf '## Annotation %d (line 1)\nComment on: "pane"\n> pane note\n' "$((next + 1))" >>"$TUI_STATE"
	;;
esac
FAKE
chmod +x "$TMP_DIR/bin/plannotator-tui"
export TUI_SEEN_DOC="$TMP_DIR/seen-doc-path.txt"
printf '# nothing yet\n' >"$TUI_STATE"
: >"$REX_CALLS"
"$WRAPPER" - session:1 block:1 >/dev/null 2>&1
assert_contains "REVIEW-ME-PANE-TEXT" "$(cat "$TUI_SEEN_DOC" 2>/dev/null || true)" "pane mode snapshots the block" || true
assert_contains '"block_id":"block:1"' "$(cat "$REX_CALLS")" "the paste targets the block it snapshotted" || true

# ── Message mode reviews the last agent message ───────────────────────────

cat >"$TMP_DIR/bin/plannotator-tui" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
--export)
	cat "${TUI_STATE:?}"
	;;
last)
	printf '%s\n' "$*" >"${TUI_LAST_ARGS:?}"
	printf 'LAST-MESSAGE-THIRD-PARAGRAPH\n'
	;;
*)
	cp "$1" "${TUI_SEEN_DOC:?}"
	printf '%s' "$1" >"${TUI_DOC_PATH:?}"
	next=$(grep -c '^## Annotation [0-9]' "$TUI_STATE" || true)
	printf '## Annotation %d (line 1)\nComment on: "message"\n> message note\n' "$((next + 1))" >>"$TUI_STATE"
	;;
esac
FAKE
chmod +x "$TMP_DIR/bin/plannotator-tui"
export TUI_LAST_ARGS="$TMP_DIR/last-args.txt"
export TUI_DOC_PATH="$TMP_DIR/doc-path.txt"
: >"$TUI_LAST_ARGS"
printf '# nothing yet\n' >"$TUI_STATE"
: >"$REX_CALLS"
"$WRAPPER" message session:1 block:1 >/dev/null 2>&1
assert_contains "LAST-MESSAGE-THIRD-PARAGRAPH" "$(cat "$TUI_SEEN_DOC" 2>/dev/null || true)" \
	"message mode reviews the last agent message" || true
assert_contains "--host pi" "$(cat "$TUI_LAST_ARGS")" "message mode asks pi for its message" || true
assert_equal "message" "$(basename "$(cat "$TUI_DOC_PATH")")" "message mode names the document message, with no extension" || true
assert_contains '"type":"paste"' "$(cat "$REX_CALLS")" "a message review delivers one paste" || true

# An agent with no message fails instead of opening an empty document.
cat >"$TMP_DIR/bin/plannotator-tui" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "last" ]] && exit 1
exit 0
FAKE
chmod +x "$TMP_DIR/bin/plannotator-tui"
: >"$REX_CALLS"
if "$WRAPPER" message session:1 block:1 >/dev/null 2>&1; then
	printf 'not ok - a missing message must fail\n' >&2
	failures=$((failures + 1))
else
	printf 'ok - a missing message fails\n'
fi
assert_equal "" "$(cat "$REX_CALLS")" "a missing message sends nothing" || true

# ── Pick mode uses Plannotator's own picker and its review record ─────────

export PLANNOTATOR_DATA_DIR="$TMP_DIR/plannotator"
mkdir -p "$PLANNOTATOR_DATA_DIR/feedback/project"

cat >"$TMP_DIR/bin/plannotator-tui" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${TUI_CALLS:?}"
case "${1:-}" in
last)
	# A review that ended with annotations leaves a record behind, which is what
	# the wrapper reads instead of a second export.
	if [ -n "${TUI_RECORD:-}" ]; then
		index="${PLANNOTATOR_DATA_DIR:?}/feedback/project/index.jsonl"
		ts=$(python3 -c 'import datetime;now=datetime.datetime.now(datetime.timezone.utc);print(now.strftime("%Y-%m-%dT%H:%M:%S.")+"%03dZ"%(now.microsecond//1000))')
		jq -nc --arg ts "$ts" --arg feedback "$TUI_RECORD" \
			'{v: 1, ts: $ts, client: "plannotator-tui", decision: "feedback", feedback: $feedback}' >>"$index"
	fi
	;;
esac
exit 0
FAKE
chmod +x "$TMP_DIR/bin/plannotator-tui"
export TUI_CALLS="$TMP_DIR/tui-calls.txt"

: >"$TUI_CALLS"
: >"$REX_CALLS"
export TUI_RECORD='## Annotation 1 (line 2)
> PICKED-REVIEW-FEEDBACK'
"$WRAPPER" pick session:1 block:1 >/dev/null 2>&1
assert_contains "PICKED-REVIEW-FEEDBACK" "$(cat "$REX_CALLS")" "pick mode pastes the review it recorded" || true
assert_contains "last --host pi" "$(cat "$TUI_CALLS")" "pick mode opens Plannotator's picker over pi" || true
if grep -q -- "--print" "$TUI_CALLS"; then
	printf 'not ok - pick mode must not skip the picker\n' >&2
	failures=$((failures + 1))
else
	printf 'ok - pick mode keeps the picker\n'
fi
assert_contains '"type":"paste"' "$(cat "$REX_CALLS")" "a picked review delivers one paste" || true

# A review that ends without annotations leaves no record, so nothing is pasted.
: >"$REX_CALLS"
: >"$TUI_CALLS"
unset TUI_RECORD
"$WRAPPER" pick session:1 block:1 >/dev/null 2>&1
assert_equal "" "$(cat "$REX_CALLS")" "a picker run with no feedback pastes nothing" || true

# A record from an earlier review is not this run's feedback.
printf '{"v":1,"ts":"2020-01-01T00:00:00.000Z","client":"plannotator-tui","decision":"feedback","feedback":"STALE-FEEDBACK"}\n' \
	>"$PLANNOTATOR_DATA_DIR/feedback/project/index.jsonl"
: >"$REX_CALLS"
"$WRAPPER" pick session:1 block:1 >/dev/null 2>&1
assert_equal "" "$(cat "$REX_CALLS")" "a stale record is not pasted" || true

# ── Failures are visible and send nothing ─────────────────────────────────

: >"$REX_CALLS"
if "$WRAPPER" "$TMP_DIR/missing.md" session:1 block:1 >/dev/null 2>&1; then
	printf 'not ok - a missing document must fail\n' >&2
	failures=$((failures + 1))
else
	printf 'ok - a missing document fails\n'
fi
assert_equal "" "$(cat "$REX_CALLS")" "a missing document sends nothing" || true

if PLANNOTATOR_TUI="$TMP_DIR/not-installed" PATH="/usr/bin:/bin" "$WRAPPER" "$doc" session:1 block:1 >/dev/null 2>&1; then
	printf 'not ok - a missing plannotator-tui must fail\n' >&2
	failures=$((failures + 1))
else
	printf 'ok - a missing plannotator-tui fails\n'
fi

if [[ "$failures" -gt 0 ]]; then
	printf '\n%s failure(s)\n' "$failures" >&2
	exit 1
fi
printf '\nall plannotator-review tests passed\n'
