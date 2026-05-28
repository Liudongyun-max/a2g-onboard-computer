# Windows-Jetson Link Test

## Current Jetson State

```text
Jetson IP: 192.168.1.219
Web Dashboard: 0.0.0.0:8080 listening
vision-dashboard.service: running, enabled
/dev/video0: occupied by Dashboard
ArUco detection: normal
Status log: writing normally
Backup UDP video: deployed on port 5600
MAVLink/QGC: 14550 reserved; Jetson control disabled
```

## Main Windows Link

```powershell
ping 192.168.1.219
Test-NetConnection 192.168.1.219 -Port 8080
curl.exe http://192.168.1.219:8080/status
```

Dashboard:

```text
http://192.168.1.219:8080
http://192.168.1.219:8080/stream
```

SSH maintenance:

```powershell
ssh jetson@192.168.1.219
```

Jetson commands after login:

```bash
cd "/home/jetson/on-board computer"
bash scripts/port_status.sh
journalctl --user -u vision-dashboard -f
```

Restart Dashboard only when needed:

```bash
systemctl --user restart vision-dashboard
```

## QGroundControl

Open QGroundControl and connect to the flight controller. Confirm:

```text
attitude
mode
battery
failsafe
manual takeover path
```

Current Jetson config keeps `mavlink.enabled=false`, so QGC is only for flight
controller monitoring and manual takeover.

## Backup UDP Video

Use only when the Dashboard video path is intentionally stopped. Dashboard owns
`/dev/video0`, so do not run both camera consumers at the same time.

Jetson:

```bash
cd "/home/jetson/on-board computer"
systemctl --user stop vision-dashboard
GROUND_STATION_IP=<Windows电脑IP> bash scripts/run_udp_video.sh
```

Windows VLC:

```text
udp://@:5600
```

Restore Dashboard:

```bash
systemctl --user start vision-dashboard
```
