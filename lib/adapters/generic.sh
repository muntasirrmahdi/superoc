#!/usr/bin/env bash
# adapters/generic.sh - Generic adapter for SuperOC
# Exports state.json in various formats for universal tool consumption.

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"

# --- Utility functions ---

# Check for required commands
command -v jq >/dev/null 2>&1 || { echo >&2 "ERROR: 'jq' is not installed. Aborting."; exit 1; }

# --- Format Converters ---

to_json() {
    jq '.' "$STATE_FILE"
}

to_markdown() {
    local user_content identity_content memory_content learning_content understanding_content
    local wikilinks_summary daily_summary days_loaded

    user_content=$(jq -r '.user.content // "Not set"' "$STATE_FILE")
    identity_content=$(jq -r '.identity.content // "Not set"' "$STATE_FILE")
    memory_content=$(jq -r '.memory.content // "Not set"' "$STATE_FILE")
    learning_content=$(jq -r '.learning_model.content // "Not set"' "$STATE_FILE")
    understanding_content=$(jq -r '.understanding_model.content // "Not set"' "$STATE_FILE")
    wikilinks_summary=$(jq -r '.wikilinks_graph.entities | length' "$STATE_FILE")
    daily_summary=$(jq -r '.daily.logs | keys | length' "$STATE_FILE")
    days_loaded=$(jq -r '.days_loaded // 0' "$STATE_FILE")

    cat << EOF
# SuperOC Memory State

## User
$user_content

## Identity
$identity_content

## Memory
$memory_content

## Learning Model
$learning_content

## Understanding Model
$understanding_content

## Metrics
- Wikilinks Entities: $wikilinks_summary
- Daily Logs: $daily_summary
- Days Loaded: $days_loaded
EOF
}

to_env() {
    local keys
    keys=$(jq -r 'keys[]' "$STATE_FILE")
    for key in $keys; do
        # For nested objects, export summary stats
        if [[ "$(jq -r ".$key | type" "$STATE_FILE")" == "object" ]]; then
            if [[ "$key" == "wikilinks_graph" ]]; then
                echo "export SUPEROC_WIKILINKS_ENTITIES=$(jq -r '.wikilinks_graph.entities | length' "$STATE_FILE")"
            elif [[ "$key" == "daily" ]]; then
                 echo "export SUPEROC_DAILY_LOGS_COUNT=$(jq -r '.daily.logs | keys | length' "$STATE_FILE")"
            else
                echo "export SUPEROC_${key^^}_PRESENT=true"
            fi
        else
            local value
            value=$(jq -r ".$key" "$STATE_FILE")
            echo "export SUPEROC_${key^^}=\"$value\""
        fi
    done
}

# --- SUPEROC_ACTIVE Bypass Guard ---
check_bypass() {
    if [ "${SUPEROC_ACTIVE:-0}" != "1" ]; then
        echo "WARNING: SUPEROC_ACTIVE is not set. You are bypassing SuperOC memory enforcement."
        echo "         Memory state will not be automatically loaded by your agent."
        echo "         To use SuperOC correctly, run: superoc <agent_name>"
        echo ""
    fi
}

# --- Main Logic ---

usage() {
    echo "Usage: $0 [--format json|md|env]"
    exit 1
}

# Run bypass check
check_bypass

FORMAT="md" # Default format

if [[ $# -gt 0 ]]; then
    case "$1" in
        --format)
            shift
            FORMAT="$1"
            ;;
        *)
            usage
            ;;
    esac
fi

if [ ! -f "$STATE_FILE" ]; then
    echo "ERROR: SuperOC state.json not found at $STATE_FILE"
    exit 1
fi

case "$FORMAT" in
    json)
        to_json
        ;;
    md|markdown)
        to_markdown
        ;;
    env)
        to_env
        ;;
    *)
        echo "ERROR: Invalid format '$FORMAT'"
        usage
        ;;
esac
