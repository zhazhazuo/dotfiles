#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PEASHOOTER="$SKILL_DIR/peashooter.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_jq() {
	local expr="$1"
	local json="$2"
	local msg="${3:-assert_jq failed: $expr}"
	if ! printf '%s' "$json" | jq -e "$expr" >/dev/null 2>&1; then
		fail "$msg (expr: $expr, json: $json)"
	fi
}

setup_repo() {
	TEST_REPO="$(mktemp -d)"
	cd "$TEST_REPO"
	git init -q
	git config user.email "pea-shooter-test@example.com"
	git config user.name "Pea Shooter Test"
	printf '%s\n' 'export const value = 1;' >src.ts
	git add src.ts
	git commit -q -m "init"
}

fake_agent_path() {
	local fixture_name="$1"
	local bin_dir
	bin_dir="$(mktemp -d)"
	ln -sf "$FIXTURES/$fixture_name" "$bin_dir/agent"
	printf '%s' "$bin_dir"
}

test_legacy_success() {
	setup_repo
	local bin_dir
	bin_dir="$(fake_agent_path agent-success.sh)"
	rm -f /tmp/pea-shooter-agent-args.log

	export PATH="$bin_dir:$PATH"
	unset CODEX_SANDBOX

	local output=""
	local status=0
	output="$("$PEASHOOTER" src.ts "append a marker comment" 2>&1)" || status=$?

	[ "$status" -eq 0 ] || fail "expected exit 0, got $status: $output"

	assert_jq '.status == "success"' "$output" "report status should be success"
	assert_jq '.legacy_mode == true or .legacy_mode == 1' "$output" "legacy mode should be true"
	assert_jq '(.changed_files | index("src.ts")) != null' "$output" "src.ts should appear in changed_files"

	grep -q '// updated by fake agent' src.ts || fail "src.ts missing fake agent update"
	[ -f /tmp/pea-shooter-agent-args.log ] || fail "agent args log was not written"
	grep -q 'append a marker comment' /tmp/pea-shooter-agent-args.log ||
		fail "edit instruction was not passed to the fake agent"
}

main() {
	command -v jq >/dev/null 2>&1 || fail "jq is required"
	command -v git >/dev/null 2>&1 || fail "git is required"
	[ -x "$PEASHOOTER" ] || fail "peashooter.sh is missing or not executable"

	test_legacy_success

	echo "PASS pea_shooter_contract_test"
}

main "$@"
