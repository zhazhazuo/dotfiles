#!/usr/bin/env bash
#
# Compatibility wrapper for the tmux agent monitor reconciliation script.

set +e +u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
"${script_dir}/agent-monitor-check.sh" "$@"
exit 0
