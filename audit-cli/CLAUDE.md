# CLAUDE.md — audit-cli

This file provides guidance to Claude Code when working inside `audit-cli/`.

## What This Project Does

Standalone terminal pipeline that fills Sections 1–3, 5–6 of `audit-evidence.md` with **zero LLM token consumption**. Section 4 (license interpretation) is intentionally left for a single Claude Code pass (`/review-compliance`).

Sibling to `framework/`. Nothing in `framework/` is modified by this project.

## Entry Points

```bash
# Interactive menu (recommended for first-time use)
./menu.sh

# Direct invocation
./audit-pipeline.sh <target_dir>
./audit-pipeline.sh <target_dir> --sbom path/to/sbom.csv
./audit-pipeline.sh <target_dir> --mode binary
./audit-pipeline.sh <target_dir> --full-report

# Standalone report generation (after Section 4 is filled by LLM)
python3 generate-report.py --ledger <path>/audit-evidence.md --output-dir <path>
```

## File Layout

```
audit-cli/
├── menu.sh                         # Interactive shell menu — entry point for users
├── audit-pipeline.sh               # Main orchestrator
├── generate-report.py              # Standalone report generator (zero LLM)
├── requirements.txt                # No external Python deps (stdlib only)
└── scripts/
    ├── preflight-check.sh          # Verifies python3, strings, tools, target dir
    ├── verify-strings.sh           # Wraps strings(1) with regex match; returns MATCH_FOUND/NO_MATCH
    ├── extract-license-headers.py  # Scans first 50 lines of a file for license headers; outputs JSON
    ├── update-ledger.py            # Shared helper: appends stdin content under a named ledger section
    ├── init-ledger.py              # Creates blank audit-evidence.md with 6 section headers
    ├── scan-deps.py                # Parses manifests → Sections 1 + 2
    ├── run-tools.sh                # Invokes boost-scanner / sbom-checker / osc-evidence → Sections 5–6
    └── scan-binaries.sh            # find + verify-strings.sh → Section 3 raw evidence
```

## Pipeline Stages

```
audit-pipeline.sh
  [1] preflight-check.sh      — abort if FAIL
  [2] init-ledger.py          — create audit-evidence.md
  [3] scan-deps.py            — Sections 1 + 2  (full / sbom modes)
  [4] run-tools.sh            — Sections 5 + 6  (full / sbom modes)
  [5] scan-binaries.sh        — Section 3        (full / binary modes)
  [6] generate-report.py      — final report     (only with --full-report or --mode report)
```

After the terminal pipeline completes, run in Claude Code:
```
/review-compliance <target_dir>
```
This fills **Section 4** (license review, risk matrix) and generates the final `compliance_report_YYYY-MM-DD.md`.

## Audit Modes

| `--mode` | Sections filled | Steps |
|----------|----------------|-------|
| `full` (default) | 1, 2, 3, 5, 6 | preflight + init + scan-deps + run-tools + scan-binaries |
| `sbom` | 1, 2, 5, 6 | preflight + init + scan-deps + run-tools |
| `binary` | 3 | preflight + init + scan-binaries |
| `report` | reads existing ledger | preflight + init + generate-report |

Add `--full-report` to any mode to also run `generate-report.py` at the end.

## Python Tool Paths

| Tool | Module | Fallback CLI path |
|------|--------|-------------------|
| boost-scanner | `boost_scanner` | `/Users/Yehboy/Claude Code/boost_filter/src/boost_scanner/cli.py` |
| sbom-checker | `sbom_checker` | `/Users/Yehboy/Claude Code/sbom_checker/src/sbom_checker/cli.py` |
| osc-evidence | `osc_evidence` | `/Users/Yehboy/Claude Code/osc-evidence-main/src/osc_evidence/cli.py` |

Try `python3 -m <module>` first. Fall back to `python3 <path>` if not pip-installed.

**osc-evidence**: always pass `--no-interactive`. Without it the curses UI blocks the script.

## Key Implementation Notes

- **`scripts/update-ledger.py`** is the shared ledger-write helper. All scripts that write to `audit-evidence.md` pipe content via stdin:
  ```bash
  printf '%s\n' "$content" | python3 "$SCRIPTS_DIR/update-ledger.py" \
      --ledger "$LEDGER" --section "5. SBOM Cross-Validation"
  ```
  This avoids shell→Python string interpolation issues (heredoc triple-quote injection).

- **`scan-deps.py`** uses `write_sections()` to update Sections 1 and 2 in a single file read+write cycle.

- **`run-tools.sh`** probes tool availability once at startup (`BOOST_USE_MODULE`, `SBOM_USE_MODULE`, `OSC_USE_MODULE`) then invokes directly — no double Python spawn.

- **Binary discovery** (`scan-binaries.sh`): uses platform-specific dirs (`WIN64/bin`, `linux_x64/bin`) when present; generic recursive `find` only when neither exists.

## Evidence Citation Format

All findings written in the standard format:
```
- <package> <version> | License: <spdx-id or UNKNOWN> | Source: <file>:<line>
- <package> <version> | License: <spdx-id or UNKNOWN> | Source: $ <command> → <output>
```

## Scripts Copied from framework/

These three scripts are copies of `framework/scripts/` equivalents. Keep them in sync manually:
- `scripts/preflight-check.sh`
- `scripts/verify-strings.sh`
- `scripts/extract-license-headers.py`
