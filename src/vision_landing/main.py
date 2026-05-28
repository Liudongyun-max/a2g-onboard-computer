from __future__ import annotations

import argparse
from pathlib import Path

import yaml

from vision_landing.config import AppConfig
from vision_landing.pipeline import VisionLandingPipeline


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="UAV visual landing runtime")
    parser.add_argument("--config", default="configs/default.yaml")
    parser.add_argument("--camera-config", default="configs/camera.yaml")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--synthetic-frames", type=int, default=20)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    app_config = AppConfig.load(args.config)
    camera_config = load_yaml(app_config.resolve(args.camera_config))
    runtime = app_config.section("runtime")
    dry_run = bool(args.dry_run or runtime.get("dry_run", False))
    pipeline = VisionLandingPipeline(app_config.raw, camera_config, dry_run=dry_run)
    if dry_run:
        frame_count = int(runtime.get("synthetic_frames", args.synthetic_frames))
        pipeline.run_dry_synthetic(frame_count=frame_count)
    else:
        pipeline.run_with_camera()


if __name__ == "__main__":
    main()
