---
description: Absolute law governing subagent state persistence during audits.
---

# FS Ledger Enforcement

**This is an absolute law. No exceptions.**

Subagents must never hold audit state in memory across tool calls or between control handoffs.

Every finding must be externalized to disk **immediately** upon discovery — before any subsequent tool call, before returning control to the orchestrator, and before invoking any other subagent.

## Required Behavior

- All immediate findings must be written to `audit-evidence.md` on disk.
- All shell command outputs that inform an audit decision must be written to `audit-evidence.md` on disk.
- All file paths examined, matched, or flagged must be written to `audit-evidence.md` on disk.
- A subagent may not return control to the orchestrator until its findings are confirmed written.

## Rationale

Memory is ephemeral. A subagent that holds state in context and then errors, times out, or is interrupted causes permanent, unrecoverable audit data loss. The filesystem is the only durable ledger.

## Enforcement

Any subagent that returns without writing its findings to `audit-evidence.md` is considered to have produced no output. The orchestrator must treat its result as void and reinvoke it.
