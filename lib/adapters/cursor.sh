#!/usr/bin/env bash
# adapters/cursor.sh - Cursor adapter for SuperOC
# Injects SuperOC memory context into Cursor's configuration.

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
CURSOR_CONFIG_DIR="${CURSOR_CONFIG_DIR:-$HOME/.cursor}"
CURSOR_PROMPT_FILE="$CURSOR_CONFIG_DIR/prompt.json"

# Create a JSON payload for Cursor's prompt configuration
create_prompt_json() {
    if [ ! -f "$SUPEROC_DIR/state.json" ]; then
        echo "ERROR: state.json not found."
        return 1
    fi

    # Use generic.sh to get a clean Markdown summary
    local system_prompt
    system_prompt=$(bash "$(dirname "$0")/generic.sh" --format md)

    # Create a JSON object for Cursor's prompt
    jq -n --arg prompt "$system_prompt" \
        '{ "prompt": $prompt }' > "$CURSOR_PROMPT_FILE"
}

# Inject action
ensure_cursor_injected() {
    mkdir -p "$CURSOR_CONFIG_DIR"
    if create_prompt_json; then
        echo "SUCCESS: Cursor prompt created at $CURSOR_PROMPT_FILE"
        echo "Cursor will now use the SuperOC memory context."
    else
        echo "WARNING: Could not create Cursor prompt."
        return 1
    fi
}

# Verify injection
verify_injection() {
    if [ -f "$CURSOR_PROMPT_FILE" ] && jq -e '.prompt | contains("SuperOC")' "$CURSOR_PROMPT_FILE" >/dev/null; then
        echo "SUCCESS: Cursor prompt file verified."
        return 0
    else
        echo "WARNING: Cursor prompt file not found or invalid."
        return 1
    fi
}

# Generic adapter interface
case "${1:-inject}" in
    inject)
        ensure_cursor_injected
        ;;
    verify)
        verify_injection
        ;;
    *)
        ensure_cursor_injected
        ;;
esac
