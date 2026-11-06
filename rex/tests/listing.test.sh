#!/usr/bin/env bash
#
# tests/listing.test.sh — the listing snapshot
#
# The contract is a file: a reader opens it and gets every session, tab and pane
# with no wait on Rex. So the test drives the real server, runs the daemon, and
# asserts on the file. It checks the three properties the reader depends on: the
# file appears, it follows changes within a second, and it is never half
# written.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/listing.lua"

if ! command -v rex >/dev/null 2>&1; then
	printf 'not ok - the rex CLI is not on PATH, so the daemon cannot start\n' >&2
	exit 1
fi

TMP_DIR="$(mktemp -d)"
daemon_pid=""
sessions=()

# A failing kill must not stop the rest of the cleanup, or a run leaves sessions
# behind for the next one to see.
cleanup() {
	set +e
	[[ -n "$daemon_pid" ]] && kill "$daemon_pid" >/dev/null 2>&1
	for s in "${sessions[@]:-}"; do
		[[ -n "$s" ]] && rex kill "$s" >/dev/null 2>&1
	done
	rex ls --json 2>/dev/null |
		jq -r '.sessions[] | select(.label | startswith("ZZ-LISTING")) | .session_id' |
		while read -r leftover; do rex kill "$leftover" >/dev/null 2>&1; done
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

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

snapshot="$TMP_DIR/listing.json"

# Waits for the file to hold a condition, so a slow server does not read as a
# failure. Prints the time it took.
wait_for() {
	local description="$1" timeout="$2" condition="$3"
	local start
	start=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
	for _ in $(seq 1 $((timeout * 20))); do
		if eval "$condition"; then
			local now
			now=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
			printf 'ok - %s (%d ms)\n' "$description" $(((now - start) / 1000000))
			return 0
		fi
		sleep 0.05
	done
	printf 'not ok - %s: still not true after %ss\n' "$description" "$timeout" >&2
	failures=$((failures + 1))
	return 1
}

file_has() { [[ -f "$snapshot" ]] && jq -e "$1" "$snapshot" >/dev/null 2>&1; }

# The daemon writes once, then rewrites a quarter of a second after a change.
rex do "$SCRIPT" snapshot="$snapshot" --all --for 60s >"$TMP_DIR/daemon.log" 2>&1 &
daemon_pid=$!

wait_for "the file appears" 8 'file_has ".sessions | length > 0"'
wait_for "every block carries the fields the view reads" 2 \
	'file_has "[.sessions[].windows[].blocks[]] | length > 0 and ([.[] | has(\"block_id\") and has(\"label\") and has(\"floating\")] | all)"'
wait_for "the document carries a timestamp" 2 'jq -e ".generated_at > 0" "$snapshot" >/dev/null'

# The one-shot form answers the same question, so it is the oracle.
expected_labels=$(rex do "$SCRIPT" | jq -r '[.sessions[].label] | sort | join(",")')
assert_equal "$expected_labels" "$(jq -r '[.sessions[].label] | sort | join(",")' "$snapshot")" \
	"the file agrees with a one-shot listing"

# A change reaches the file without anyone asking for it.
created=$(rex new ZZ-LISTING --json -- sleep 300 | jq -r .session_id)
sessions+=("$created")
wait_for "a new session reaches the file" 2 "file_has '[.sessions[].label] | index(\"ZZ-LISTING\")'"

rex kill "$created" >/dev/null 2>&1
wait_for "a closed session leaves the file" 3 "file_has '([.sessions[].label] | index(\"ZZ-LISTING\")) == null'"

# A reader never sees a half-written document: the daemon renames a finished
# file over the old one. Hammer the file while changes arrive.
unreadable=0
for index in $(seq 1 40); do
	jq -e . "$snapshot" >/dev/null 2>&1 || unreadable=$((unreadable + 1))
	if ((index == 5 || index == 25)); then
		sessions+=("$(rex new "ZZ-LISTING-$index" --json -- sleep 120 | jq -r .session_id)")
	fi
	sleep 0.05
done
assert_equal "0" "$unreadable" "every read of the file during changes found valid JSON"

if ((failures > 0)); then
	printf '%d test(s) failed\n' "$failures" >&2
	exit 1
fi
printf 'all tests passed\n'
