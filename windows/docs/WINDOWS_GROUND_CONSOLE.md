# Windows Ground Station Console

The first-stage Windows interaction layer is a single WinForms dialog:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\open_ground_station_console.ps1
```

The desktop shortcut starts the same console through:

```text
scripts/launch_ground_station_console_hidden.vbs
```

This hides the intermediate PowerShell host and shows only the ground-station
dialog.

## Resizable Layout

The console uses split panes:

```text
left/right splitter: adjust Dashboard status vs. operation controls
top/bottom splitter: adjust main panel vs. message log
```

When maximized, the Dashboard status area expands by default while the command
panel and message log remain compact. Drag the splitters to resize text areas
for the current session.

## Included Controls

Observation:

```text
Refresh /status
Open Dashboard
Load /stream
```

`Load /stream` renders the Jetson MJPEG stream inside the left-side "Live
Video" tab instead of opening a browser window. The console parses MJPEG frames
directly and renders them into a native picture panel, so it does not depend on
the legacy WinForms browser control. The "Status JSON" tab keeps the raw
`/status` output available for diagnostics.

Maintenance and operator tools:

```text
Open QGC
Open SSH
Open VLC UDP 5600
Run Ground Check
```

Ground command signals:

```text
ping
status_snapshot
mark_event
start_record
stop_record
shadow_start
shadow_stop
```

## Command API Contract

Buttons in the "Ground Command Signals" panel send:

```text
POST http://192.168.1.219:8080/api/ground-command
```

Headers:

```text
Content-Type: application/json
X-A2G-Token: value of A2G_GROUND_TOKEN, when configured
```

Payload:

```json
{
  "command": "mark_event",
  "params": {
    "note": "ground test"
  },
  "client_time": "2026-05-27T10:30:00.0000000+08:00",
  "client": "windows-ground-console"
}
```

The Windows console does not execute arbitrary shell commands for these signals.
Jetson must accept or reject each signal through its Command API and Safety Gate.
