#!/usr/bin/env bash
# monitor_health.sh - Health monitoring for SuperOC
# Checks state, locks, and system integrity

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
LOG_FILE="${LOG_FILE:-$SUPEROC_DIR/logs/health.log}"
STATE_FILE="$SUPEROC_DIR/state.json"
LOCK_DIR="/tmp/superoc.lock.$(id -u)"

# === FIX 3.3: Cross-platform stale lock detection ===
get_lock_age() {
    local lock="$1"
    if [[ -d "$lock" ]]; then
        # Try GNU stat first
        if stat -c %Y "$lock" >/dev/null 2>&1; then
            stat -c %Y "$lock"
        elif stat -f %m "$lock" >/dev/null 2>&1; then
            # BSD/macOS stat
            stat -f %m "$lock"
        else
            # Fallback: use ls
            ls -ld --time-style=+%s "$lock" | awk '{print $6}'
        fi
    fi
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

log "Health check started."

# === FIX 1: Check if state.json exists ===
if [[ ! -f "$STATE_FILE" ]]; then
    log "WARNING: state.json is missing!"
    # === FIX 4.1: Attempt recovery ===
    if [[ -x "$SUPEROC_DIR/lib/compile_state.sh" ]]; then
        if "$SUPEROC_DIR/lib/compile_state.sh"; then
            log "SUCCESS: state.json recompiled."
        else
            log "ERROR: Recovery failed."
        fi
    fi
else
    # === FIX 1.4: Validate JSON ===
    if jq -e '.' "$STATE_FILE" >/dev/null 2>&1; then
        log "OK: state.json exists and is valid JSON."
    else
        log "ERROR: state.json is corrupted!"
        log "Attempting recovery..."
        rm -f "$STATE_FILE"
        if [[ -x "$SUPEROC_DIR/lib/compile_state.sh" ]]; then
            "$SUPEROC_DIR/lib/compile_state.sh" && log "SUCCESS: Recovered." || log "ERROR: Recovery failed."
        fi
    fi
fi

# === FIX 3.3: Check for stale locks ===
if [[ -d "$LOCK_DIR" ]]; then
    # === FIX 3.3: Cross-platform age check ===
    LOCK_AGE=$(get_lock_age "$LOCK_DIR")
    CURRENT_TIME=$(date +%s)
    
    if [[ -n "$LOCK_AGE" ]]; then
        AGE_SECONDS=$((CURRENT_TIME - LOCK_AGE))
        if [[ "$AGE_SECONDS" -gt 300 ]]; then  # 5 minutes
            log "WARNING: Stale lock found (age: ${AGE_SECONDS}s). Removing..."
            rm -rf "$LOCK_DIR"
            log "SUCCESS: Stale lock removed."
        else
            log "OK: Lock is fresh (${AGE_SECONDS}s)."
        fi
    fi
else
    log "OK: No lock directory present."
fi

# === FIX 2.5: Verify state.json ownership ===
if [[ -f "$STATE_FILE" ]]; then
    OWNER=$(stat -c %u "$STATE_FILE" 2>/dev/null || stat -f %u "$STATE_FILE" 2>/dev/null || echo "unknown")
    CURRENT_UID=$(id -u)
    if [[ "$OWNER" != "$CURRENT_UID" ]]; then
        log "WARNING: state.json owned by $OWNER, expected $CURRENT_UID."
    fi
fi

log "Health check complete."
exit 0