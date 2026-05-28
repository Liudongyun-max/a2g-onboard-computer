# A2G Dual-System Deployment Workspace

This repository maintains both sides of the A2G visual landing test stack:

- `windows/`: Windows ground station console, checks, local logs/reports placeholders.
- `jetson/`: Ubuntu / Jetson onboard vision landing runtime, Dashboard, Ground Command API, services, logs placeholder.
- `shared/`: API contracts, command whitelist, status schema, and safety boundary shared by both sides.
- `deploy/`: platform detection and deployment entrypoints.

## Deployment Entrypoints

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\bootstrap.ps1
```

Ubuntu / Jetson:

```bash
bash deploy/bootstrap.sh
```

## Current Safety Boundary

The current repository state is monitor-only:

- `jetson/configs/aruco_live.yaml` keeps `mavlink.enabled=false`.
- `vision-dashboard.service` may run for Dashboard, `/status`, `/stream`, and Ground Command API.
- `vision-landing.service` must stay disabled / inactive.
- Ground Command API must reject flight-control commands.

## Jetson Quick Link

```bash
cd jetson
bash scripts/quick_link_start.sh
```

## Windows Quick Link

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\scripts\quick_link_test.ps1 -JetsonIp 192.168.1.219 -Port 8080 -OpenDashboard
```

## Documentation

- Dual-system push standard: `docs/GITHUB_DUAL_SYSTEM_PUSH_STANDARD.md`
- Jetson deployment: `jetson/docs/GITHUB_JETSON_DEPLOY.md`
- Jetson/Windows link test: `jetson/docs/QUICK_LINK_TEST_GUIDE.md`
- Shared API contract: `shared/api/ground_command_contract.md`
