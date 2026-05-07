#!/usr/bin/env bash

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"
SUPERVISOR_LOG="$SUPEROC_DIR/monitoring/logs/supervisor.log"
CHECK_INTERVAL=60
TIMEOUT=300
AGENT_PID="${1:-}"

mkdir -p "$(dirname "$SUPERVISOR_LOG")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$SUPERVISOR_LOG"
}

log "=== Background Supervisor Started ==="
log "Agent PID: $AGENT_PID"
log "Check interval: ${CHECK_INTERVAL}s, Timeout: ${TIMEOUT}s"

if [ -n "$AGENT_PID" ] && ! kill -0 "$AGENT_PID" 2>/dev/null; then
    log "ERROR: Agent PID $AGENT_PID not running"
    exit 1
fi

LAST_ACCESS_CHECK=0

while true; do
    if [ -n "$AGENT_PID" ] && ! kill -0 "$AGENT_PID" 2>/dev/null; then
        log "Agent process exited"
        break
    fi
    
    if [ ! -f "$STATE_FILE" ]; then
        log "WARNING: state.json not found"
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    ACCESS_TIME=$(stat -c %X "$STATE_FILE" 2>/dev/null || stat -f %a "$STATE_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    DIFF=$((NOW - ACCESS_TIME))
    
    if [ "$DIFF" -gt "$TIMEOUT" ] && [ "$LAST_ACCESS_CHECK" -eq 0 ]; then
        log "WARNING: state.json not accessed in ${DIFF}s (timeout: ${TIMEOUT}s)"
        LAST_ACCESS_CHECK=1
    elif [ "$DIFF" -le "$CHECK_INTERVAL" ]; then
        log "OK: state.json accessed recently (${DIFF}s ago)"
        LAST_ACCESS_CHECK=0
    fi
    
    sleep "$CHECK_INTERVAL"
done

log "=== Background Supervisor Stopped ==="
exit 0
