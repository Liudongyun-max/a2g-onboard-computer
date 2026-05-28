# A2G Onboard Computer and Ground Station

本仓库用于维护 A2G 项目的 Windows 地面站、Jetson 机载端、共享协议和部署入口。

## 总体原则

一个仓库，两端模块，统一协议，分端部署。

```text
Jetson 负责看见和建议；
MAVLink 负责传输；
飞控负责稳定和落地；
QGroundControl / 遥控器负责监督和接管。
```

## 目录结构

- `windows/`：Windows 地面站控制台、PowerShell 检查脚本、QGC / SSH / VLC 入口。
- `jetson/`：Jetson 机载端 Dashboard、ArUco 检测、Ground Command API、安全门禁和 systemd 服务。
- `shared/`：双端共享的 API 契约、状态 schema、命令白名单和安全边界。
- `deploy/`：平台识别和分端部署入口。
- `docs/`：项目规范和阶段文档。

## 当前安全阶段

当前阶段为 `monitor_only`：

- `mavlink.enabled=false`
- `vision-landing.service=disabled/inactive`
- Windows Ground Station Console 只发送监管类白名单信号
- Jetson 不通过 API 执行飞控控制

允许命令：

```text
ping
status_snapshot
mark_event
start_record
stop_record
shadow_start
shadow_stop
```

禁止命令：

```text
enable_mavlink
start_vision_landing
send_velocity
arm
takeoff
land
set_mode
```

## Windows 部署入口

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\bootstrap.ps1
```

启动 Windows Ground Station Console：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\scripts\open_ground_station_console.ps1
```

## Jetson 部署入口

```bash
bash deploy/bootstrap.sh
```

如果在 Jetson 运行时工程内，应进入：

```bash
cd "/home/jetson/on-board computer"
```

再执行项目本地自检脚本，例如：

```bash
bash scripts/integration_preflight.sh
```

## Windows-Jetson 快速联调

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\scripts\quick_link_test.ps1 -JetsonIp 192.168.1.219 -Port 8080 -OpenDashboard
```

Jetson：

```bash
cd "/home/jetson/on-board computer"
bash scripts/quick_link_start.sh
bash scripts/quick_link_watch.sh
```

## Ground Command API

Windows 控制台发送：

```text
POST http://<jetson-ip>:8080/api/ground-command
Content-Type: application/json
```

请求示例：

```json
{
  "command": "mark_event",
  "params": {
    "note": "ground test"
  },
  "client": "windows-ground-console"
}
```

当前阶段任何飞控控制类命令都必须被拒绝。

## 安全边界

禁止通过 Ground Command API 执行以下飞控控制类命令：

- `enable_mavlink`
- `start_vision_landing`
- `send_velocity`
- `arm`
- `takeoff`
- `land`
- `set_mode`

## 推送规范

双系统合并部署和推送规范见：

```text
docs/GITHUB_DUAL_SYSTEM_PUSH_STANDARD.md
```

推送前必须确认没有提交以下运行产物：

```text
logs/*
reports/*
*.mjpg
*.mp4
*.lnk
*.exe
*.dll
*.zip
*.7z
__pycache__/
.venv/
.vscode/
.idea/
```

## 参考文档

```text
A2G_Project_Principles.md
docs/GITHUB_DUAL_SYSTEM_PUSH_STANDARD.md
windows/docs/WINDOWS_GROUND_CONSOLE.md
windows/docs/WINDOWS_JETSON_LINK_TEST.md
shared/api/ground_command_contract.md
shared/docs/safety_boundary.md
```
