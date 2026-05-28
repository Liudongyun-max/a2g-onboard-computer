#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:-/dev/video0}"
WIDTH="${2:-640}"
HEIGHT="${3:-480}"
FPS="${4:-30}"

python3 - <<PY
import cv2

device = "$DEVICE"
width = int("$WIDTH")
height = int("$HEIGHT")
fps = int("$FPS")
pipeline = (
    f"v4l2src device={device} ! video/x-raw,width={width},height={height},framerate={fps}/1 "
    "! videoconvert ! video/x-raw,format=BGR ! appsink drop=true sync=false"
)
cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
print("pipeline:", pipeline)
print("opened:", cap.isOpened())
ok, frame = cap.read() if cap.isOpened() else (False, None)
print("read:", ok, None if frame is None else frame.shape)
cap.release()
raise SystemExit(0 if ok else 1)
PY
