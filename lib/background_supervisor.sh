#!/usr/bin/env bash

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="$SUPEROC_DIR/state.json"
SUPERVISOR_LOG="$SUPEROC_DIR/monitoring/logs/supervisor.log"
CHECK_INTERVAL=60
TIMEOUT=300
AGENT_PARENT_PID="${1:-}"
AGENT_NAME="${2:-}"
INTERVENTION_ENABLED="${SUPERVISOR_INTERVENTION:-1}"
MAX_VIOLATIONS=3

mkdir -p "$(dirname "$SUPERVISOR_LOG")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$SUPERVISOR_LOG"
}

# Resolve actual agent PID by looking at children of the wrapper
get_agent_pid() {
    if [ -z "$AGENT_PARENT_PID" ]; then return 0; fi
    
    # The wrapper starts 'script', which then starts the agent.
    # Hierarchy: Wrapper ($AGENT_PARENT_PID) -> script -> agent
    
    local script_pid
    script_pid=$(pgrep -P "$AGENT_PARENT_PID" | grep -v "$$" | head -n 1)
    
    if [ -n "$script_pid" ]; then
        # Check if script has a child (the actual agent)
        local agent_pid
        agent_pid=$(pgrep -P "$script_pid" | head -n 1)
        
        if [ -n "$agent_pid" ]; then
            echo "$agent_pid"
            return 0
        fi
        
        # Fallback to script PID if no child found yet
        echo "$script_pid"
        return 0
    fi
    
    return 1
}

violation_count=0

check_bypass() {
    local pid=$(get_agent_pid)
    if [ -z "$pid" ] || [ ! -d "/proc/$pid" ]; then
        return 0
    fi
    if [ -r "/proc/$pid/environ" ]; then
        # Check environment of the resolved agent process
        if tr '\0' '\n' < "/proc/$pid/environ" | grep -q "^SUPEROC_ACTIVE=1$"; then
            return 0
        else
            return 1
        fi
    fi
    return 0
}

intervene() {
    local pid=$(get_agent_pid)
    if [ -z "$pid" ]; then return 0; fi
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
log "Wrapper PID: $AGENT_PARENT_PID"
log "Agent Name: $AGENT_NAME"
log "Check interval: ${CHECK_INTERVAL}s, Timeout: ${TIMEOUT}s"
log "Intervention enabled: $INTERVENTION_ENABLED"

if [ -n "$AGENT_PARENT_PID" ] && ! kill -0 "$AGENT_PARENT_PID" 2>/dev/null; then
    log "ERROR: Wrapper PID $AGENT_PARENT_PID not running"
    exit 1
fi

# Initial check
if ! check_bypass; then
    violation_count=$((violation_count + 1))
    log "VIOLATION #$violation_count: Agent running without SUPEROC_ACTIVE (immediate check)"
fi

LAST_ACCESS_CHECK=0

while true; do
    if [ -n "$AGENT_PARENT_PID" ] && ! kill -0 "$AGENT_PARENT_PID" 2>/dev/null; then
        log "Wrapper process exited"
        break
    fi
    
    if ! check_bypass; then
        violation_count=$((violation_count + 1))
        log "VIOLATION #$violation_count: Agent running without SUPEROC_ACTIVE"
        if [ "$violation_count" -ge "$MAX_VIOLATIONS" ]; then
            intervene "" "Agent bypassed SuperOC wrapper (violation $violation_count/$MAX_VIOLATIONS)"
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
