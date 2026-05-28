# Windows Ground Station Link Test

Jetson on-board computer:

```text
Project: /home/jetson/on-board computer
Jetson IP observed during deployment: 192.168.1.219
Dashboard: TCP 8080
Backup video: UDP 5600
QGroundControl MAVLink: UDP 14550, flight-controller dependent
```

## 1. Jetson-side Preflight

SSH into Jetson from Windows:

```powershell
ssh jetson@192.168.1.219
```

Then run:

```bash
cd "/home/jetson/on-board computer"
bash scripts/port_status.sh
```

Expected:

- `vision-dashboard.service` is active.
- `0.0.0.0:8080` is listening.
- `/status` returns JSON.
- `/dev/video0` is owned by `web_dashboard.py` while dashboard is running.

## 2. Windows PowerShell Checks

```powershell
ping 192.168.1.219
Test-NetConnection 192.168.1.219 -Port 8080
curl.exe http://192.168.1.219:8080/status
```

Browser:

```text
http://192.168.1.219:8080
```

Ground Command API:

```powershell
$body = @{
  command = "ping"
  params = @{}
  client_time = (Get-Date).ToString("o")
  client = "windows-ground-console"
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Post `
  -Uri "http://192.168.1.219:8080/api/ground-command" `
  -ContentType "application/json" `
  -Body $body
```

Allowed first-stage commands:

```text
ping
status_snapshot
mark_event
start_record
stop_record
shadow_start
shadow_stop
```

Forbidden commands are rejected on Jetson:

```text
enable_mavlink
start_vision_landing
send_velocity
arm
takeoff
land
set_mode
```

Jetson logs all ground commands to:

```text
logs/ground_commands.jsonl
```

Operator event/status logs are written to:

```text
logs/system_events.jsonl
```

MJPEG stream endpoint:

```text
http://192.168.1.219:8080/stream
```

## 3. QGroundControl

Install and open QGroundControl on Windows.

Current Jetson config keeps MAVLink disabled:

```yaml
mavlink:
  enabled: false
```

QGroundControl should connect to the flight controller through USB, telemetry
radio, or Wi-Fi/UDP. Do not enable Jetson closed-loop MAVLink control until
camera extrinsics and shadow tests are complete.

Common QGC UDP port:

```text
14550/UDP
```

## 4. Backup VLC/GStreamer Video

The web dashboard already streams video over TCP 8080. Use UDP 5600 only as a
backup video path.

Important: the backup UDP video script needs `/dev/video0`; stop dashboard first:

```bash
systemctl --user stop vision-dashboard
GROUND_STATION_IP=<windows-ip> bash scripts/run_udp_video.sh
```

Windows VLC:

```text
Media -> Open Network Stream -> udp://@:5600
```

Windows GStreamer:

```powershell
gst-launch-1.0 udpsrc port=5600 caps="application/x-rtp,media=video,encoding-name=H264,payload=96" ! rtph264depay ! avdec_h264 ! autovideosink
```

After backup video testing:

```bash
systemctl --user start vision-dashboard
```

## 5. Current Safe Operating Rule

Only one process should own `/dev/video0`:

```text
Dashboard OR local visualize OR UDP video OR landing runtime
```

During current integration, use dashboard as the primary monitor and keep
`vision-landing.service` disabled.
