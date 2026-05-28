from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Tuple

import numpy as np


@dataclass(frozen=True)
class Frame:
    image: np.ndarray
    timestamp_s: float
    frame_id: int


@dataclass(frozen=True)
class Detection:
    class_id: int
    label: str
    confidence: float
    xyxy: Tuple[float, float, float, float]
    corners_px: Optional[Tuple[Tuple[float, float], ...]] = None

    @property
    def center_px(self) -> Tuple[float, float]:
        x1, y1, x2, y2 = self.xyxy
        return (x1 + x2) * 0.5, (y1 + y2) * 0.5

    @property
    def size_px(self) -> Tuple[float, float]:
        x1, y1, x2, y2 = self.xyxy
        return max(0.0, x2 - x1), max(0.0, y2 - y1)


@dataclass(frozen=True)
class TargetEstimate:
    detected: bool
    timestamp_s: float
    center_error_px: Tuple[float, float]
    range_m: Optional[float]
    confidence: float
    position_camera_m: Optional[Tuple[float, float, float]] = None
    target_id: Optional[int] = None


@dataclass(frozen=True)
class VelocityCommand:
    vx_mps: float
    vy_mps: float
    vz_mps: float
    yaw_rate_rad_s: float = 0.0
    valid: bool = True
    reason: str = "tracking"
