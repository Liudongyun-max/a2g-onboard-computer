from __future__ import annotations

import argparse
import time
from pathlib import Path

import cv2
import numpy as np
import yaml


def load_camera(path: Path):
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    camera_matrix = np.array(data["camera_matrix"]["data"], dtype=np.float64).reshape(3, 3)
    dist_coeffs = np.array(data["distortion_coefficients"]["data"], dtype=np.float64).reshape(1, -1)
    return camera_matrix, dist_coeffs


def parse_args():
    parser = argparse.ArgumentParser(description="Live ArUco detection and pose sanity test")
    parser.add_argument("--device", default="/dev/video0")
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--dictionary", default="DICT_5X5_250")
    parser.add_argument("--marker-id", type=int, default=1)
    parser.add_argument("--marker-length-m", type=float, default=0.04268)
    parser.add_argument("--camera-config", default="configs/camera.yaml")
    parser.add_argument("--frames", type=int, default=120)
    return parser.parse_args()


def main():
    args = parse_args()
    dictionary_id = getattr(cv2.aruco, args.dictionary)
    dictionary = cv2.aruco.Dictionary_get(dictionary_id)
    parameters = cv2.aruco.DetectorParameters_create()
    camera_matrix, dist_coeffs = load_camera(Path(args.camera_config))
    pipeline = (
        f"v4l2src device={args.device} ! video/x-raw,width={args.width},height={args.height},framerate={args.fps}/1 "
        "! videoconvert ! video/x-raw,format=BGR ! appsink drop=true sync=false"
    )
    cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
    if not cap.isOpened():
        raise RuntimeError(f"Unable to open camera: {pipeline}")

    seen = 0
    started = time.monotonic()
    try:
        for _ in range(args.frames):
            ok, frame = cap.read()
            if not ok:
                raise RuntimeError("Camera read failed")
            corners, ids, _ = cv2.aruco.detectMarkers(frame, dictionary, parameters=parameters)
            if ids is None:
                print("no marker")
                continue
            for marker_corners, marker_id_arr in zip(corners, ids):
                marker_id = int(marker_id_arr[0])
                if marker_id != args.marker_id:
                    continue
                _, tvecs, _ = cv2.aruco.estimatePoseSingleMarkers(
                    marker_corners,
                    args.marker_length_m,
                    camera_matrix,
                    dist_coeffs,
                )
                tvec = tvecs[0][0]
                seen += 1
                print(
                    f"id={marker_id} x={tvec[0]:.3f}m y={tvec[1]:.3f}m z={tvec[2]:.3f}m "
                    f"seen={seen}"
                )
    finally:
        cap.release()
    elapsed = max(0.001, time.monotonic() - started)
    print(f"frames={args.frames} detections={seen} rate={args.frames / elapsed:.1f}fps")


if __name__ == "__main__":
    main()
