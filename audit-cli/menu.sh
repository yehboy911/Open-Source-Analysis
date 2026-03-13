#!/usr/bin/env bash
# menu.sh — Interactive shell menu for audit-cli
# Guides the user through selecting a target project and audit options,
# then calls audit-pipeline.sh with the assembled arguments.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================"
echo "  Open Source Compliance Audit — audit-cli"
echo "================================================"
echo ""

# ── Step 1: Target project directory ─────────────────────────────────────────
read -rp "Target project directory: " TARGET_DIR
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"  # expand leading ~

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a directory." >&2
    exit 1
fi

# ── Step 2: Audit mode ────────────────────────────────────────────────────────
echo ""
echo "Audit mode:"
select MODE_CHOICE in "Full Audit" "SBOM Validation only" "Binary Analysis only" "Report Only"; do
    case "$REPLY" in
        1) MODE="full";   break ;;
        2) MODE="sbom";   break ;;
        3) MODE="binary"; break ;;
        4) MODE="report"; break ;;
        *) echo "Please enter 1–4." ;;
    esac
done

# ── Step 3: SBOM CSV (if relevant) ───────────────────────────────────────────
SBOM_ARG=""
if [[ "$MODE" == "full" || "$MODE" == "sbom" ]]; then
    echo ""
    read -rp "SBOM CSV path (leave blank to skip): " SBOM_PATH
    SBOM_PATH="${SBOM_PATH/#\~/$HOME}"
    if [[ -n "$SBOM_PATH" ]]; then
        if [[ ! -f "$SBOM_PATH" ]]; then
            echo "Error: '$SBOM_PATH' not found." >&2
            exit 1
        fi
        SBOM_ARG="--sbom $SBOM_PATH"
    fi
fi

# ── Step 4: Optional extras ───────────────────────────────────────────────────
CONFIG_H_ARG=""
EXCLUDE_ARG=""

echo ""
echo "Optional extras (select Done when finished):"
while true; do
    select EXTRA_CHOICE in "Add --config-h path" "Add --exclude directory" "Done"; do
        case "$REPLY" in
            1)
                read -rp "  config.h path: " CONFIG_H_PATH
                CONFIG_H_PATH="${CONFIG_H_PATH/#\~/$HOME}"
                if [[ ! -f "$CONFIG_H_PATH" ]]; then
                    echo "  Warning: '$CONFIG_H_PATH' not found, including anyway."
                fi
                CONFIG_H_ARG="--config-h $CONFIG_H_PATH"
                break
                ;;
            2)
                read -rp "  Exclude directory name: " EXCLUDE_DIR
                EXCLUDE_ARG="--exclude $EXCLUDE_DIR"
                break
                ;;
            3)
                break 2
                ;;
            *)
                echo "Please enter 1–3."
                ;;
        esac
    done
done

# ── Step 5: Confirm ───────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────"
echo "  Summary"
echo "────────────────────────────────────────────────"
echo "  Target : $TARGET_DIR"
echo "  Mode   : $MODE_CHOICE"
[[ -n "$SBOM_ARG" ]]     && echo "  SBOM   : $SBOM_PATH"
[[ -n "$CONFIG_H_ARG" ]] && echo "  config : $CONFIG_H_PATH"
[[ -n "$EXCLUDE_ARG" ]]  && echo "  Exclude: $EXCLUDE_DIR"
echo "────────────────────────────────────────────────"
echo ""

read -rp "Proceed? (y/n): " CONFIRM
case "$CONFIRM" in
    [Yy]*) ;;
    *)
        echo "Aborted."
        exit 0
        ;;
esac

# ── Step 6: Launch pipeline ───────────────────────────────────────────────────
echo ""
# shellcheck disable=SC2086
exec "$SCRIPT_DIR/audit-pipeline.sh" "$TARGET_DIR" \
    --mode "$MODE" \
    $SBOM_ARG \
    $CONFIG_H_ARG \
    $EXCLUDE_ARG
