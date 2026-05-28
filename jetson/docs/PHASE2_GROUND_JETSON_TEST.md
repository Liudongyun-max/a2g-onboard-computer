# Phase 2 Ground Station and Jetson Integration Test

This phase validates the Windows Ground Station Console against the Jetson
monitor-only command API. It does not enable MAVLink control.

## Safety Boundary

Required Jetson state:

```yaml
mavlink:
  enabled: false
```

Required service state:

```text
vision-dashboard.service: running
vision-landing.service: disabled or inactive
```

The ground command API may only change monitoring flags, shadow state, and logs.
It must not start flight control, arm, take off, land, set mode, or send velocity.

## Jetson Preflight

On Jetson:

```bash
cd "/home/jetson/on-board computer"
bash scripts/integration_preflight.sh
```

Expected:

```text
Dashboard status returns JSON
Ground command API self-test: PASS
mavlink.enabled: False
8080/TCP listening
```

## Windows Console Checks

PowerShell:

```powershell
ping 192.168.1.219
Test-NetConnection 192.168.1.219 -Port 8080
curl.exe http://192.168.1.219:8080/status
```

Open:

```text
F:\A2G Windows\scripts\ground_station_console.ps1
```

Or desktop shortcut:

```text
A2G Ground Station Console.lnk
```

## Command Test Order

Use the Windows console to send commands in this order:

```text
ping
status_snapshot
mark_event
start_record
stop_record
shadow_start
shadow_stop
```

For each command, verify:

```text
HTTP response ok=true
accepted=true
executed=true
logs/ground_commands.jsonl appended
logs/system_events.jsonl appended for event/snapshot/record/shadow commands
```

## Rejection Test

If the Windows console has a manual command test box, verify these are rejected:

```text
enable_mavlink
start_vision_landing
send_velocity
arm
takeoff
land
set_mode
```

Expected:

```text
ok=false
accepted=false
executed=false
reason=flight_control_forbidden_when_mavlink_disabled
```

## Jetson Live Log Watch

During Windows-side testing, keep one SSH terminal open:

```bash
cd "/home/jetson/on-board computer"
tail -f logs/ground_commands.jsonl
```

Optional second terminal:

```bash
tail -f logs/system_events.jsonl
```

## Pass Criteria

Phase 2 passes when:

```text
Windows dashboard URL opens
Windows console receives valid JSON from /status
All whitelisted commands are accepted and logged
All flight-control commands are rejected
Jetson remains monitor_only
mavlink.enabled remains false
vision-landing.service remains disabled/inactive
```

## Abort Criteria

Stop the test if any of these occur:

```text
mavlink.enabled becomes true
vision-landing.service starts unexpectedly
Dashboard loses /dev/video0
Ground command API accepts a forbidden flight-control command
QGroundControl indicates unexpected mode/control changes
```
