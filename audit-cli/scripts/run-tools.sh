#!/usr/bin/env bash
# run-tools.sh — Invoke boost-scanner, sbom-checker, osc-evidence.
# Writes Sections 5-6 and appends Boost findings to Section 1.
#
# Usage:
#   run-tools.sh --project-dir <path> --ledger <path>
#                [--sbom <csv>] [--config-h <path>] [--exclude <dir>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DIR=""
LEDGER=""
SBOM_CSV=""
CONFIG_H=""
EXCLUDE=""

# Canonical fallback paths (from CLAUDE.md)
BOOST_FALLBACK="/Users/Yehboy/Claude Code/boost_filter/src/boost_scanner/cli.py"
SBOM_FALLBACK="/Users/Yehboy/Claude Code/sbom_checker/src/sbom_checker/cli.py"
OSC_FALLBACK="/Users/Yehboy/Claude Code/osc-evidence-main/src/osc_evidence/cli.py"

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-dir)  PROJECT_DIR="$2"; shift 2 ;;
        --ledger)       LEDGER="$2";      shift 2 ;;
        --sbom)         SBOM_CSV="$2";    shift 2 ;;
        --config-h)     CONFIG_H="$2";    shift 2 ;;
        --exclude)      EXCLUDE="$2";     shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

[[ -z "$PROJECT_DIR" ]] && { echo "Error: --project-dir required" >&2; exit 1; }
[[ -z "$LEDGER"      ]] && { echo "Error: --ledger required" >&2;      exit 1; }

# Probe each tool's availability once up front — saves one Python startup per
# tool vs. probing inside a helper on every call (6 spawns → 3).
BOOST_USE_MODULE=false; python3 -m boost_scanner --help &>/dev/null 2>&1 && BOOST_USE_MODULE=true
SBOM_USE_MODULE=false;  python3 -m sbom_checker  --help &>/dev/null 2>&1 && SBOM_USE_MODULE=true
OSC_USE_MODULE=false;   python3 -m osc_evidence   --help &>/dev/null 2>&1 && OSC_USE_MODULE=true

# Helper: append text under a ledger section.
# Passes content via stdin to avoid shell→Python string interpolation issues
# (heredoc triple-quote injection breaks when content contains """).
append_section() {
    local section_header="$1"
    local content="$2"
    printf '%s\n' "$content" \
        | python3 "$SCRIPT_DIR/update-ledger.py" --ledger "$LEDGER" --section "$section_header"
}

# ── boost-scanner ─────────────────────────────────────────────────────────────
CMAKE_FILE="$PROJECT_DIR/CMakeLists.txt"
if [[ -f "$CMAKE_FILE" ]]; then
    echo "  Running boost-scanner..."
    if $BOOST_USE_MODULE; then
        BOOST_OUTPUT=$(python3 -m boost_scanner "$PROJECT_DIR" 2>&1 || true)
    elif [[ -f "$BOOST_FALLBACK" ]]; then
        BOOST_OUTPUT=$(python3 "$BOOST_FALLBACK" "$PROJECT_DIR" 2>&1 || true)
    else
        echo "  boost-scanner: not available (module or fallback)." >&2
        BOOST_OUTPUT=""
    fi
    if [[ -n "$BOOST_OUTPUT" ]]; then
        BOOST_SECTION="<!-- boost-scanner output -->
\`\`\`
$BOOST_OUTPUT
\`\`\`
"
        append_section "1. Direct Dependencies" "$BOOST_SECTION"
        echo "  boost-scanner: output appended to Section 1."
    else
        echo "  boost-scanner: no output."
    fi
else
    echo "  boost-scanner: skipped (no CMakeLists.txt at project root)."
fi

# ── sbom-checker ──────────────────────────────────────────────────────────────
if [[ -n "$SBOM_CSV" ]]; then
    echo "  Running sbom-checker..."
    SBOM_ARGS=("check" "$SBOM_CSV" "--source-dir" "$PROJECT_DIR")
    if $SBOM_USE_MODULE; then
        SBOM_OUTPUT=$(python3 -m sbom_checker "${SBOM_ARGS[@]}" 2>&1 || true)
    elif [[ -f "$SBOM_FALLBACK" ]]; then
        SBOM_OUTPUT=$(python3 "$SBOM_FALLBACK" "${SBOM_ARGS[@]}" 2>&1 || true)
    else
        echo "  sbom-checker: not available (module or fallback)." >&2
        SBOM_OUTPUT="WARNING: sbom-checker not installed"
    fi
    CMD_REPR="python3 -m sbom_checker check $SBOM_CSV --source-dir $PROJECT_DIR"
    SBOM_SECTION="<!-- sbom-checker output -->
\`\`\`
\$ $CMD_REPR
$SBOM_OUTPUT
\`\`\`
"
    append_section "5. SBOM Cross-Validation" "$SBOM_SECTION"
    echo "  sbom-checker: output written to Section 5."
else
    echo "  sbom-checker: skipped (no --sbom provided)."
    append_section "5. SBOM Cross-Validation" "_N/A — no SBOM CSV provided._"
fi

# ── osc-evidence ──────────────────────────────────────────────────────────────
if [[ -f "$CMAKE_FILE" ]]; then
    echo "  Running osc-evidence..."
    OSC_ARGS=("audit" "$PROJECT_DIR" "--no-interactive")
    [[ -n "$CONFIG_H" ]] && OSC_ARGS+=("--config-h" "$CONFIG_H")
    [[ -n "$SBOM_CSV" ]] && OSC_ARGS+=("--sbom" "$SBOM_CSV")
    [[ -n "$EXCLUDE"  ]] && OSC_ARGS+=("--exclude" "$EXCLUDE")

    if $OSC_USE_MODULE; then
        OSC_OUTPUT=$(python3 -m osc_evidence "${OSC_ARGS[@]}" 2>&1 || true)
    elif [[ -f "$OSC_FALLBACK" ]]; then
        OSC_OUTPUT=$(python3 "$OSC_FALLBACK" "${OSC_ARGS[@]}" 2>&1 || true)
    else
        echo "  osc-evidence: not available (module or fallback)." >&2
        OSC_OUTPUT="WARNING: osc-evidence not installed"
    fi
    CMD_REPR="python3 -m osc_evidence audit $PROJECT_DIR --no-interactive${CONFIG_H:+ --config-h $CONFIG_H}${SBOM_CSV:+ --sbom $SBOM_CSV}${EXCLUDE:+ --exclude $EXCLUDE}"
    OSC_SECTION="<!-- osc-evidence output -->
\`\`\`
\$ $CMD_REPR
$OSC_OUTPUT
\`\`\`
"
    append_section "6. GPL/LGPL Checkpoint Audit" "$OSC_SECTION"
    echo "  osc-evidence: output written to Section 6."
else
    echo "  osc-evidence: skipped (no CMakeLists.txt at project root)."
    append_section "6. GPL/LGPL Checkpoint Audit" "_N/A — no CMakeLists.txt found._"
fi

echo "run-tools.sh complete."
