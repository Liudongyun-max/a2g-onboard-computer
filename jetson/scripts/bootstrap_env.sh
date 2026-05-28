#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$PROJECT_ROOT/src:${PYTHONPATH:-}"

PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
PIP_TRUSTED_HOST="${PIP_TRUSTED_HOST:-pypi.tuna.tsinghua.edu.cn}"

python3 -m pip install --user \
  -i "$PIP_INDEX_URL" \
  --trusted-host "$PIP_TRUSTED_HOST" \
  -r "$PROJECT_ROOT/requirements.txt"

echo "Environment ready. Add this before running:"
echo "export PYTHONPATH=$PROJECT_ROOT/src:\$PYTHONPATH"
