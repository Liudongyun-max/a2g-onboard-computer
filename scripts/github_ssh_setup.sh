#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${A2G_GITHUB_KEY_PATH:-$HOME/.ssh/a2g_jetson_github}"
HOST_ALIAS="${A2G_GITHUB_HOST_ALIAS:-github.com-a2g}"
REPO_SSH=""

usage() {
  cat <<'USAGE'
Usage: bash scripts/github_ssh_setup.sh [--repo owner/name]

Creates a dedicated SSH key for GitHub push and prints the public key.
After adding the key to GitHub, this script can also configure origin.

Options:
  --repo owner/name   Optional GitHub repository, for example acme/a2g-vision-landing
  -h, --help          Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_SSH="${2:?missing owner/name}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ ! -f "$KEY_PATH" ]]; then
  ssh-keygen -t ed25519 -C "jetson-onboard-a2g" -f "$KEY_PATH" -N ""
else
  echo "SSH key already exists: $KEY_PATH"
fi

touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

if ! grep -q "^Host ${HOST_ALIAS}$" "$HOME/.ssh/config"; then
  cat >> "$HOME/.ssh/config" <<EOF

Host ${HOST_ALIAS}
  HostName github.com
  User git
  IdentityFile ${KEY_PATH}
  IdentitiesOnly yes
EOF
fi

echo
echo "Add this public key to GitHub:"
echo "  Repository Settings -> Deploy keys -> Add deploy key -> Allow write access"
echo "  Or GitHub account Settings -> SSH and GPG keys -> New SSH key"
echo
cat "${KEY_PATH}.pub"
echo

cd "$PROJECT_ROOT"

if [[ -n "$REPO_SSH" ]]; then
  REMOTE_URL="git@${HOST_ALIAS}:${REPO_SSH}.git"
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
  else
    git remote add origin "$REMOTE_URL"
  fi
  git branch -M main
  echo
  echo "origin configured:"
  git remote -v
fi

echo
echo "After adding the key to GitHub, test SSH:"
echo "  ssh -T git@${HOST_ALIAS}"
echo
echo "Then push:"
echo "  cd \"${PROJECT_ROOT}\""
echo "  bash scripts/github_push.sh"
