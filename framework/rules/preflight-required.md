---
description: Absolute rule requiring preflight checks before any audit pipeline execution.
---

# Preflight Required

**This is an absolute rule. No exceptions.**

Before any compliance audit pipeline begins, the orchestrator (`compliance-planner`) must run the preflight check script:

```bash
bash scripts/preflight-check.sh <target_dir>
```

## Required Behavior

1. Run `preflight-check.sh` with the target directory as the first argument.
2. Parse the JSON output to confirm `"status": "PASS"`.
3. If status is `FAIL`, abort the entire pipeline immediately and report which tools or paths are missing.
4. Do not initialize `audit-evidence.md` or invoke any subagent until preflight passes.

## Rationale

A missing tool mid-pipeline causes silent partial results — the worst outcome for a compliance audit. Failing fast at the start is cheaper than discovering a broken pipeline after 3 subagents have already run.
