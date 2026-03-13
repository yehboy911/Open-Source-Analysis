# audit-cli

Standalone terminal pipeline for open-source compliance audits. Fills Sections 1–3, 5–6 of `audit-evidence.md` with zero LLM token consumption. Section 4 (license interpretation) is intentionally reserved for a single Claude Code pass (`/review-compliance`).

---

## Quick Start

```bash
# Interactive menu
./menu.sh

# Direct invocation
./audit-pipeline.sh /path/to/project

# With SBOM cross-validation
./audit-pipeline.sh /path/to/project --sbom /path/to/sbom.csv

# With all options
./audit-pipeline.sh /path/to/project \
    --sbom   /path/to/sbom.csv \
    --config-h /path/to/config.h \
    --exclude  third_party \
    --full-report
```

---

## Prerequisites

- bash, python3, strings (macOS built-in)
- Optional Python tools (pipeline degrades gracefully if absent):
  - `boost-scanner` — `python3 -m boost_scanner`
  - `sbom-checker`  — `python3 -m sbom_checker`
  - `osc-evidence`  — `python3 -m osc_evidence`

---

## File Layout

```
audit-cli/
├── menu.sh                         # Interactive shell menu
├── audit-pipeline.sh               # Main orchestrator
├── generate-report.py              # Standalone report generator (zero LLM)
├── requirements.txt                # No external Python deps (stdlib only)
└── scripts/
    ├── preflight-check.sh          # Verifies python3, strings, tools, target dir
    ├── verify-strings.sh           # Wraps strings(1) with regex match
    ├── extract-license-headers.py  # Scans first 50 lines for license headers
    ├── init-ledger.py              # Creates blank audit-evidence.md
    ├── scan-deps.py                # Parses manifests → Sections 1 + 2
    ├── run-tools.sh                # Runs boost-scanner / sbom-checker / osc-evidence
    └── scan-binaries.sh            # find + verify-strings → Section 3
```

---

## Audit Modes

| Flag | Sections filled | Use case |
|------|----------------|----------|
| `--mode full` (default) | 1, 2, 3, 5, 6 | Full compliance audit |
| `--mode sbom` | 1, 2, 5, 6 | Dependency + SBOM focus |
| `--mode binary` | 3 | Binary analysis only |
| `--mode report` | (reads existing ledger) | Re-generate report only |
| `--full-report` | + runs generate-report.py | Append report generation to any mode |

---

## Pipeline Flow

```
audit-pipeline.sh
  [1/6] preflight-check.sh          — abort on FAIL
  [2/6] init-ledger.py              — create audit-evidence.md
  [3/6] scan-deps.py                — Sections 1 + 2
  [4/6] run-tools.sh                — Sections 5 + 6 (boost, sbom, osc)
  [5/6] scan-binaries.sh            — Section 3
  [6/6] generate-report.py          — (if --full-report)
```

After the terminal pipeline, run in Claude Code:
```
/review-compliance /path/to/project
```
This fills **Section 4** (license interpretation) and produces the final `compliance_report_YYYY-MM-DD.md`.

---

## Evidence Citation Format

All findings are written in the standard format:

```
- <package> <version> | License: <spdx-id or UNKNOWN> | Source: <file>:<line>
- <package> <version> | License: <spdx-id or UNKNOWN> | Source: $ <command> → <output>
```

---

## Relationship to framework/

`audit-cli/` is a sibling project. Nothing in `framework/` is modified. The three scripts in `scripts/` that were copied from `framework/scripts/` are kept in sync manually.
