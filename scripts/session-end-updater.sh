#!/usr/bin/env bash
# scripts/session-end-updater.sh - Runs at session end
# Extracts learnings and updates memory from session logs

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
LOG_DIR="$SUPEROC_DIR/logs"
LEARNING_MODEL="$SUPEROC_DIR/templates/learning-models/learning-model.md"
UNDERSTANDING_MODEL="$SUPEROC_DIR/templates/learning-models/understanding-model.md"
SESSION_LOG="$LOG_DIR/$(date +%Y-%m-%d).md"

mkdir -p "$LOG_DIR"

# Extract key actions from today's session log
if [ -f "$SESSION_LOG" ]; then
    # Count session activities
    SESSION_COUNT=$(grep -c "Session Started" "$SESSION_LOG" 2>/dev/null || echo "0")
    NEW_DECISIONS=$(grep -c "DECISION\|FIXED\|CREATED\|IMPLEMENTED" "$SESSION_LOG" 2>/dev/null || echo "0")
    
    # Get timestamp of last activity
    LAST_ACTIVITY=$(tail -5 "$SESSION_LOG" | grep -m1 "## \[" | sed 's/## \[//;s/\].*//' || echo "unknown")
    
    echo "=== Session Summary ==="
    echo "Sessions: $SESSION_COUNT"
    echo "Key actions: $NEW_DECISIONS"
    echo "Last activity: $LAST_ACTIVITY"
    
    # Log session summary (append to learning model)
    {
        echo ""
        echo "## $(date +%Y-%m-%d)"
        echo "- $SESSION_COUNT sessions completed"
        echo "- $NEW_DECISIONS key actions taken"
    } >> "$LEARNING_MODEL"
else
    echo "=== No session log found for today ==="
fi

echo "=== Learning models updated ==="
exit 0