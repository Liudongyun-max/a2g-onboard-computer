from __future__ import annotations

import argparse
import time
from pathlib import Path

import cv2
import numpy as np
import yaml


DICTIONARIES = [
    "DICT_4X4_50",
    "DICT_4X4_100",
    "DICT_5X5_50",
    "DICT_5X5_100",
    "DICT_5X5_250",
    "DICT_6X6_50",
    "DICT_6X6_100",
]


def load_camera(path: Path):
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    camera_matrix = np.array(data["camera_matrix"]["data"], dtype=np.float64).reshape(3, 3)
    dist_coeffs = np.array(data["distortion_coefficients"]["data"], dtype=np.float64).reshape(1, -1)
    return camera_matrix, dist_coeffs


def pipeline(device: str, width: int, height: int, fps: int) -> str:
    return (
        f"v4l2src device={device} ! video/x-raw,width={width},height={height},framerate={fps}/1 "
        "! videoconvert ! video/x-raw,format=BGR ! appsink drop=true sync=false"
    )


def parse_args():
    parser = argparse.ArgumentParser(description="Visual ArUco camera verification")
    parser.add_argument("--device", default="/dev/video0")
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--dictionary", default="DICT_5X5_250", choices=DICTIONARIES)
    parser.add_argument("--marker-id", type=int, default=1)
    parser.add_argument("--marker-length-m", type=float, default=0.04268)
    parser.add_argument("--camera-config", default="configs/camera.yaml")
    parser.add_argument("--show-all", action="store_true", help="Do not filter by marker id")
    parser.add_argument("--known-distance-m", type=float, default=0.0, help="Measured marker distance for scale calibration")
    parser.add_argument("--save-samples", default="logs/aruco_calibration_samples.csv")
    return parser.parse_args()


def put_lines(image, lines):
    y = 24
    for line in lines:
        cv2.putText(image, line, (10, y), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 0, 0), 4, cv2.LINE_AA)
        cv2.putText(image, line, (10, y), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 1, cv2.LINE_AA)
        y += 24


def main():
    args = parse_args()
    camera_matrix, dist_coeffs = load_camera(Path(args.camera_config))
    dictionary_index = DICTIONARIES.index(args.dictionary)
    marker_length_m = args.marker_length_m
    marker_id = args.marker_id
    show_all = args.show_all
    known_distance_m = args.known_distance_m
    samples = []

    cap = cv2.VideoCapture(pipeline(args.device, args.width, args.height, args.fps), cv2.CAP_GSTREAMER)
    if not cap.isOpened():
        raise RuntimeError(f"Unable to open {args.device}")

    parameters = cv2.aruco.DetectorParameters_create()
    window = "ArUco Landing Target"
    cv2.namedWindow(window, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(window, args.width, args.height)
    last_t = time.monotonic()
    fps_smooth = 0.0

    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                raise RuntimeError("Camera frame read failed")

            now = time.monotonic()
            dt = max(1e-6, now - last_t)
            last_t = now
            fps_smooth = 0.9 * fps_smooth + 0.1 * (1.0 / dt) if fps_smooth else 1.0 / dt

            dictionary_name = DICTIONARIES[dictionary_index]
            dictionary = cv2.aruco.Dictionary_get(getattr(cv2.aruco, dictionary_name))
            corners, ids, _ = cv2.aruco.detectMarkers(frame, dictionary, parameters=parameters)
            status = "no marker"
            active_tvec = None

            if ids is not None:
                cv2.aruco.drawDetectedMarkers(frame, corners, ids)
                for marker_corners, marker_id_arr in zip(corners, ids):
                    current_id = int(marker_id_arr[0])
                    if not show_all and current_id != marker_id:
                        continue
                    rvecs, tvecs, _ = cv2.aruco.estimatePoseSingleMarkers(
                        marker_corners,
                        marker_length_m,
                        camera_matrix,
                        dist_coeffs,
                    )
                    rvec = rvecs[0][0]
                    tvec = tvecs[0][0]
                    active_tvec = tvec
                    cv2.aruco.drawAxis(frame, camera_matrix, dist_coeffs, rvec, tvec, marker_length_m * 0.5)
                    status = f"id={current_id} x={tvec[0]:.3f}m y={tvec[1]:.3f}m z={tvec[2]:.3f}m"

            calibration_line = "cal: set --known-distance-m, press s to sample"
            if known_distance_m > 0.0 and active_tvec is not None:
                estimated_z = float(active_tvec[2])
                ratio = known_distance_m / max(estimated_z, 1e-6)
                suggested_marker = marker_length_m * ratio
                calibration_line = (
                    f"known={known_distance_m:.3f}m err={estimated_z - known_distance_m:+.3f}m "
                    f"suggest_size={suggested_marker:.4f}m"
                )
            elif known_distance_m > 0.0:
                calibration_line = f"known={known_distance_m:.3f}m waiting marker"

            put_lines(
                frame,
                [
                    f"{status}",
                    f"dict={dictionary_name} target_id={'all' if show_all else marker_id} size={marker_length_m:.3f}m fps={fps_smooth:.1f}",
                    calibration_line,
                    "keys: q quit | a all/id | [ ] id | - + size | d dict | s sample",
                ],
            )
            cv2.imshow(window, frame)
            key = cv2.waitKey(1) & 0xFF
            if key == ord("q") or key == 27:
                break
            if key == ord("a"):
                show_all = not show_all
            elif key == ord("["):
                marker_id = max(0, marker_id - 1)
            elif key == ord("]"):
                marker_id += 1
            elif key in (ord("-"), ord("_")):
                marker_length_m = max(0.01, marker_length_m - 0.01)
            elif key in (ord("+"), ord("=")):
                marker_length_m += 0.01
            elif key == ord("d"):
                dictionary_index = (dictionary_index + 1) % len(DICTIONARIES)
            elif key == ord("s") and known_distance_m > 0.0 and active_tvec is not None:
                estimated_z = float(active_tvec[2])
                ratio = known_distance_m / max(estimated_z, 1e-6)
                suggested_marker = marker_length_m * ratio
                samples.append((time.time(), dictionary_name, marker_id, marker_length_m, known_distance_m, estimated_z, suggested_marker))
                print(
                    f"sample known={known_distance_m:.3f}m estimated={estimated_z:.3f}m "
                    f"suggest_marker_length={suggested_marker:.4f}m"
                )
    finally:
        if samples:
            output = Path(args.save_samples)
            output.parent.mkdir(parents=True, exist_ok=True)
            exists = output.exists()
            with output.open("a", encoding="utf-8") as f:
                if not exists:
                    f.write("timestamp,dictionary,marker_id,current_marker_length_m,known_distance_m,estimated_z_m,suggested_marker_length_m\n")
                for row in samples:
                    f.write(",".join(str(x) for x in row) + "\n")
            print(f"saved samples to {output}")
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
