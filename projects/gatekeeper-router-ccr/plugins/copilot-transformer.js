// plugins/copilot-transformer.js
// CCR v2.0.0 custom transformer for GitHub Copilot Chat API.
//
// Responsibilities:
//   • auth()           — exchanges ghu_ token for short-lived session Bearer token
//   • transformRequestIn() — injects Copilot-specific HTTP headers required by the API
//
// CCR lifecycle:
//   processRequestTransformers → auth() (bypass path) OR transformRequestIn() (non-bypass)
//   For a single-transformer provider (bypass=true), auth() is used.
//   For a multi-transformer chain (bypass=false), transformRequestIn() handles auth.
//   We implement BOTH so this transformer is safe in either config.
//
// Registration: listed in config.json under transformers[].path and
//   referenced by name in Providers[].transformer.use = ['CopilotAuth']

const { getCopilotSessionToken } = require('./ghu-exchanger');

const COPILOT_EXTRA_HEADERS = {
  'Editor-Version':         'vscode/1.95.0',
  'Editor-Plugin-Version':  'copilot-chat/0.20.0',
  'User-Agent':             'GitHubCopilotChat/0.20.0',
  'Copilot-Integration-Id': 'vscode-chat',
};

// Claude Code sends dash-separated model IDs; Copilot requires dot-separated.
// Also strips date suffixes (e.g. -20251001).
const MODEL_MAP = {
  'claude-sonnet-4-6':           'claude-sonnet-4.6',
  'claude-sonnet-4-5':           'claude-sonnet-4.5',
  'claude-sonnet-4':             'claude-sonnet-4',
  'claude-haiku-4-5':            'claude-haiku-4.5',
  'claude-haiku-4-5-20251001':   'claude-haiku-4.5',
  'claude-opus-4-6':             'claude-opus-4.6',
  'claude-opus-4-5':             'claude-opus-4.5',
  'claude-3-5-sonnet':           'claude-sonnet-4.5',
};

function normalizeModel(model) {
  if (!model) return model;
  if (MODEL_MAP[model]) return MODEL_MAP[model];
  // Generic: replace trailing date suffix, then last dash-number to dot-number
  return model.replace(/-\d{8}$/, '').replace(/-(\d)$/, '.$1');
}

class CopilotAuthTransformer {
  // Name must match the string used in provider.transformer.use array
  name = 'CopilotAuth';

  // ── bypass path (single-transformer provider) ─────────────────────────────
  async auth(requestBody, provider) {
    const ghuToken = provider.apiKey;
    const sessionToken = await getCopilotSessionToken(ghuToken);
    const body = requestBody && requestBody.model
      ? { ...requestBody, model: normalizeModel(requestBody.model) }
      : requestBody;
    return {
      body,
      config: {
        headers: {
          Authorization: `Bearer ${sessionToken}`,
          ...COPILOT_EXTRA_HEADERS,
        },
      },
    };
  }

  // ── non-bypass path (multi-transformer chain) ─────────────────────────────
  async transformRequestIn(request, provider, context) {
    const ghuToken     = provider.apiKey;
    const sessionToken = await getCopilotSessionToken(ghuToken);

    if (context) context._copilotSessionToken = sessionToken;

    const body = request && request.model
      ? { ...request, model: normalizeModel(request.model) }
      : request;
    return {
      body,
      config: {
        headers: {
          Authorization: `Bearer ${sessionToken}`,
          ...COPILOT_EXTRA_HEADERS,
        },
      },
    };
  }
}

module.exports = CopilotAuthTransformer;
