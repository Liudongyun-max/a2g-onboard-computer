#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"

cp "$PROJECT_ROOT/systemd/user-vision-dashboard.service" "$USER_SYSTEMD_DIR/vision-dashboard.service"
cp "$PROJECT_ROOT/systemd/user-vision-landing.service" "$USER_SYSTEMD_DIR/vision-landing.service"

systemctl --user daemon-reload

echo "Installed user services:"
echo "  $USER_SYSTEMD_DIR/vision-dashboard.service"
echo "  $USER_SYSTEMD_DIR/vision-landing.service"
echo
echo "Start dashboard:"
echo "  systemctl --user start vision-dashboard"
echo
echo "View dashboard logs:"
echo "  journalctl --user -u vision-dashboard -f"
echo
echo "Enable on user login:"
echo "  systemctl --user enable vision-dashboard"
echo
echo "For boot without login, an administrator must run:"
echo "  sudo loginctl enable-linger $USER"
