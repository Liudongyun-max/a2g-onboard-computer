#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
cd "$PROJECT_ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

warn() {
  echo "WARN: $*" >&2
}

echo "A2G GitHub release check"
echo "repo_root=${REPO_ROOT}"
echo "jetson_root=${PROJECT_ROOT}"

[[ -f "$REPO_ROOT/README.md" ]] || fail "root README.md missing"
[[ -f "$REPO_ROOT/A2G_Project_Principles.md" ]] || fail "A2G_Project_Principles.md missing"
[[ -f "$REPO_ROOT/.gitattributes" ]] || fail ".gitattributes missing"
[[ -f README.md ]] || fail "jetson/README.md missing"
[[ -f requirements.txt ]] || fail "jetson/requirements.txt missing"
[[ -f configs/aruco_live.yaml ]] || fail "jetson/configs/aruco_live.yaml missing"
[[ -f scripts/quick_link_start.sh ]] || fail "jetson/scripts/quick_link_start.sh missing"
[[ -f docs/GITHUB_JETSON_DEPLOY.md ]] || fail "jetson/docs/GITHUB_JETSON_DEPLOY.md missing"
[[ -f "$REPO_ROOT/shared/api/command_whitelist.json" ]] || fail "shared/api/command_whitelist.json missing"
[[ -f "$REPO_ROOT/shared/api/status_schema.json" ]] || fail "shared/api/status_schema.json missing"
[[ -f "$REPO_ROOT/shared/api/ground_command_contract.md" ]] || fail "shared/api/ground_command_contract.md missing"
[[ -f "$REPO_ROOT/deploy/bootstrap.sh" ]] || fail "deploy/bootstrap.sh missing"
[[ -f "$REPO_ROOT/deploy/bootstrap.ps1" ]] || fail "deploy/bootstrap.ps1 missing"

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
[[ "$MAVLINK_ENABLED" == "false" ]] || fail "jetson/configs/aruco_live.yaml must keep mavlink.enabled=false"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git repository: yes"
  echo
  echo "Tracked/untracked summary:"
  git -C "$REPO_ROOT" status --short
  echo
  echo "Ignored runtime files:"
  git -C "$REPO_ROOT" status --ignored --short jetson/logs jetson/models jetson/calib windows/logs windows/reports | sed -n '1,120p'
else
  warn "not inside a git repository yet"
fi

for path in \
  jetson/logs/ground_commands.jsonl \
  jetson/logs/dashboard_status.jsonl \
  jetson/logs/system_events.jsonl \
  jetson/configs/env.local \
  windows/logs/runtime.json \
  windows/reports/report.json
do
  if git -C "$REPO_ROOT" ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    fail "runtime/local file is tracked: $path"
  fi
done

git -C "$REPO_ROOT" diff --check

export PYTHONPATH="$PROJECT_ROOT/src:${PYTHONPATH:-}"
if python3 -m pytest --version >/dev/null 2>&1; then
  python3 -m pytest tests
else
  warn "pytest is not installed; running compile check only"
  python3 -m compileall -q src tools scripts "$REPO_ROOT/deploy"
fi

echo
echo "PASS: dual-system repository is ready for GitHub push."
