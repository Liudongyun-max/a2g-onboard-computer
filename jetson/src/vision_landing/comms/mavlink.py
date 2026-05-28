from __future__ import annotations

import os
from typing import Dict, Optional

from vision_landing.types import VelocityCommand


class MavlinkClient:
    def __init__(self, config: Dict, dry_run: bool):
        self.enabled = bool(config.get("enabled", False)) and not dry_run
        self.connection_string = os.environ.get("MAVLINK_CONNECTION") or config.get("connection", "udp:127.0.0.1:14550")
        self.master: Optional[object] = None
        if self.enabled:
            from pymavlink import mavutil

            self.master = mavutil.mavlink_connection(self.connection_string)
            self.master.wait_heartbeat(timeout=10)

    def send_velocity(self, command: VelocityCommand) -> None:
        if not self.enabled:
            print(
                f"[dry-run] velocity vx={command.vx_mps:.2f} vy={command.vy_mps:.2f} "
                f"vz={command.vz_mps:.2f} valid={command.valid} reason={command.reason}"
            )
            return

        if self.master is None:
            raise RuntimeError("MAVLink connection is not initialized")

        # MAV_FRAME_BODY_NED: x forward, y right, z down. Positive vz descends.
        self.master.mav.set_position_target_local_ned_send(
            0,
            self.master.target_system,
            self.master.target_component,
            8,
            0b0000111111000111,
            0,
            0,
            0,
            command.vx_mps,
            command.vy_mps,
            command.vz_mps,
            0,
            0,
            0,
            0,
            command.yaw_rate_rad_s,
        )
