#!/usr/bin/env bash

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
CHECKPOINT_INTERVAL="${CHECKPOINT_INTERVAL:-300}"
CHECKPOINT_DIR="$SUPEROC_DIR/monitoring/checkpoints"
PID_FILE="$SUPEROC_DIR/monitoring/session_checkpoint.pid"
LOG_FILE="$SUPEROC_DIR/monitoring/logs/checkpoint.log"

mkdir -p "$CHECKPOINT_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
echo $$ > "$PID_FILE"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

cleanup() {
    log "Checkpoint process shutting down"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup EXIT INT TERM

log "Starting session checkpoint (interval: ${CHECKPOINT_INTERVAL}s)"

while true; do
    TIMESTAMP=$(date -Iseconds)
    CHECKPOINT_FILE="$CHECKPOINT_DIR/checkpoint_$(date +%Y%m%d_%H%M%S).json"
    
    if [ -f "$SUPEROC_DIR/state.json" ]; then
        cp "$SUPEROC_DIR/state.json" "$CHECKPOINT_FILE" 2>/dev/null || true
        log "Checkpoint saved: $CHECKPOINT_FILE"
        
        if [ -f "$SUPEROC_DIR/logs/latest_session.log" ]; then
            TRANSCRIPT_CHECKPOINT="${CHECKPOINT_FILE/.json/.log}"
            cp "$SUPEROC_DIR/logs/latest_session.log" "$TRANSCRIPT_CHECKPOINT" 2>/dev/null || true
            log "Transcript checkpoint saved: $TRANSCRIPT_CHECKPOINT"
        fi
    else
        log "WARNING: state.json not found, skipping checkpoint"
    fi
    
    sleep "$CHECKPOINT_INTERVAL" &
    wait $!
done
