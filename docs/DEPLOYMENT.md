# Deployment Checklist

## 1. System Baseline

Run:

```bash
bash scripts/check_system.sh
bash scripts/check_camera.sh /dev/video0 640 480 30
```

Expected:

- TensorRT and CUDA packages are present.
- `cv2`, `numpy`, `yaml`, `tensorrt`, and `pymavlink` are importable.
- A camera appears as `/dev/video*` or a CSI/GStreamer pipeline is configured.

## 2. Camera

Update `configs/default.yaml`:

- USB camera: set `camera.device` to `/dev/video0`.
- CSI camera: set `camera.gstreamer_pipeline`.
- Confirm width, height, and fps match the camera mode.

Calibrate:

```bash
python3 tools/calibrate_camera.py --images 'calib/*.jpg' --output configs/camera.yaml
```

## 3. Detector

### ArUco Landing Target

For the printed ArUco target, start with:

```bash
python3 tools/aruco_live_test.py \
  --device /dev/video0 \
  --dictionary DICT_5X5_250 \
  --marker-id 1 \
  --marker-length-m 0.16 \
  --camera-config configs/camera.yaml
```

Then update `configs/aruco_live.yaml`:

- `detector.dictionary`: printed marker dictionary.
- `detector.marker_id`: printed marker id.
- `target.marker_length_m`: physical side length of the black marker in meters.

Run the ArUco pipeline without flight-controller output:

```bash
bash scripts/run_aruco_live.sh
```

Keep `mavlink.enabled: false` until the pose output is stable.

The full marker scale, camera intrinsic, and extrinsic confirmation flow is in
`docs/CALIBRATION_PLAN.md`.

### Neural Detector

Keep deployment stable by training away from the Jetson:

1. Train the landing target detector on a workstation.
2. Export ONNX to `models/landing_target.onnx`.
3. Build the TensorRT engine on the Jetson:

```bash
bash tools/build_tensorrt_engine.sh models/landing_target.onnx models/landing_target.engine
```

4. Set `detector.backend: tensorrt` in `configs/default.yaml`.

The current `tensorrt` backend is intentionally scaffolded. Wire in the exact
preprocess and postprocess for the selected model family before flight.

## 4. MAVLink

For SITL:

```yaml
mavlink:
  enabled: true
  connection: udp:127.0.0.1:14550
```

For UART:

```yaml
mavlink:
  enabled: true
  connection: /dev/ttyTHS1,57600
```

Validate heartbeat and command acceptance in simulation before propellers are
installed.

## 5. Flight Test Gates

- Dry-run pipeline passes.
- Camera frame rate is stable above 12 fps.
- Detection confidence is stable under outdoor lighting.
- Target-loss command becomes hold, not descent.
- Manual takeover works.
- Flight controller native failsafes remain enabled.

## 6. Service

Create a local environment file:

```bash
cp configs/env.example configs/env.local
```

Install the service after the camera, detector, and MAVLink settings are final:

```bash
bash scripts/install_service.sh
sudo systemctl enable vision-landing
sudo systemctl start vision-landing
```
