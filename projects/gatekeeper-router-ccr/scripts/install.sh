#!/usr/bin/env bash
# install.sh — one-shot global install + config sync for gatekeeper-router-ccr
# Run once after cloning/moving to a new machine.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Installing global tools..."
npm install -g @musistudio/claude-code-router@2.0.0
npm install -g ccxray@1.2.2

echo "==> Verifying versions..."
ccr -v
ccxray --version 2>/dev/null | head -1

echo "==> Installing project dependencies..."
(cd "$PROJECT_DIR" && npm install)

echo "==> Syncing config.json to ~/.claude-code-router/..."
bash "$SCRIPT_DIR/sync-config.sh"

echo ""
echo "Done. Next steps:"
echo "  1. Edit .env: set COPILOT_CHAT_TOKEN (run copilot-login.js in gatekeeper-router/)"
echo "  2. Add aic-* shell aliases to ~/.zshrc (see docs/vscode-setup.md)"
echo "  3. Run: aic-start"
