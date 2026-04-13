#!/usr/bin/env bash
# sync-config.sh — copies project config.json to ~/.claude-code-router/
# Run this after editing config.json in the project directory.
# CCR does NOT auto-reload — restart ccr after syncing:
#   ./scripts/sync-config.sh && ccr stop && ccr start

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="$HOME/.claude-code-router"

mkdir -p "$TARGET_DIR"

# Load .env so envsubst can expand $COPILOT_CHAT_TOKEN and other vars
if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Expand env vars + fix any stale home-dir paths from old username
envsubst < "$PROJECT_DIR/config.json" \
  | sed "s|/Users/OwenYeh/|/Users/$(whoami)/|g" \
  > "$TARGET_DIR/config.json"

echo "config.json synced to $TARGET_DIR/ (env vars expanded) — restart ccr to apply"
