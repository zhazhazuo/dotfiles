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
