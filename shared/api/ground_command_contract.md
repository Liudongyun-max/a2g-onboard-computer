# Ground Command API Contract

Endpoint:

```text
POST /api/ground-command
Content-Type: application/json
X-A2G-Token: <optional token>
```

Request:

```json
{
  "command": "mark_event",
  "params": {
    "note": "ground test"
  },
  "client_time": "2026-05-28T14:30:00+08:00",
  "client": "windows-ground-console"
}
```

Success response:

```json
{
  "ok": true,
  "command_id": "cmd_20260528_143000_001",
  "command": "mark_event",
  "accepted": true,
  "executed": true,
  "reason": "event marked",
  "safety_mode": "monitor_only"
}
```

Rejected response:

```json
{
  "ok": false,
  "command_id": "cmd_20260528_143001_002",
  "command": "send_velocity",
  "accepted": false,
  "executed": false,
  "reason": "flight_control_forbidden_when_mavlink_disabled",
  "safety_mode": "monitor_only"
}
```

Allowed commands are defined in `command_whitelist.json`.

Hard rules:

- `mavlink.enabled=false` means every flight-control command must be rejected.
- The API must not start `vision-landing.service`.
- The API must not arm, take off, land, set mode, or send velocity.
- Windows ground station commands may only affect monitoring, logging, event marking, recording flags, and Shadow state.
