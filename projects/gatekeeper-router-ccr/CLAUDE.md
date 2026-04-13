# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Commands

```bash
# Start full stack (CCR + sidecar + ccxray)
aic-start                        # loads .env, starts all three processes

# Start individual components
ccr start                        # CCR on :3001
node sidecar-dashboard.js        # sidecar on :3002
ccxray start --port 5577 --upstream http://localhost:3001

# Stop everything
aic-stop

# Syntax check
npm run check                    # node -e "require('./custom-router.js'); require('./plugins/copilot-transformer.js')" && echo OK

# Sync config to CCR home
./scripts/sync-config.sh         # copies config.json → ~/.claude-code-router/config.json

# Live log
aicl                             # tail -f /tmp/ccr.log /tmp/ccr-sidecar.log

# Dashboards
aic-dash                         # http://localhost:3002 (sidecar)
aic-xray                         # http://localhost:5578 (ccxray)
```

## Architecture (CCR v2.0.0 + sidecar)

**Entry point:** `ccr start` (global `@musistudio/claude-code-router@2.0.0` CLI)
**Config:** `~/.claude-code-router/config.json` (copy of project `config.json`)
**Sidecar:** `sidecar-dashboard.js` — read-only Express on `:3002`

**Request flow:**
```
Claude Code CLI
  → ccxray :5577  (observability proxy)
  → CCR :3001     (@musistudio/claude-code-router v2.0.0)
     ├── CUSTOM_ROUTER_PATH → custom-router.js (3-tier classifier)
     ├── CopilotAuth transformer (ghu_ → session token exchange)
     └── Providers: copilot-economy / copilot-balanced / copilot-premium
  → api.githubcopilot.com/chat/completions

sidecar-dashboard.js :3002  (independent read-only process)
  ├── GET /                  → public/dashboard.html
  ├── GET /v1/session-status → JSON tier + quota summary
  └── GET /v1/metrics        → JSON: quota, daily burn, tier distribution
```

## 3-Tier Intelligence Hierarchy

| Tier | Provider | Model | Premium Units | Use Case |
|---|---|---|---|---|
| ECONOMY | copilot-economy | `gpt-5-mini` (env: `COPILOT_MODEL_ECONOMY`) | 0x | Quick lookups, formatting, janitor |
| BALANCED (default) | copilot-balanced | `gemini-3-flash-preview` (env: `COPILOT_MODEL_BALANCED`) | 0x | Daily development, SBOM, unit tests |
| PREMIUM | copilot-premium | `claude-sonnet-4.6` (env: `COPILOT_MODEL_PREMIUM`) | 1x | GPL/legal, architecture, deep debug |

## Port Usage Table (SBOM / User Manual)

| Port | Process | Purpose |
|---|---|---|
| `:3000` | `gatekeeper-router` (Option 1) | Legacy Express proxy (frozen) |
| `:3001` | `ccr` (CCR v2.0.0) | AI model router — main request path |
| `:3002` | `sidecar-dashboard.js` | Read-only dashboard (quota / burn / tiers) |
| `:5577` | `ccxray` proxy + dashboard | Observability — body capture, tool inspection (same port in ccxray 1.2.2) |

## File Layout

```
gatekeeper-router-ccr/
├── config.json                   # CCR v2 config (source of truth — sync to ~/.claude-code-router/)
├── custom-router.js              # CUSTOM_ROUTER_PATH — 3-tier classifier
├── plugins/
│   ├── copilot-transformer.js    # CCR v2 transformer (CopilotAuth)
│   ├── ghu-exchanger.js          # ghu_ → session token (in-memory cache)
│   └── quota-guard.js            # monthTotal/appendQuotaLog/quotaMultiplierFor
├── sidecar-dashboard.js          # Express :3002 dashboard
├── public/dashboard.html         # Vanilla HTML+JS dashboard UI
├── docs/
│   ├── classifier-flow.md        # Mermaid decision tree + keyword tables
│   └── vscode-setup.md           # Claude Code + VSCode + Copilot client config
├── scripts/
│   ├── sync-config.sh            # cp config.json → ~/.claude-code-router/
│   └── install.sh                # one-shot global installs
├── package.json                  # deps: express, dotenv (no @musistudio/llms)
├── .env                          # COPILOT_CHAT_TOKEN, tier models, ports, quota
└── ROADMAP_2A.md                 # Phase 2A feature roadmap (moved from gatekeeper-router)
```

## Config Change Workflow

Edits to `config.json` in this project do NOT auto-propagate to CCR. Manual sync required:

```bash
./scripts/sync-config.sh   # cp config.json → ~/.claude-code-router/config.json
ccr stop && ccr start       # restart CCR to pick up new config
```

## Key Design Decisions

- **No `@musistudio/llms` dependency** — CCR v2.0.0 is global; this project has `express` + `dotenv` only.
- **`CUSTOM_ROUTER_PATH`** — CCR v2 native feature; classifies per request with zero LLM calls.
- **Sidecar, not middleware** — quota + dashboard run as a separate process; no interception of request flow.
- **Quota-guard is soft-warn only** — `CUSTOM_ROUTER_PATH` cannot reject requests in CCR v2, only pick a provider.
- **Config copy, not symlink** — decision for clarity and portability; `sync-config.sh` re-deploys.
- **Shared quota log** — `~/.gatekeeper/quota.log` is shared with Option 1 (`gatekeeper-router`); `ai-quota` aggregates both.

## ToS Note

Uses the Copilot Chat API from a custom client (same pattern as `aider`, `copilot.vim`). Personal use only.
