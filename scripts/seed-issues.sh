#!/usr/bin/env bash
# Seed Sprint 1 issues via GitHub CLI
# Usage: ./scripts/seed-issues.sh owner/repo

set -euo pipefail
REPO="${1:-}"
if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required: https://cli.github.com/"; exit 1
fi
if [ -z "$REPO" ]; then
  echo "Usage: $0 <owner/repo>"; exit 1
fi

function create_issue() {
  local title="$1"; shift
  local body="$1"; shift
  gh issue create --repo "$REPO" -t "$title" -b "$body" -l "sprint-1"
}

create_issue "feat: WebCodecs detection & decision logging" "Implement src/modules/encode.ts per docs/SPRINT-1.md"
create_issue "feat: OPFS journal stubs (append/snapshot/replay)" "Implement src/modules/journal.ts and wire to Save flow"
create_issue "chore: CI build passes for Pages artifact" "Ensure Actions workflow builds and uploads dist"
create_issue "docs: add status HUD & README update" "Surface encode decision in UI and document it"
