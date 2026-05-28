from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request


ALLOWED = [
    "ping",
    "status_snapshot",
    "mark_event",
    "start_record",
    "stop_record",
    "shadow_start",
    "shadow_stop",
]

FORBIDDEN = [
    "enable_mavlink",
    "start_vision_landing",
    "send_velocity",
    "arm",
    "takeoff",
    "land",
    "set_mode",
]


def post_json(base_url: str, command: str, params: dict | None = None, token: str | None = None) -> tuple[int, dict]:
    payload = {
        "command": command,
        "params": params or {},
        "client_time": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime()),
        "client": "jetson-selftest",
    }
    body = json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["X-A2G-Token"] = token
    request = urllib.request.Request(f"{base_url}/api/ground-command", data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8"))


def get_status(base_url: str) -> dict:
    with urllib.request.urlopen(f"{base_url}/status", timeout=3) as response:
        return json.loads(response.read().decode("utf-8"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Ground command API self-test")
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--token", default="")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    failures = []
    status = get_status(args.base_url)
    print("status:", json.dumps({
        "running": status.get("running"),
        "detected": status.get("detected"),
        "target_id": status.get("target_id"),
        "mavlink_enabled": status.get("mavlink_enabled"),
        "safety_mode": status.get("safety_mode"),
    }, sort_keys=True))
    if status.get("mavlink_enabled") is not False:
        failures.append("mavlink_enabled is not false")
    if status.get("safety_mode") != "monitor_only":
        failures.append("safety_mode is not monitor_only")

    for command in ALLOWED:
        http_status, response = post_json(args.base_url, command, {"note": "selftest"} if command == "mark_event" else {}, args.token or None)
        print("allowed:", command, http_status, response.get("reason"))
        if http_status != 200 or not response.get("accepted") or not response.get("executed"):
            failures.append(f"allowed command failed: {command}")

    for command in FORBIDDEN:
        http_status, response = post_json(args.base_url, command, {"vx": 1.0} if command == "send_velocity" else {}, args.token or None)
        print("forbidden:", command, http_status, response.get("reason"))
        if http_status == 200 or response.get("accepted") or response.get("executed"):
            failures.append(f"forbidden command was not blocked: {command}")

    # Restore neutral state after testing.
    post_json(args.base_url, "stop_record", {}, args.token or None)
    post_json(args.base_url, "shadow_stop", {}, args.token or None)

    if failures:
        print("FAIL")
        for failure in failures:
            print("-", failure)
        raise SystemExit(1)
    print("PASS")


if __name__ == "__main__":
    main()
