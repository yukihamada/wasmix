#!/usr/bin/env bash
# Bootstrap a GitHub repo, enable Pages deploy, and push main.
# Usage: ./scripts/gh-setup.sh yourname/wasmix

set -euo pipefail
REPO="${1:-}"
if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required: https://cli.github.com/"; exit 1
fi
if [ -z "$REPO" ]; then
  echo "Usage: $0 <owner/repo>"; exit 1
fi

git init
git add -A
git commit -m "feat: WASMIX MVP scaffold"
git branch -M main
gh repo create "$REPO" --public --source=. --remote=origin --push

echo "Enabling Actions and Pages..."
gh workflow enable "Deploy to GitHub Pages" || true

echo "Done. Repo: https://github.com/$REPO"
