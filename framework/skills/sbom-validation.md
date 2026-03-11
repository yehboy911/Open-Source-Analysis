---
name: sbom-validation
description: Teaches agents when and how to use sbom-checker to cross-validate SBOM CSV files against CMake source trees.
---

## When to Use

Use this skill when SBOM CSV files are available alongside a CMake source tree. The sbom-checker tool validates that every binary listed in the SBOM has a corresponding CMake build target, and classifies each entry.

## How to Invoke

### Step 1 — Scan CMake targets (optional, for context)

```bash
sbom-checker scan <source_dir> --platform <linux|windows>
```

This lists all CMake build targets found in the source tree. Use it to understand what the project actually builds.

### Step 2 — Validate SBOM CSV against source

```bash
sbom-checker check <csv_path> --source-dir <source_dir> --platform <linux|windows>
```

If sbom-checker is not pip-installed, use the fallback path:
```bash
python3 /Users/Yehboy/Claude\ Code/sbom_checker/src/sbom_checker/cli.py check <csv_path> --source-dir <source_dir> --platform <linux|windows>
```

## Output Classification (6 tiers)

The tool classifies each SBOM entry into one of six categories:

| Tier | Meaning |
|------|---------|
| `cmake_internal` | Built by the project's own CMakeLists.txt |
| `test_sample` | Test or sample binary, not shipped |
| `static_lib` | Static library (.lib/.a), linked into other binaries |
| `third_party` | External dependency, not built from project source |
| `platform_specific` | Platform-specific binary not relevant to current platform |
| `unknown` | No matching CMake target found — **flag for review** |

## What to Record in audit-evidence.md

Write results to **Section 5: SBOM Cross-Validation** using this format:

```
## 5. SBOM Cross-Validation

Platform: <platform>
CSV: <csv_path>
Total entries: <N>

| Binary | Classification | CMake Target | Notes |
|--------|---------------|--------------|-------|
| foo.dll | cmake_internal | foo_lib | — |
| bar.dll | unknown | — | ⚠️ No matching target |

Summary: X cmake_internal, Y third_party, Z unknown (flagged)

Evidence: $ sbom-checker check <csv> --source-dir <dir> --platform <platform> → <output>
```

Flag any `unknown` entries — these may be missing from the build system or incorrectly named.
