#!/usr/bin/env bash

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
LOG_FILE="$SUPEROC_DIR/monitoring/logs/knowledge-sync.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKILINKS_PARSER="$SCRIPT_DIR/wikilinks_parser.py"
WIKILINKS_CONFIG="$SUPEROC_DIR/wikilinks.json"
WIKILINKS_OUTPUT="$SUPEROC_DIR/wikilinks_graph.json"

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$SUPEROC_DIR"

{
    echo "=== SuperOC Knowledge Sync ==="
    echo "Timestamp: $(date -Iseconds)"
    echo "Status: Running wikilinks parser..."
} >> "$LOG_FILE" 2>/dev/null || true

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
fi

if [ ! -f "$WIKILINKS_PARSER" ]; then
    echo "ERROR: wikilinks_parser.py not found at $WIKILINKS_PARSER" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
fi

if [ ! -f "$WIKILINKS_CONFIG" ]; then
    echo "Creating default wikilinks config at $WIKILINKS_CONFIG" >> "$LOG_FILE" 2>/dev/null || true
    cat > "$WIKILINKS_CONFIG" << 'EOF'
{
    "sources": ["~/.superoc/templates", "~/.superoc/monitoring/session_logs"],
    "exclude": ["*.pyc", "__pycache__", "node_modules", ".git"],
    "file_extensions": [".md", ".txt"]
}
EOF
fi

export SUPEROC_WIKILINKS_CONFIG="$WIKILINKS_CONFIG"
export SUPEROC_WIKILINKS_OUTPUT="$WIKILINKS_OUTPUT"

PARSER_OUTPUT=$(python3 "$WIKILINKS_PARSER" --config "$WIKILINKS_CONFIG" --output "$WIKILINKS_OUTPUT" 2>&1)
PARSER_EXIT=$?

echo "$PARSER_OUTPUT" >> "$LOG_FILE" 2>/dev/null || true

if [ $PARSER_EXIT -ne 0 ]; then
    echo "ERROR: Wikilinks parser failed with exit code $PARSER_EXIT" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
fi

if [ ! -f "$WIKILINKS_OUTPUT" ]; then
    echo "ERROR: Output file not created: $WIKILINKS_OUTPUT" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
fi

{
    echo "Status: Completed successfully"
    echo "Output: $WIKILINKS_OUTPUT"
} >> "$LOG_FILE" 2>/dev/null || true

exit 0
