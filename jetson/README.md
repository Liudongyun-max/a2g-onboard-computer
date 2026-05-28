# Jetson Module Placeholder

This repository snapshot currently contains the Windows ground station assets and shared deployment contracts. Jetson runtime source files should be placed under this directory when they are merged into the dual-system repository.

Do not add fabricated Jetson service or control implementations. Keep the current safety boundary:

```text
mavlink.enabled=false
vision-landing.service=disabled/inactive
safety_mode=monitor_only
```
