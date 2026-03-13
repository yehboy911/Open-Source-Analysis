#!/usr/bin/env bash
set -euo pipefail

# Preflight check — verify all audit tools are available before pipeline runs.
# Usage: preflight-check.sh <target_dir>
# Output: JSON summary to stdout. Exit 1 if any critical tool missing.

TARGET_DIR="${1:-.}"
PASS=true

check_cmd() {
    local name="$1" cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        echo "  \"$name\": \"$(command -v "$cmd")\","
    else
        echo "  \"$name\": null,"
        PASS=false
    fi
}

check_python_tool() {
    local name="$1" module="$2" fallback="$3"
    if python3 -m "$module" --help &>/dev/null 2>&1; then
        echo "  \"$name\": \"python3 -m $module\","
    elif [[ -f "$fallback" ]]; then
        echo "  \"$name\": \"python3 $fallback\","
    else
        echo "  \"$name\": null,"
        # Python tools are optional — don't fail preflight
    fi
}

echo "{"

# Critical tools
check_cmd "python3" "python3"
check_cmd "strings" "strings"

# Python CLI tools (optional — pipeline degrades gracefully)
check_python_tool "boost-scanner" "boost_scanner" "boost_filter/src/boost_scanner/cli.py"
check_python_tool "sbom-checker" "sbom_checker" "sbom_checker/src/sbom_checker/cli.py"
check_python_tool "osc-evidence" "osc_evidence" "osc-evidence-main/src/osc_evidence/cli.py"

# Target directory
if [[ -d "$TARGET_DIR" ]]; then
    echo "  \"target_dir\": \"$(cd "$TARGET_DIR" && pwd)\","
    echo "  \"target_exists\": true,"
else
    echo "  \"target_dir\": \"$TARGET_DIR\","
    echo "  \"target_exists\": false,"
    PASS=false
fi

if $PASS; then
    echo "  \"status\": \"PASS\""
else
    echo "  \"status\": \"FAIL\""
fi

echo "}"

if ! $PASS; then
    echo "PREFLIGHT FAILED: Missing critical tools or target directory." >&2
    exit 1
fi
