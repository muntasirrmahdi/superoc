#!/usr/bin/env bash
# adapters/claude.sh - Standard Claude adapter for SuperOC

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"
CLAUDE_PROMPT_FILE="$SUPEROC_DIR/.claude_prompt"
TEMPLATE_FILE="$(dirname "$0")/../../templates/claude.md"

# Create system prompt from state.json using a template
create_system_prompt() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "ERROR: state.json not found."
        return 1
    fi
    if [ ! -f "$TEMPLATE_FILE" ]; then
        echo "ERROR: Template file not found."
        return 1
    fi

    # Using generic adapter to get a clean summary
    local system_prompt
    system_prompt=$(bash "$(dirname "$0")/generic.sh" --format md)

    local template
    template=$(<"$TEMPLATE_FILE")
    template=${template//"{{SYSTEM_PROMPT}}"/$system_prompt}

    echo "$template" > "$CLAUDE_PROMPT_FILE"
    chmod 600 "$CLAUDE_PROMPT_FILE"
}

# Inject action
ensure_claude_injected() {
    if create_system_prompt; then
        echo "SUCCESS: Claude prompt created at $CLAUDE_PROMPT_FILE"
        echo "To use with Claude CLI, you can pass this file with the --system flag."
    else
        echo "WARNING: Could not create Claude prompt."
        return 1
    fi
}

# Verify injection
verify_injection() {
    if [ -f "$CLAUDE_PROMPT_FILE" ] && grep -q "SuperOC" "$CLAUDE_PROMPT_FILE" 2>/dev/null; then
        echo "SUCCESS: Claude prompt file verified."
        return 0
    else
        echo "WARNING: Claude prompt file not found or invalid."
        return 1
    fi
}

# Generic adapter interface
case "${1:-inject}" in
    inject)
        ensure_claude_injected
        ;;
    verify)
        verify_injection
        ;;
    *)
        ensure_claude_injected
        ;;
esac
