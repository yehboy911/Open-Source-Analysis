#!/usr/bin/env node
'use strict';

// ─── ANSI helpers ────────────────────────────────────────────────────────────
const A = {
  reset:      '\x1b[0m',
  bold:       '\x1b[1m',
  dim:        '\x1b[2m',
  cyan:       '\x1b[36m',
  blue:       '\x1b[34m',
  yellow:     '\x1b[33m',
  gray:       '\x1b[90m',
  white:      '\x1b[97m',
  green:      '\x1b[32m',
  hideCursor: '\x1b[?25l',
  showCursor: '\x1b[?25h',
  clearLine:  '\r\x1b[2K',
  up:  (n) => `\x1b[${n}A`,
};

// ─── Menu data ────────────────────────────────────────────────────────────────
const ITEMS = [
  { label: 'Full Audit',        desc: 'Run all compliance checks on the target directory' },
  { label: 'SBOM Validation',   desc: 'Cross-validate SBOM CSV against CMake source tree' },
  { label: 'License Review',    desc: 'Resolve unknown licenses and assign risk verdicts'  },
  { label: 'Binary Analysis',   desc: 'Forensic binary and linkage classification'         },
  { label: 'Report Only',       desc: 'Re-compile final report from existing ledger'       },
];

const SCAN_MODES = [
  { label: 'Deep Scan',  hint: '(default)' },
  { label: 'Quick Scan', hint: ''          },
];

// ─── State ────────────────────────────────────────────────────────────────────
let cursor    = 0;
let scanMode  = 0;
let rendered  = 0; // number of lines drawn so far

// ─── Rendering ───────────────────────────────────────────────────────────────
function render() {
  const { stdout } = process;
  const lines = [];

  // Header  ◆  Test Target (測試目標)
  lines.push(
    `${A.cyan}◆${A.reset}  ${A.bold}Test Target${A.reset} ${A.gray}(測試目標)${A.reset}`
  );

  // Options
  const labelWidth = Math.max(...ITEMS.map(i => i.label.length)) + 2;
  for (let i = 0; i < ITEMS.length; i++) {
    const item = ITEMS[i];
    const isSelected = i === cursor;
    const label = item.label.padEnd(labelWidth);
    if (isSelected) {
      lines.push(
        `${A.blue}❯${A.reset}  ${A.bold}${A.white}${label}${A.reset}` +
        `${A.gray}${item.desc}${A.reset}`
      );
    } else {
      lines.push(
        `${A.gray}○  ${label}${item.desc}${A.reset}`
      );
    }
  }

  // Blank separator
  lines.push('');

  // Footer  ← scan mode → to adjust  (mirrors "Medium effort (default) ← → to adjust")
  const mode = SCAN_MODES[scanMode];
  const modeStr = mode.hint
    ? `${mode.label} ${A.gray}${mode.hint}${A.reset}`
    : `${mode.label}`;
  lines.push(
    `   ${A.gray}Scan Mode:${A.reset}  ${A.yellow}${modeStr}${A.reset}` +
    `  ${A.gray}← → to adjust${A.reset}`
  );

  // Erase previous render
  if (rendered > 0) stdout.write(A.up(rendered));

  // Draw each line
  for (let i = 0; i < lines.length; i++) {
    stdout.write(A.clearLine + lines[i]);
    if (i < lines.length - 1) stdout.write('\n');
  }

  rendered = lines.length;
}

// ─── Finish (Enter) ───────────────────────────────────────────────────────────
function finish() {
  const { stdout, stdin } = process;

  // Move below the menu
  stdout.write(`\x1b[${rendered - 1}B`);
  stdout.write('\n');
  stdout.write(A.showCursor);
  stdin.setRawMode(false);
  stdin.pause();

  const item = ITEMS[cursor];
  const mode = SCAN_MODES[scanMode];

  // Redraw title line as a confirmed selection (✔ in green)
  stdout.write(
    `${A.clearLine}${A.green}✔${A.reset}  ${A.bold}Test Target${A.reset}` +
    `  ${A.cyan}${item.label}${A.reset}` +
    `  ${A.gray}·  ${mode.label}${A.reset}\n`
  );

  // Surface the result as JSON for downstream use
  const result = { target: item.label, scanMode: mode.label };
  stdout.write(`\n${A.gray}Result: ${JSON.stringify(result)}${A.reset}\n`);
}

// ─── Graceful exit (Ctrl+C) ───────────────────────────────────────────────────
function gracefulExit() {
  const { stdout, stdin } = process;
  stdout.write('\n' + A.showCursor);
  stdin.setRawMode(false);
  stdin.pause();
  process.exit(0);
}

// ─── Main ─────────────────────────────────────────────────────────────────────
const { stdin, stdout } = process;

if (!stdin.isTTY) {
  process.stderr.write('Error: select-target.js must be run in an interactive terminal.\n');
  process.exit(1);
}

stdout.write(A.hideCursor);
stdin.setRawMode(true);
stdin.resume();
stdin.setEncoding('utf8');

render();

stdin.on('data', (key) => {
  switch (key) {
    case '\x03':        // Ctrl+C
      gracefulExit();
      break;

    case '\r':          // Enter
    case '\n':
      finish();
      break;

    case '\x1b[A':      // Up arrow
      cursor = (cursor - 1 + ITEMS.length) % ITEMS.length;
      render();
      break;

    case '\x1b[B':      // Down arrow
      cursor = (cursor + 1) % ITEMS.length;
      render();
      break;

    case '\x1b[D':      // Left arrow  — cycle scan mode backward
      scanMode = (scanMode - 1 + SCAN_MODES.length) % SCAN_MODES.length;
      render();
      break;

    case '\x1b[C':      // Right arrow — cycle scan mode forward
      scanMode = (scanMode + 1) % SCAN_MODES.length;
      render();
      break;
  }
});
