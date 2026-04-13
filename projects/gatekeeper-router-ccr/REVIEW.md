# Phase 4 Review — gatekeeper-router-ccr

**Date:** 2026-04-12
**Reviewer:** Claude Code (post-redo, pre-live-verification)
**Verdict:** SHIP (pending live boot test by user)

---

## Files Reviewed

| File | Lines | Issues |
|---|---|---|
| `custom-router.js` | 102 | None |
| `plugins/copilot-transformer.js` | 64 | None |
| `plugins/ghu-exchanger.js` | 44 | None |
| `plugins/quota-guard.js` | 46 | None |
| `sidecar-dashboard.js` | 105 | None |
| `config.json` | 48 | None |
| `public/dashboard.html` | 155 | None |

---

## Checklist Results

### Dead code / unused imports
- No dead code found. All imports in `sidecar-dashboard.js` are used.
- `copilot-transformer.js` imports only `ghu-exchanger.js` — used in both `auth()` and `transformRequestIn()`.

### Hardcoded paths
- `config.json` contains two absolute paths (`CUSTOM_ROUTER_PATH` and transformer `path`) — these are **required** by CCR v2 and documented in `CLAUDE.md`.
- All other JS files use `os.homedir()`, `path.join(__dirname, ...)`, or `process.env.*` — no hardcoded paths.

### SBOM / README port table
- All 5 ports (`:3000`, `:3001`, `:3002`, `:5577`, `:5578`) documented in both `CLAUDE.md` and `README.md`. ✓

### Mermaid diagram vs custom-router.js
- `docs/classifier-flow.md` Mermaid matches the actual decision tree in `custom-router.js`. ✓
- PREMIUM keyword list in the table matches source. ✓

### vscode-setup.md accuracy
- Startup flow matches `aic-start` function in `~/.zshrc`. ✓
- Distinction between Claude Code traffic and VSCode Copilot extension is explicitly stated. ✓

### Config.json schema
- Capital-P `Providers` ✓
- `CUSTOM_ROUTER_PATH` with absolute path ✓
- Env interpolation via `$VAR` syntax ✓
- All three providers (`copilot-economy`, `copilot-balanced`, `copilot-premium`) present ✓
- `Router.default` set to BALANCED ✓

### custom-router.js invariants
- Default returns `'BALANCED'` (safe 0x fallback) ✓
- All force flags read from `allConfig` (not process.env directly) ✓
- `[Classifier]` log line emitted for every classified request ✓

### copilot-transformer.js
- `name = 'CopilotAuth'` matches `Providers[].transformer.use: ['CopilotAuth']` in config.json ✓
- Both `auth()` (bypass path) and `transformRequestIn()` (chain path) implemented ✓

### sidecar-dashboard.js
- Read-only: no middleware that intercepts/modifies request flow ✓
- `app.use(express.static(...))` only serves `public/dashboard.html` ✓
- Three endpoints: `GET /`, `GET /v1/session-status`, `GET /v1/metrics` ✓

---

## Phase 3 Live Verification Results (2026-04-12)

All 11 tests passed after 3 runtime fixes (see commit `977d867`):

| Test | Result | Notes |
|---|---|---|
| 11.1 versions | ✓ | CCR 2.0.0, ccxray 1.2.2 |
| 11.2 config load | ✓ | `ccr status` no warnings |
| 11.3 npm check | ✓ | OK |
| 11.4 boot coexistence | ✓ | ai-start (:3000) + aic-start (:3001/:3002) |
| 11.5 /v1/metrics | ✓ | `quota_used=26.5, quota_pct=9` |
| 11.6 /v1/session-status | ✓ | all 3 tiers, correct models |
| 11.7 ECONOMY probe | ✓ | `gpt-5-mini` in response |
| 11.8 BALANCED short | ✓ | `gemini-3-flash-preview` in response |
| 11.9 BALANCED code block | ✓ | `gemini-3-flash-preview` in response |
| 11.10 PREMIUM keyword (GPL) | ✓ | `Claude Sonnet 4.6` in response |
| 11.11 PREMIUM CP checkpoint | ✓ | `Claude Sonnet 4.6` in response |
| 11.12 ccxray dashboard | ✓ | :5578 serving requests |
| 11.13 sidecar tier counts | ✓ | E:2 B:2 P:2 after probes |
| 11.14 quota log shared | ✓ | `~/.gatekeeper/quota.log` has +0x/+1x entries |
| 11.15 clean shutdown | ✓ | no stray processes |

### Runtime fixes applied
1. `custom-router.js`: use `process.env.*` for model/flag reads (CCR v2 doesn't interpolate `$VAR` in allConfig)
2. `config.json`: hardcode model names in `Providers[].models[]` (arrays don't get `$VAR` expansion)
3. `sidecar-dashboard.js`: read `/tmp/ccr.log` for `[Classifier]` lines (CCR logs go to stdout, not to log file)
4. `~/.zshrc aic-start`: use `ANTHROPIC_TEST_HOST/PORT/PROTOCOL` env vars to point ccxray at CCR HTTP (no `--upstream` flag in ccxray 1.2.2)

### Note on x-tier headers
CCR v2's `CUSTOM_ROUTER_PATH` can only return `"provider,model"` — it cannot inject response headers.
Tier is verified via the response body `model` field + `[Classifier] tier=...` lines in `/tmp/ccr.log`.

---

## Verdict

**SHIP** — all static and live verification tests pass.
