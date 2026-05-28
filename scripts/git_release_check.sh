#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

warn() {
  echo "WARN: $*" >&2
}

echo "A2G GitHub release check"
echo "project_root=${PROJECT_ROOT}"

[[ -f README.md ]] || fail "README.md missing"
[[ -f requirements.txt ]] || fail "requirements.txt missing"
[[ -f configs/aruco_live.yaml ]] || fail "configs/aruco_live.yaml missing"
[[ -f scripts/quick_link_start.sh ]] || fail "scripts/quick_link_start.sh missing"
[[ -f docs/GITHUB_JETSON_DEPLOY.md ]] || fail "docs/GITHUB_JETSON_DEPLOY.md missing"

MAVLINK_ENABLED="$(python3 - <<'PY'
from pathlib import Path

path = Path("configs/aruco_live.yaml")
enabled = None
in_mavlink = False
for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.split("#", 1)[0].rstrip()
    if not line.strip():
        continue
    if line.startswith("mavlink:"):
        in_mavlink = True
        continue
    if in_mavlink and line and not line.startswith((" ", "\t")):
        in_mavlink = False
    if in_mavlink and line.strip().startswith("enabled:"):
        enabled = line.split(":", 1)[1].strip().lower()
        break
print(enabled or "unknown")
PY
)"

echo "mavlink.enabled=${MAVLINK_ENABLED}"
[[ "$MAVLINK_ENABLED" == "false" ]] || fail "configs/aruco_live.yaml must keep mavlink.enabled=false for public monitor-only release"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git repository: yes"
  echo
  echo "Tracked/untracked summary:"
  git status --short
  echo
  echo "Ignored runtime files:"
  git status --ignored --short logs models calib | sed -n '1,80p'
else
  warn "not inside a git repository yet"
fi

if git ls-files --error-unmatch logs/ground_commands.jsonl >/dev/null 2>&1; then
  fail "runtime log logs/ground_commands.jsonl is tracked"
fi
if git ls-files --error-unmatch logs/dashboard_status.jsonl >/dev/null 2>&1; then
  fail "runtime log logs/dashboard_status.jsonl is tracked"
fi
if git ls-files --error-unmatch configs/env.local >/dev/null 2>&1; then
  fail "local environment file configs/env.local is tracked"
fi

export PYTHONPATH="$PROJECT_ROOT/src:${PYTHONPATH:-}"
if python3 -m pytest --version >/dev/null 2>&1; then
  python3 -m pytest tests
else
  warn "pytest is not installed; running compile check only"
  python3 -m compileall -q src tools scripts
fi

echo
echo "PASS: repository is ready for GitHub push after setting origin."
