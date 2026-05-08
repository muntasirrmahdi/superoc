#!/usr/bin/env bash
# adapters/claudecode.sh - Claude Code adapter for SuperOC
# This adapter uses environment variable injection.

set -euo pipefail

# === SUPEROC_ACTIVE Bypass Guard ===
if [ "${SUPEROC_ACTIVE:-0}" != "1" ]; then
    echo "WARNING: SUPEROC_ACTIVE is not set. You are bypassing SuperOC memory enforcement."
    echo "         Memory state will not be automatically loaded by Claude Code."
    echo "         To use SuperOC correctly, run: superoc claudecode"
fi

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"
SUPEROC_PROMPT="$SUPEROC_DIR/.system_prompt"
ENV_FILE="$SUPEROC_DIR/env.sh"
TEMPLATE_FILE="$(dirname "$0")/../../templates/claudecode.md"

# Check for state.json
if [ ! -f "$STATE_FILE" ]; then
    echo "WARNING: SuperOC state.json not found at $STATE_FILE"
    echo "Run: superoc opencode (first) to initialize"
fi

# Create system prompt from state.json using a template
create_system_prompt() {
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    if [ ! -f "$TEMPLATE_FILE" ]; then
        echo "ERROR: Template file not found at $TEMPLATE_FILE"
        return 1
    fi

    # Extract content and replace placeholders in template
    local template
    template=$(<"$TEMPLATE_FILE")
    template=${template//"{{USER_CONTENT}}"/$(jq -r '.user.content // "User"' "$STATE_FILE")}
    template=${template//"{{IDENTITY_CONTENT}}"/$(jq -r '.identity.content // "AI Assistant"' "$STATE_FILE")}
    template=${template//"{{MEMORY_CONTENT}}"/$(jq -r '.memory.content // ""' "$STATE_FILE")}
    template=${template//"{{LEARNING_CONTENT}}"/$(jq -r '.learning_model.content // ""' "$STATE_FILE")}
    template=${template//"{{UNDERSTANDING_CONTENT}}"/$(jq -r '.understanding_model.content // ""' "$STATE_FILE")}
    template=${template//"{{WIKILINKS_SUMMARY}}"/$(jq -r '.wikilinks_graph.entities | length' "$STATE_FILE")}
    template=${template//"{{DAILY_SUMMARY}}"/$(jq -r '.daily.logs | keys | length' "$STATE_FILE")}
    template=${template//"{{DAYS_LOADED}}"/$(jq -r '.days_loaded // 0' "$STATE_FILE")}

    echo "$template" > "$SUPEROC_PROMPT"
    chmod 600 "$SUPEROC_PROMPT"
    return 0
}

# Inject action: create prompt and env file
ensure_claudecode_injected() {
    if create_system_prompt; then
        echo "SUCCESS: System prompt created at $SUPEROC_PROMPT"
        # Create env file for sourcing
        echo "export CLAUDE_SYSTEM_PROMPT=\"$SUPEROC_PROMPT\"" > "$ENV_FILE"
        echo "SUCCESS: Environment file created at $ENV_FILE"
        echo "To use, run: source $ENV_FILE"
    else
        echo "WARNING: Could not create system prompt."
        return 1
    fi
}

# Verify injection
verify_injection() {
    if [ -f "$SUPEROC_PROMPT" ] && grep -q "CRITICAL" "$SUPEROC_PROMPT" 2>/dev/null; then
        if [ -f "$ENV_FILE" ] && grep -q "CLAUDE_SYSTEM_PROMPT" "$ENV_FILE" 2>/dev/null; then
            echo "SUCCESS: Claude Code system prompt and env file verified."
            return 0
        else
            echo "WARNING: $ENV_FILE not found or invalid."
            return 1
        fi
    else
        echo "WARNING: Claude Code system prompt not found or invalid."
        return 1
    fi
}

# Generic adapter interface
case "${1:-inject}" in
    inject)
        ensure_claudecode_injected
        ;;
    verify)
        verify_injection
        ;;
    *)
        ensure_claudecode_injected
        ;;
esac
