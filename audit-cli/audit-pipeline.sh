#!/usr/bin/env bash
# audit-pipeline.sh — Main orchestrator for the audit-cli terminal pipeline.
#
# Usage:
#   audit-pipeline.sh <target_dir> [--mode <full|sbom|binary|report>]
#                     [--sbom <csv>] [--config-h <path>] [--exclude <dir>]
#                     [--full-report]
#
# Sections filled by this pipeline:
#   1. Direct Dependencies      (scan-deps.py + boost-scanner)
#   2. Transitive Dependencies  (scan-deps.py)
#   3. Binary & Linkage         (scan-binaries.sh)
#   5. SBOM Cross-Validation    (sbom-checker — if --sbom)
#   6. GPL/LGPL Checkpoint      (osc-evidence — if CMakeLists.txt present)
#
# Section 4 (License Review) is intentionally left blank — requires LLM.
# Run /review-compliance <target> in Claude Code after this pipeline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# ── Arg parsing ───────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Usage: audit-pipeline.sh <target_dir> [options]" >&2
    echo "       --mode        full|sbom|binary|report  (default: full)" >&2
    echo "       --sbom        path to SBOM CSV" >&2
    echo "       --config-h    path to config.h" >&2
    echo "       --exclude     directory name to exclude" >&2
    echo "       --full-report also run generate-report.py at the end" >&2
    exit 1
fi

TARGET_DIR="$(cd "$1" && pwd)"
shift

MODE="full"
SBOM_CSV=""
CONFIG_H=""
EXCLUDE=""
FULL_REPORT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)        MODE="$2";      shift 2 ;;
        --sbom)        SBOM_CSV="$2";  shift 2 ;;
        --config-h)    CONFIG_H="$2";  shift 2 ;;
        --exclude)     EXCLUDE="$2";   shift 2 ;;
        --full-report) FULL_REPORT=true; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

LEDGER="$TARGET_DIR/audit-evidence.md"

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

step() { echo -e "\n${GREEN}[$1]${RESET} $2"; }
fail() { echo -e "${RED}FAIL:${RESET} $1" >&2; exit 1; }

echo "================================================"
echo "  audit-cli — Compliance Pipeline"
echo "================================================"
echo "  Target : $TARGET_DIR"
echo "  Mode   : $MODE"
[[ -n "$SBOM_CSV" ]] && echo "  SBOM   : $SBOM_CSV"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Determine total steps (preflight + init always run; rest depend on mode/flags)
# ─────────────────────────────────────────────────────────────────────────────
[[ "$MODE" != "full" && "$MODE" != "sbom" && "$MODE" != "binary" && "$MODE" != "report" ]] \
    && fail "Unknown mode: $MODE"

TOTAL_STEPS=2  # preflight + init
[[ "$MODE" == "full" || "$MODE" == "sbom"   ]] && TOTAL_STEPS=$((TOTAL_STEPS + 2))  # scan-deps + run-tools
[[ "$MODE" == "full" || "$MODE" == "binary" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))  # scan-binaries
[[ "$FULL_REPORT" == true || "$MODE" == "report" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))  # generate-report

STEP=0
next_step() { STEP=$((STEP+1)); step "$STEP/$TOTAL_STEPS" "$1"; }

# ─────────────────────────────────────────────────────────────────────────────
# [1] Preflight
# ─────────────────────────────────────────────────────────────────────────────
next_step "Preflight check"
PREFLIGHT_OUT=$("$SCRIPTS_DIR/preflight-check.sh" "$TARGET_DIR" 2>&1) || {
    echo "$PREFLIGHT_OUT"
    fail "Preflight failed. Aborting."
}
echo "$PREFLIGHT_OUT"

# ─────────────────────────────────────────────────────────────────────────────
# [2] Initialise ledger
# ─────────────────────────────────────────────────────────────────────────────
next_step "Initialising audit-evidence.md"
python3 "$SCRIPTS_DIR/init-ledger.py" \
    --project-dir "$TARGET_DIR" \
    --output "$LEDGER" \
    --mode "$MODE"

# ─────────────────────────────────────────────────────────────────────────────
# Phases by mode
# ─────────────────────────────────────────────────────────────────────────────

if [[ "$MODE" == "full" || "$MODE" == "sbom" ]]; then
    # ── [3] Scan dependencies ─────────────────────────────────────────────────
    next_step "Scanning dependencies (Sections 1 + 2)"
    python3 "$SCRIPTS_DIR/scan-deps.py" \
        --project-dir "$TARGET_DIR" \
        --ledger "$LEDGER"

    # ── [4] Run external tools ────────────────────────────────────────────────
    next_step "Running boost-scanner / sbom-checker / osc-evidence (Sections 5 + 6)"
    RUN_TOOLS_ARGS=(
        --project-dir "$TARGET_DIR"
        --ledger "$LEDGER"
    )
    [[ -n "$SBOM_CSV"  ]] && RUN_TOOLS_ARGS+=(--sbom "$SBOM_CSV")
    [[ -n "$CONFIG_H"  ]] && RUN_TOOLS_ARGS+=(--config-h "$CONFIG_H")
    [[ -n "$EXCLUDE"   ]] && RUN_TOOLS_ARGS+=(--exclude "$EXCLUDE")
    "$SCRIPTS_DIR/run-tools.sh" "${RUN_TOOLS_ARGS[@]}"
fi

if [[ "$MODE" == "full" || "$MODE" == "binary" ]]; then
    # ── [5] Scan binaries ─────────────────────────────────────────────────────
    next_step "Scanning binaries (Section 3)"
    "$SCRIPTS_DIR/scan-binaries.sh" \
        --project-dir "$TARGET_DIR" \
        --ledger "$LEDGER" \
        --scripts-dir "$SCRIPTS_DIR"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Optional: generate report
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$FULL_REPORT" == true || "$MODE" == "report" ]]; then
    next_step "Generating compliance report"
    python3 "$SCRIPT_DIR/generate-report.py" \
        --ledger "$LEDGER" \
        --output-dir "$TARGET_DIR"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "================================================"
echo -e "${GREEN}Terminal pipeline complete.${RESET}"
echo ""
echo "  Ledger : $LEDGER"
echo ""
echo "  Sections 1–3, 5–6 have been populated."
echo "  Section 4 (License Review) requires LLM interpretation."
echo ""
echo "  Next step:"
echo "    Run /review-compliance $TARGET_DIR in Claude Code"
echo "    to fill Section 4 and produce the final report."
echo "================================================"
