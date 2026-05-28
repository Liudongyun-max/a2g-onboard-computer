from __future__ import annotations

from typing import Dict

from vision_landing.detectors.base import Detector
from vision_landing.detectors.mock import MockDetector


def build_detector(config: Dict) -> Detector:
    backend = str(config.get("backend", "mock")).lower()
    if backend == "mock":
        return MockDetector(config)
    if backend == "aruco":
        from vision_landing.detectors.aruco import ArucoDetector

        return ArucoDetector(config)
    if backend == "tensorrt":
        from vision_landing.detectors.tensorrt import TensorRTDetector

        return TensorRTDetector(config)
    raise ValueError(f"Unsupported detector backend: {backend}")
