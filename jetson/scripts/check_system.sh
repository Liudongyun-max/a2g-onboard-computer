#!/usr/bin/env bash
set -euo pipefail

echo "== System =="
uname -a
cat /etc/nv_tegra_release 2>/dev/null || true

echo "== Memory =="
free -h

echo "== CUDA / TensorRT packages =="
dpkg -l | grep -E 'cuda-11-4|libnvinfer|libcudnn8' || true

echo "== Python modules =="
python3 - <<'PY'
import importlib.util
for name in ["cv2", "numpy", "yaml", "tensorrt", "pymavlink"]:
    print(f"{name}: {'yes' if importlib.util.find_spec(name) else 'no'}")
PY

echo "== Cameras =="
ls -l /dev/video* 2>/dev/null || echo "No /dev/video* device found"
