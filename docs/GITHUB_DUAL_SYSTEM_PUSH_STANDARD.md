# GitHub 双系统合并部署与推送规范

核心规范：

```text
平台代码分目录，接口契约放 shared，部署入口放 deploy，运行产物不入库，安全边界不放宽。
```

当前仓库采用：

```text
repo/
  shared/
  windows/
  jetson/
  deploy/
```

提交边界：

- Windows 端改动：`windows/`，必要时同步 `shared/`。
- Jetson 端改动：`jetson/`，必要时同步 `shared/`。
- 协议改动：先提交 `shared/`，再分别提交 Windows / Jetson 实现。
- 运行产物、日志、报告、视频、portable 工具不提交。

推送前检查：

```bash
git status --short
git diff --check
bash jetson/scripts/git_release_check.sh
```

当前安全边界：

- `jetson/configs/aruco_live.yaml` 必须保持 `mavlink.enabled=false`。
- `vision-landing.service` 不得启用。
- Ground Command API 只允许监管类白名单命令。
