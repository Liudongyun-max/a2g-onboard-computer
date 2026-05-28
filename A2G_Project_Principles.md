# A2G 视觉辅助精准降落项目原则文档

> 适用阶段：局域网小闭环验证、Shadow 模式验证、后续 MAVLink 受控接入前的系统安全设计。`r`n> 核心原则：**视觉辅助，飞控主控，人类监督，安全优先。**

---

## 1. 项目总体原则

本项目采用“**Jetson 视觉辅助 + 飞控安全主控 + QGroundControl / 遥控器人工监督**”的分层架构。

系统不应将 Jetson 视觉结果直接作为最终飞行安全决策依据。Jetson 负责感知、估计、辅助对准、日志记录和 Shadow 验证；飞控负责姿态稳定、高度融合、LAND 模式、接地检测、停桨和自动 disarm；QGroundControl 与遥控器负责全过程人工监控和随时接管。

核心原则如下：

```text
Jetson 负责看见和建议；
MAVLink 负责传输；
飞控负责稳定和落地；
QGroundControl / 遥控器负责人工监督和接管。
```

---

## 2. 系统分工边界

### 2.1 Jetson 视觉端职责

Jetson 机载计算机负责：

```text
1. 识别降落平台
2. 检测 ArUco / Marker
3. 估计相机坐标系下目标相对位置
4. 完成 camera frame -> body frame 映射
5. 计算横向误差
6. 辅助对准平台
7. 辅助下降阶段状态判断
8. 输出建议控制量
9. 记录 Dashboard 状态
10. 记录 Shadow 日志
11. 写入事件标记
12. 支持 Windows Ground Station Console 的监管信号
```

Jetson 可以输出：

```text
1. detected
2. target_id
3. range_m
4. camera x / y / z
5. 建议 vx / vy / vz
6. Shadow 状态
7. 视觉质量状态
8. 目标丢失状态
```

Jetson 不负责：

```text
1. 最终停桨
2. 最终 disarm
3. 接地检测
4. 姿态稳定
5. 飞控高度融合
6. 遥控器 failsafe
7. 飞行模式最终安全决策
8. 单独判断无人机是否已经真实落地
```

---

### 2.2 MAVLink 职责边界

MAVLink 后续只作为通信链路，不作为标定工具，不作为最终安全判定模块。

MAVLink 后续可用于传输：

```text
1. 速度 setpoint
2. 状态数据
3. landing target
4. heartbeat
5. 模式状态
6. 日志辅助信息
```

MAVLink 不应承担：

```text
1. 相机外参标定
2. camera frame -> body frame 标定
3. marker 尺寸校正
4. 视觉 z 值最终可信度判断
5. 最终落地判定
6. 最终停桨判定
7. 自动 disarm 判定
```

原则：

```text
MAVLink 是传输层 / 控制接口，不是几何标定工具。
```

---

### 2.3 飞控职责边界

飞控负责所有飞行安全关键功能，包括：

```text
1. 姿态稳定
2. 高度融合
3. 电机控制
4. LAND 模式
5. 接地检测
6. 停桨
7. 自动 disarm
8. failsafe
9. RC 接管
10. 飞行模式安全切换
```

最终落地和停桨应优先依赖：

```text
1. 飞控内部 land detector
2. 高度 / 加速度 / 推力 / 垂向速度综合判断
3. LAND 模式逻辑
4. 接地状态判断
5. 自动 disarm 逻辑
```

飞控是最终飞行安全主控，Jetson 只能作为视觉辅助输入。

---

### 2.4 QGroundControl / 遥控器职责边界

QGroundControl 与遥控器负责：

```text
1. 飞行状态监控
2. 姿态观察
3. 电池状态观察
4. GPS / 高度观察
5. 飞行模式确认
6. failsafe 观察
7. 人工接管
8. 紧急切换模式
9. 必要时终止测试
```

原则：

```text
QGroundControl / 遥控器接管链路的优先级必须高于 Jetson 自动控制链路。
```

---

## 3. 关于视觉 z 值的原则

当前视觉 z 估计允许存在约 ±5cm 误差。

该误差范围可以接受为：

```text
1. 视觉辅助量
2. 接近平台的参考量
3. 辅助下降速度限幅依据
4. Shadow 模式日志分析变量
5. 平台相对高度趋势判断
```

但视觉 z 不应作为：

```text
1. 最终停桨依据
2. 最终 disarm 依据
3. 接地检测唯一依据
4. 是否完成真实落地的唯一依据
5. 飞控 LAND 结束条件的唯一依据
```

原因：

```text
1. ArUco 姿态估计受光照、角度、畸变、像素误差影响
2. 低高度阶段 z 估计更敏感
3. 相机外参误差会传递到 z 值
4. 平台高度、脚架高度、机体姿态会影响最终接地判断
5. 停桨属于安全关键动作，应由飞控内部 land detector 处理
```

结论：

```text
Jetson 视觉 z 用于辅助下降；
飞控 land detector 用于最终落地、停桨和 disarm。
```

---

## 4. 当前阶段安全边界

当前阶段必须保持：

```text
mavlink.enabled = false
vision-landing.service = disabled / inactive
safety_mode = monitor_only
/dev/video0 owner = Dashboard
```

当前阶段允许：

```text
1. Web Dashboard 实时监控
2. ArUco 检测
3. /status 状态读取
4. /stream 视频查看
5. Windows Ground Station Console 白名单监管命令
6. Ground Command API 日志写入
7. Shadow 状态标记
8. 事件标记
9. start_record / stop_record 作为记录阶段标记
10. QGroundControl 连接飞控做状态监控
11. 遥控器 / QGC 人工接管链路确认
```

当前阶段禁止：

```text
1. 启用 mavlink.enabled=true
2. 启动 vision-landing.service
3. 通过 Windows API 执行飞控控制
4. 发送 send_velocity
5. arm
6. takeoff
7. land
8. set_mode
9. 自动停桨
10. 自动 disarm
11. 让 Jetson 单独决定是否真实落地
12. Dashboard 和 UDP 视频脚本同时占用 /dev/video0
```

---

## 5. Windows Ground Station Console 原则

Windows Ground Station Console 当前只允许发送监管类意图信号。

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

必须拒绝命令：

```text
enable_mavlink
start_vision_landing
send_velocity
arm
takeoff
land
set_mode
```

原则：

```text
Windows Ground Station Console 可以发监管信号；
Jetson 可以接收、记录、返回状态；
但 Jetson 绝不能在当前阶段通过该接口控制飞控。
```

---

## 6. Shadow 模式原则

当前 Shadow 模式定义为：

```text
Jetson 只计算视觉误差和建议控制量；
Jetson 只记录状态和建议值；
Jetson 不向飞控发送 MAVLink 控制指令。
```

也就是说：

```text
看得到 vx / vy / vz；
记录得到 vx / vy / vz；
但不执行 vx / vy / vz。
```

Shadow 模式需要验证：

```text
1. 相机方向是否正确
2. marker 坐标是否正确
3. x / y / z 符号是否正确
4. 横向误差方向是否正确
5. 控制量方向是否正确
6. 目标丢失时建议控制量是否归零
7. 数据是否稳定
8. 是否存在突变指令
9. 控制量是否有合理限幅
10. 日志是否能与视频和 QGC 观察对齐
```

---

## 7. 后续 MAVLink 启用前置条件

在打开以下配置前：

```yaml
mavlink:
  enabled: true
```

必须完成：

```text
[ ] camera frame -> body frame 映射确认
[ ] x / y / z 方向符号确认
[ ] ArUco marker_length_m 实测确认
[ ] z 估计与实际距离误差统计
[ ] 横向误差与实际偏移方向一致
[ ] Shadow 模式下 vx / vy / vz 方向正确
[ ] 目标丢失时 setpoint 归零或进入安全状态
[ ] 控制量限幅生效
[ ] QGroundControl / 遥控器接管链路稳定
[ ] 飞控 LAND / land detector 逻辑验证
[ ] 飞控控制类命令有明确安全门禁
[ ] 测试场地和桨叶安全流程确认
```

特别原则：

```text
不要因为视觉 z 看起来较准，就直接让 Jetson 决定停桨。
```

---

## 8. 后续闭环控制建议

进入受控闭环后，Jetson 应只输出低风险辅助量。

建议允许：

```text
1. 低速 vx
2. 低速 vy
3. 受限 vz
4. landing target 信息
5. 状态标记
6. 目标丢失提示
```

建议暂不允许：

```text
1. arm
2. takeoff
3. land
4. disarm
5. kill
6. 直接停桨
7. 大速度 setpoint
8. 未限幅控制量
9. 未经确认的 yaw 控制
```

推荐流程：

```text
1. 飞控保持可控飞行状态
2. Jetson 识别平台并计算横向误差
3. Jetson 输出低速 vx / vy 对准
4. 下降动作由飞控 LAND 或受限 vz 执行
5. 接地和停桨由飞控 land detector 完成
6. QGroundControl / 遥控器全程可接管
```

---

## 9. 测试推进顺序

当前推荐推进顺序：

```text
1. Windows ↔ Jetson API 联调
2. Ground Command 日志验证
3. Shadow 模式连续日志测试
4. Dashboard 状态快照与视频时间对齐
5. QGroundControl 观察记录对齐
6. ArUco 目标移动测试
7. camera frame -> body frame 映射验证
8. z 误差统计
9. 目标丢失 failsafe 测试
10. 控制量限幅测试
11. MAVLink 只读状态接入
12. MAVLink 低速 setpoint 受控测试
13. 飞控 LAND / land detector 联合验证
14. 逐步进入真实闭环验证
```

---

## 10. 项目安全设计结论

本系统采用“**视觉辅助、飞控主控、人类监督**”的安全分层架构。

Jetson 机载计算机负责 ArUco 平台识别、相对位姿估计、横向对准辅助、下降阶段状态辅助、日志记录与 Shadow 模式验证。Jetson 输出的视觉 z 值允许存在约 ±5cm 误差，可作为辅助下降和接近平台判断依据，但不得作为最终停桨或 disarm 的唯一依据。

MAVLink 在后续阶段仅作为速度 setpoint、状态信息或 landing target 的通信通道，不承担相机外参标定、坐标映射验证或最终落地判定功能。

飞控负责姿态稳定、高度融合、LAND 模式、接地检测、停桨和自动 disarm 等安全关键功能。真实落地后的停桨与 disarm 应优先依赖飞控内部 land detector 逻辑。

QGroundControl 与遥控器负责全过程人工监控和随时接管。在任何自动控制测试中，人工接管链路优先级必须高于 Jetson 视觉辅助链路。

---

## 11. 一句话原则

```text
Jetson 负责看见和建议；
MAVLink 负责传输；
飞控负责稳定和落地；
QGroundControl / 遥控器负责监督和接管。
```
