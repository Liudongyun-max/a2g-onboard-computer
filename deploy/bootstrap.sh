#!/usr/bin/env bash
set -e

echo "A2G Jetson Bootstrap"
echo "Checking Jetson workspace layout..."

for p in jetson shared deploy; do
  if [ -d "$p" ]; then
    echo "[OK] $p"
  else
    echo "[WARN] Missing $p"
  fi
done

echo "This bootstrap is a repository-level entry."
echo "On Jetson runtime system, use project-local scripts such as:"
echo "bash scripts/quick_link_start.sh"
echo "bash scripts/integration_preflight.sh"
