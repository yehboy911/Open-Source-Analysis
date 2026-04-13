// sidecar-dashboard.js
// Read-only Express sidecar on SIDECAR_PORT (default :3002).
// Does NOT intercept or modify request flow — tails log files only.
//
// Endpoints:
//   GET /                   → serves public/dashboard.html
//   GET /v1/session-status  → JSON session summary (compatible with Option 1 shape)
//   GET /v1/metrics         → JSON: quota_used, quota_limit, daily_burn[7], tier_distribution

require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const express = require('express');
const fs      = require('fs');
const path    = require('path');
const os      = require('os');

const { monthTotal } = require('./plugins/quota-guard');

const app          = express();
const SIDECAR_PORT = parseInt(process.env.SIDECAR_PORT || '3002', 10);
const QUOTA_LIMIT  = parseInt(process.env.QUOTA_MONTHLY_LIMIT || '300', 10);
// CCR stdout is captured to /tmp/ccr.log by aic-start; that file has our [Classifier] lines.
// Fallback: look for [Classifier] lines in the CCR JSON log directory.
const CCR_LOG      = process.env.CCR_STDOUT_LOG || '/tmp/ccr.log';
const QUOTA_LOG    = path.join(os.homedir(), '.gatekeeper', 'quota.log');

// ── Log parsers ───────────────────────────────────────────────────────────────

function readLastLines(filePath, n) {
  if (!fs.existsSync(filePath)) return [];
  const content = fs.readFileSync(filePath, 'utf8');
  const lines   = content.split('\n').filter(Boolean);
  return lines.slice(-n);
}

function parseTierDistribution(lines) {
  const counts = { ECONOMY: 0, BALANCED: 0, PREMIUM: 0 };
  for (const line of lines) {
    const m = line.match(/\[Classifier\] tier=(ECONOMY|BALANCED|PREMIUM)/);
    if (m) counts[m[1]]++;
  }
  return counts;
}

function parseDailyBurn(filePath, days) {
  const result = new Array(days).fill(0);
  if (!fs.existsSync(filePath)) return result;
  const now     = Date.now();
  const MS_DAY  = 86400000;
  const content = fs.readFileSync(filePath, 'utf8');
  for (const line of content.split('\n')) {
    const m = line.match(/^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z?)\] \+(\d+(?:\.\d+)?)x /);
    if (!m) continue;
    const age  = (now - new Date(m[1]).getTime()) / MS_DAY;
    const slot = Math.floor(age);
    if (slot >= 0 && slot < days) result[days - 1 - slot] += parseFloat(m[2]);
  }
  return result;
}

// ── Routes ────────────────────────────────────────────────────────────────────

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'dashboard.html'));
});

app.get('/v1/metrics', (_req, res) => {
  const ccrLines        = readLastLines(CCR_LOG, 500);
  const tierDistribution = parseTierDistribution(ccrLines);
  const dailyBurn       = parseDailyBurn(QUOTA_LOG, 7);
  const quotaUsed       = monthTotal();

  res.json({
    quota_used:        quotaUsed,
    quota_limit:       QUOTA_LIMIT,
    quota_pct:         QUOTA_LIMIT > 0 ? Math.round((quotaUsed / QUOTA_LIMIT) * 100) : 0,
    daily_burn:        dailyBurn,
    tier_distribution: tierDistribution,
  });
});

app.get('/v1/session-status', (_req, res) => {
  const quotaUsed = monthTotal();
  res.json({
    status:   'ok',
    tiers: {
      ECONOMY:  { model: process.env.COPILOT_MODEL_ECONOMY  || 'gpt-5-mini' },
      BALANCED: { model: process.env.COPILOT_MODEL_BALANCED || 'gemini-3-flash-preview' },
      PREMIUM:  { model: process.env.COPILOT_MODEL_PREMIUM  || 'claude-sonnet-4.6' },
    },
    quota: {
      used:  quotaUsed,
      limit: QUOTA_LIMIT,
    },
    force: {
      premium: process.env.FORCE_PREMIUM === 'true',
      economy: process.env.FORCE_ECONOMY === 'true',
    },
    classifier_enabled: process.env.CLASSIFIER_ENABLED !== 'false',
  });
});

// ── Start ─────────────────────────────────────────────────────────────────────

app.listen(SIDECAR_PORT, '127.0.0.1', () => {
  console.log(`[Sidecar] Dashboard listening on http://localhost:${SIDECAR_PORT}`);
  console.log(`[Sidecar] CCR log: ${CCR_LOG}`);
  console.log(`[Sidecar] Quota log: ${QUOTA_LOG}`);
});
