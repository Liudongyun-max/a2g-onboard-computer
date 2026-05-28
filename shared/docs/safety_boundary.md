# Safety Boundary

当前阶段安全边界：

```text
Jetson 只做视觉检测、Dashboard、日志、Shadow。
Windows 只做监管、可视化、状态检查和地面站交互。
飞控由 QGC / 遥控器监控和接管。
MAVLink 控制当前不启用。
```

必须保持：

```text
mavlink.enabled=false
vision-landing.service=disabled/inactive
safety_mode=monitor_only
```
