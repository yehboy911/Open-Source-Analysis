# gatekeeper-router-ccr

GitHub Copilot-backed AI model router using **claude-code-router v2.0.0**.
Intelligently routes Claude Code traffic across three model tiers based on request complexity — all billed against a Copilot Pro subscription.

## Quick Start

### 1. Install prerequisites

```bash
npm install -g @musistudio/claude-code-router@2.0.0
npm install -g ccxray@1.2.2
```

### 2. Get a Copilot token

```bash
# Run from gatekeeper-router/ (has the login script)
cd ~/Claude-workspace/projects/gatekeeper-router
node scripts/copilot-login.js   # device-code flow → writes COPILOT_CHAT_TOKEN
```

### 3. Configure

```bash
cd ~/Claude-workspace/projects/gatekeeper-router-ccr
cp .env .env.local   # edit COPILOT_CHAT_TOKEN in .env
npm install
./scripts/sync-config.sh   # copies config.json to ~/.claude-code-router/
```

### 4. Start

```bash
aic-start   # CCR :3001 + sidecar :3002 + ccxray :5577
```

### 5. Point Claude Code at the stack

```bash
ANTHROPIC_BASE_URL=http://localhost:5577 ANTHROPIC_API_KEY=dummy claude
```

### 6. Open dashboards

- Sidecar: http://localhost:3002 — quota usage, burn rate, tier distribution
- ccxray: http://localhost:5578 — request bodies, tools, system prompts

---

## 3-Tier Model Selection

| Tier | Model | Cost | When Used |
|---|---|---|---|
| **ECONOMY** | `gpt-5-mini` | 0x | Quick lookups, formatting, janitor tasks |
| **BALANCED** (default) | `gemini-3-flash-preview` | 0x | Daily development, unit tests, SBOM |
| **PREMIUM** | `claude-sonnet-4.6` | 1x | GPL/legal review, architecture, deep debug |

Routing is automatic — zero LLM calls, pure keyword + heuristic classification.

## Ports Used

| Port | Process | Notes |
|---|---|---|
| `:3001` | CCR v2.0.0 | Main router (AI model proxy) |
| `:3002` | Sidecar dashboard | Read-only metrics / quota |
| `:5577` | ccxray proxy + dashboard | Observability — body capture, request explorer (same port in 1.2.2) |
| `:3000` | Option 1 (legacy) | `gatekeeper-router` server.js — frozen |

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `COPILOT_CHAT_TOKEN` | — | `ghu_…` token (required) |
| `COPILOT_MODEL_ECONOMY` | `gpt-5-mini` | ECONOMY tier |
| `COPILOT_MODEL_BALANCED` | `gemini-3-flash-preview` | BALANCED tier |
| `COPILOT_MODEL_PREMIUM` | `claude-sonnet-4.6` | PREMIUM tier |
| `ROUTER_PORT` | `3001` | CCR port |
| `SIDECAR_PORT` | `3002` | Dashboard port |
| `QUOTA_MONTHLY_LIMIT` | `300` | Hard cap (soft-warn at 80%) |
| `FORCE_PREMIUM` | `false` | Pin all requests to PREMIUM |
| `FORCE_ECONOMY` | `false` | Pin all requests to ECONOMY |
| `CLASSIFIER_ENABLED` | `true` | `false` → always BALANCED |

## Shell Aliases

```zsh
aic-start   # start full stack
aic-stop    # stop all processes
aic-status  # check process status
aicl        # tail live logs
aic-dash    # open sidecar dashboard
aic-xray    # open ccxray dashboard
```

## After Editing config.json

```bash
./scripts/sync-config.sh && ccr stop && ccr start
```

## See Also

- `docs/classifier-flow.md` — decision tree + keyword tables
- `docs/vscode-setup.md` — detailed Claude Code + VSCode integration guide
- `CLAUDE.md` — architecture reference for Claude Code sessions
