from __future__ import annotations

import time
from typing import Dict, Optional

import numpy as np

from vision_landing.camera import OpenCVCamera
from vision_landing.comms import MavlinkClient
from vision_landing.control import LandingController
from vision_landing.detectors import build_detector
from vision_landing.geometry import TargetEstimator
from vision_landing.types import Detection, Frame


def select_best_detection(detections: list[Detection], min_confidence: float) -> Optional[Detection]:
    candidates = [d for d in detections if d.confidence >= min_confidence]
    if not candidates:
        return None
    return max(candidates, key=lambda d: d.confidence)


class VisionLandingPipeline:
    def __init__(self, config: Dict, camera_intrinsics: Dict, dry_run: bool):
        self.config = config
        self.dry_run = dry_run
        self.detector_config = config.get("detector", {})
        self.detector = build_detector(self.detector_config)
        self.estimator = TargetEstimator(camera_intrinsics, config.get("target", {}))
        self.controller = LandingController(config.get("control", {}))
        self.mavlink = MavlinkClient(config.get("mavlink", {}), dry_run=dry_run)
        self.loop_hz = float(config.get("runtime", {}).get("loop_hz", 20))

    def run_with_camera(self) -> None:
        camera = OpenCVCamera(self.config.get("camera", {}))
        try:
            for frame in camera.frames():
                self.process_frame(frame)
                time.sleep(max(0.0, (1.0 / self.loop_hz)))
        finally:
            camera.close()

    def run_dry_synthetic(self, frame_count: int = 20) -> None:
        width = int(self.config.get("camera", {}).get("width", 640))
        height = int(self.config.get("camera", {}).get("height", 480))
        for idx in range(frame_count):
            image = np.zeros((height, width, 3), dtype=np.uint8)
            self.process_frame(Frame(image=image, timestamp_s=time.monotonic(), frame_id=idx))
            time.sleep(1.0 / self.loop_hz)

    def process_frame(self, frame: Frame) -> None:
        detections = self.detector.detect(frame)
        detection = select_best_detection(
            detections,
            float(self.detector_config.get("confidence_threshold", 0.45)),
        )
        estimate = self.estimator.estimate(detection, frame.timestamp_s)
        command = self.controller.update(estimate)
        self.mavlink.send_velocity(command)
