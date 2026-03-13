#!/usr/bin/env bash
# scan-binaries.sh — Enumerate platform binaries and run signature checks.
# Writes Section 3 raw evidence to audit-evidence.md.
#
# Usage:
#   scan-binaries.sh --project-dir <path> --ledger <path> --scripts-dir <path>

set -euo pipefail

PROJECT_DIR=""
LEDGER=""
SCRIPTS_DIR=""

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-dir)  PROJECT_DIR="$2"; shift 2 ;;
        --ledger)       LEDGER="$2";      shift 2 ;;
        --scripts-dir)  SCRIPTS_DIR="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

[[ -z "$PROJECT_DIR" ]] && { echo "Error: --project-dir required" >&2; exit 1; }
[[ -z "$LEDGER"      ]] && { echo "Error: --ledger required" >&2;      exit 1; }
[[ -z "$SCRIPTS_DIR" ]] && { echo "Error: --scripts-dir required" >&2; exit 1; }

VERIFY_SH="$SCRIPTS_DIR/verify-strings.sh"
if [[ ! -x "$VERIFY_SH" ]]; then
    echo "Error: verify-strings.sh not found or not executable at $VERIFY_SH" >&2
    exit 1
fi

# ── Binary discovery ──────────────────────────────────────────────────────────
# Candidate search paths (gracefully skipped if absent)
WIN_BIN="$PROJECT_DIR/WIN64/bin"
LINUX_BIN="$PROJECT_DIR/linux_x64/bin"

mapfile -t BINARIES < <(
    {
        if [[ -d "$WIN_BIN" || -d "$LINUX_BIN" ]]; then
            # Use platform-specific dirs when present — avoids double-scanning
            [[ -d "$WIN_BIN"   ]] && find "$WIN_BIN"   -type f \( -name "*.dll" -o -name "*.lib" -o -name "*.exe" \) 2>/dev/null || true
            [[ -d "$LINUX_BIN" ]] && find "$LINUX_BIN" -type f \( -name "*.so*" -o -name "*.a"   \)                 2>/dev/null || true
        else
            # Generic fallback when no platform-specific dirs exist
            find "$PROJECT_DIR" -maxdepth 4 -type f \
                \( -name "*.dll" -o -name "*.lib" -o -name "*.so*" -o -name "*.a" -o -name "*.exe" \) \
                2>/dev/null || true
        fi
    } | sort -u
)

if [[ ${#BINARIES[@]} -eq 0 ]]; then
    SECTION_CONTENT="_No binaries found in $PROJECT_DIR._"
else
    # ── Per-binary analysis ───────────────────────────────────────────────────
    SECTION_CONTENT=""
    for binary in "${BINARIES[@]}"; do
        fname=$(basename "$binary")

        # Classify by extension
        case "${fname,,}" in
            *.lib|*.a)           LINKAGE="STATIC" ;;
            *.dll|*.so*)         LINKAGE="SHARED" ;;
            *.exe)               LINKAGE="EXECUTABLE" ;;
            *)                   LINKAGE="UNKNOWN" ;;
        esac

        # Generic copyright/license signature check
        REGEX="(copyright|license|gpl|mit|apache|lgpl|bsd)"
        SIG_OUTPUT=$("$VERIFY_SH" "$binary" "$REGEX" 2>/dev/null || echo "ERROR")

        # Strip PROJECT_DIR prefix via bash — no subprocess needed
        REL_PATH="${binary#$PROJECT_DIR/}"

        SECTION_CONTENT+="### $fname
- Path: $REL_PATH
- Linkage: $LINKAGE
- Signature Check: \$ ./scripts/verify-strings.sh $REL_PATH \"$REGEX\" → $SIG_OUTPUT
- Notes: classified by file extension

"
    done
fi

# ── Append to ledger ──────────────────────────────────────────────────────────
# Pass content via stdin to avoid shell→Python string interpolation issues.
printf '%s\n' "$SECTION_CONTENT" \
    | python3 "$SCRIPTS_DIR/update-ledger.py" --ledger "$LEDGER" --section "3. Binary & Linkage Evidence"

BINARY_COUNT=${#BINARIES[@]}
echo "Section 3: $BINARY_COUNT binary file(s) written."
