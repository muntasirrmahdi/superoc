#!/usr/bin/env bash
# update-learning.sh - Extracts learnings from session and updates learning model

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
LOG_DIR="$SUPEROC_DIR/logs"
LEARNING_MODEL="$SUPEROC_DIR/templates/learning-models/learning-model.md"
UNDERSTANDING_MODEL="$SUPEROC_DIR/templates/learning-models/understanding-model.md"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$(dirname "$LEARNING_MODEL")"

SESSION_LOG="$LOG_DIR/$TODAY.md"
[ -f "$SESSION_LOG" ] || exit 0

grep -E "DECISION|FIXED|CREATED|IMPLEMENTED|INSIGHT|PATTERN" "$SESSION_LOG" 2>/dev/null | while read -r line; do
    [ -n "$line" ] && echo "- $line" >> "$LEARNING_MODEL"
done

{
    echo ""
    echo "## $TODAY"
    echo "Updated: $(date)"
} >> "$LEARNING_MODEL"

exit 0