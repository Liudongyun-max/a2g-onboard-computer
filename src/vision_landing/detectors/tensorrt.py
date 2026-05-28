from __future__ import annotations

from typing import Dict, List

from vision_landing.detectors.base import Detector
from vision_landing.types import Detection, Frame


class TensorRTDetector(Detector):
    """TensorRT backend placeholder.

    Keep the detector API stable while engine-specific preprocessing, bindings,
    and postprocessing are implemented for the selected model family.
    """

    def __init__(self, config: Dict):
        self.engine_path = config.get("engine_path", "models/landing_target.engine")
        raise NotImplementedError(
            "TensorRT detector is scaffolded but not wired. Build the engine and implement "
            "model-specific preprocess/postprocess in detectors/tensorrt.py."
        )

    def detect(self, frame: Frame) -> List[Detection]:
        return []
