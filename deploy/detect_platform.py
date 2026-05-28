#!/usr/bin/env python3
import json
import os
import platform
from pathlib import Path


def main() -> None:
    system = platform.system().lower()
    is_windows = system == "windows"
    is_linux = system == "linux"
    is_jetson = Path("/etc/nv_tegra_release").exists()
    os_release = {}
    if Path("/etc/os-release").exists():
        for line in Path("/etc/os-release").read_text(encoding="utf-8").splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                os_release[key] = value.strip('"')

    print(json.dumps({
        "system": system,
        "is_windows": is_windows,
        "is_linux": is_linux,
        "is_jetson": is_jetson,
        "os_release": os_release,
        "cwd": os.getcwd()
    }, indent=2))


if __name__ == "__main__":
    main()
