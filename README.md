# UAV Vision Landing Deploy

This project is a deployable on-board computer package for a Jetson-based UAV visual landing
system. It is structured for field use: camera input, target detection,
relative pose estimation, landing control, and flight-controller communication
are separated behind small interfaces.

## Current Target Platform

- NVIDIA Jetson, Ubuntu 20.04 / L4T R35.x
- CUDA 11.4, TensorRT 8.x
- Python 3.8
- OpenCV with GStreamer
- PX4 or ArduPilot through MAVLink

## Directory Layout

```text
configs/                 Runtime configuration
models/                  ONNX and TensorRT engine files
logs/                    Runtime logs
scripts/                 Host checks, environment bootstrap, launch helpers
src/vision_landing/      Python package
tests/                   Unit tests for control and geometry logic
tools/                   Calibration and model conversion utilities
```

## Recommended Deployment Flow

1. Run `scripts/check_system.sh` and confirm camera, TensorRT, and Python modules.
2. Calibrate the landing camera and write intrinsics to `configs/camera.yaml`.
3. Train the detector on a workstation, export ONNX, then build TensorRT on Jetson.
4. Validate `mock` detector mode with recorded frames or live camera.
5. Switch detector backend to `tensorrt` and verify frame rate.
6. Connect the flight controller and validate MAVLink in simulation first.
7. Fly with conservative limits: low speed, target-loss hover, manual takeover.

## Run

Dry-run with the mock detector:

```bash
cd "/home/jetson/on-board computer"
python3 -m vision_landing.main --config configs/default.yaml --dry-run
```

Live mode after installing dependencies and setting camera/MAVLink config:

```bash
cd "/home/jetson/on-board computer"
python3 -m vision_landing.main --config configs/aruco_live.yaml
```

Convenience scripts:

```bash
bash scripts/run_dry.sh
bash scripts/visualize_aruco.sh
bash scripts/run_aruco_live.sh
bash scripts/run_live.sh
```

Deployment details are in `docs/DEPLOYMENT.md`; calibration gates are in
`docs/CALIBRATION_PLAN.md`.

For local development:

```bash
export PYTHONPATH=$PWD/src:$PYTHONPATH
python3 -m vision_landing.main --config configs/default.yaml --dry-run
```

## Safety Notes

This repository does not bypass the flight controller. It should send high-level
velocity or position setpoints only. Keep RC/manual takeover, geofence, low
battery, target-loss, and communication-loss failsafes enabled in the flight
controller.
