#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JETSON_ROOT="$REPO_ROOT/jetson"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "FAIL: deploy/bootstrap.sh must run on Ubuntu / Jetson Linux." >&2
  exit 1
fi

echo "A2G Linux / Jetson bootstrap"
python3 "$REPO_ROOT/deploy/detect_platform.py"

cd "$JETSON_ROOT"

bash scripts/check_system.sh || true
bash scripts/check_camera.sh /dev/video0 640 480 30 || true

if [[ ! -f configs/env.local ]]; then
  cp configs/env.example configs/env.local
  echo "Created jetson/configs/env.local. Review it before flight use."
fi

bash scripts/install_user_service.sh
systemctl --user enable --now vision-dashboard.service
systemctl --user disable --now vision-landing.service || true
bash scripts/integration_preflight.sh

echo
echo "Jetson bootstrap complete."
echo "Dashboard service should be enabled/running."
echo "vision-landing.service remains disabled/inactive for monitor_only phase."
