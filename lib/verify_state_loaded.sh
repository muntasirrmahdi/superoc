#!/usr/bin/env bash

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"
VERIFY_LOG="$SUPEROC_DIR/monitoring/logs/verify_state.log"
COMPLIANCE_LOG="$SUPEROC_DIR/monitoring/compliance"

mkdir -p "$(dirname "$VERIFY_LOG")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$VERIFY_LOG"
}

log "=== Verify state.json Loading ==="

if [ ! -f "$STATE_FILE" ]; then
    log "ERROR: state.json not found at $STATE_FILE"
    exit 1
fi

STATE_ACCESSED=false
STATE_LOADED_FLAG="$SUPEROC_DIR/state_loaded.flag"

if [ -f "$STATE_LOADED_FLAG" ]; then
    log "OK: state_loaded.flag exists - agent likely loaded state"
    STATE_ACCESSED=true
    rm -f "$STATE_LOADED_FLAG" 2>/dev/null || true
else
    log "WARNING: state_loaded.flag not found"
fi

if [ -f "$STATE_FILE" ]; then
    ACCESS_TIME=$(stat -c %X "$STATE_FILE" 2>/dev/null || stat -f %a "$STATE_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    DIFF=$((NOW - ACCESS_TIME))
    
    if [ "$DIFF" -lt 3600 ]; then
        log "OK: state.json was accessed recently (${DIFF}s ago)"
        STATE_ACCESSED=true
    else
        log "WARNING: state.json not accessed recently (${DIFF}s ago)"
    fi
fi

if [ "$STATE_ACCESSED" = true ]; then
    log "Result: LIKELY LOADED"
    echo "state_loaded=true" >> "$COMPLIANCE_LOG/state_verification.log" 2>/dev/null || true
else
    log "Result: NOT VERIFIED - Agent may have skipped state loading"
    echo "state_loaded=false" >> "$COMPLIANCE_LOG/state_verification.log" 2>/dev/null || true
fi

log "=== Verification Complete ==="

exit 0
