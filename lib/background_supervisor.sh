#!/usr/bin/env bash

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"
SUPERVISOR_LOG="$SUPEROC_DIR/monitoring/logs/supervisor.log"
CHECK_INTERVAL=60
TIMEOUT=300
AGENT_PID="${1:-}"
INTERVENTION_ENABLED="${SUPERVISOR_INTERVENTION:-1}"
MAX_VIOLATIONS=3

mkdir -p "$(dirname "$SUPERVISOR_LOG")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$SUPERVISOR_LOG"
}

violation_count=0

check_bypass() {
    local pid="$1"
    if [ ! -d "/proc/$pid" ]; then
        return 0
    fi
    if [ -r "/proc/$pid/environ" ]; then
        if grep -q "SUPEROC_ACTIVE=1" "/proc/$pid/environ" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
    return 0
}

intervene() {
    local pid="$1"
    local reason="$2"
    log "INTERVENTION: $reason"
    if [ "$INTERVENTION_ENABLED" -eq 1 ]; then
        log "Sending SIGTERM to agent PID $pid"
        kill -TERM "$pid" 2>/dev/null || true
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            log "Agent still alive, sending SIGKILL"
            kill -KILL "$pid" 2>/dev/null || true
        fi
    else
        log "Intervention disabled, logging only"
    fi
}

log "=== Background Supervisor Started ==="
log "Agent PID: $AGENT_PID"
log "Check interval: ${CHECK_INTERVAL}s, Timeout: ${TIMEOUT}s"
log "Intervention enabled: $INTERVENTION_ENABLED"

if [ -n "$AGENT_PID" ] && ! kill -0 "$AGENT_PID" 2>/dev/null; then
    log "ERROR: Agent PID $AGENT_PID not running"
    exit 1
fi

if [ -n "$AGENT_PID" ] && ! check_bypass "$AGENT_PID"; then
    violation_count=$((violation_count + 1))
    log "VIOLATION #$violation_count: Agent running without SUPEROC_ACTIVE (immediate check)"
fi

LAST_ACCESS_CHECK=0

while true; do
    if [ -n "$AGENT_PID" ] && ! kill -0 "$AGENT_PID" 2>/dev/null; then
        log "Agent process exited"
        break
    fi
    
    if [ -n "$AGENT_PID" ] && ! check_bypass "$AGENT_PID"; then
        violation_count=$((violation_count + 1))
        log "VIOLATION #$violation_count: Agent running without SUPEROC_ACTIVE"
        if [ "$violation_count" -ge "$MAX_VIOLATIONS" ]; then
            intervene "$AGENT_PID" "Agent bypassed SuperOC wrapper (violation $violation_count/$MAX_VIOLATIONS)"
            break
        fi
    else
        violation_count=0
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
