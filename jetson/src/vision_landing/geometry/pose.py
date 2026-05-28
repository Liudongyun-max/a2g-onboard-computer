from __future__ import annotations

from typing import Dict, Optional

import cv2
import numpy as np

from vision_landing.types import Detection, TargetEstimate


class TargetEstimator:
    def __init__(self, camera_config: Dict, target_config: Dict):
        matrix = camera_config.get("camera_matrix", {})
        data = matrix.get("data", [600.0, 0.0, 320.0, 0.0, 600.0, 240.0, 0.0, 0.0, 1.0])
        self.fx = float(data[0])
        self.fy = float(data[4])
        self.cx = float(data[2])
        self.cy = float(data[5])
        self.target_width_m = float(target_config.get("real_width_m", 0.60))
        self.marker_length_m = float(target_config.get("marker_length_m", self.target_width_m))
        distortion = camera_config.get("distortion_coefficients", {})
        dist_data = distortion.get("data", [0.0, 0.0, 0.0, 0.0, 0.0])
        self.camera_matrix = np.array(data, dtype=np.float64).reshape(3, 3)
        self.dist_coeffs = np.array(dist_data, dtype=np.float64).reshape(1, -1)

    def estimate(self, detection: Optional[Detection], timestamp_s: float) -> TargetEstimate:
        if detection is None:
            return TargetEstimate(False, timestamp_s, (0.0, 0.0), None, 0.0)

        center_x, center_y = detection.center_px
        width_px, _ = detection.size_px
        range_m = None
        position_camera_m = None
        if width_px > 1.0:
            range_m = (self.fx * self.target_width_m) / width_px

        if detection.corners_px:
            corners = np.array(detection.corners_px, dtype=np.float32).reshape(1, 4, 2)
            _, tvecs, _ = cv2.aruco.estimatePoseSingleMarkers(
                corners,
                self.marker_length_m,
                self.camera_matrix,
                self.dist_coeffs,
            )
            tvec = tvecs[0][0]
            position_camera_m = (float(tvec[0]), float(tvec[1]), float(tvec[2]))
            range_m = float(tvec[2])

        return TargetEstimate(
            detected=True,
            timestamp_s=timestamp_s,
            center_error_px=(center_x - self.cx, center_y - self.cy),
            range_m=range_m,
            confidence=detection.confidence,
            position_camera_m=position_camera_m,
            target_id=detection.class_id,
        )
