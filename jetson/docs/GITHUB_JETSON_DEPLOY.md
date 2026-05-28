# Jetson 端 GitHub 推送与拉取部署流程

本文定义 Jetson 机载端项目推送到 GitHub，以及另一台 Jetson 从 GitHub 拉取后复现部署的实际流程。

## 1. 仓库边界

推荐 GitHub 仓库只保存可迁移代码、配置模板、脚本和文档：

- `src/`：视觉降落核心代码
- `tools/`：标定、可视化、Dashboard、联调自检工具
- `scripts/`：启动、检查、安装、联调脚本
- `configs/`：默认配置和示例配置
- `systemd/`：systemd 服务模板
- `docs/`：部署、标定、联调文档
- `tests/`：单元测试
- `windows/`：Windows 地面站辅助脚本模板

默认不推送：

- `logs/*`：运行日志和联调记录
- `models/*`：ONNX、TensorRT engine 等模型产物
- `calib/*`：本机标定采集原始数据
- `configs/env.local`：本机环境变量、串口、token 等私有配置
- Python 缓存和测试缓存

## 2. Jetson 端首次准备仓库

在当前机载电脑执行：

```bash
cd "/home/jetson/on-board computer"
bash scripts/git_release_check.sh
git init
git config user.name "Jetson Deploy"
git config user.email "jetson@local"
git add .
git status --short
bash scripts/git_release_check.sh
git commit -m "Initial Jetson onboard vision landing deployment"
```

如果已经初始化过，只需要：

```bash
cd "/home/jetson/on-board computer"
bash scripts/git_release_check.sh
git add .
git commit -m "Update Jetson onboard deployment"
```

## 3. 绑定 GitHub 远端并推送

先在 GitHub 创建一个空仓库，例如：

```text
git@github.com:<OWNER>/<REPO>.git
```

Jetson 推荐使用专用 SSH key 推送。执行：

```bash
cd "/home/jetson/on-board computer"
bash scripts/github_ssh_setup.sh --repo <OWNER>/<REPO>
```

脚本会生成：

```text
~/.ssh/a2g_jetson_github
~/.ssh/a2g_jetson_github.pub
```

把脚本输出的公钥添加到 GitHub：

- 仓库级：`Repository Settings -> Deploy keys -> Add deploy key`
- 必须勾选：`Allow write access`
- 或账号级：`Settings -> SSH and GPG keys -> New SSH key`

添加后测试：

```bash
ssh -T git@github.com-a2g
```

推送：

```bash
cd "/home/jetson/on-board computer"
bash scripts/github_push.sh
```

如果你要手动执行 SSH key 配置，流程如下：

```bash
cd "/home/jetson/on-board computer"
ssh-keygen -t ed25519 -C "jetson-onboard" -f "$HOME/.ssh/a2g_jetson_github"
cat "$HOME/.ssh/a2g_jetson_github.pub"
```

把输出的公钥添加到 GitHub 仓库的 Deploy key 或个人 SSH keys。然后配置 SSH：

```bash
cat >> "$HOME/.ssh/config" <<'EOF'
Host github.com-a2g
  HostName github.com
  User git
  IdentityFile ~/.ssh/a2g_jetson_github
  IdentitiesOnly yes
EOF
chmod 600 "$HOME/.ssh/config"
ssh -T git@github.com-a2g
```

绑定远端并推送：

```bash
cd "/home/jetson/on-board computer"
git remote add origin git@github.com-a2g:<OWNER>/<REPO>.git
git branch -M main
git push -u origin main
```

如果你使用 HTTPS token：

```bash
git remote add origin https://github.com/<OWNER>/<REPO>.git
git branch -M main
git push -u origin main
```

如果需要安装 GitHub CLI `gh`，Jetson 本机执行：

```bash
sudo apt-get update
sudo apt-get install -y gh
gh auth login
```

当前项目不强依赖 `gh`，SSH key 方案已经可以完成 `git push`。

## 4. 新 Jetson 从 GitHub 拉取部署

目标路径固定为：

```text
/home/jetson/on-board computer
```

首次部署：

```bash
cd /home/jetson
git clone git@github.com-a2g:<OWNER>/<REPO>.git "on-board computer"
cd "/home/jetson/on-board computer"
bash scripts/bootstrap_env.sh
bash scripts/check_system.sh
bash scripts/git_release_check.sh
```

如果使用 HTTPS：

```bash
cd /home/jetson
git clone https://github.com/<OWNER>/<REPO>.git "on-board computer"
cd "/home/jetson/on-board computer"
bash scripts/bootstrap_env.sh
bash scripts/check_system.sh
bash scripts/git_release_check.sh
```

## 5. 新 Jetson 本机配置

复制本机环境配置：

```bash
cd "/home/jetson/on-board computer"
cp configs/env.example configs/env.local
```

按实际机体修改：

- `DASHBOARD_HOST`
- `DASHBOARD_PORT`
- `MAVLINK_CONNECTION`
- 相机设备路径 `/dev/video0`
- `configs/camera.yaml` 内参和相机安装角
- `configs/aruco_live.yaml` 中 ArUco marker 真实尺寸

当前阶段必须保持：

```yaml
mavlink:
  enabled: false
```

## 6. 安装 Jetson 用户服务

当前推荐先只启用 Dashboard，不启用视觉降落控制服务：

```bash
cd "/home/jetson/on-board computer"
bash scripts/install_user_service.sh
systemctl --user daemon-reload
systemctl --user enable --now vision-dashboard.service
systemctl --user status vision-dashboard.service
```

确认 `vision-landing.service` 不自动启动：

```bash
systemctl --user disable --now vision-landing.service || true
systemctl --user status vision-landing.service || true
```

## 7. 拉取更新

后续更新 Jetson 端代码：

```bash
cd "/home/jetson/on-board computer"
git pull --ff-only
bash scripts/git_release_check.sh
systemctl --user restart vision-dashboard.service
bash scripts/quick_link_start.sh --no-restart
```

如果本地有配置改动，先检查：

```bash
git status --short
```

不要把 `logs/`、`models/`、`calib/`、`configs/env.local` 提交到 GitHub。

## 8. 地面站验证

Jetson 端：

```bash
cd "/home/jetson/on-board computer"
bash scripts/quick_link_start.sh
bash scripts/quick_link_watch.sh
```

Windows 端：

```powershell
powershell -ExecutionPolicy Bypass -File "F:\A2G Windows\scripts\quick_link_test.ps1" -JetsonIp <JETSON_IP> -Port 8080 -OpenDashboard
```

通过标准：

- Windows 能访问 `http://<JETSON_IP>:8080`
- `/status` 返回 JSON
- `/api/ground-command` 白名单命令通过
- 飞控控制类命令被拒绝
- `mavlink.enabled=false`
- Jetson 日志能记录 Windows 命令

## 9. 真实飞行前禁止项

在完成 Shadow 测试、外参确认、MAVLink 安全评审前，禁止：

- 在 GitHub 默认配置中打开 `mavlink.enabled=true`
- 通过地面站 API 启动 `vision-landing.service`
- 通过地面站 API 发送 `arm/takeoff/land/set_mode/send_velocity`
- 让 Dashboard 和 UDP 视频同时抢占 `/dev/video0`
