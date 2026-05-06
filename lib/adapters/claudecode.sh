#!/usr/bin/env bash
# adapters/claudecode.sh - Claude Code adapter for SuperOC
# NOTE: Claude Code doesn't support CLI prompt injection the same way as other agents.
# This adapter uses environment variable injection instead.

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"
SUPEROC_PROMPT="$SUPEROC_DIR/.system_prompt"

# === FIX 8.2: Proper Claude Code integration ===
# Claude Code uses CLAUDE_MODEL var or reads from .claude/settings.json
# We'll create a system prompt file and set the environment

# Check for state.json
if [ ! -f "$STATE_FILE" ]; then
    echo "WARNING: SuperOC state.json not found at $STATE_FILE"
    echo "Run: superoc opencode (first) to initialize"
fi

# Create system prompt from state.json
create_system_prompt() {
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    
    # Extract content for system prompt
    USER_CONTENT=$(jq -r '.user.content // "User"' "$STATE_FILE" 2>/dev/null || echo "User")
    IDENTITY_CONTENT=$(jq -r '.identity.content // "AI Assistant"' "$STATE_FILE" 2>/dev/null || echo "AI Assistant")
    MEMORY_CONTENT=$(jq -r '.memory.content // ""' "$STATE_FILE" 2>/dev/null || echo "")
    
    cat > "$SUPEROC_PROMPT" << EOF
# User Context
$USER_CONTENT

# Agent Identity  
$IDENTITY_CONTENT

# Long-term Memory
$MEMORY_CONTENT

---
CRITICAL: Read this file before responding. VIOLATION = IMMEDIATE FAILURE.
EOF
    
    chmod 600 "$SUPEROC_PROMPT"
    return 0
}

# Inject action
ensure_claudecode_injected() {
    # Create system prompt file
    if create_system_prompt; then
        echo "SUCCESS: System prompt created at $SUPEROC_PROMPT"
        echo "To use with Claude Code, set: CLAUDE_SYSTEM_PROMPT=$SUPEROC_PROMPT"
    else
        echo "WARNING: Could not create system prompt."
        return 1
    fi
}

# === FIX 1.5: Verify injection ===
verify_injection() {
    if [ -f "$SUPEROC_PROMPT" ] && grep -q "MANDATORY" "$SUPEROC_PROMPT" 2>/dev/null; then
        echo "SUCCESS: Claude Code system prompt verified."
        return 0
    else
        echo "WARNING: Claude Code system prompt not found."
        return 1
    fi
}

# === FIX 8.3: Generic adapter interface ===
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