from __future__ import annotations

from typing import Dict, List, Optional

import cv2

from vision_landing.detectors.base import Detector
from vision_landing.types import Detection, Frame


class ArucoDetector(Detector):
    def __init__(self, config: Dict):
        if not hasattr(cv2, "aruco"):
            raise RuntimeError("Current OpenCV build does not include cv2.aruco")

        dictionary_name = str(config.get("dictionary", "DICT_4X4_50"))
        dictionary_id = getattr(cv2.aruco, dictionary_name, None)
        if dictionary_id is None:
            raise ValueError(f"Unsupported ArUco dictionary: {dictionary_name}")

        self.dictionary = cv2.aruco.Dictionary_get(dictionary_id)
        self.parameters = cv2.aruco.DetectorParameters_create()
        marker_id = config.get("marker_id", None)
        self.marker_id: Optional[int] = None if marker_id is None else int(marker_id)

    def detect(self, frame: Frame) -> List[Detection]:
        corners, ids, _ = cv2.aruco.detectMarkers(frame.image, self.dictionary, parameters=self.parameters)
        if ids is None:
            return []

        detections: List[Detection] = []
        for marker_corners, marker_id_arr in zip(corners, ids):
            marker_id = int(marker_id_arr[0])
            if self.marker_id is not None and marker_id != self.marker_id:
                continue

            points = marker_corners.reshape(4, 2)
            xs = points[:, 0]
            ys = points[:, 1]
            detections.append(
                Detection(
                    class_id=marker_id,
                    label=f"aruco_{marker_id}",
                    confidence=1.0,
                    xyxy=(float(xs.min()), float(ys.min()), float(xs.max()), float(ys.max())),
                    corners_px=tuple((float(x), float(y)) for x, y in points),
                )
            )
        return detections
