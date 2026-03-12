# Open Source Compliance Framework

A Claude Code agentic pipeline for auditing open-source license compliance in C/C++ and CMake-based projects. Run one command, get a full compliance report.

## What It Does

1. Detects all direct and transitive dependencies from CMakeLists, Makefiles, and package manifests
2. Scans Boost library usage via `boost-scanner`
3. Cross-validates SBOM CSV files against CMake build targets via `sbom-checker`
4. Runs a 15-checkpoint GPL/LGPL audit via `osc-evidence`
5. Classifies each binary by linkage (static/shared/bundled)
6. Assigns a risk verdict (No Risk → High Risk) to every dependency
7. Produces a signed evidence ledger and a polished Markdown compliance report

## Prerequisites

- Claude Code installed and running
- Python 3.8+
- Node.js 14+ (required for `select-target.js` interactive target selector)
- `strings` command (macOS/Linux standard; included in Xcode command-line tools)
- The three Python audit tools (install with pipx or use fallback paths):

```bash
pipx install -e "/Users/Yehboy/Claude Code/boost_filter"
pipx install -e "/Users/Yehboy/Claude Code/sbom_checker"
pipx install -e "/Users/Yehboy/Claude Code/osc-evidence-main"
```

## Usage

```bash
# Basic audit — direct deps, transitive deps, binary evidence, license review
/audit-compliance /path/to/project

# With SBOM cross-validation
/audit-compliance /path/to/project --sbom win.csv

# Full options
/audit-compliance /path/to/project \
  --sbom win.csv \
  --sbom linux.csv \
  --config-h /path/to/ffmpeg/config.h \
  --exclude third_party \
  --exclude build

# Re-run the report from an existing evidence ledger
/gen-report
```

## Output Files

| File | Description |
|------|-------------|
| `audit-evidence.md` | Machine-written evidence ledger — all raw findings |
| `compliance_report_YYYY-MM-DD.md` | Human-readable compliance report |

## Data Flow

```
User: /audit-compliance /path/to/project --sbom win.csv

  1. compliance-planner
     ├─ preflight-check.sh ✓ (aborts if python3, strings, or target dir missing)
     └─ init audit-evidence.md (6 sections)

  2. dep-tracer
     ├─ Phase 1: CMakeLists / package.json / Makefile → Section 1 (direct deps)
     ├─ Phase 2: transitive deps → Section 2
     ├─ Phase 3a: boost-scanner → enrich Section 1
     ├─ Phase 3b: sbom-checker check win.csv → Section 5 (SBOM validation)
     └─ Phase 3c: osc-evidence audit --no-interactive → Section 6 (15 checkpoints)

  3. binary-evidence
     └─ strings + linkage classification → Section 3

  4. license-reviewer
     └─ cross-refs Sections 1-3 + 6, applies risk matrix → Section 4

  5. report-writer
     └─ compliance_report_YYYY-MM-DD.md
```

## Framework File Inventory

```
framework/
├── agents/               5 agents — each does exactly ONE thing
│   ├── compliance-planner.md     orchestrator
│   ├── dep-tracer.md             dependency mapper + tool runner
│   ├── binary-evidence.md        binary forensics
│   ├── license-reviewer.md       risk assignment
│   └── report-writer.md          report synthesis
├── commands/             2 slash commands
│   ├── audit-compliance.md       /audit-compliance
│   └── gen-report.md             /gen-report
├── rules/                3 absolute laws (always enforced)
│   ├── fs-ledger-enforcement.md  findings must be written to disk before returning
│   ├── strict-evidence.md        every claim needs a file:line or shell citation
│   └── preflight-required.md     preflight-check.sh must pass before pipeline starts
├── scripts/              4 utility scripts
│   ├── preflight-check.sh        verifies tools + target dir, outputs JSON
│   ├── verify-strings.sh         binary string search wrapper
│   ├── extract-license-headers.py  license header extractor (JSON output)
│   └── select-target.js            interactive TUI — audit target + scan mode → JSON
└── skills/               4 knowledge modules
    ├── dependency-tracing.md       2-phase dep graph workflow
    ├── c-cpp-linkage-audit.md      .lib/.dll/.a/.so compliance implications
    ├── sbom-validation.md          sbom-checker workflow + 6-tier classification
    └── gpl-lgpl-checkpoint-audit.md osc-evidence workflow + 15-checkpoint reference
```

## audit-evidence.md Structure

The ledger is the shared state between all agents. Nothing passes through in-context memory.

```markdown
# Audit Evidence Ledger

## 1. Direct Dependencies       ← dep-tracer Phase 1 + boost-scanner
## 2. Transitive Dependencies   ← dep-tracer Phase 2
## 3. Binary & Linkage Evidence ← binary-evidence
## 4. License Review & Risk Assessment ← license-reviewer
## 5. SBOM Cross-Validation     ← dep-tracer Phase 3b (requires --sbom)
## 6. GPL/LGPL Checkpoint Audit ← dep-tracer Phase 3c (requires CMakeLists.txt)
```

Sections 1–4 are mandatory. Sections 5–6 are optional and written as `N/A` when skipped.

## Risk Levels

| Level | Criteria |
|-------|----------|
| **No Risk** | Permissive license (MIT, BSD, Apache-2.0, ISC, zlib) regardless of linkage |
| **Low Risk** | LGPL dynamically linked (.dll / .so) |
| **Medium Risk** | Bison/Flex parser with valid exception |
| **High Risk** | GPL/AGPL statically linked; GPL shipped without exception; AGPL in networked context |
| **UNRESOLVED** | License cannot be determined — requires manual legal review |

**Escalation**: If `osc-evidence` reports a FAIL checkpoint for a dependency, the license-reviewer overrides the matrix and sets that dependency to High Risk.

## GPL/LGPL Checkpoint Tiers (osc-evidence)

| Tier | Checkpoints | Focus |
|------|------------|-------|
| 1 — Direct Risk | CP01–CP05 | GPL source, static linking, license files, nonfree detection |
| 2 — Build Hygiene | CP06–CP10 | SBOM accuracy, build flag contamination, symbol visibility |
| 3 — External Tracking | CP11–CP15 | Version pinning, upstream license changes, patch management |

## Compliance Report Structure

```
# Open-Source Compliance Report — YYYY-MM-DD

## Executive Summary
## Dependency Inventory
## Binary & Linkage Evidence
## Risk Assessment
## SBOM Validation Results       (only if Section 5 populated)
## GPL/LGPL Checkpoint Summary   (only if Section 6 populated)
## Unresolved Items
```

## Preflight Check

Run this before any audit to verify all tools are available:

```bash
bash framework/scripts/preflight-check.sh /path/to/project
```

Expected output when all tools are present:
```json
{
  "python3": "/usr/bin/python3",
  "strings": "/usr/bin/strings",
  "boost-scanner": "python3 -m boost_scanner",
  "sbom-checker": "python3 -m sbom_checker",
  "osc-evidence": "python3 -m osc_evidence",
  "target_dir": "/path/to/project",
  "target_exists": true,
  "status": "PASS"
}
```

`python3` and `strings` are critical — a missing one exits 1 and aborts the pipeline. The three Python tools are optional; the pipeline degrades gracefully if they are absent (Sections 5 and 6 will be marked N/A).

## Design Principles

- **Single source of truth**: `audit-evidence.md` is the only shared state. No in-context memory between agents.
- **Shell-first**: Agents call Python tools directly via bash — no wrapper layers.
- **Fail fast**: Missing tools are caught at preflight, not mid-pipeline.
- **Evidence required**: Every finding must cite a `file:line` or a `$ command → output`. No guessing.
- **Minimal pipeline**: 4 subagents (dep-tracer, binary-evidence, license-reviewer, report-writer). Each does exactly one thing.
