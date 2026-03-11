---
description: Absolute law requiring all audit claims to be backed by verifiable evidence.
---

# Strict Evidence Standard

**This is an absolute law. No exceptions.**

Every claim made during an audit must be backed by at least one of the following:

- A specific file path (absolute or relative to the project root)
- A line number within that file
- The literal output of a shell command that was actually executed

## Prohibited

- Stating that a license "is probably MIT" without reading the LICENSE file.
- Referencing a file path that was not verified to exist via a tool call.
- Inferring dependency versions from context without checking a manifest or lock file.
- Guessing, hallucinating, or assuming any path, version, license, or symbol name.

## Required Format for Evidence Citations

When logging a finding to `audit-evidence.md`, every entry must include its evidence source:

```
[FINDING] <description>
  Source: <file_path>:<line_number>
  OR
  Source: $ <command> → <output>
```

## Rationale

Compliance audits produce legal artifacts. An unverified claim in an audit report carries the same legal risk as a false claim. When in doubt, run the command. When you cannot run the command, flag the item as UNVERIFIED and do not assert a conclusion.
