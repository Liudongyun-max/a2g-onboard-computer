from __future__ import annotations

import argparse
import json
import os
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional

import cv2
import yaml

from vision_landing.camera import OpenCVCamera
from vision_landing.config import AppConfig
from vision_landing.control import LandingController
from vision_landing.detectors import build_detector
from vision_landing.geometry import TargetEstimator
from vision_landing.pipeline import select_best_detection
from vision_landing.types import Frame, TargetEstimate, VelocityCommand


class DashboardState:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.jpeg: Optional[bytes] = None
        self.recording = False
        self.shadow_active = False
        self.last_ground_command = None
        self.status = {
            "running": False,
            "detected": False,
            "target_id": None,
            "camera_position_m": None,
            "range_m": None,
            "confidence": 0.0,
            "command": None,
            "fps": 0.0,
            "frame_id": 0,
            "updated_at": None,
            "error": None,
            "safety_mode": "monitor_only",
            "recording": False,
            "shadow_active": False,
            "mavlink_enabled": False,
            "last_ground_command": None,
        }

    def update(self, jpeg: bytes, status: dict) -> None:
        with self.lock:
            self.jpeg = jpeg
            self.status.update(status)

    def set_error(self, message: str) -> None:
        with self.lock:
            self.status["running"] = False
            self.status["error"] = message

    def set_ground_flags(self, recording: Optional[bool] = None, shadow_active: Optional[bool] = None) -> None:
        with self.lock:
            if recording is not None:
                self.recording = recording
                self.status["recording"] = recording
            if shadow_active is not None:
                self.shadow_active = shadow_active
                self.status["shadow_active"] = shadow_active

    def set_last_ground_command(self, command_result: dict) -> None:
        with self.lock:
            self.last_ground_command = command_result
            self.status["last_ground_command"] = command_result

    def snapshot(self):
        with self.lock:
            return self.jpeg, dict(self.status)


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def draw_overlay(frame, estimate: TargetEstimate, command: VelocityCommand, fps: float) -> None:
    lines = [
        f"detected={estimate.detected} id={estimate.target_id} fps={fps:.1f}",
        f"range={estimate.range_m if estimate.range_m is not None else 0.0:.3f}m conf={estimate.confidence:.2f}",
        f"cmd vx={command.vx_mps:.2f} vy={command.vy_mps:.2f} vz={command.vz_mps:.2f} valid={command.valid}",
    ]
    if estimate.position_camera_m:
        x, y, z = estimate.position_camera_m
        lines.insert(1, f"camera x={x:.3f} y={y:.3f} z={z:.3f}m")
    y = 24
    for line in lines:
        cv2.putText(frame, line, (10, y), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 0, 0), 4, cv2.LINE_AA)
        cv2.putText(frame, line, (10, y), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 1, cv2.LINE_AA)
        y += 24


def append_status_log(log_path: Path, status: dict) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(status, sort_keys=True) + "\n")


def iso_now_local() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime())


def make_command_id(counter: int) -> str:
    return f"cmd_{time.strftime('%Y%m%d_%H%M%S', time.localtime())}_{counter:03d}"


def append_jsonl(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(payload, sort_keys=True, ensure_ascii=False) + "\n")


ALLOWED_GROUND_COMMANDS = {
    "ping",
    "status_snapshot",
    "mark_event",
    "start_record",
    "stop_record",
    "shadow_start",
    "shadow_stop",
}

FORBIDDEN_FLIGHT_COMMANDS = {
    "enable_mavlink",
    "start_vision_landing",
    "send_velocity",
    "arm",
    "takeoff",
    "land",
    "set_mode",
}

DEFERRED_COMMANDS = {
    "restart_dashboard_request",
    "start_udp_video_request",
    "stop_udp_video_request",
    "reload_config",
}


class GroundCommandProcessor:
    def __init__(self, state: DashboardState, config_path: Path, command_log_path: Path, event_log_path: Path, token: Optional[str]):
        self.state = state
        self.config_path = config_path
        self.command_log_path = command_log_path
        self.event_log_path = event_log_path
        self.token = token
        self.lock = threading.Lock()
        self.counter = 0
        self.safety_mode = "monitor_only"

    def next_id(self) -> str:
        with self.lock:
            self.counter += 1
            return make_command_id(self.counter)

    def mavlink_enabled(self) -> bool:
        try:
            config = load_yaml(self.config_path)
            return bool(config.get("mavlink", {}).get("enabled", False))
        except Exception:
            return True

    def handle(self, body: bytes, source_ip: str, headers) -> tuple[int, dict]:
        command_id = self.next_id()
        now = iso_now_local()
        try:
            payload = json.loads(body.decode("utf-8"))
        except Exception:
            response = self._result(command_id, None, False, False, "invalid_json")
            self._log(now, command_id, source_ip, {}, response)
            return HTTPStatus.BAD_REQUEST, response

        command = payload.get("command")
        if not command:
            response = self._result(command_id, None, False, False, "missing_command")
            self._log(now, command_id, source_ip, payload, response)
            return HTTPStatus.BAD_REQUEST, response

        if self.token:
            supplied = headers.get("X-A2G-Token", "")
            if supplied != self.token:
                response = self._result(command_id, command, False, False, "invalid_token")
                self._log(now, command_id, source_ip, payload, response)
                return HTTPStatus.FORBIDDEN, response

        mavlink_enabled = self.mavlink_enabled()
        if command in FORBIDDEN_FLIGHT_COMMANDS:
            reason = "flight_control_forbidden_when_mavlink_disabled" if not mavlink_enabled else "flight_control_forbidden_in_monitor_only"
            response = self._result(command_id, command, False, False, reason)
            self._log(now, command_id, source_ip, payload, response, mavlink_enabled=mavlink_enabled)
            return HTTPStatus.FORBIDDEN, response

        if command in DEFERRED_COMMANDS:
            response = self._result(command_id, command, False, False, "command_deferred_not_enabled")
            self._log(now, command_id, source_ip, payload, response, mavlink_enabled=mavlink_enabled)
            return HTTPStatus.FORBIDDEN, response

        if command not in ALLOWED_GROUND_COMMANDS:
            response = self._result(command_id, command, False, False, "command_not_whitelisted")
            self._log(now, command_id, source_ip, payload, response, mavlink_enabled=mavlink_enabled)
            return HTTPStatus.FORBIDDEN, response

        if self.safety_mode != "monitor_only":
            response = self._result(command_id, command, False, False, "invalid_safety_mode")
            self._log(now, command_id, source_ip, payload, response, mavlink_enabled=mavlink_enabled)
            return HTTPStatus.FORBIDDEN, response

        if mavlink_enabled:
            response = self._result(command_id, command, False, False, "mavlink_must_remain_disabled")
            self._log(now, command_id, source_ip, payload, response, mavlink_enabled=mavlink_enabled)
            return HTTPStatus.FORBIDDEN, response

        response = self._execute(command_id, command, payload)
        self._log(now, command_id, source_ip, payload, response, mavlink_enabled=mavlink_enabled)
        self.state.set_last_ground_command(response)
        return HTTPStatus.OK, response

    def _execute(self, command_id: str, command: str, payload: dict) -> dict:
        params = payload.get("params") if isinstance(payload.get("params"), dict) else {}
        if command == "ping":
            response = self._result(command_id, command, True, True, "pong")
            response["safety_mode"] = self.safety_mode
            return response
        if command == "status_snapshot":
            _, status = self.state.snapshot()
            response = self._result(command_id, command, True, True, "status snapshot captured")
            response["status"] = {
                "detected": status.get("detected"),
                "target_id": status.get("target_id"),
                "fps": status.get("fps"),
                "range_m": status.get("range_m"),
                "running": status.get("running"),
                "mavlink_enabled": False,
                "recording": status.get("recording"),
                "shadow_active": status.get("shadow_active"),
            }
            append_jsonl(self.event_log_path, {"time": iso_now_local(), "type": "status_snapshot", "command_id": command_id, "status": response["status"]})
            return response
        if command == "mark_event":
            note = str(params.get("note", ""))
            event = {"time": iso_now_local(), "type": "mark_event", "command_id": command_id, "note": note, "params": params}
            append_jsonl(self.event_log_path, event)
            response = self._result(command_id, command, True, True, "event marked")
            response["event"] = event
            return response
        if command == "start_record":
            self.state.set_ground_flags(recording=True)
            append_jsonl(self.event_log_path, {"time": iso_now_local(), "type": "recording_started", "command_id": command_id, "params": params})
            return self._result(command_id, command, True, True, "recording flag enabled")
        if command == "stop_record":
            self.state.set_ground_flags(recording=False)
            append_jsonl(self.event_log_path, {"time": iso_now_local(), "type": "recording_stopped", "command_id": command_id, "params": params})
            return self._result(command_id, command, True, True, "recording flag disabled")
        if command == "shadow_start":
            self.state.set_ground_flags(shadow_active=True)
            append_jsonl(self.event_log_path, {"time": iso_now_local(), "type": "shadow_started", "command_id": command_id, "params": params})
            return self._result(command_id, command, True, True, "shadow mode enabled")
        if command == "shadow_stop":
            self.state.set_ground_flags(shadow_active=False)
            append_jsonl(self.event_log_path, {"time": iso_now_local(), "type": "shadow_stopped", "command_id": command_id, "params": params})
            return self._result(command_id, command, True, True, "shadow mode disabled")
        return self._result(command_id, command, False, False, "handler_missing")

    def _result(self, command_id: str, command: Optional[str], accepted: bool, executed: bool, reason: str) -> dict:
        return {
            "ok": bool(accepted and executed),
            "command_id": command_id,
            "command": command,
            "accepted": accepted,
            "executed": executed,
            "reason": reason,
        }

    def _log(self, now: str, command_id: str, source_ip: str, payload: dict, response: dict, mavlink_enabled: Optional[bool] = None) -> None:
        entry = {
            "time": now,
            "command_id": command_id,
            "source_ip": source_ip,
            "client": payload.get("client"),
            "client_time": payload.get("client_time"),
            "command": payload.get("command"),
            "params": payload.get("params") if isinstance(payload.get("params"), dict) else {},
            "accepted": response.get("accepted"),
            "executed": response.get("executed"),
            "reason": response.get("reason"),
            "safety_mode": self.safety_mode,
            "mavlink_enabled": self.mavlink_enabled() if mavlink_enabled is None else mavlink_enabled,
        }
        append_jsonl(self.command_log_path, entry)


def run_vision_loop(project_root: Path, config_path: Path, camera_config_path: Path, log_path: Path, state: DashboardState) -> None:
    app_config = AppConfig.load(config_path)
    raw = app_config.raw
    camera_intrinsics = load_yaml(camera_config_path)
    detector_config = raw.get("detector", {})
    detector = build_detector(detector_config)
    estimator = TargetEstimator(camera_intrinsics, raw.get("target", {}))
    controller = LandingController(raw.get("control", {}))
    min_confidence = float(detector_config.get("confidence_threshold", 0.45))
    camera = OpenCVCamera(raw.get("camera", {}))
    last_t = time.monotonic()
    last_log_t = 0.0
    fps_smooth = 0.0
    try:
        for frame in camera.frames():
            now = time.monotonic()
            dt = max(1e-6, now - last_t)
            last_t = now
            fps_smooth = 0.9 * fps_smooth + 0.1 * (1.0 / dt) if fps_smooth else 1.0 / dt
            detections = detector.detect(frame)
            detection = select_best_detection(detections, min_confidence)
            estimate = estimator.estimate(detection, frame.timestamp_s)
            command = controller.update(estimate)
            annotated = frame.image.copy()
            if detection and detection.corners_px:
                points = [(int(x), int(y)) for x, y in detection.corners_px]
                for i in range(4):
                    cv2.line(annotated, points[i], points[(i + 1) % 4], (0, 255, 0), 2)
            draw_overlay(annotated, estimate, command, fps_smooth)
            ok, encoded = cv2.imencode(".jpg", annotated, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
            if not ok:
                continue
            status = {
                "running": True,
                "detected": estimate.detected,
                "target_id": estimate.target_id,
                "camera_position_m": estimate.position_camera_m,
                "range_m": estimate.range_m,
                "confidence": estimate.confidence,
                "command": {
                    "vx_mps": command.vx_mps,
                    "vy_mps": command.vy_mps,
                    "vz_mps": command.vz_mps,
                    "valid": command.valid,
                    "reason": command.reason,
                },
                "fps": fps_smooth,
                "frame_id": frame.frame_id,
                "updated_at": time.time(),
                "error": None,
            }
            state.update(encoded.tobytes(), status)
            if now - last_log_t >= 1.0:
                append_status_log(log_path, status)
                last_log_t = now
    except Exception as exc:
        state.set_error(str(exc))
        raise
    finally:
        camera.close()


def make_handler(state: DashboardState, command_processor: GroundCommandProcessor):
    class DashboardHandler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            return

        def do_HEAD(self):
            if self.path == "/" or self.path == "/status":
                self.send_response(HTTPStatus.OK)
                self.end_headers()
                return
            self.send_error(HTTPStatus.NOT_FOUND)

        def do_GET(self):
            if self.path == "/":
                body = b"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Vision Landing Dashboard</title>
  <style>
    body { margin: 0; font-family: sans-serif; background: #101418; color: #e6edf3; }
    main { display: grid; grid-template-columns: minmax(320px, 1fr) 360px; min-height: 100vh; }
    img { width: 100%; height: 100vh; object-fit: contain; background: #000; }
    aside { padding: 16px; border-left: 1px solid #26313a; background: #151b22; }
    h1 { font-size: 20px; margin: 0 0 16px; }
    pre { white-space: pre-wrap; word-break: break-word; font-size: 14px; line-height: 1.4; }
    .ok { color: #7ee787; }
    .bad { color: #ff7b72; }
  </style>
</head>
<body>
<main>
  <img src="/stream" />
  <aside>
    <h1>Vision Landing Dashboard</h1>
    <pre id="status">loading...</pre>
  </aside>
</main>
<script>
async function refresh() {
  const res = await fetch('/status');
  const data = await res.json();
  document.getElementById('status').textContent = JSON.stringify(data, null, 2);
}
setInterval(refresh, 500);
refresh();
</script>
</body>
</html>"""
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if self.path == "/status":
                _, status = state.snapshot()
                body = json.dumps(status, indent=2, sort_keys=True).encode("utf-8")
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if self.path == "/stream":
                self.send_response(HTTPStatus.OK)
                self.send_header("Age", "0")
                self.send_header("Cache-Control", "no-cache, private")
                self.send_header("Pragma", "no-cache")
                self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
                self.end_headers()
                try:
                    while True:
                        jpeg, _ = state.snapshot()
                        if jpeg is None:
                            time.sleep(0.1)
                            continue
                        self.wfile.write(b"--frame\r\n")
                        self.wfile.write(b"Content-Type: image/jpeg\r\n")
                        self.wfile.write(f"Content-Length: {len(jpeg)}\r\n\r\n".encode("ascii"))
                        self.wfile.write(jpeg)
                        self.wfile.write(b"\r\n")
                        time.sleep(0.03)
                except (BrokenPipeError, ConnectionResetError):
                    return
                return
            self.send_error(HTTPStatus.NOT_FOUND)

        def do_POST(self):
            if self.path != "/api/ground-command":
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            content_type = self.headers.get("Content-Type", "")
            if "application/json" not in content_type:
                self._write_json(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, {"ok": False, "reason": "content_type_must_be_application_json"})
                return
            try:
                content_length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                self._write_json(HTTPStatus.BAD_REQUEST, {"ok": False, "reason": "invalid_content_length"})
                return
            if content_length <= 0 or content_length > 65536:
                self._write_json(HTTPStatus.BAD_REQUEST, {"ok": False, "reason": "invalid_body_size"})
                return
            body = self.rfile.read(content_length)
            status, response = command_processor.handle(body, self.client_address[0], self.headers)
            self._write_json(status, response)

        def _write_json(self, status, payload: dict):
            body = json.dumps(payload, indent=2, sort_keys=True).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return DashboardHandler


def parse_args():
    parser = argparse.ArgumentParser(description="On-board vision landing web dashboard")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--config", default="configs/aruco_live.yaml")
    parser.add_argument("--camera-config", default="configs/camera.yaml")
    parser.add_argument("--log-file", default="logs/dashboard_status.jsonl")
    parser.add_argument("--ground-command-log", default="logs/ground_commands.jsonl")
    parser.add_argument("--event-log", default="logs/system_events.jsonl")
    parser.add_argument("--ground-command-token", default=os.environ.get("A2G_GROUND_COMMAND_TOKEN", ""))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    project_root = Path(__file__).resolve().parents[1]
    config_path = Path(args.config)
    if not config_path.is_absolute():
        config_path = project_root / config_path
    camera_config_path = Path(args.camera_config)
    if not camera_config_path.is_absolute():
        camera_config_path = project_root / camera_config_path
    log_path = Path(args.log_file)
    if not log_path.is_absolute():
        log_path = project_root / log_path
    command_log_path = Path(args.ground_command_log)
    if not command_log_path.is_absolute():
        command_log_path = project_root / command_log_path
    event_log_path = Path(args.event_log)
    if not event_log_path.is_absolute():
        event_log_path = project_root / event_log_path
    state = DashboardState()
    config = load_yaml(config_path)
    state.status["mavlink_enabled"] = bool(config.get("mavlink", {}).get("enabled", False))
    command_processor = GroundCommandProcessor(
        state,
        config_path,
        command_log_path,
        event_log_path,
        args.ground_command_token or None,
    )
    thread = threading.Thread(
        target=run_vision_loop,
        args=(project_root, config_path, camera_config_path, log_path, state),
        daemon=True,
    )
    thread.start()
    server = ThreadingHTTPServer((args.host, args.port), make_handler(state, command_processor))
    print(f"Dashboard listening on http://{args.host}:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
