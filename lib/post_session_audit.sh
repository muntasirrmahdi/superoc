#!/usr/bin/env bash
# post_session_audit.sh - Post-session learning and state update
# Called by EXIT trap to parse transcripts and update memory

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
LOG_DIR="$SUPEROC_DIR/logs"
LOG_FILE="$LOG_DIR/audit.log"

# === FIX 4.4: Proper exit code handling ===
cleanup_and_exit() {
    local exit_code=$?
    echo "Exit code: $exit_code"
    exit "$exit_code"
}

# Create logs directory
mkdir -p "$LOG_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log "Starting post-flight audit..."

# === FIX 2.3: Sanitize API keys in logs ===
sanitize_key() {
    local key="$1"
    if [[ -z "$key" ]]; then
        echo ""
    elif [[ "$key" == "sk-"* ]]; then
        echo "${key:0,7}...${key: -4}"
    else
        echo "[REDACTED]"
    fi
}

# Check for API keys
OPENAI_KEY="${OPENAI_API_KEY:-}"
ANTHROPIC_KEY="${ANTHROPIC_API_KEY:-}"

log "API keys present: $([ -n "$OPENAI_KEY" ] && echo 'OpenAI yes' || echo 'no'), $([ -n "$ANTHROPIC_KEY" ] && echo 'Anthropic yes' || echo 'no')"
log "OpenAI key: $(sanitize_key "$OPENAI_KEY")"
log "Anthropic key: $(sanitize_key "$ANTHROPIC_KEY")"

# === FIX 3.2: Test python3 availability ===
if ! command -v python3 >/dev/null 2>&1; then
    log "WARNING - python3 not found. Skipping LLM extraction."
    log "Install python3 to enable post-session learning."
else
    log "Python3 available - running LLM extraction..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LLM_EXTRACT="$SCRIPT_DIR/llm_extract.py"
    
    if [ ! -f "$LLM_EXTRACT" ]; then
        log "WARNING: llm_extract.py not found at $LLM_EXTRACT"
    else
        TRANSCRIPT_PATH="$LOG_DIR/latest_session.log"
        if [ ! -f "$TRANSCRIPT_PATH" ]; then
            log "WARNING: No session transcript found at $TRANSCRIPT_PATH"
        else
            export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"
            python3 "$LLM_EXTRACT" --transcript "$TRANSCRIPT_PATH" --superoc-dir "$SUPEROC_DIR" 2>&1 | while read -r line; do
                log "LLM: $line"
            done
        fi
    fi
fi

# === FIX 4.4: Recompile state with any new updates ===
if [[ -x "$SUPEROC_DIR/lib/compile_state.sh" ]]; then
    if "$SUPEROC_DIR/lib/compile_state.sh" >> "$LOG_FILE" 2>&1; then
        log "SUCCESS: State recompiled with any updates."
    else
        log "ERROR: State recompilation failed."
    fi
fi

log "Audit complete."

# === FIX 4.4: Proper exit code propagation ===
cleanup_and_exit