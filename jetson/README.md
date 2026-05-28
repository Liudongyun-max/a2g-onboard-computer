# A2G Jetson Onboard Module

This module contains the Ubuntu / Jetson onboard runtime for the A2G visual landing stack.

## Current Runtime Scope

- ArUco detection and pose estimation
- Web Dashboard
- `/status`
- `/stream`
- `POST /api/ground-command`
- Ground command safety gate
- Monitor-only logging and Shadow flags

Current safety state:

```yaml
mavlink:
  enabled: false
```

`vision-landing.service` must remain disabled / inactive until Shadow testing and flight-control authorization are complete.

## Run From Repository Root

```bash
bash deploy/bootstrap.sh
```

## Run From Jetson Module

```bash
cd jetson
bash scripts/quick_link_start.sh
```
