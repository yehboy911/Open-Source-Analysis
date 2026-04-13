# Claude Code + VSCode + Copilot Setup

## Architecture Overview

```
Claude Code CLI / VSCode Claude Extension
  ↓  ANTHROPIC_BASE_URL=http://localhost:5577
ccxray :5577   (observability proxy — captures bodies, tools, system prompts)
  ↓  upstream=http://localhost:3001
CCR v2.0.0 :3001   (claude-code-router — 3-tier classifier + Copilot proxy)
  ↓  model routed by custom-router.js
api.githubcopilot.com   (billed against Copilot Pro $10/mo)
```

**Important distinction:** This router only affects **Claude Code**'s traffic
(re-routed to Copilot as a backend). The **GitHub Copilot extension in VSCode**
talks directly to `api.githubcopilot.com` with its own token — it is completely
unaffected by this router.

## Quick Start

```bash
# One-time: get a Copilot session token
# (run from gatekeeper-router/, which has the login script)
cd ~/Claude-workspace/projects/gatekeeper-router
node scripts/copilot-login.js   # follow device-code flow → writes COPILOT_CHAT_TOKEN

# Copy the token to gatekeeper-router-ccr .env
# Then start the stack:
aic-start
```

## Shell Functions

Add to `~/.zshrc` (the `aic-start` block):

```zsh
export GKC_DIR="$HOME/Claude-workspace/projects/gatekeeper-router-ccr"

aic-start() {
  set -a; source "$GKC_DIR/.env"; set +a
  # ccxray: use ANTHROPIC_TEST_* to point upstream at CCR :3001
  ANTHROPIC_TEST_HOST=localhost ANTHROPIC_TEST_PORT=3001 ANTHROPIC_TEST_PROTOCOL=http \
    ccxray start --port 5577 --no-browser > /tmp/ccxray.log 2>&1 &
  ccr start > /tmp/ccr.log 2>&1 &
  (cd "$GKC_DIR" && nohup node sidecar-dashboard.js > /tmp/ccr-sidecar.log 2>&1 &)
  echo "CCR :3001 | sidecar :3002 | ccxray :5577 (proxy+dashboard same port in 1.2.2)"
}
aic-claude() { ANTHROPIC_BASE_URL=http://localhost:5577 ANTHROPIC_API_KEY=gatekeeper-internal claude "$@"; }
aic-stop()   { ccr stop; pkill -f sidecar-dashboard.js 2>/dev/null; pkill -f ccxray 2>/dev/null; echo "stopped"; }
aic-status() { ccr status; pgrep -fl sidecar-dashboard.js; pgrep -fl ccxray; }
aicl()       { tail -f /tmp/ccr.log /tmp/ccr-sidecar.log; }
aic-dash()   { open http://localhost:3002; }
aic-xray()   { open http://localhost:5577; }
```

## Environment Variables

| Variable | Purpose | Default |
|---|---|---|
| `ANTHROPIC_BASE_URL` | Points Claude Code at ccxray | `http://localhost:5577` |
| `ANTHROPIC_API_KEY` | Dummy key (Copilot doesn't use it) | `dummy` |
| `COPILOT_CHAT_TOKEN` | `ghu_…` token from copilot-login | required |
| `COPILOT_MODEL_ECONOMY` | ECONOMY tier model | `gpt-5-mini` |
| `COPILOT_MODEL_BALANCED` | BALANCED tier model | `gemini-3-flash-preview` |
| `COPILOT_MODEL_PREMIUM` | PREMIUM tier model | `claude-sonnet-4.6` |
| `ROUTER_PORT` | CCR listen port | `3001` |
| `SIDECAR_PORT` | Dashboard listen port | `3002` |

## Launching Claude Code

```bash
# Use aic-claude — sets correct API key and base URL in one command
aic-claude

# IMPORTANT: do NOT run bare `claude` — your shell may have a real sk-ant-... key
# in ANTHROPIC_API_KEY (from Keychain), which CCR rejects with 401.
# aic-claude overrides both vars:
#   ANTHROPIC_BASE_URL=http://localhost:5577
#   ANTHROPIC_API_KEY=gatekeeper-internal   ← must match config.json "APIKEY"
```

## Observability Dashboards

| Dashboard | URL | Purpose |
|---|---|---|
| ccxray | http://localhost:5578 | Request bodies, tools, system prompts, latency |
| Sidecar | http://localhost:3002 | Quota usage, 7-day burn rate, tier distribution |

## Config Changes

After editing `config.json` in the project:

```bash
./scripts/sync-config.sh   # copies to ~/.claude-code-router/config.json
ccr stop && ccr start       # CCR does NOT hot-reload config
```

## Coexistence with Option 1 (gatekeeper-router)

Both routers can run simultaneously:

| Stack | Port | Aliases |
|---|---|---|
| Option 1 (Express, `server.js`) | `:3000` | `ai-start`, `ai-stop`, `ail`, `ai-quota` |
| Option 2 (CCR v2.0.0) | `:3001` + `:3002` sidecar | `aic-start`, `aic-stop`, `aicl`, `aic-dash` |
| ccxray | `:5577` (proxy), `:5578` (dashboard) | shared by both stacks |

**Quota log is shared:** `~/.gatekeeper/quota.log` — `ai-quota` aggregates correctly for both.
