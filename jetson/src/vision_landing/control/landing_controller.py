from __future__ import annotations

import time
from typing import Dict, Optional

from vision_landing.types import TargetEstimate, VelocityCommand


class LandingController:
    def __init__(self, config: Dict):
        self.max_xy = float(config.get("max_xy_speed_mps", 0.6))
        self.max_z = float(config.get("max_z_speed_mps", 0.35))
        self.kp_xy = float(config.get("kp_xy", 0.0025))
        self.descent_speed = float(config.get("descent_speed_mps", 0.22))
        self.deadband_px = float(config.get("center_deadband_px", 18))
        self.lost_timeout_s = float(config.get("target_lost_timeout_s", 0.6))
        self.last_seen_s: Optional[float] = None

    def update(self, estimate: TargetEstimate) -> VelocityCommand:
        now = time.monotonic()
        if not estimate.detected:
            if self.last_seen_s is None or now - self.last_seen_s > self.lost_timeout_s:
                return VelocityCommand(0.0, 0.0, 0.0, valid=False, reason="target_lost")
            return VelocityCommand(0.0, 0.0, 0.0, valid=True, reason="short_target_gap")

        self.last_seen_s = now
        err_x, err_y = estimate.center_error_px
        vx = self._clamp(-err_y * self.kp_xy, -self.max_xy, self.max_xy)
        vy = self._clamp(err_x * self.kp_xy, -self.max_xy, self.max_xy)
        if abs(err_x) < self.deadband_px:
            vy = 0.0
        if abs(err_y) < self.deadband_px:
            vx = 0.0

        centered = abs(err_x) < self.deadband_px and abs(err_y) < self.deadband_px
        vz = self.descent_speed if centered else 0.0
        return VelocityCommand(vx, vy, self._clamp(vz, 0.0, self.max_z), reason="tracking")

    @staticmethod
    def _clamp(value: float, low: float, high: float) -> float:
        return max(low, min(high, value))
