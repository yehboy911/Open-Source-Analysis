---
name: gpl-lgpl-checkpoint-audit
description: Teaches agents when and how to use osc-evidence to run a 15-checkpoint GPL/LGPL compliance audit on CMake C/C++ projects.
---

## When to Use

Use this skill when auditing a CMake-based C/C++ project for GPL/LGPL compliance. The osc-evidence tool runs 15 automated checkpoints covering direct risk, build hygiene, and external tracking.

## How to Invoke

**Critical: Always pass `--no-interactive` to prevent the curses menu from blocking the agent.**

```bash
osc-evidence audit <source_dir> --no-interactive [--output <file>] [--config-h <path>] [--sbom <csv>] [--exclude <dir>]
```

If osc-evidence is not pip-installed, use the fallback path:
```bash
python3 /Users/Yehboy/Claude\ Code/osc-evidence-main/src/osc_evidence/cli.py audit <source_dir> --no-interactive [--output <file>] [--config-h <path>] [--sbom <csv>] [--exclude <dir>]
```

### Flag Reference

| Flag | Purpose |
|------|---------|
| `--no-interactive` | **Required.** Disables curses menu. |
| `--output <file>` | Write standalone report to file (optional — agent reads stdout) |
| `--config-h <path>` | FFmpeg config.h for enhanced GPL/nonfree detection (CP01/CP04) |
| `--sbom <csv>` | OSC-format SBOM CSV for GPL confirmation (repeatable) |
| `--exclude <dir>` | Exclude directory prefix from scanning (repeatable) |

## Checkpoint Structure (15 checkpoints, 3 tiers)

### Tier 1 — Direct Risk (highest priority)
- CP01: GPL/LGPL source presence
- CP02: Static linking of GPL/LGPL libraries
- CP03: License file completeness
- CP04: Nonfree/proprietary component detection
- CP05: GPL/LGPL header presence in source files

### Tier 2 — Build Hygiene
- CP06: SBOM accuracy vs actual build output
- CP07: Build flag contamination (GPL flags leaking)
- CP08: Conditional compilation guards
- CP09: Install target completeness
- CP10: Symbol visibility / export controls

### Tier 3 — External Tracking
- CP11: Third-party directory structure
- CP12: Version pinning of dependencies
- CP13: Upstream license change tracking
- CP14: Patch management
- CP15: Distribution packaging compliance

## Verdict Meanings

| Verdict | Meaning |
|---------|---------|
| **N/A** | Checkpoint not applicable to this project |
| **PASS** | Checkpoint satisfied with evidence |
| **KNOWN ISSUE** | Issue found but documented/accepted |
| **MANUAL** | Requires human legal review |
| **FAIL** | Checkpoint failed — compliance risk |

## What to Record in audit-evidence.md

Write results to **Section 6: GPL/LGPL Checkpoint Audit** using this format:

```
## 6. GPL/LGPL Checkpoint Audit

Source: <source_dir>
Tool: osc-evidence audit --no-interactive

| CP | Checkpoint | Tier | Verdict | Detail |
|----|-----------|------|---------|--------|
| CP01 | GPL/LGPL source presence | 1 | PASS | No GPL source found |
| CP02 | Static linking | 1 | FAIL | libgpl.a statically linked |
| ... | ... | ... | ... | ... |

FAIL items: CP02, CP07
MANUAL items: CP13

Evidence: $ osc-evidence audit <dir> --no-interactive → <output>
```

**Important**: Any checkpoint with FAIL verdict must be escalated to the license-reviewer agent as High Risk, overriding the standard risk matrix.
