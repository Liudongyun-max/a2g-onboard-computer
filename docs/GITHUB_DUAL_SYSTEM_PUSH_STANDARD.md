# GitHub 双系统合并部署与推送规范

本文档用于规范 A2G 项目在同一个 GitHub 仓库内同时维护 Windows 地面端和 Ubuntu / Jetson 机载端代码时的目录结构、提交边界、忽略规则、部署入口和冲突规避方式。

目标是：用户拉取同一个仓库后，部署入口能够自动识别当前系统是 Windows 还是 Ubuntu / Jetson，并执行对应模块部署；双端部署完成后，再进入 Windows-Jetson 联调测试。

## 1. 总体原则

```text
一个仓库，两端模块，统一协议，分端部署。
```

必须保持：

```text
Windows 地面端：监管、交互、可视化、测试报告、QGC / SSH / VLC 入口
Jetson 机载端：视觉检测、Dashboard、Ground Command API、安全门禁、日志
共享协议层：命令白名单、状态字段、接口契约、安全边界
```

禁止：

```text
Windows 端脚本直接修改 Jetson 源码目录
Jetson 端部署脚本写入 Windows 专属目录
两端共用同名 runtime 日志目录并提交日志
把 reports、logs、视频探测文件、大型二进制工具提交到 GitHub
通过 Ground Command API 绕过安全门禁执行飞控控制
```

## 2. 推荐仓库结构

合并仓库建议采用以下结构：

```text
repo/
  README.md
  A2G_Project_Principles.md
  .gitignore
  .gitattributes

  shared/
    api/
      ground_command_contract.md
      status_schema.json
      command_whitelist.json
    docs/
      safety_boundary.md

  windows/
    config/
      ground_station.json
    scripts/
      ground_station_console.ps1
      open_ground_station_console.ps1
      launch_ground_station_console_hidden.vbs
      a2g_ground_check.ps1
      test_dashboard_sampling.ps1
      test_stream_probe.ps1
      test_jetson_readonly.ps1
    docs/
      WINDOWS_GROUND_CONSOLE.md
      WINDOWS_JETSON_LINK_TEST.md
    assets/
      a2g-ground-station-logo.ico
      a2g-ground-station-logo.svg
      a2g-ground-station-logo-256.png
    logs/
      .gitkeep
    reports/
      .gitkeep
    tools/
      .gitkeep
      vlc/
        README.md

  jetson/
    configs/
      aruco_live.yaml
    scripts/
      port_status.sh
      run_udp_video.sh
      integration_preflight.sh
      install_jetson.sh
    tools/
      ground_command_selftest.py
    docs/
      PHASE2_GROUND_JETSON_TEST.md
    services/
      vision-dashboard.service
      vision-landing.service
    logs/
      .gitkeep

  deploy/
    bootstrap.ps1
    bootstrap.sh
    detect_platform.py
    README.md
```

如果当前仓库已经以 Windows 端为根目录，可以先保持现状，但后续合并 Jetson 端时必须迁移到上述模块化结构。迁移时建议使用 `git mv`，不要直接复制后删除，减少历史丢失。

## 3. 模块职责边界

### 3.1 Windows 模块

Windows 目录只放地面端内容：

```text
WinForms 地面站控制台
PowerShell 检查脚本
VBS 隐藏启动器
Windows 快捷方式生成逻辑
QGroundControl / SSH / VLC 启动入口
Windows 本地 reports 和 logs 占位
```

Windows 模块不得包含：

```text
Jetson systemd 用户服务安装逻辑
Jetson Python 视觉主程序
Jetson /dev/video0 控制脚本
飞控控制实现逻辑
```

### 3.2 Jetson 模块

Jetson 目录只放 Ubuntu / Jetson 端内容：

```text
Dashboard 服务
ArUco 检测配置
Ground Command API
Safety Gate
systemd user service
Jetson 自检脚本
UDP 视频脚本
机载端日志占位
```

Jetson 模块不得包含：

```text
Windows .lnk 文件
Windows portable VLC 二进制
Windows PowerShell GUI 专属逻辑
QGroundControl 安装包
```

### 3.3 Shared 模块

共享模块只放双端都必须遵守的协议：

```text
Ground Command API 契约
/status schema
命令白名单
禁止命令列表
安全边界说明
```

共享模块不得放运行产物和平台专属脚本。

## 4. 自动识别系统的部署入口

### 4.1 Windows 用户入口

Windows 用户在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\bootstrap.ps1
```

`bootstrap.ps1` 负责：

```text
确认当前系统是 Windows
检查 PowerShell 版本
检查 OpenSSH Client
检查 Chrome / Edge
检查 QGroundControl
检查 VLC 或提示部署 portable VLC
检查 windows/config/ground_station.json
创建桌面快捷方式
执行 windows/scripts/a2g_ground_check.ps1 -SkipNetwork
提示用户执行完整网络检查
```

### 4.2 Ubuntu / Jetson 用户入口

Jetson 用户在仓库根目录执行：

```bash
bash deploy/bootstrap.sh
```

`bootstrap.sh` 负责：

```text
确认当前系统是 Linux
确认是否为 Jetson / Ubuntu 环境
检查 Python 和必要依赖
检查 /dev/video0
检查 configs/aruco_live.yaml
安装或更新 user systemd 服务
确保 vision-dashboard.service enabled / running
确保 vision-landing.service disabled / inactive
执行 jetson/scripts/integration_preflight.sh
```

### 4.3 平台识别规则

平台识别建议：

```text
Windows:
  PowerShell $IsWindows 或 [System.Environment]::OSVersion.Platform

Ubuntu / Jetson:
  uname -s = Linux
  /etc/os-release 存在
  可选检查 /etc/nv_tegra_release 或 jetson_release
```

不要在 Windows 上调用 Bash 部署 Jetson，也不要在 Jetson 上调用 PowerShell GUI 部署 Windows。

## 5. 文件命名规范

Windows 专属：

```text
*.ps1
*.vbs
*.ico
*.lnk，不提交
windows_*.md
```

Jetson / Ubuntu 专属：

```text
*.sh
*.service
*.yaml
*.py
jetson_*.md
```

共享协议：

```text
*_contract.md
*_schema.json
command_whitelist.json
safety_boundary.md
```

禁止出现：

```text
scripts/setup.ps1 和 scripts/setup.sh 混放在同一 scripts 根目录
config/config.json 同时被 Windows 和 Jetson 改写
logs/ground_commands.jsonl 被提交
reports/*.json 被提交
```

## 6. 换行符和文件属性规范

必须提交 `.gitattributes`。

建议规则：

```gitattributes
* text=auto

*.ps1 text eol=crlf
*.vbs text eol=crlf
*.bat text eol=crlf
*.cmd text eol=crlf

*.sh text eol=lf
*.service text eol=lf
*.py text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
*.json text eol=lf
*.md text eol=lf

*.png binary
*.ico binary
*.jpg binary
*.jpeg binary
*.mjpg binary
*.mp4 binary
*.dll binary
*.exe binary
```

原因：

```text
PowerShell / VBS 在 Windows 上使用 CRLF 更稳
Bash / systemd / Python / YAML 在 Jetson 上必须避免 CRLF
图片、视频、二进制工具必须 binary，避免 Git 改写
```

## 7. .gitignore 规范

仓库级 `.gitignore` 必须忽略：

```gitignore
# Runtime logs
logs/*
**/logs/*
!logs/.gitkeep
!**/logs/.gitkeep

# Reports and probes
reports/*
**/reports/*
!reports/.gitkeep
!**/reports/.gitkeep

# Media captures
*.mjpg
*.mp4
*.avi
*.mov
*.mkv

# Local binaries and portable tools
tools/vlc/vlc-*/
**/tools/vlc/vlc-*/
*.exe
*.dll
*.zip
*.7z

# Windows local shortcuts
*.lnk
Thumbs.db
Desktop.ini

# Python / editor cache
__pycache__/
*.pyc
.venv/
.vscode/
.idea/
*.tmp
*.log
```

如果确实需要提交某个小型 `.exe` 或工具，必须单独说明理由，并用更精确的 `!path/to/file.exe` 放行。默认不提交二进制工具。

## 8. 提交边界规范

### 8.1 Windows 端提交

只允许改：

```text
windows/
shared/api/，仅当接口契约同步变化
docs/，仅当文档同步变化
README.md，必要时
```

提交信息建议：

```text
windows: update ground station console layout
windows: add mjpeg stream renderer
windows: improve ground check script
```

### 8.2 Jetson 端提交

只允许改：

```text
jetson/
shared/api/，仅当接口契约同步变化
docs/，仅当文档同步变化
README.md，必要时
```

提交信息建议：

```text
jetson: add ground command safety gate
jetson: update dashboard status schema
jetson: add integration preflight script
```

### 8.3 协议变更提交

当改动影响 Windows 和 Jetson 双端时，必须单独提交协议变更：

```text
shared: update ground command contract
```

然后再分端提交实现：

```text
windows: support new status field
jetson: expose new status field
```

不要把协议、Windows UI、Jetson 服务、运行报告混在一个提交里。

## 9. 分支策略

推荐：

```text
main：稳定可部署版本
develop：双端集成开发
windows/*：Windows 地面端功能分支
jetson/*：Jetson 机载端功能分支
shared/*：接口协议和安全边界变更分支
release/*：阶段验收版本
```

示例：

```text
windows/console-mjpeg-viewer
jetson/ground-command-api
shared/status-schema-v2
release/phase2-ground-jetson-link
```

## 10. 合并前检查清单

每个 PR 或合并前必须检查：

```text
[ ] 没有提交 logs/*
[ ] 没有提交 reports/*
[ ] 没有提交 *.mjpg / *.mp4
[ ] 没有提交 *.lnk
[ ] 没有提交 tools/vlc/vlc-* portable 二进制
[ ] Windows 脚本仍可执行 -SelfTest
[ ] Jetson Bash 脚本没有 CRLF
[ ] systemd service 没有 CRLF
[ ] shared/api 契约与双端实现一致
[ ] README 部署入口仍正确
[ ] 当前安全边界没有被放宽
```

Windows 本地检查：

```powershell
git status --short
git diff --check
powershell -ExecutionPolicy Bypass -File .\windows\scripts\ground_station_console.ps1 -SelfTest
powershell -ExecutionPolicy Bypass -File .\windows\scripts\a2g_ground_check.ps1 -SkipNetwork
```

Jetson 本地检查：

```bash
git status --short
git diff --check
bash jetson/scripts/integration_preflight.sh
python3 jetson/tools/ground_command_selftest.py
```

## 11. 双端部署流程

### 11.1 用户拉取仓库

```bash
git clone https://github.com/<owner>/<repo>.git
cd <repo>
```

### 11.2 Windows 端部署

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\bootstrap.ps1
```

完成后应具备：

```text
Windows Ground Station Console 可启动
Dashboard /status 可刷新
Live Video 可显示 /stream
QGroundControl / SSH / VLC 按钮可用
Ground Command 白名单按钮可发送
```

### 11.3 Jetson 端部署

```bash
bash deploy/bootstrap.sh
```

完成后应具备：

```text
vision-dashboard.service running / enabled
vision-landing.service disabled / inactive
Dashboard 监听 0.0.0.0:8080
/status 正常
/stream 正常
POST /api/ground-command 正常
logs/ground_commands.jsonl 正常写入
mavlink.enabled=false
safety_mode=monitor_only
```

### 11.4 双端联调

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\scripts\open_ground_station_console.ps1
```

Jetson：

```bash
cd "/home/jetson/on-board computer"
tail -f logs/ground_commands.jsonl
```

Windows 控制台依次点击：

```text
Refresh /status
Ping
Status Snapshot
Mark Event
Start Record
Stop Record
Shadow Start
Shadow Stop
```

验收标准：

```text
白名单命令全部 accepted=true, executed=true
禁止类命令全部 403
Dashboard 视频不中断
mavlink.enabled=false
vision-landing.service disabled / inactive
QGroundControl 只用于监控和人工接管
```

## 12. 冲突处理规范

### 12.1 配置冲突

Windows 配置：

```text
windows/config/ground_station.json
```

Jetson 配置：

```text
jetson/configs/aruco_live.yaml
```

共享协议：

```text
shared/api/command_whitelist.json
shared/api/status_schema.json
```

不要让 Windows 和 Jetson 同时修改同一个运行配置文件。

### 12.2 日志冲突

日志永远不提交。只提交 `.gitkeep`。

如果需要保留一次验收结果，写成文档摘要：

```text
docs/test-reports/phase2_summary.md
```

不要提交原始 `.jsonl`、`.mjpg`、大体积视频。

### 12.3 脚本冲突

Windows 和 Jetson 脚本分目录：

```text
windows/scripts/
jetson/scripts/
deploy/
```

`deploy/` 只放平台识别和调度脚本，不放业务逻辑。

### 12.4 API 冲突

如果新增命令或状态字段，先改：

```text
shared/api/
```

再分别改：

```text
windows/
jetson/
```

任何 API 变更必须注明：

```text
字段名
类型
默认值
是否向后兼容
Windows UI 行为
Jetson Safety Gate 行为
```

## 13. 当前阶段安全边界

当前阶段必须保持：

```text
mavlink.enabled=false
vision-landing.service=disabled/inactive
safety_mode=monitor_only
Windows Ground Station Console 只发送监管类白名单信号
```

允许：

```text
ping
status_snapshot
mark_event
start_record
stop_record
shadow_start
shadow_stop
```

禁止：

```text
enable_mavlink
start_vision_landing
send_velocity
arm
takeoff
land
set_mode
```

## 14. 推送前最终命令

首次建仓：

```bash
git init
git add README.md A2G_Project_Principles.md .gitignore .gitattributes shared windows jetson deploy
git commit -m "Add dual-system A2G deployment workspace"
git branch -M main
git remote add origin https://github.com/<owner>/<repo>.git
git push -u origin main
```

已有仓库：

```bash
git status --short
git diff --check
git add README.md A2G_Project_Principles.md .gitignore .gitattributes shared windows jetson deploy
git commit -m "Document dual-system deployment and push standards"
git push
```

如果当前仓库尚未完成目录迁移，先提交规范文档：

```bash
git add docs/GITHUB_DUAL_SYSTEM_PUSH_STANDARD.md .gitattributes .gitignore README.md
git commit -m "Add dual-system GitHub push standard"
```

## 15. 一句话规范

```text
平台代码分目录，接口契约放 shared，部署入口放 deploy，运行产物不入库，安全边界不放宽。
```
