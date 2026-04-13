// custom-router.js  (CUSTOM_ROUTER_PATH target for CCR v2.0.0)
// 3-tier domain classifier for firmware/OSC work.
//
// CCR v2 signature:
//   module.exports = async function(req, allConfig, context) → "provider,model" | null
//
// allConfig is the loaded config.json object with env vars already interpolated.
// Reads: allConfig.MODEL_ECONOMY/MODEL_BALANCED/MODEL_PREMIUM, FORCE_PREMIUM, FORCE_ECONOMY, CLASSIFIER_ENABLED
//
// Tiers:
//   PREMIUM  → claude-sonnet-4.6        (1x) — OSC legal, architecture, deep debug
//   BALANCED → gemini-3-flash-preview   (0x) — daily driver (default)
//   ECONOMY  → gpt-5-mini              (0x) — quick lookups, janitor

// ── Keyword tables ────────────────────────────────────────────────────────────
const PREMIUM_KEYWORDS = [
  'gpl', 'lgpl', 'agpl', 'copyleft', 'derivative work',
  'license conflict', 'bison exception', 'legal review',
  'osc-evidence', 'oss-compliance', 'sbom conflict',
  'security audit', 'threat model', 'cve-', 'vulnerability',
  'architectural decision', 'architecture review',
  'deadlock', 'race condition', 'memory leak', 'use-after-free',
];
const BALANCED_KEYWORDS = [
  'unit test', 'pytest', 'test coverage', 'tdd',
  'sha256', 'hash match', 'cross-file',
  'cmakelists', 'dependency graph', 'sbom',
  'refactor', 'implement', 'generate',
];
const ECONOMY_KEYWORDS = [
  'what is', 'quick question', 'health check', 'ping',
  'list files', 'show me', 'format this', 'rename',
];
const CP_CHECKPOINT_RE = /\bcp-\d{1,2}\b/;

// ── Helpers ───────────────────────────────────────────────────────────────────
function extractClassifierText(body) {
  const msgs = body.messages || [];
  const systemText = Array.isArray(body.system)
    ? body.system.map(b => b.text || '').join(' ')
    : (typeof body.system === 'string' ? body.system : '');
  const lastUserMsg = [...msgs].reverse().find(m => m.role === 'user');
  const lastText = typeof lastUserMsg?.content === 'string'
    ? lastUserMsg.content
    : [].concat(lastUserMsg?.content || []).map(b => b.text || '').join(' ');
  return { fullText: (systemText + ' ' + lastText).toLowerCase(), lastText, msgCount: msgs.length };
}

function hasStructuralTools(body) {
  const msgs = body.messages || [];
  if ((body.tools || []).length > 0) return false;
  return msgs.some(m => [].concat(m.content || []).some(
    b => b && (b.type === 'tool_use' || b.type === 'tool_result')
  ));
}

function matchAny(text, keywords) {
  return keywords.some(k => text.includes(k));
}

function classifyRequest(body) {
  const { fullText, lastText, msgCount } = extractClassifierText(body);

  if (matchAny(fullText, PREMIUM_KEYWORDS)) return 'PREMIUM';
  if (CP_CHECKPOINT_RE.test(fullText))      return 'PREMIUM';

  if (/```|<code/i.test(lastText))            return 'BALANCED';
  if (lastText.length > 1500 || msgCount > 5) return 'BALANCED';

  if (hasStructuralTools(body))              return 'BALANCED';
  if (matchAny(fullText, BALANCED_KEYWORDS)) return 'BALANCED';

  if (lastText.length < 200 && matchAny(fullText, ECONOMY_KEYWORDS)) return 'ECONOMY';

  return 'BALANCED'; // safe 0x default
}

// ── Router entry point ────────────────────────────────────────────────────────
module.exports = async function tierClassifier(req, allConfig) {
  const body = req.body;
  if (!body) return null;

  // Read booleans from process.env (resolved) with allConfig as fallback
  const rawForcePremium = process.env.FORCE_PREMIUM  ?? allConfig.FORCE_PREMIUM;
  const rawForceEconomy = process.env.FORCE_ECONOMY  ?? allConfig.FORCE_ECONOMY;
  const rawClassifier   = process.env.CLASSIFIER_ENABLED ?? allConfig.CLASSIFIER_ENABLED;
  const forcePremium = rawForcePremium === 'true' || rawForcePremium === true;
  const forceEconomy = rawForceEconomy === 'true' || rawForceEconomy === true;

  let tier;
  if (forcePremium)       tier = 'PREMIUM';
  else if (forceEconomy)  tier = 'ECONOMY';
  else if (rawClassifier === false || rawClassifier === 'false')
    tier = 'BALANCED';
  else                    tier = classifyRequest(body);

  // Prefer process.env over allConfig — CCR v2 does not interpolate $VAR in config fields
  // passed to the custom router; process.env is already resolved by dotenv at startup.
  const modelPremium  = process.env.COPILOT_MODEL_PREMIUM  || allConfig.MODEL_PREMIUM  || 'claude-sonnet-4.6';
  const modelBalanced = process.env.COPILOT_MODEL_BALANCED || allConfig.MODEL_BALANCED || 'gemini-3-flash-preview';
  const modelEconomy  = process.env.COPILOT_MODEL_ECONOMY  || allConfig.MODEL_ECONOMY  || 'gpt-5-mini';

  const tierMap = {
    PREMIUM:  `copilot-premium,${modelPremium}`,
    BALANCED: `copilot-balanced,${modelBalanced}`,
    ECONOMY:  `copilot-economy,${modelEconomy}`,
  };

  const result = tierMap[tier];
  console.log(`[Classifier] tier=${tier} → ${result}`);
  return result;
};
