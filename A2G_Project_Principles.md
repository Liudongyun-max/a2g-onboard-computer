# A2G Project Principles

一个仓库，两端模块，统一协议，分端部署。

## Boundaries

- Windows 地面端负责监管、交互、可视化、测试报告、QGroundControl / SSH / VLC 入口。
- Jetson 机载端负责视觉检测、Dashboard、Ground Command API、安全门禁和日志。
- `shared/` 只保存双端必须共同遵守的协议、状态 schema、命令白名单和安全边界。
- `deploy/` 只做平台识别和部署调度，不放业务逻辑。

## Current Safety Phase

- `mavlink.enabled=false`
- `vision-landing.service` 必须保持 disabled / inactive
- `safety_mode=monitor_only`
- Windows Ground Station 只发送监管类白名单信号

Allowed ground commands:

- `ping`
- `status_snapshot`
- `mark_event`
- `start_record`
- `stop_record`
- `shadow_start`
- `shadow_stop`

Forbidden control commands:

- `enable_mavlink`
- `start_vision_landing`
- `send_velocity`
- `arm`
- `takeoff`
- `land`
- `set_mode`
