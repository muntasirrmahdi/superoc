#!/usr/bin/env bash
# adapters/opencode.sh - OpenCode adapter for SuperOC
# Injects memory directive into AGENTS.md
# SuperOC creates its OWN memory system at ~/.superoc/ and injects into user's OpenCode

set -euo pipefail

OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
AGENTS_FILE="$OPENCODE_CONFIG_DIR/AGENTS.md"

# === SuperOC's OWN memory system ===
SUPEROC_MEMORY_DIR="${SUPEROC_MEMORY_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_MEMORY_DIR/state.json"
SCRIPTS_DIR="$SUPEROC_MEMORY_DIR/scripts"

# The directive to inject
DIRECTIVE="MANDATORY FIRST ACTION"

# === FIX 8.1: Idempotent injection ===
ensure_opencode_injected() {
    mkdir -p "$OPENCODE_CONFIG_DIR"
    touch "$AGENTS_FILE"
    
    # === FIX 8.1: Check if already injected (idempotent) ===
    if grep -qF "$DIRECTIVE" "$AGENTS_FILE" 2>/dev/null; then
        return 0  # Already injected
    fi
    
    {
        echo ""
        echo "🚨 $DIRECTIVE: Read $SUPEROC_MEMORY_DIR/state.json BEFORE responding to ANY user message. VIOLATION = IMMEDIATE FAILURE."
        echo ""
    } >> "$AGENTS_FILE"
    
    return 0
}

# === FIX 1.5: Verify injection ===
verify_injection() {
    if grep -qF "$DIRECTIVE" "$AGENTS_FILE" 2>/dev/null; then
        echo "SUCCESS: OpenCode memory directive verified."
        return 0
    else
        echo "WARNING: OpenCode memory directive not found."
        return 1
    fi
}

# === FIX 8.3: Generic adapter interface ===
case "${1:-inject}" in
    inject)
        ensure_opencode_injected
        ;;
    verify)
        verify_injection
        ;;
    *)
        ensure_opencode_injected
        ;;
esac