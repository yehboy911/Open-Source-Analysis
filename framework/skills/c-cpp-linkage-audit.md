---
name: c-cpp-linkage-audit
description: Distinguishes static libraries from shared binaries in WIN64/bin/ and linux_x64/bin/ distributions and determines their compliance implications.
---

## When to Use

Use this skill when auditing C/C++ binary distributions that ship pre-built libraries. It clarifies which artifacts are statically linked (and therefore must satisfy copyleft obligations at link time) versus dynamically linked (subject to runtime LGPL/GPL exceptions).

## How It Works

### File Type Identification

| Extension | Platform  | Type             | Notes                                              |
|-----------|-----------|------------------|----------------------------------------------------|
| `.lib`    | WIN64     | Static library   | Linked at compile time; code is baked into final binary |
| `.dll`    | WIN64     | Shared library   | Loaded at runtime; may qualify for LGPL dynamic-link exception |
| `.a`      | linux_x64 | Static archive   | Equivalent to `.lib`; linked at compile time        |
| `.so`     | linux_x64 | Shared object    | Equivalent to `.dll`; loaded at runtime             |

### Audit Steps for `WIN64/bin/`

1. List all `.dll` and `.lib` files:
   ```
   find WIN64/bin/ -name "*.dll" -o -name "*.lib"
   ```
2. For each `.dll`, run `strings` or `dumpbin /DEPENDENTS` to identify upstream dependencies.
3. For each `.lib`, check whether its source license permits static linking (GPL does not without exceptions).

### Audit Steps for `linux_x64/bin/`

1. List all `.so` and `.a` files:
   ```
   find linux_x64/bin/ -name "*.so*" -o -name "*.a"
   ```
2. For each `.so`, run `ldd <binary>` or `readelf -d <binary> | grep NEEDED` to enumerate runtime dependencies.
3. For each `.a`, apply the same static-linking license checks as `.lib` on Windows.

### Compliance Implications

- **Static (`.lib` / `.a`)**: The consuming binary inherits the library's license obligations. GPL static linking requires the consuming project to also be GPL-compatible.
- **Shared (`.dll` / `.so`)**: LGPL libraries shipped as shared binaries typically satisfy the LGPL dynamic-link exception — but verify the specific LGPL version and any project-level exceptions.
- **Unnamed / stripped binaries**: If `strings` reveals no copyright headers and no SONAME, escalate for manual legal review.
