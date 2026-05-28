#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${A2G_DASHBOARD_PORT:-8080}"

first_lan_ip() {
  hostname -I 2>/dev/null | tr ' ' '\n' | awk '
    /^127\./ { next }
    /^169\.254\./ { next }
    /^172\.17\./ { next }
    /^172\.18\./ { next }
    /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }
  '
}

JETSON_IP="$(first_lan_ip)"
[[ -n "$JETSON_IP" ]] || JETSON_IP="<JETSON_IP>"

echo "A2G quick link watch"
echo "Dashboard: http://${JETSON_IP}:${PORT}"
echo "Status:    http://${JETSON_IP}:${PORT}/status"
echo "Stream:    http://${JETSON_IP}:${PORT}/stream"
echo
echo "Press Ctrl-C to stop watching logs."
echo

touch "${PROJECT_ROOT}/logs/ground_commands.jsonl" "${PROJECT_ROOT}/logs/system_events.jsonl"
tail -n 40 -F \
  "${PROJECT_ROOT}/logs/ground_commands.jsonl" \
  "${PROJECT_ROOT}/logs/system_events.jsonl"
