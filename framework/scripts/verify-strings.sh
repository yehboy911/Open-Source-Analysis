#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: verify-strings.sh <binary_path> <regex>" >&2
    exit 1
fi

binary_path="$1"
regex="$2"

match=$(strings -n 6 "$binary_path" | grep -iE "$regex" | head -n 1 || true)

if [[ -n "$match" ]]; then
    echo "MATCH_FOUND: $match"
else
    echo "NO_MATCH"
fi
