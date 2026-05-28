from vision_landing.control import LandingController
from vision_landing.types import TargetEstimate


def test_centered_target_descends():
    controller = LandingController({"center_deadband_px": 18, "descent_speed_mps": 0.2})
    estimate = TargetEstimate(True, 0.0, (0.0, 0.0), 2.0, 0.9)
    command = controller.update(estimate)
    assert command.vx_mps == 0.0
    assert command.vy_mps == 0.0
    assert command.vz_mps == 0.2
    assert command.valid


def test_offset_target_holds_descent():
    controller = LandingController({"center_deadband_px": 18, "kp_xy": 0.01})
    estimate = TargetEstimate(True, 0.0, (100.0, 0.0), 2.0, 0.9)
    command = controller.update(estimate)
    assert command.vy_mps > 0.0
    assert command.vz_mps == 0.0
