# CLAUDE.md — Open Source Compliance Framework

This file provides guidance to Claude Code when working inside `framework/`.

## What This Framework Does

Multi-stage open-source compliance audit pipeline for C/C++ and CMake projects. Produces a signed `audit-evidence.md` ledger and a final `compliance_report_YYYY-MM-DD.md` from a single command.

## Entry Points (Slash Commands)

```bash
/audit-compliance /path/to/project                          # full pipeline
/audit-compliance /path/to/project --sbom win.csv           # + SBOM cross-validation
/audit-compliance /path/to/project --sbom win.csv --config-h config.h --exclude third_party
/gen-report                                                  # re-run report-writer only
```

## File Layout

```
framework/
├── agents/
│   ├── compliance-planner.md   # orchestrator — runs first, coordinates all others
│   ├── dep-tracer.md           # phases 1-3: direct deps, transitive deps, tool analysis
│   ├── binary-evidence.md      # forensic binary + linkage classification
│   ├── license-reviewer.md     # risk matrix + GPL/LGPL escalation
│   └── report-writer.md        # final report synthesizer
├── commands/
│   ├── audit-compliance.md     # /audit-compliance entry point
│   └── gen-report.md           # /gen-report entry point
├── rules/
│   ├── fs-ledger-enforcement.md  # ABSOLUTE: write findings to disk before returning
│   ├── strict-evidence.md        # ABSOLUTE: every claim needs file:line or $ cmd → output
│   └── preflight-required.md     # ABSOLUTE: run preflight-check.sh before any pipeline
├── scripts/
│   ├── preflight-check.sh        # verifies python3, strings, 3 Python tools, target dir
│   ├── verify-strings.sh         # wraps strings(1) with regex match; returns MATCH_FOUND/NO_MATCH
│   ├── extract-license-headers.py # scans first 50 lines of a file for license headers; outputs JSON
│   └── select-target.js           # interactive TUI menu for audit target + scan mode selection; outputs JSON
└── skills/
    ├── dependency-tracing.md       # 2-phase dep graph workflow
    ├── c-cpp-linkage-audit.md      # .lib/.dll/.a/.so classification
    ├── sbom-validation.md          # sbom-checker workflow + 6-tier classification
    └── gpl-lgpl-checkpoint-audit.md # osc-evidence workflow + 15-checkpoint structure
```

## Python Tool Paths (confirmed)

| Tool | Module | Fallback CLI path |
|------|--------|-------------------|
| boost-scanner | `boost_scanner` | `/Users/Yehboy/Claude Code/boost_filter/src/boost_scanner/cli.py` |
| sbom-checker | `sbom_checker` | `/Users/Yehboy/Claude Code/sbom_checker/src/sbom_checker/cli.py` |
| osc-evidence | `osc_evidence` | `/Users/Yehboy/Claude Code/osc-evidence-main/src/osc_evidence/cli.py` |

Try `python3 -m <module>` first. Fall back to `python3 <path>` if not pip-installed.

**osc-evidence**: Always pass `--no-interactive`. Without it the curses UI blocks the agent.

## Audit Evidence Ledger (audit-evidence.md)

The single shared state file. All inter-agent communication goes through this file — never through in-context memory.

| Section | Written by | Optional? |
|---------|-----------|-----------|
| 1. Direct Dependencies | dep-tracer (Phase 1 + 3a) | No |
| 2. Transitive Dependencies | dep-tracer (Phase 2) | No |
| 3. Binary & Linkage Evidence | binary-evidence | No |
| 4. License Review & Risk Assessment | license-reviewer | No |
| 5. SBOM Cross-Validation | dep-tracer (Phase 3b) | Yes — requires `--sbom` flag |
| 6. GPL/LGPL Checkpoint Audit | dep-tracer (Phase 3c) | Yes — requires CMakeLists.txt |

## Absolute Rules (never bypass)

1. **fs-ledger-enforcement**: Every finding goes to disk immediately. A subagent that returns without writing its findings is treated as void and reinvoked.
2. **strict-evidence**: Every claim must cite `file:line` or `$ command → output`. No guessing licenses or versions.
3. **preflight-required**: `compliance-planner` must run `scripts/preflight-check.sh` first. Abort if status is `FAIL`.

## Pipeline Order

```
compliance-planner
  └─ preflight-check.sh         (abort if FAIL)
  └─ init audit-evidence.md
  └─ dep-tracer                 → Sections 1, 2, 5, 6
  └─ binary-evidence            → Section 3
  └─ license-reviewer           → Section 4
  └─ report-writer              → compliance_report_YYYY-MM-DD.md
```

## Evidence Citation Format

```
- <package> <version> | License: <spdx-id or UNKNOWN> | Source: <file>:<line>
- <package> <version> | License: <spdx-id or UNKNOWN> | Source: $ <command> → <output>
```

## Risk Escalation

If Section 6 (osc-evidence) reports a FAIL checkpoint for a dependency, the `license-reviewer` must escalate that dependency to **High Risk** regardless of the standard risk matrix. osc-evidence is the authoritative GPL/LGPL source.
