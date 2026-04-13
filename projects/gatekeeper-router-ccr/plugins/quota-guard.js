// plugins/quota-guard.js
// Quota tracking: append-only monthly log at ~/.gatekeeper/quota.log.
// Pure functions — no globals, no I/O side effects except appendQuotaLog.

const fs   = require('fs');
const path = require('path');
const os   = require('os');

const QUOTA_LOG = path.join(os.homedir(), '.gatekeeper', 'quota.log');

function monthTotal() {
  if (!fs.existsSync(QUOTA_LOG)) return 0;
  const content = fs.readFileSync(QUOTA_LOG, 'utf8');
  const now     = new Date();
  const year    = now.getUTCFullYear();
  const month   = now.getUTCMonth();
  let total     = 0;
  for (const line of content.split('\n')) {
    const m = line.match(/^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z?)\] \+(\d+(?:\.\d+)?)x /);
    if (!m) continue;
    const d = new Date(m[1]);
    if (d.getUTCFullYear() === year && d.getUTCMonth() === month) {
      total += parseFloat(m[2]);
    }
  }
  return total;
}

function appendQuotaLog(multiplier, model) {
  const dir = path.dirname(QUOTA_LOG);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const ts   = new Date().toISOString().replace(/\.\d{3}/, '');
  const line = `[${ts}] +${multiplier}x ${model}\n`;
  fs.appendFileSync(QUOTA_LOG, line, 'utf8');
}

function quotaMultiplierFor(model) {
  if (!model) return 0.9;
  const m = model.toLowerCase();
  if (m.includes('gpt-5-mini') || m.includes('gemini-3-flash') || m.includes('grok-code-fast')) return 0;
  if (m.includes('claude-sonnet') || m.includes('claude sonnet') || m.includes('gpt-5.1') || m.includes('gpt-5.2')) return 1;
  if (m.includes('claude-opus') || m.includes('claude opus') || m.includes('gpt-5.4')) return 3;
  return 0.9;
}

module.exports = { monthTotal, appendQuotaLog, quotaMultiplierFor };
