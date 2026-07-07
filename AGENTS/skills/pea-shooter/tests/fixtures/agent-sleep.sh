#!/usr/bin/env bash
set -euo pipefail

sleep "${FAKE_AGENT_SLEEP_SECONDS:-5}"
printf '%s\n' '// late update' >>src.ts
