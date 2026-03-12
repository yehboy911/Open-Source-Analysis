---
name: dependency-tracing
description: Maps direct and transitive dependencies in a strict two-phase workflow, logging all findings to audit-evidence.md.
---

## When to Use

Use this skill whenever an audit requires building a complete dependency graph — either for a package manifest, a binary distribution, or a source tree. It enforces a sequential, disk-backed workflow to prevent state loss between phases.

## How It Works

### Phase 1 — Direct Dependencies

1. Parse all top-level dependency declarations (e.g., `package.json`, `CMakeLists.txt`, `*.podspec`, vendor manifests).
2. For each direct dependency, record:
   - Package name and version
   - Declared license (if present in manifest)
   - Source file and line number of the declaration
3. **Write all Phase 1 findings to `audit-evidence.md` on disk before proceeding.**
   Phase 2 must not begin until this write is confirmed complete. This is a hard stop.

### Phase 2 — Transitive Dependencies

Phase 2 begins only after Phase 1 data exists in `audit-evidence.md`.

1. For each direct dependency identified in Phase 1, recursively resolve its own dependencies.
2. Deduplicate entries by package name + version.
3. Flag any transitive dependency whose license differs from or is incompatible with the project's declared license policy.
4. Append all transitive findings to `audit-evidence.md` under a clearly labeled `## Transitive Dependencies` section.

## Examples

**Phase 1 entry in `audit-evidence.md`:**
```
## Direct Dependencies
- openssl 3.0.2 | License: Apache-2.0 | Source: CMakeLists.txt:42
- zlib 1.2.11   | License: zlib      | Source: CMakeLists.txt:67
```

**Phase 2 entry in `audit-evidence.md`:**
```
## Transitive Dependencies
- openssl → c-ares 1.19.0 | License: MIT     | Source: $ npm ls c-ares → c-ares@1.19.0
- openssl → perl 5.36.0   | License: GPL-1.0-or-later | Source: CMakeLists.txt:89 ⚠️ FLAG FOR REVIEW
```
