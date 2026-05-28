from __future__ import annotations

import argparse
import json
import statistics
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


def build_pipeline(device: str, width: int, height: int, fps: int) -> str:
    return (
        f"v4l2src device={device} ! video/x-raw,width={width},height={height},framerate={fps}/1 "
        "! videoconvert ! video/x-raw,format=BGR ! appsink drop=true sync=false"
    )


def parse_args():
    parser = argparse.ArgumentParser(description="ArUco distance gate validation")
    parser.add_argument("--device", default="/dev/video0")
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--dictionary", default="DICT_5X5_250")
    parser.add_argument("--marker-id", type=int, default=1)
    parser.add_argument("--marker-size-m", type=float, required=True)
    parser.add_argument("--distance-m", type=float, required=True)
    parser.add_argument("--samples", type=int, default=80)
    parser.add_argument("--min-detections", type=int, default=30)
    parser.add_argument("--camera-config", default="configs/camera.yaml")
    parser.add_argument("--output", default="logs/aruco_distance_gate.jsonl")
    return parser.parse_args()


def main():
    args = parse_args()
    dictionary_id = getattr(cv2.aruco, args.dictionary)
    dictionary = cv2.aruco.Dictionary_get(dictionary_id)
    parameters = cv2.aruco.DetectorParameters_create()
    camera_matrix, dist_coeffs = load_camera(Path(args.camera_config))

    cap = cv2.VideoCapture(build_pipeline(args.device, args.width, args.height, args.fps), cv2.CAP_GSTREAMER)
    if not cap.isOpened():
        raise RuntimeError(f"Unable to open camera device: {args.device}")

    z_values = []
    started = time.monotonic()
    try:
        while len(z_values) < args.samples:
            ok, frame = cap.read()
            if not ok:
                raise RuntimeError("Camera frame read failed")
            corners, ids, _ = cv2.aruco.detectMarkers(frame, dictionary, parameters=parameters)
            if ids is None:
                print(f"waiting marker detections={len(z_values)}/{args.samples}")
                continue
            for marker_corners, marker_id_arr in zip(corners, ids):
                marker_id = int(marker_id_arr[0])
                if marker_id != args.marker_id:
                    continue
                _, tvecs, _ = cv2.aruco.estimatePoseSingleMarkers(
                    marker_corners,
                    args.marker_size_m,
                    camera_matrix,
                    dist_coeffs,
                )
                z_m = float(tvecs[0][0][2])
                z_values.append(z_m)
                print(f"sample={len(z_values)}/{args.samples} z={z_m:.4f}m")
                break
    finally:
        cap.release()

    if len(z_values) < args.min_detections:
        raise RuntimeError(f"Only {len(z_values)} detections, required at least {args.min_detections}")

    median_z = statistics.median(z_values)
    abs_error = abs(median_z - args.distance_m)
    rel_error = abs_error / args.distance_m
    recommended_marker_size = args.marker_size_m * args.distance_m / max(median_z, 1e-6)
    result = {
        "timestamp": time.time(),
        "dictionary": args.dictionary,
        "marker_id": args.marker_id,
        "configured_marker_size_m": args.marker_size_m,
        "distance_m": args.distance_m,
        "samples": len(z_values),
        "median_z_m": median_z,
        "abs_error_m": abs_error,
        "rel_error": rel_error,
        "recommended_marker_size_m": recommended_marker_size,
        "width": args.width,
        "height": args.height,
        "fps": args.fps,
        "elapsed_s": time.monotonic() - started,
    }

    print("== distance gate result ==")
    for key in [
        "median_z_m",
        "abs_error_m",
        "rel_error",
        "recommended_marker_size_m",
        "samples",
    ]:
        value = result[key]
        print(f"{key}: {value:.6f}" if isinstance(value, float) else f"{key}: {value}")

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("a", encoding="utf-8") as f:
        f.write(json.dumps(result, sort_keys=True) + "\n")
    print(f"saved: {output}")


if __name__ == "__main__":
    main()
