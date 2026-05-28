from __future__ import annotations

import time
from typing import Dict, Iterator

import cv2

from .types import Frame


class CameraSource:
    def frames(self) -> Iterator[Frame]:
        raise NotImplementedError

    def close(self) -> None:
        pass


class OpenCVCamera(CameraSource):
    def __init__(self, config: Dict):
        self.config = config
        source = self._build_source(config)
        self.capture = cv2.VideoCapture(source, cv2.CAP_GSTREAMER if isinstance(source, str) else 0)
        if not self.capture.isOpened():
            raise RuntimeError(f"Unable to open camera source: {source}")
        self.frame_id = 0

    def _build_source(self, config: Dict):
        pipeline = config.get("gstreamer_pipeline") or ""
        if pipeline:
            return pipeline
        device = config.get("device", "/dev/video0")
        width = int(config.get("width", 640))
        height = int(config.get("height", 480))
        fps = int(config.get("fps", 30))
        if str(config.get("backend", "gstreamer")).lower() == "gstreamer":
            return (
                f"v4l2src device={device} ! video/x-raw,width={width},height={height},framerate={fps}/1 "
                "! videoconvert ! video/x-raw,format=BGR ! appsink drop=true sync=false"
            )
        return int(str(device).replace("/dev/video", "")) if str(device).startswith("/dev/video") else device

    def frames(self) -> Iterator[Frame]:
        while True:
            ok, image = self.capture.read()
            if not ok:
                raise RuntimeError("Camera frame read failed")
            self.frame_id += 1
            yield Frame(image=image, timestamp_s=time.monotonic(), frame_id=self.frame_id)

    def close(self) -> None:
        self.capture.release()
