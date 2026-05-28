#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== Jetson IP addresses =="
hostname -I || true

echo
echo "== Listening ports =="
ss -ltnup | grep -E '(:8080|:5600|:14550|:5760)' || true

echo
echo "== Dashboard user service =="
systemctl --user --no-pager --full status vision-dashboard || true

echo
echo "== Dashboard HTTP status =="
curl -s --max-time 2 http://127.0.0.1:8080/status || true

echo
echo
echo "== Camera owner =="
fuser -v /dev/video0 /dev/video1 2>&1 || true

echo
echo "== Recent dashboard logs =="
tail -n 3 "$PROJECT_ROOT/logs/dashboard_status.jsonl" 2>/dev/null || true
