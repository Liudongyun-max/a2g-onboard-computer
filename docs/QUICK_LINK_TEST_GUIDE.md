# A2G Jetson / Windows 快速联调测试教材

本文用于把 Jetson 机载端和 Windows 地面站端快速连通。当前阶段只做监管、日志、Shadow 标记和状态读取，不启用 MAVLink 控制。

## 1. 当前安全边界

- Jetson Dashboard 端口：`8080`
- Jetson Dashboard：`http://<JETSON_IP>:8080`
- Status：`http://<JETSON_IP>:8080/status`
- Stream：`http://<JETSON_IP>:8080/stream`
- Ground Command API：`POST http://<JETSON_IP>:8080/api/ground-command`
- 配置必须保持：`configs/aruco_live.yaml` 中 `mavlink.enabled=false`
- 禁止通过地面站启动 `vision-landing.service`
- 禁止地面站直接发送飞控控制类命令

## 2. Jetson 端一键启动

在 Jetson 终端执行：

```bash
cd "/home/jetson/on-board computer"
bash scripts/quick_link_start.sh
```

脚本会自动完成：

- 检查 `mavlink.enabled=false`
- 重启并检查 `vision-dashboard.service`
- 检查 `/status`
- 打印 Jetson 局域网 IP 和 Dashboard 地址
- 向本机 `/api/ground-command` 发送 `ping`
- 执行 `tools/ground_command_selftest.py`
- 写入联调会话记录到 `logs/link_sessions/`

如果只想检查当前服务，不重启 Dashboard：

```bash
cd "/home/jetson/on-board computer"
bash scripts/quick_link_start.sh --no-restart
```

## 3. Jetson 端观察日志

另开一个 Jetson 终端：

```bash
cd "/home/jetson/on-board computer"
bash scripts/quick_link_watch.sh
```

重点观察：

- `logs/ground_commands.jsonl`
- `logs/system_events.jsonl`

每次 Windows 端点击或发送命令后，Jetson 日志应出现对应记录。

## 4. Windows 端快速测试

建议把 Jetson 项目内的模板脚本复制到 Windows：

```text
/home/jetson/on-board computer/windows/quick_link_test.ps1
```

推荐放到：

```text
F:\A2G Windows\scripts\quick_link_test.ps1
```

然后在 Windows PowerShell 执行：

```powershell
powershell -ExecutionPolicy Bypass -File "F:\A2G Windows\scripts\quick_link_test.ps1" -JetsonIp 192.168.1.219 -Port 8080 -OpenDashboard
```

如果 Jetson IP 变化，把 `192.168.1.219` 替换成 `quick_link_start.sh` 输出的地址。

## 5. Windows 手动检查命令

```powershell
Test-NetConnection 192.168.1.219 -Port 8080
curl.exe http://192.168.1.219:8080/status
start http://192.168.1.219:8080
```

发送一次安全 `ping`：

```powershell
$body = @{
  command = "ping"
  params = @{}
  client_time = (Get-Date).ToString("o")
  client = "windows-manual-test"
} | ConvertTo-Json

Invoke-RestMethod -Method Post `
  -Uri "http://192.168.1.219:8080/api/ground-command" `
  -ContentType "application/json" `
  -Body $body
```

## 6. PASS 标准

一次快速联调通过必须同时满足：

- Windows `Test-NetConnection` 显示 `TcpTestSucceeded=True`
- 浏览器能打开 `http://<JETSON_IP>:8080`
- `/status` 返回 JSON
- `/stream` 能看到摄像头画面或 Dashboard 视频预览
- `ping/status_snapshot/mark_event/start_record/stop_record/shadow_start/shadow_stop` 返回 `accepted=true`
- `send_velocity/arm/takeoff/land/set_mode/start_vision_landing/enable_mavlink` 返回拒绝
- Jetson 日志 `ground_commands.jsonl` 有完整记录
- `mavlink.enabled=false` 未被修改

## 7. 常见故障

`Test-NetConnection=False`：

- 确认 Windows 和 Jetson 在同一 Wi-Fi、手机热点或局域网
- 确认 Jetson IP 是否变化
- 在 Jetson 执行 `bash scripts/quick_link_start.sh --no-restart`
- 确认 Windows 防火墙或网络类型没有阻断局域网访问

`/status` 不返回：

- 在 Jetson 执行 `systemctl --user status vision-dashboard.service`
- 查看 `logs/dashboard.log`
- 确认端口 `8080` 没有被其他程序占用

`/stream` 黑屏或打不开：

- 确认 Dashboard 正在占用 `/dev/video0`
- 不要同时启动 UDP 视频脚本和 Dashboard 争抢同一个摄像头
- 检查摄像头设备权限和连接状态

命令被拒绝：

- 当前阶段拒绝飞控控制类命令是正确结果
- 如果安全命令也被拒绝，检查是否启用了 `A2G_GROUND_COMMAND_TOKEN`

## 8. 后续进入 Shadow 测试前

进入真实飞行相关阶段前，必须先完成：

- 相机内参和 ArUco 尺度标定复核
- 相机外参和机体系符号映射确认
- Z 轴滤波、落地判定和停桨逻辑评审
- QGroundControl 人工接管流程验证
- 明确 MAVLink 启用时机和只读/写入权限边界

GitHub 推送、拉取和新 Jetson 复现部署流程见 `docs/GITHUB_JETSON_DEPLOY.md`。
