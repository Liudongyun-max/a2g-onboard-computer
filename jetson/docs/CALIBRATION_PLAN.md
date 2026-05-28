# Calibration Plan For Current Jetson Deployment

Target platform verified on this machine:

- Ubuntu 20.04.6 / L4T R35.6.4
- OpenCV 4.2.0 with `cv2.aruco`
- Camera device: `/dev/video0`, tested at `640x480@30`
- Landing marker: `DICT_5X5_250`, `marker_id=1`

## 1. Marker Scale Calibration

This step must be performed first. ArUco PnP distance is approximately linear
with `marker_size_m`; an incorrect printed marker size directly scales the
estimated distance.

Measure the physical side length of the black/white outer ArUco square with a
ruler or caliper. Use meters. Do not use the paper size.

Set the measured size for the shell:

```bash
export ARUCO_MARKER_SIZE_M=0.04268
```

Validate the three distance gates:

```bash
cd "/home/jetson/on-board computer"
bash scripts/aruco_gate_1_00m.sh --samples 80
bash scripts/aruco_gate_1_36m.sh --samples 80
bash scripts/aruco_gate_1_50m.sh --samples 80
```

Each command outputs:

- `median_z_m`
- `abs_error_m`
- `rel_error`
- `recommended_marker_size_m`

Suggested acceptance:

- PASS: `rel_error <= 0.05`
- REVIEW: `0.05 < rel_error <= 0.10`
- FAIL: `rel_error > 0.10`

If error is large, check in this order:

1. Physical marker side length matches `ARUCO_MARKER_SIZE_M`.
2. The same camera resolution is used for calibration and flight.
3. The marker is flat, front-facing, fully visible, and well lit.
4. Camera intrinsics in `configs/camera.yaml` are valid for `640x480`.

## 2. Camera Intrinsics Calibration

Run this only if marker scale is correct but distance gates still fail.

Requirements:

- Same resolution as flight, currently `640x480`.
- At least 25 valid calibration images.
- Cover image center, four corners, near/far distances, and tilted angles.

Current project helper for chessboard images:

```bash
python3 tools/calibrate_camera.py \
  --images 'calib/*.jpg' \
  --cols 9 \
  --rows 6 \
  --square-size-m 0.024 \
  --output configs/camera.yaml
```

If you use a ROS/ChArUco calibration package, update `configs/camera.yaml` with
the final camera matrix and distortion coefficients. The runtime must consume
the same intrinsics as the camera_info used during validation.

## 3. Camera Extrinsics Calibration

Do not connect visual output to the real control loop until camera-to-body
extrinsics are confirmed.

Measure and record the camera optical center relative to the aircraft body
center:

- `x`: forward positive
- `y`: right positive
- `z`: down positive

PASS checks:

1. Marker under body center: observed body `x/y` near 0.
2. Marker moved forward: body `x` sign is correct.
3. Marker moved right: body `y` sign is correct.
4. Marker height changed: body `z` sign and scale are correct.
5. Record physical value vs observed output for each direction.

Current code estimates marker position in the camera optical frame. The
camera-to-body transform should be added before enabling `mavlink.enabled`.

## Current Commands

Visual live check:

```bash
ARUCO_MARKER_LENGTH_M=$ARUCO_MARKER_SIZE_M bash scripts/visualize_aruco.sh
```

ArUco pipeline without MAVLink enabled:

```bash
bash scripts/run_aruco_live.sh
```
