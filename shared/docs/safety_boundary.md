# A2G Safety Boundary

Current phase: `monitor_only`.

Jetson may run:

- Dashboard HTTP service
- `/status`
- `/stream`
- `POST /api/ground-command`
- Logging and Shadow flags

Jetson must not run flight control from ground commands:

- No arming
- No takeoff
- No landing command
- No mode switch
- No velocity setpoint
- No `vision-landing.service` start from Ground Command API

Before enabling MAVLink control, complete camera intrinsics, ArUco scale, camera extrinsics, Shadow testing, QGroundControl takeover checks, and explicit flight-stage authorization.
