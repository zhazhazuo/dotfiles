#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" >/tmp/pea-shooter-agent-args.log
printf '%s\n' '// updated by fake agent' >>src.ts
