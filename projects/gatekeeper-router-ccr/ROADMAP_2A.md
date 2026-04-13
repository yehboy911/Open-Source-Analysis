# ROADMAP 2A — `claude-code-router` v2.0.0 Integration

**Status:** DRAFT / PLANNING ONLY
**Target Session:** Next (NOT current)
**Baseline:** Option 1 (`server.js` at 679 lines, MODE-C v2 3-tier, merged this session)
**Upstream:** https://github.com/musistudio/claude-code-router/tree/v2.0.0

> **Separation rule:** No line of Option 2A logic is allowed to bleed into `server.js` during the current session. This document is a blueprint for a future branch (`feature/ccr-v2-integration`), not an implementation plan for today.

---

## 0. Why 2A exists

Option 1 is a hand-rolled Express proxy. It works, it's ~680 lines, it has no external routing dependency, and it's production-ready for single-user Copilot Chat proxying. However, three forces push toward `claude-code-router` v2.0.0 adoption in the next phase:

1. **Community parity** — `claude-code-router` has become the de-facto open-source standard for routing Claude Code across multiple backends (Copilot, OpenRouter, DeepSeek, Ollama, etc.). Owen's work increasingly touches multi-backend scenarios (firmware compliance evidence from different vendors, cross-platform SBOM audits).
2. **Transformer ecosystem** — v2.0.0 ships with built-in format transformers (Anthropic ↔ OpenAI, tool-call normalization, streaming SSE) that are **more battle-tested** than our `anthropicToOpenAI` / `openAIToAnthropic` pair. Any edge case they fix upstream is free for us.
3. **Declarative config** — v2.0.0 uses a JSON/YAML config to define providers, routes, and transformers. This eliminates keyword classifiers hardcoded in JavaScript and lets non-programmers tune routing.

**2A is NOT about replacing Copilot.** Copilot Chat remains the primary (and only) inference backend. 2A is about replacing the *transport and routing plumbing* between Claude Code CLI and Copilot Chat API.

---

## 1. Goals

- **G1.** Adopt `claude-code-router` v2.0.0 as the core proxy, retire our hand-rolled Express handlers for `/v1/messages` and format translation.
- **G2.** Preserve the 3-tier intelligence hierarchy (Economy / Balanced / Premium) as a claude-code-router **Router plugin** or **config-driven rule set**.
- **G3.** Preserve 100% of Option 1's observability surface: `x-tier`, `x-system-prompt`, `x-session-tokens`, `x-session-warn`, `x-quota-month`, `[ROUTE]` log lines, and the `GET /v1/session-status` endpoint.
- **G4.** Preserve the quota guard (`~/.gatekeeper/quota.log`) and the `ai-quota` alias without format changes — users have months of history in that file.
- **G5.** Maintain a clean migration path: `git checkout` between Option 1 and Option 2A branches should require zero `.env` changes.

## 2. Non-Goals

- **NG1.** NOT switching to multi-backend routing (Copilot stays the only provider — ToS boundary).
- **NG2.** NOT replacing the Copilot session-token exchange helper. `claude-code-router` does not natively handle `ghu_` → session-token exchange; we keep that logic.
- **NG3.** NOT introducing a database. Quota log stays file-based.
- **NG4.** NOT adding authentication / multi-user support to the gateway.

---

## 3. Phase 0 — Prerequisites (must complete BEFORE any coding)

This phase is pure research. It produces a `PHASE0_REPORT.md` and nothing else.

| Task | Deliverable | Why |
|---|---|---|
| P0.1 Clone `claude-code-router` v2.0.0 locally | `~/work/ccr-v2.0.0/` | Read-only reference |
| P0.2 Identify the config schema | `PHASE0_REPORT.md § config` | Know whether v2.0.0 uses JSON or YAML, and the keys for providers / routes / transformers |
| P0.3 Identify the plugin API for custom routers | `PHASE0_REPORT.md § plugins` | Know whether our 3-tier classifier can be expressed as a JS plugin file or must live as external logic |
| P0.4 Identify the session-token / auth extension points | `PHASE0_REPORT.md § auth` | Know where to inject our `getCopilotSessionToken()` helper |
| P0.5 Identify SSE streaming & transformer chain | `PHASE0_REPORT.md § transformers` | Confirm Anthropic ↔ OpenAI translation is handled natively, so we can retire our implementation |
| P0.6 Identify response-header extension points | `PHASE0_REPORT.md § middleware` | Know where to inject `x-tier`, `x-system-prompt`, `x-session-*` headers |
| P0.7 Identify logging hooks | `PHASE0_REPORT.md § logging` | Know where to emit our `[ROUTE]` log lines |

**Gate:** Phase 0 is a go/no-go decision. If `claude-code-router` v2.0.0 cannot accommodate any of P0.4, P0.6, or P0.7 cleanly, we fall back to **Option 2B** (keep Express, adopt only the transformers as an npm dep — see §8).

---

## 4. Proposed Architecture (post-2A)

```
Claude Code CLI
  → ccxray :5577  (observability proxy)
  → claude-code-router v2.0.0 :3000
     │
     ├── config.json
     │     providers:
     │       copilot-economy:  { url: …, model: gpt-5-mini,             auth: ghu-exchanger }
     │       copilot-balanced: { url: …, model: gemini-3-flash-preview, auth: ghu-exchanger }
     │       copilot-premium:  { url: …, model: claude-sonnet-4.6,      auth: ghu-exchanger }
     │     routers:
     │       - { name: tier-classifier, handler: ./plugins/tier-classifier.js }
     │     transformers: [ anthropic ↔ openai (built-in) ]
     │
     ├── plugins/tier-classifier.js   ← our 3-tier logic as a plugin
     ├── plugins/ghu-exchanger.js     ← session-token exchange helper
     ├── plugins/observability.js     ← response-header injector + [ROUTE] logger
     └── plugins/quota-guard.js       ← pre-request quota check + post-request log append
  → Copilot Chat API
```

**Key insight:** every piece of Option 1 becomes either a config entry or a plugin file. Nothing is lost; the shape changes from "one 680-line Express file" to "one 50-line entry + five focused plugin files."

---

## 5. Phase Plan

### Phase 1 — Skeleton (no behavior change yet)
1. Create branch `feature/ccr-v2-integration`
2. `npm install @musistudio/claude-code-router@2.0.0` (exact version pin)
3. Scaffold `config.json` with three Copilot providers and a stub classifier plugin that always returns `BALANCED`
4. Wire `ai-start` alias to launch `claude-code-router` instead of `node server.js`
5. Smoke test: Claude Code CLI → 1 request → BALANCED → Copilot → response
6. **Gate:** `GET /v1/session-status` may break temporarily; documented and accepted for Phase 1 only

### Phase 2 — Port classifier
1. Move `PREMIUM_KEYWORDS`, `BALANCED_KEYWORDS`, `ECONOMY_KEYWORDS`, `CP_CHECKPOINT_RE` into `plugins/tier-classifier.js`
2. Re-run the 15-probe regression harness against the plugin-hosted classifier (reuse `classifier_probes.js`)
3. **Gate:** 15/15 probes must pass before Phase 3 starts

### Phase 3 — Port auth + quota
1. Move `getCopilotSessionToken()` → `plugins/ghu-exchanger.js`
2. Move `monthTotal()` / `appendQuotaLog()` / `quotaMultiplierFor()` → `plugins/quota-guard.js`
3. Verify `ai-quota` alias still reads the same log file format
4. **Gate:** one month of quota history must still parse and aggregate correctly

### Phase 4 — Port observability
1. Move `setRoutingHeaders()` + `systemPromptHash()` → `plugins/observability.js`
2. Re-implement `GET /v1/session-status` as a `claude-code-router` custom route
3. Verify ccxray dashboard shows `x-tier` / `x-system-prompt` / `x-session-tokens`
4. **Gate:** header parity test (curl `-D -` diff against Option 1 baseline) must match

### Phase 5 — Decommission
1. Delete `server.js`
2. Update `CLAUDE.md` architecture section to reference `claude-code-router` v2.0.0
3. Keep `ROADMAP_2A.md` as historical record; add `CHANGELOG.md` noting the Option 1 → 2A transition
4. Merge `feature/ccr-v2-integration` → `main`

---

## 6. Potential Breaking Changes vs Option 1

| Change | User Impact | Mitigation |
|---|---|---|
| `server.js` deleted | `npm run check` command needs new script | Update `package.json` scripts to `claude-code-router check` |
| Route config moves from `.env` to `config.json` | Users must learn the new config file | Keep `.env` as a shim that `claude-code-router` reads for Copilot credentials |
| Custom env vars (`FORCE_PREMIUM`, `SESSION_TOKEN_CAP`) | May need to be re-introduced as config.json keys | Document mapping in `CHANGELOG.md` |
| In-memory session counter semantics | If `claude-code-router` workers restart mid-session, counter resets more often | Acceptable — already documented as best-effort in Option 1 |
| Log line format (`[ROUTE] tier=…`) | `ail` grep patterns may break | Reimplement the exact format in the observability plugin |
| Response header names | ccxray dashboard filters may break | Keep identical header names; this is the single strongest contract |
| Error HTTP codes (503 on quota exhaustion) | Client-visible | Match exactly in quota-guard plugin |

---

## 7. Risk Register

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| `claude-code-router` v2.0.0 plugin API cannot express our 3-tier classifier | Medium | High | Phase 0 gate; fall back to Option 2B if blocked |
| `claude-code-router` v2.0.0 does not expose response-header injection hooks | Medium | High | Phase 0 gate; reverse-proxy pattern as last resort (Option 2C, §8) |
| Session-token exchange incompatible with plugin lifecycle | Low | Medium | Keep an Express sidecar on :3001 that handles auth, proxy the rest |
| `ghu_` token exchange breaks if `claude-code-router` upstream changes the auth interface | Low | High | Pin version exactly; track upstream releases via quarterly audit |
| New ToS surface — `claude-code-router` is a third-party intermediary on the `ghu_` path | Low | High | Document in CLAUDE.md; reconfirm personal-use-only policy |
| ccxray filters by `x-complexity` break after rename | Low | Low | Keep `x-complexity` as back-compat alias of `x-tier` (Option 1 already does this) |
| Regression: streaming SSE differs from Option 1 in event ordering | Medium | Medium | Compare live streams byte-by-byte between branches before Phase 5 cutover |
| Pull request churn blocks Owen's daily work | Medium | Medium | 2A lives entirely on a feature branch; `main` keeps Option 1 until the cutover commit |

---

## 8. Alternatives Considered

### Option 2B — Adopt transformers only (lightweight)

Install `@musistudio/claude-code-router` as a library, import only its Anthropic ↔ OpenAI transformer module, keep our Express server otherwise untouched.

- **Pros:** Very small diff; we get upstream transformer bug-fixes for free; no config-file migration
- **Cons:** We stay on an unmaintained hand-rolled proxy long-term; doesn't align with the "community parity" goal
- **When to pick:** If Phase 0 reveals that v2.0.0's plugin API is immature or poorly documented

### Option 2C — Reverse-proxy sidecar

Run `claude-code-router` v2.0.0 on port :3001, keep Option 1's `server.js` on :3000 as a thin reverse proxy that injects our observability headers and forwards to :3001.

- **Pros:** 100% preserves observability contract even if `claude-code-router` has no header hooks
- **Cons:** Two processes to manage; two sources of truth for routing
- **When to pick:** If Phase 0 reveals no header-injection mechanism in `claude-code-router` v2.0.0

### Option 2D — Stay on Option 1 indefinitely

- **Pros:** Zero risk; already production-ready
- **Cons:** Falls behind community tooling; Owen must maintain a bespoke classifier
- **When to pick:** If Phase 0 reveals Copilot Chat ToS risks from third-party routers, or if Owen's usage patterns diverge from `claude-code-router`'s design assumptions

---

## 9. Decision Log (prefilled for Phase 0 review)

| Decision | Default | Override Trigger |
|---|---|---|
| Config format | JSON (over YAML) | `claude-code-router` v2.0.0 mandates YAML |
| Plugin language | JavaScript | `claude-code-router` plugin API requires TypeScript |
| Header-injection mechanism | Plugin middleware | Only Express middleware is supported → Option 2C |
| Cutover strategy | Feature branch + explicit merge | `main` must stay shippable → branch-per-phase |

---

## 10. Explicit Out-of-Scope for This Session

The following MUST NOT happen in the current session, even as a sketch:

- [ ] Do NOT `npm install @musistudio/claude-code-router`
- [ ] Do NOT create `config.json` for `claude-code-router`
- [ ] Do NOT create any `plugins/*.js` files
- [ ] Do NOT touch `server.js` (Option 1 is frozen)
- [ ] Do NOT touch `package.json` dependencies
- [ ] Do NOT create a `feature/ccr-v2-integration` branch
- [ ] Do NOT modify `.env` or `~/.zshrc` aliases

Only `ROADMAP_2A.md` (this file) is produced.

---

## 11. Compositional Audit of Option 1 (proof 2A is achievable without rewrite)

This section demonstrates that Option 1's `server.js` already has clean seams for 2A extraction. For each planned plugin, the source location and purity status are listed.

| 2A Plugin | Option 1 Source | Purity | Extraction Effort |
|---|---|---|---|
| `tier-classifier` | `server.js` L142–228 (`PREMIUM_KEYWORDS`, `BALANCED_KEYWORDS`, `ECONOMY_KEYWORDS`, `CP_CHECKPOINT_RE`, `extractClassifierText`, `hasStructuralTools`, `matchAny`, `classifyRequest`, `selectModel`, `MODEL_BY_TIER`) | **100% pure** — no I/O, no globals, no mutation | Trivial — copy + `module.exports` |
| `ghu-exchanger` | `server.js` L54–104 (`getCopilotSessionToken`, `copilotChatHeaders`, `_sessionToken`, `_sessionExpires`) | Stateful but self-contained — only touches two module-level vars | Moderate — wrap state in a class or closure |
| `quota-guard` | `server.js` L106–140 (`monthTotal`, `appendQuotaLog`, `quotaMultiplierFor`) | **100% pure for `monthTotal` + `quotaMultiplierFor`**; `appendQuotaLog` does append-only I/O | Trivial — file path is a constant, easy to parameterize |
| `observability` | `server.js` L248–260 (`systemPromptHash`, `sessionTotal`, `sessionFraction`) + L501–514 (`setRoutingHeaders`) | **100% pure for hash**; header setter touches res only, no globals | Trivial |
| `format-translator` | `server.js` L278–396 (`anthropicToOpenAI`, `openAIToAnthropic`) | **100% pure** | **NOT extracted — retired in favor of upstream transformer** |
| `sse-streaming` | `server.js` L398–499 (`pipeStreamingResponse`) | Touches res, reads from copilotResp.body | **NOT extracted — retired in favor of upstream transformer** |

**Conclusion:** Every component we intend to keep is already a pure or near-pure function. There is **no hidden coupling** between the classifier, the quota guard, and the observability layer. The 2A migration is a packaging exercise, not a rewrite.

**Red flags to monitor (none found in Option 1 as of this session):**
- ❌ Classifier mutating `body` → would prevent caching
- ❌ Quota guard reading from request-scoped state → would prevent parallelization
- ❌ Observability headers computed from classifier internals → would prevent plugin boundary
- ❌ Session token state shared between `routeToCopilot` and `selectModel` → would prevent independent testing

All four are **absent** in Option 1. ✅ Option 1 is 2A-ready.

---

## 12. Next Session Bootstrap

When resuming to start 2A:

```bash
# 1. Branch
git checkout -b feature/ccr-v2-integration

# 2. Phase 0 research (produces /tmp/ctx-ccr-v2/PHASE0_REPORT.md)
mkdir -p /tmp/ctx-ccr-v2
git clone --depth 1 --branch v2.0.0 \
    https://github.com/musistudio/claude-code-router.git /tmp/ctx-ccr-v2/ccr

# 3. Read these files first (priority order)
ls /tmp/ctx-ccr-v2/ccr/README.md
ls /tmp/ctx-ccr-v2/ccr/src/
ls /tmp/ctx-ccr-v2/ccr/config.example.*

# 4. Reuse the regression harness — do NOT rewrite it
cp /tmp/ctx-gatekeeper/classifier_probes.js /tmp/ctx-ccr-v2/
```

Do not touch `server.js` until Phase 0 is green.

---

## 繁體中文摘要

- **本文件僅為規劃藍圖，不觸動 Option 1 程式碼。**
- **Phase 0 必做：** Clone `claude-code-router` v2.0.0，搞清楚它的 config schema、plugin API、auth 擴充點、SSE transformer、header injection 機制，寫成 `PHASE0_REPORT.md`。Phase 0 是 go/no-go 決策點。
- **計畫路徑：** 5 個 Phase，從 skeleton → port classifier → port auth/quota → port observability → decommission Option 1。
- **關鍵觀察（§11 組合式稽核）：** Option 1 的每一個要保留的模組都是純函數或自封閉狀態，沒有隱藏耦合。從 Option 1 遷移到 2A 是「打包練習」而不是「重寫」。
- **Fallback 策略：** 若 Phase 0 發現 `claude-code-router` v2.0.0 無法容納我們的觀測需求，有 Option 2B（只用 transformer 作為 lib）與 Option 2C（反向代理 sidecar）兩條退路。
- **本 session 絕對不做：** 不 install 套件、不建 config.json、不建 plugins/*.js、不碰 server.js、不建新分支。僅產出本文件。
