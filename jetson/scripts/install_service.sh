#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANDING_SERVICE_SRC="$PROJECT_ROOT/systemd/vision-landing.service"
DASHBOARD_SERVICE_SRC="$PROJECT_ROOT/systemd/vision-dashboard.service"
LANDING_SERVICE_DST="/etc/systemd/system/vision-landing.service"
DASHBOARD_SERVICE_DST="/etc/systemd/system/vision-dashboard.service"

if [[ ! -f "$PROJECT_ROOT/configs/env.local" ]]; then
  cp "$PROJECT_ROOT/configs/env.example" "$PROJECT_ROOT/configs/env.local"
  echo "Created configs/env.local. Review it before enabling the service."
fi

sudo cp "$LANDING_SERVICE_SRC" "$LANDING_SERVICE_DST"
sudo cp "$DASHBOARD_SERVICE_SRC" "$DASHBOARD_SERVICE_DST"
sudo systemctl daemon-reload
echo "Installed $LANDING_SERVICE_DST"
echo "Installed $DASHBOARD_SERVICE_DST"
echo "Enable with: sudo systemctl enable vision-landing"
echo "Start with:  sudo systemctl start vision-landing"
echo "Enable dashboard with: sudo systemctl enable vision-dashboard"
echo "Start dashboard with:  sudo systemctl start vision-dashboard"
