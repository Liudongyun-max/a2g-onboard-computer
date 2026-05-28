#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/configs/aruco_live.yaml"
LOG_DIR="${PROJECT_ROOT}/logs/link_sessions"
DASHBOARD_SERVICE="vision-dashboard.service"
PORT="${A2G_DASHBOARD_PORT:-8080}"
HOST="${A2G_DASHBOARD_HOST:-127.0.0.1}"
RESTART_DASHBOARD=1
RUN_SELFTEST=1

usage() {
  cat <<'USAGE'
Usage: bash scripts/quick_link_start.sh [options]

Options:
  --no-restart       Do not restart the vision-dashboard user service.
  --skip-selftest    Skip POST /api/ground-command self-test.
  --port PORT        Dashboard port, default 8080.
  -h, --help         Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-restart)
      RESTART_DASHBOARD=0
      shift
      ;;
    --skip-selftest)
      RUN_SELFTEST=0
      shift
      ;;
    --port)
      PORT="${2:?missing port value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$LOG_DIR"
SESSION_ID="$(date +%Y%m%d_%H%M%S)"
SESSION_LOG="${LOG_DIR}/quick_link_${SESSION_ID}.txt"

log() {
  local line
  line="[$(date '+%F %T')] $*"
  echo "$line"
  echo "$line" >> "$SESSION_LOG"
}

run_and_log() {
  log "+ $*"
  "$@" 2>&1 | tee -a "$SESSION_LOG"
}

first_lan_ip() {
  hostname -I 2>/dev/null | tr ' ' '\n' | awk '
    /^127\./ { next }
    /^169\.254\./ { next }
    /^172\.17\./ { next }
    /^172\.18\./ { next }
    /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }
  '
}

yaml_mavlink_enabled() {
  python3 - "$CONFIG_FILE" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    print("missing")
    sys.exit(0)

enabled = None
in_mavlink = False
for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.split("#", 1)[0].rstrip()
    if not line.strip():
        continue
    if line.startswith("mavlink:"):
        in_mavlink = True
        continue
    if in_mavlink and line and not line.startswith((" ", "\t")):
        in_mavlink = False
    if in_mavlink and line.strip().startswith("enabled:"):
        enabled = line.split(":", 1)[1].strip().lower()
        break
print(enabled if enabled is not None else "unknown")
PY
}

post_json() {
  local payload="$1"
  curl -fsS \
    -H 'Content-Type: application/json' \
    -X POST \
    -d "$payload" \
    "http://${HOST}:${PORT}/api/ground-command"
}

cd "$PROJECT_ROOT"
: > "$SESSION_LOG"

log "A2G quick link start"
log "project_root=${PROJECT_ROOT}"
log "session_log=${SESSION_LOG}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  log "FAIL: missing config ${CONFIG_FILE}"
  exit 1
fi

MAVLINK_ENABLED="$(yaml_mavlink_enabled)"
log "mavlink.enabled=${MAVLINK_ENABLED}"
if [[ "$MAVLINK_ENABLED" != "false" ]]; then
  log "FAIL: current phase requires configs/aruco_live.yaml mavlink.enabled=false"
  exit 1
fi

if [[ "$RESTART_DASHBOARD" -eq 1 ]]; then
  log "Restarting user service ${DASHBOARD_SERVICE}"
  run_and_log systemctl --user restart "$DASHBOARD_SERVICE"
else
  log "Skipping dashboard restart"
fi

run_and_log systemctl --user --no-pager --full status "$DASHBOARD_SERVICE"

log "Waiting for Dashboard on http://${HOST}:${PORT}/status"
for _ in $(seq 1 20); do
  if curl -fsS "http://${HOST}:${PORT}/status" >/tmp/a2g_quick_status.json; then
    break
  fi
  sleep 0.5
done

if ! curl -fsS "http://${HOST}:${PORT}/status" >/tmp/a2g_quick_status.json; then
  log "FAIL: Dashboard status endpoint is not reachable"
  exit 1
fi

log "Dashboard /status response:"
cat /tmp/a2g_quick_status.json | tee -a "$SESSION_LOG"
echo | tee -a "$SESSION_LOG" >/dev/null

python3 - /tmp/a2g_quick_status.json <<'PY' | tee -a "$SESSION_LOG"
import json
import sys
from pathlib import Path

status = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
running = bool(status.get("running"))
mavlink_enabled = bool(status.get("mavlink_enabled"))
detected = bool(status.get("detected"))
fps = status.get("fps")
error = status.get("error")

print(f"status_summary: running={running} detected={detected} fps={fps} mavlink_enabled={mavlink_enabled}")
if not running:
    print("WARN: Dashboard HTTP/API is reachable, but the vision camera loop is not running. Check /dev/video0 ownership, camera connection, or restart dashboard.")
if mavlink_enabled:
    print("FAIL: status reports mavlink_enabled=true, current quick-link phase requires false.")
    sys.exit(1)
if error:
    print(f"WARN: status error={error}")
PY

JETSON_IP="$(first_lan_ip)"
if [[ -z "$JETSON_IP" ]]; then
  JETSON_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
if [[ -z "$JETSON_IP" ]]; then
  JETSON_IP="<JETSON_IP>"
fi

log "Jetson LAN IP guess: ${JETSON_IP}"
log "Dashboard: http://${JETSON_IP}:${PORT}"
log "Status:    http://${JETSON_IP}:${PORT}/status"
log "Stream:    http://${JETSON_IP}:${PORT}/stream"

log "Sending local API ping"
post_json '{"command":"ping","params":{},"client":"jetson-quick-link-start"}' | tee -a "$SESSION_LOG"
echo | tee -a "$SESSION_LOG" >/dev/null

if [[ "$RUN_SELFTEST" -eq 1 && -f "${PROJECT_ROOT}/tools/ground_command_selftest.py" ]]; then
  log "Running ground command self-test"
  run_and_log python3 "${PROJECT_ROOT}/tools/ground_command_selftest.py" --base-url "http://${HOST}:${PORT}"
elif [[ "$RUN_SELFTEST" -eq 1 ]]; then
  log "WARN: tools/ground_command_selftest.py not found, skipping"
else
  log "Skipping self-test"
fi

cat <<EOF | tee -a "$SESSION_LOG"

Windows quick test:
  powershell -ExecutionPolicy Bypass -File "F:\\A2G Windows\\scripts\\quick_link_test.ps1" -JetsonIp ${JETSON_IP} -Port ${PORT}

Windows manual checks:
  Test-NetConnection ${JETSON_IP} -Port ${PORT}
  curl.exe http://${JETSON_IP}:${PORT}/status

Open in browser:
  http://${JETSON_IP}:${PORT}

Watch Jetson logs:
  cd "${PROJECT_ROOT}"
  bash scripts/quick_link_watch.sh

PASS criteria:
  1. /status returns JSON.
  2. /stream can be opened by browser or VLC.
  3. Allowed ground commands return accepted=true.
  4. Forbidden flight commands return accepted=false.
  5. configs/aruco_live.yaml keeps mavlink.enabled=false.
EOF

log "Quick link preparation complete"
