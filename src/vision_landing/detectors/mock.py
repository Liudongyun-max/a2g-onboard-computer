from __future__ import annotations

from typing import Dict, List

from vision_landing.detectors.base import Detector
from vision_landing.types import Detection, Frame


class MockDetector(Detector):
    """Deterministic detector for dry-run pipeline validation."""

    def __init__(self, config: Dict):
        self.confidence = float(config.get("confidence_threshold", 0.45)) + 0.2

    def detect(self, frame: Frame) -> List[Detection]:
        h, w = frame.image.shape[:2]
        box_w = w * 0.22
        box_h = h * 0.22
        cx = w * 0.5
        cy = h * 0.5
        return [
            Detection(
                class_id=0,
                label="landing_pad",
                confidence=min(self.confidence, 0.99),
                xyxy=(cx - box_w / 2, cy - box_h / 2, cx + box_w / 2, cy + box_h / 2),
            )
        ]
