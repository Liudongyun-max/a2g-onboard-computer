from __future__ import annotations

from typing import List

from vision_landing.types import Detection, Frame


class Detector:
    def detect(self, frame: Frame) -> List[Detection]:
        raise NotImplementedError
