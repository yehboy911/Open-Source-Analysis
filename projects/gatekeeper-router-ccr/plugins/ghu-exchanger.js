// plugins/ghu-exchanger.js
// Exchanges a GitHub ghu_ token for a short-lived Copilot session token.
// Self-contained module with in-memory cache. Import from copilot-transformer.js.

const TOKEN_EXCHANGE_URL = 'https://api.github.com/copilot_internal/v2/token';

let _sessionToken   = null;
let _sessionExpires = 0; // Unix ms

async function getCopilotSessionToken(ghuToken) {
  const nowMs     = Date.now();
  const refreshAt = _sessionExpires - 5 * 60 * 1000; // refresh 5 min before expiry

  if (_sessionToken && nowMs < refreshAt) {
    return _sessionToken;
  }

  const resp = await fetch(TOKEN_EXCHANGE_URL, {
    method:  'GET',
    headers: {
      'Authorization':          `token ${ghuToken}`,
      'Accept':                 'application/json',
      'Editor-Version':         'vscode/1.95.0',
      'Editor-Plugin-Version':  'copilot-chat/0.20.0',
      'User-Agent':             'GitHubCopilotChat/0.20.0',
      'Copilot-Integration-Id': 'vscode-chat',
    },
  });

  if (!resp.ok) {
    const body = await resp.text().catch(() => '');
    throw new Error(`[GhuExchanger] Token exchange failed ${resp.status}: ${body}`);
  }

  const data = await resp.json();
  if (!data.token) throw new Error('[GhuExchanger] Token exchange returned no token');

  _sessionToken   = data.token;
  _sessionExpires = (data.expires_at || (Math.floor(Date.now() / 1000) + 1800)) * 1000;
  console.log(`[GhuExchanger] Session token refreshed, expires ${new Date(_sessionExpires).toISOString()}`);
  return _sessionToken;
}

module.exports = { getCopilotSessionToken };
