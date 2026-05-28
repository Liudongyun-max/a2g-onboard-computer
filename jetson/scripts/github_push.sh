#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

REMOTE="${1:-origin}"
BRANCH="${2:-main}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FAIL: not a git repository: $PROJECT_ROOT" >&2
  exit 1
fi

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "FAIL: git remote '$REMOTE' is not configured." >&2
  echo "Run: bash scripts/github_ssh_setup.sh --repo owner/name" >&2
  exit 1
fi

bash scripts/git_release_check.sh

git branch -M "$BRANCH"

if [[ -n "$(git status --short)" ]]; then
  echo
  echo "Working tree has changes:"
  git status --short
  echo
  echo "Stage and commit them before pushing, for example:"
  echo "  git add ."
  echo "  git commit -m \"Update Jetson onboard deployment\""
  exit 1
fi

echo
echo "Pushing ${BRANCH} to ${REMOTE}:"
git push -u "$REMOTE" "$BRANCH"
