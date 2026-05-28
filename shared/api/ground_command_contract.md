# Ground Command API Contract

```text
POST /api/ground-command
Content-Type: application/json
```

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

当前阶段任何飞控控制类命令都必须被拒绝。
