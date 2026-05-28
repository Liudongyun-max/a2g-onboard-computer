from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
import yaml


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Chessboard camera calibration helper")
    parser.add_argument("--images", required=True, help="Glob pattern, for example 'calib/*.jpg'")
    parser.add_argument("--cols", type=int, default=9, help="Inner chessboard corners per row")
    parser.add_argument("--rows", type=int, default=6, help="Inner chessboard corners per column")
    parser.add_argument("--square-size-m", type=float, default=0.024)
    parser.add_argument("--output", default="configs/camera.yaml")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    pattern = (args.cols, args.rows)
    objp = np.zeros((args.rows * args.cols, 3), np.float32)
    objp[:, :2] = np.mgrid[0 : args.cols, 0 : args.rows].T.reshape(-1, 2)
    objp *= args.square_size_m

    objpoints = []
    imgpoints = []
    image_size = None
    for path in sorted(Path().glob(args.images)):
        image = cv2.imread(str(path))
        if image is None:
            continue
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        image_size = gray.shape[::-1]
        ok, corners = cv2.findChessboardCorners(gray, pattern, None)
        if ok:
            objpoints.append(objp)
            imgpoints.append(corners)

    if not objpoints or image_size is None:
        raise RuntimeError("No valid chessboard detections found")

    _, camera_matrix, dist_coeffs, _, _ = cv2.calibrateCamera(objpoints, imgpoints, image_size, None, None)
    output = {
        "camera_matrix": {"rows": 3, "cols": 3, "data": camera_matrix.reshape(-1).tolist()},
        "distortion_coefficients": {"rows": 1, "cols": int(dist_coeffs.size), "data": dist_coeffs.reshape(-1).tolist()},
        "frame_id": "landing_camera",
        "mount": {"roll_deg": 0.0, "pitch_deg": -90.0, "yaw_deg": 0.0},
    }
    with Path(args.output).open("w", encoding="utf-8") as f:
        yaml.safe_dump(output, f, sort_keys=False)


if __name__ == "__main__":
    main()
