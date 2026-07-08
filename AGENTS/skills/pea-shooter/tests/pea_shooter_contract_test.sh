#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PEASHOOTER="$SKILL_DIR/peashooter.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_jq_file() {
	local file="$1"
	local expr="$2"
	jq -e "$expr" "$file" >/dev/null || fail "jq assertion failed: $expr"
}

setup_repo() {
	local name="$1"
	local repo="$TMP_ROOT/$name"
	mkdir -p "$repo"
	cd "$repo"
	git init -q
	git config user.email "pea-shooter-test@example.com"
	git config user.name "Pea Shooter Test"
	printf '%s\n' 'export const value = 1;' >src.ts
	git add src.ts
	git commit -q -m "init"
	printf '%s\n' "$repo"
}

install_agent_fixture() {
	local repo="$1"
	local fixture_name="$2"
	mkdir -p "$repo/bin"
	cp "$FIXTURES/$fixture_name" "$repo/bin/agent"
	chmod +x "$repo/bin/agent"
}

run_wrapper() {
	local repo="$1"
	local report="$2"
	shift 2
	(
		cd "$repo"
		export PATH="$repo/bin:$PATH"
		unset CODEX_SANDBOX
		"$PEASHOOTER" "$@" >"$report"
	)
}

run_wrapper_expect_fail() {
	local repo="$1"
	local report="$2"
	shift 2
	if run_wrapper "$repo" "$report" "$@"; then
		fail "expected wrapper failure for $*"
	fi
}

write_lock_metadata() {
	local path="$1"
	local pid="$2"
	local run_id="$3"
	cat >"$path" <<EOF
{"pid":$pid,"run_id":"$run_id","started_at":"2026-07-08T00:00:00Z","cwd":"/tmp/test","status_file":"/tmp/$run_id.status.json"}
EOF
}

test_legacy_success() {
	local repo report
	repo="$(setup_repo legacy-success)"
	install_agent_fixture "$repo" agent-success.sh
	report="$repo/report.json"
	rm -f /tmp/pea-shooter-agent-args.log

	run_wrapper "$repo" "$report" src.ts "append a marker comment"

	assert_jq_file "$report" '.status == "success"'
	assert_jq_file "$report" '.legacy_mode == true or .legacy_mode == 1'
	assert_jq_file "$report" '.project_validation.status == "skipped"'
	assert_jq_file "$report" '.safe_to_commit == false'
	assert_jq_file "$report" '.files_modified == ["src.ts"]'
	assert_jq_file "$report" '.edits_applied == true'
	assert_jq_file "$report" '.validations_run == 0'
	assert_jq_file "$report" '.lock_status == "acquired"'
	grep -q '// updated by fake agent' "$repo/src.ts" || fail "src.ts missing fake agent update"
	grep -q 'append a marker comment' /tmp/pea-shooter-agent-args.log || fail "instruction not passed to fake agent"
}

test_manifest_mode() {
	local repo report
	repo="$(setup_repo manifest-mode)"
	install_agent_fixture "$repo" agent-success.sh
	cat >"$repo/task.json" <<'EOF'
{
  "allow": ["src.ts"],
  "create": [],
  "delete": [],
  "require_change": ["src.ts"],
  "instruction": "Append a comment",
  "validate": [
    {"kind": "shell", "command": "test -f src.ts"}
  ]
}
EOF
	report="$repo/report.json"

	run_wrapper "$repo" "$report" --manifest task.json

	assert_jq_file "$report" '.target_files.allowed == ["src.ts"]'
	assert_jq_file "$report" '.project_validation.status == "passed"'
	assert_jq_file "$report" '.project_validation.results[0].kind == "shell"'
}

test_validation_kind_default() {
	local repo report
	repo="$(setup_repo validation-kind)"
	install_agent_fixture "$repo" agent-success.sh
	report="$repo/report.json"

	run_wrapper "$repo" "$report" --allow src.ts --require-change src.ts --validate "test -f src.ts" -- "Append a comment"

	assert_jq_file "$report" '.project_validation.results[0].kind == "shell"'
}

test_timeout_reports_status_sidecar() {
	local repo report
	repo="$(setup_repo timeout-case)"
	install_agent_fixture "$repo" agent-sleep.sh
	report="$repo/report.json"

	if (
		cd "$repo"
		export PATH="$repo/bin:$PATH"
		export FAKE_AGENT_SLEEP_SECONDS=3
		unset CODEX_SANDBOX
		"$PEASHOOTER" --allow src.ts --require-change src.ts --timeout-seconds 1 -- "Append a comment" >"$report"
	); then
		fail "timeout case unexpectedly succeeded"
	fi

	assert_jq_file "$report" '.status == "timeout"'
	assert_jq_file "$report" '.status_file | length > 0'
	assert_jq_file "$report" '.agent_output_status == "silent" or .agent_output_status == "finished"'
	assert_jq_file "$report" '.phase == "completed"'
	test -f "$(jq -r '.status_file' "$report")" || fail "missing status sidecar"
}

test_validation_failure_preserves_diff() {
	local repo report
	repo="$(setup_repo validation-failure)"
	install_agent_fixture "$repo" agent-success.sh
	report="$repo/report.json"

	run_wrapper_expect_fail "$repo" "$report" --allow src.ts --require-change src.ts --validate "exit 7" -- "Append a comment"

	assert_jq_file "$report" '.status == "project_validation_failed"'
	assert_jq_file "$report" '.project_validation.status == "failed"'
	assert_jq_file "$report" '.safe_to_commit == false'
	assert_jq_file "$report" '.edits_applied == true'
	grep -q '// updated by fake agent' "$repo/src.ts" || fail "diff was lost on validation failure"
}

test_stale_lock_recovers() {
	local repo report lock_dir lock_file
	repo="$(setup_repo stale-lock)"
	install_agent_fixture "$repo" agent-success.sh
	report="$repo/report.json"
	lock_dir="$repo/.agent-runs"
	lock_file="$lock_dir/edit.lock"
	mkdir -p "$lock_dir"
	write_lock_metadata "$lock_file" 999999 "stale-lock-run"

	run_wrapper "$repo" "$report" --allow src.ts --require-change src.ts -- "Append a comment"

	assert_jq_file "$report" '.status == "success"'
	assert_jq_file "$report" '.lock_status == "recovered_stale_lock"'
}

test_live_lock_blocks_with_owner_details() {
	local repo report lock_dir lock_file sleeper_pid
	repo="$(setup_repo live-lock)"
	install_agent_fixture "$repo" agent-success.sh
	report="$repo/report.json"
	lock_dir="$repo/.agent-runs"
	lock_file="$lock_dir/edit.lock"
	mkdir -p "$lock_dir"
	sleep 30 &
	sleeper_pid=$!
	trap 'kill "$sleeper_pid" >/dev/null 2>&1 || true; rm -rf "$TMP_ROOT"' EXIT
	write_lock_metadata "$lock_file" "$sleeper_pid" "live-lock-run"

	run_wrapper_expect_fail "$repo" "$report" --allow src.ts --require-change src.ts -- "Append a comment"

	assert_jq_file "$report" '.status == "blocked"'
	assert_jq_file "$report" '.lock_status == "blocked_live_lock"'
	assert_jq_file "$report" '.lock_owner_pid > 0'
	assert_jq_file "$report" '.lock_owner_run_id == "live-lock-run"'
	kill "$sleeper_pid" >/dev/null 2>&1 || true
	trap 'rm -rf "$TMP_ROOT"' EXIT
}

test_allow_noop_returns_noop() {
	local repo report
	repo="$(setup_repo allow-noop)"
	install_agent_fixture "$repo" agent-noop.sh
	report="$repo/report.json"

	run_wrapper "$repo" "$report" --allow src.ts --require-change src.ts --allow-noop -- "Instruction that results in no diff"

	assert_jq_file "$report" '.status == "noop"'
	assert_jq_file "$report" '.edits_applied == false'
}

test_noop_without_opt_in_fails_contract() {
	local repo report
	repo="$(setup_repo disallow-noop)"
	install_agent_fixture "$repo" agent-noop.sh
	report="$repo/report.json"

	run_wrapper_expect_fail "$repo" "$report" --allow src.ts --require-change src.ts -- "Instruction that results in no diff"

	assert_jq_file "$report" '.status == "validation_failed"'
	assert_jq_file "$report" '.missing_required_changes == ["src.ts"]'
}

test_instruction_file_preserves_shell_sensitive_content() {
	local repo report
	repo="$(setup_repo instruction-file)"
	install_agent_fixture "$repo" agent-success.sh
	report="$repo/report.json"
	rm -f /tmp/pea-shooter-agent-args.log
	cat >"$repo/task.txt" <<'EOF'
Replace wording around `proposed` and `CON-001`; preserve all other content.
EOF

	run_wrapper "$repo" "$report" --allow src.ts --require-change src.ts --instruction-file task.txt

	grep -q '`proposed` and `CON-001`' /tmp/pea-shooter-agent-args.log || fail "instruction file content was not passed literally"
}

test_created_file_patch_preview() {
	local repo report
	repo="$(setup_repo created-file-preview)"
	mkdir -p "$repo/bin"
	cat >"$repo/bin/agent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'export const extra = 2;' >new.ts
printf '%s\n' '// updated by fake agent' >>src.ts
EOF
	chmod +x "$repo/bin/agent"
	report="$repo/report.json"

	run_wrapper "$repo" "$report" --allow src.ts --create new.ts --require-change src.ts --require-change new.ts -- "Append a comment and create a file"

	assert_jq_file "$report" '.created_files_patch | contains("+++ b/new.ts")'
	assert_jq_file "$report" '.review_created_files == true'
}

test_failed_run_has_guidance() {
	local repo report
	repo="$(setup_repo failed-run)"
	install_agent_fixture "$repo" agent-fail.sh
	report="$repo/report.json"

	run_wrapper_expect_fail "$repo" "$report" src.ts "Append a comment"

	assert_jq_file "$report" '.status == "failed"'
	assert_jq_file "$report" '.retryable == true'
	assert_jq_file "$report" '.suggested_actions | length > 0'
}

test_predirty_file_edit_is_detected() {
	local repo report
	repo="$(setup_repo predirty-detected)"
	printf '%s\n' 'export const other = 1;' >"$repo/other.ts"
	(cd "$repo" && git add other.ts && git commit -q -m "add other")
	printf '%s\n' '// dirtied by user before run' >>"$repo/other.ts"
	mkdir -p "$repo/bin"
	cat >"$repo/bin/agent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '// updated by fake agent' >>src.ts
printf '%s\n' '// illegally touched by agent' >>other.ts
EOF
	chmod +x "$repo/bin/agent"
	report="$repo/report.json"

	run_wrapper_expect_fail "$repo" "$report" --allow src.ts --require-change src.ts -- "Append a comment"

	assert_jq_file "$report" '.status == "validation_failed"'
	assert_jq_file "$report" '.boundary_violations == ["other.ts"]'
}

test_predirty_file_untouched_is_not_reported() {
	local repo report
	repo="$(setup_repo predirty-clean)"
	printf '%s\n' 'export const other = 1;' >"$repo/other.ts"
	(cd "$repo" && git add other.ts && git commit -q -m "add other")
	printf '%s\n' '// dirtied by user before run' >>"$repo/other.ts"
	install_agent_fixture "$repo" agent-success.sh
	report="$repo/report.json"

	run_wrapper "$repo" "$report" --allow src.ts --require-change src.ts -- "Append a comment"

	assert_jq_file "$report" '.status == "success"'
	assert_jq_file "$report" '.changed_files == ["src.ts"]'
	grep -q '// dirtied by user before run' "$repo/other.ts" || fail "pre-dirty user edit was lost"
}

test_subdirectory_invocation_normalizes_paths() {
	local repo report
	repo="$(setup_repo subdir-invocation)"
	mkdir -p "$repo/sub"
	printf '%s\n' 'export const nested = 1;' >"$repo/sub/nested.ts"
	(cd "$repo" && git add sub/nested.ts && git commit -q -m "add nested")
	mkdir -p "$repo/bin"
	cat >"$repo/bin/agent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '// updated by fake agent' >>sub/nested.ts
EOF
	chmod +x "$repo/bin/agent"
	report="$repo/report.json"

	(
		cd "$repo/sub"
		export PATH="$repo/bin:$PATH"
		unset CODEX_SANDBOX
		"$PEASHOOTER" --allow nested.ts --require-change nested.ts -- "Append a comment" >"$report"
	)

	assert_jq_file "$report" '.status == "success"'
	assert_jq_file "$report" '.files_modified == ["sub/nested.ts"]'
	assert_jq_file "$report" '.target_files.allowed == ["sub/nested.ts"]'
}

test_agent_commit_fails_head_check() {
	local repo report
	repo="$(setup_repo agent-commit)"
	mkdir -p "$repo/bin"
	cat >"$repo/bin/agent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '// updated by fake agent' >>src.ts
git add src.ts
git -c user.email=rogue@example.com -c user.name=Rogue commit -q -m "sneaky commit"
EOF
	chmod +x "$repo/bin/agent"
	report="$repo/report.json"

	run_wrapper_expect_fail "$repo" "$report" --allow src.ts --require-change src.ts -- "Append a comment"

	assert_jq_file "$report" '.status == "validation_failed"'
	assert_jq_file "$report" '.validation.head_check == "failed"'
	assert_jq_file "$report" '.reason | contains("HEAD")'
}

test_docs_reference_manifest_and_validation() {
	grep -q -- '--manifest <path>' "$SKILL_DIR/references/wrapper-contract.md" || fail "wrapper contract missing manifest docs"
	grep -q -- 'project_validation' "$SKILL_DIR/references/wrapper-contract.md" || fail "wrapper contract missing project validation docs"
	grep -q -- 'status sidecar' "$SKILL_DIR/references/batch-and-streaming.md" || fail "batch-and-streaming missing sidecar docs"
	grep -q -- '--instruction-file' "$SKILL_DIR/references/wrapper-contract.md" || fail "wrapper contract missing instruction-file docs"
	grep -q -- 'status: `noop`' "$SKILL_DIR/references/failure-and-retry.md" || fail "failure-and-retry missing noop docs"
}

main() {
	command -v jq >/dev/null 2>&1 || fail "jq is required"
	command -v git >/dev/null 2>&1 || fail "git is required"
	[ -x "$PEASHOOTER" ] || fail "peashooter.sh is missing or not executable"

	test_legacy_success
	test_manifest_mode
	test_validation_kind_default
	test_timeout_reports_status_sidecar
	test_validation_failure_preserves_diff
	test_stale_lock_recovers
	test_live_lock_blocks_with_owner_details
	test_allow_noop_returns_noop
	test_noop_without_opt_in_fails_contract
	test_instruction_file_preserves_shell_sensitive_content
	test_created_file_patch_preview
	test_failed_run_has_guidance
	test_predirty_file_edit_is_detected
	test_predirty_file_untouched_is_not_reported
	test_subdirectory_invocation_normalizes_paths
	test_agent_commit_fails_head_check
	test_docs_reference_manifest_and_validation

	echo "PASS pea_shooter_contract_test"
}

main "$@"
