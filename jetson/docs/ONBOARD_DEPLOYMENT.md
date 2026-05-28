# On-board Computer Deployment

Project root:

```text
/home/jetson/on-board computer
```

## Manual Checks

```bash
cd "/home/jetson/on-board computer"
bash scripts/onboard_status.sh
```

## Web Dashboard

Run manually:

```bash
cd "/home/jetson/on-board computer"
bash scripts/run_dashboard.sh
```

Open from the ground-station browser:

```text
http://<jetson-ip>:8080
```

The dashboard owns `/dev/video0`. Do not run `visualize_aruco.sh`,
`run_aruco_live.sh`, or another video streaming command at the same time unless
the camera supports concurrent consumers.

Dashboard status is also logged to:

```text
logs/dashboard_status.jsonl
```

Windows Ground Station command API:

```text
POST http://<jetson-ip>:8080/api/ground-command
```

Ground commands are monitor-only in this phase. Logs:

```text
logs/ground_commands.jsonl
logs/system_events.jsonl
```

## Vision Landing Runtime

Run manually:

```bash
cd "/home/jetson/on-board computer"
bash scripts/run_aruco_live.sh
```

Current MAVLink output remains disabled in `configs/aruco_live.yaml`:

```yaml
mavlink:
  enabled: false
```

Keep it disabled until camera extrinsics, body-frame mapping, and shadow tests
are complete.

## systemd Services

User-level install, no root required:

```bash
cd "/home/jetson/on-board computer"
bash scripts/install_user_service.sh
```

User-level start/stop:

```bash
systemctl --user start vision-dashboard
systemctl --user stop vision-dashboard
systemctl --user start vision-landing
systemctl --user stop vision-landing
```

User-level logs:

```bash
journalctl --user -u vision-dashboard -f
journalctl --user -u vision-landing -f
```

System-level install, root required:

```bash
cd "/home/jetson/on-board computer"
bash scripts/install_service.sh
```

Start/stop:

```bash
sudo systemctl start vision-dashboard
sudo systemctl stop vision-dashboard
sudo systemctl start vision-landing
sudo systemctl stop vision-landing
```

Logs:

```bash
journalctl -u vision-dashboard -f
journalctl -u vision-landing -f
```

Recommended during current calibration stage:

```text
Run vision-dashboard for monitoring.
Do not run vision-dashboard and vision-landing simultaneously if both need /dev/video0.
```

## Ground Station Link Test

Windows-side link test steps are documented in:

```text
docs/WINDOWS_LINK_TEST.md
```

Jetson-side port status:

```bash
cd "/home/jetson/on-board computer"
bash scripts/port_status.sh
```

Phase 2 Windows Console integration:

```bash
cd "/home/jetson/on-board computer"
bash scripts/integration_preflight.sh
```

Procedure:

```text
docs/PHASE2_GROUND_JETSON_TEST.md
```
