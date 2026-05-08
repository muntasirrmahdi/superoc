#!/usr/bin/env bash
# lib/load_memory.sh - Loads SuperOC memory state into shell environment
# This script reads state.json and exports variables for use in the wrapper

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"
SHELL_ENV="$SUPEROC_DIR/shell.env"

# Default values
SUPEROC_MEMORY_READY="false"
SUPEROC_USER_NAME=""
SUPEROC_USER_EMAIL=""
SUPEROC_USER_LOCATION=""
SUPEROC_USER_TIMEZONE=""
SUPEROC_IDENTITY_CORE=""
SUPEROC_IDENTITY_RULES=""
SUPEROC_MEMORY_LONGTERM=""
SUPEROC_LEARNING_MODEL=""
SUPEROC_UNDERSTANDING_MODEL=""
SUPEROC_WIKILINKS_GRAPH=""
SUPEROC_DAILY_LOGS=""
SUPEROC_DAYS_LOADED=0

# Load from state.json if it exists and is valid
if [ -f "$STATE_FILE" ] && jq -e '.' "$STATE_FILE" >/dev/null 2>&1; then
    SUPEROC_MEMORY_READY="true"
    
    # Extract user info
    SUPEROC_USER_NAME=$(jq -r '.user.content // ""' "$STATE_FILE" 2>/dev/null | head -5)
    SUPEROC_USER_EMAIL=$(jq -r '.user.content // ""' "$STATE_FILE" 2>/dev/null | grep -i "email:" | head -1 | cut -d: -f2 | tr -d ' ' || true)
    SUPEROC_USER_LOCATION=$(jq -r '.user.content // ""' "$STATE_FILE" 2>/dev/null | grep -i "location:" | head -1 | cut -d: -f2 | tr -d ' ' || true)
    SUPEROC_USER_TIMEZONE=$(jq -r '.user.content // ""' "$STATE_FILE" 2>/dev/null | grep -i "timezone:" | head -1 | cut -d: -f2 | tr -d ' ' || true)
    
    # Extract identidad
    SUPEROC_IDENTITY_CORE=$(jq -r '.identity.content // ""' "$STATE_FILE" 2>/dev/null | head -20)
    
# Extract long-term memory
SUPEROC_MEMORY_LONGTERM=$(jq -r '.memory.content // ""' "$STATE_FILE" 2>/dev/null | head -20)

# Extract learning model
SUPEROC_LEARNING_MODEL=$(jq -r '.learning_model.content // ""' "$STATE_FILE" 2>/dev/null | head -20)

# Extract understanding model
SUPEROC_UNDERSTANDING_MODEL=$(jq -r '.understanding_model.content // ""' "$STATE_FILE" 2>/dev/null | head -20)

SUPEROC_WIKILINKS_GRAPH=$(jq -r '.wikilinks_graph // {}' "$STATE_FILE" 2>/dev/null)

SUPEROC_DAILY_LOGS=$(jq -r '.daily.logs // {}' "$STATE_FILE" 2>/dev/null)

SUPEROC_DAYS_LOADED=$(jq -r '.days_loaded // 0' "$STATE_FILE" 2>/dev/null)
fi

# Write shell environment for sourcing
{
    echo "# SuperOC Shell Environment - Auto-generated"
    echo "# DO NOT EDIT MANUALLY - This file is regenerated on each session"
    echo ""
    echo "export SUPEROC_MEMORY_READY=\"$SUPEROC_MEMORY_READY\""
    echo "export SUPEROC_USER_NAME=\"$SUPEROC_USER_NAME\""
    echo "export SUPEROC_USER_EMAIL=\"$SUPEROC_USER_EMAIL\""
    echo "export SUPEROC_USER_LOCATION=\"$SUPEROC_USER_LOCATION\""
    echo "export SUPEROC_USER_TIMEZONE=\"$SUPEROC_USER_TIMEZONE\""
    echo "export SUPEROC_LEARNING_MODEL=\"$SUPEROC_LEARNING_MODEL\""
    echo "export SUPEROC_UNDERSTANDING_MODEL=\"$SUPEROC_UNDERSTANDING_MODEL\""
    echo "export SUPEROC_WIKILINKS_GRAPH=\"$SUPEROC_WIKILINKS_GRAPH\""
    echo "export SUPEROC_DAILY_LOGS=\"$SUPEROC_DAILY_LOGS\""
    echo "export SUPEROC_DAYS_LOADED=\"$SUPEROC_DAYS_LOADED\""
} > "$SHELL_ENV"

chmod 600 "$SHELL_ENV" 2>/dev/null || true

exit 0