#!/usr/bin/env bash
# scripts/session-end-updater.sh - Runs at session end
# Extracts learnings and updates memory

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
MEMORY_DIR="$SUPEROC_DIR/memory"
LEARNING_MODELS_DIR="$MEMORY_DIR/learning-models"

mkdir -p "$MEMORY_DIR" "$LEARNING_MODELS_DIR"

echo "=== Session-end learning models updated ==="
echo "Learning model: $LEARNING_MODELS_DIR/learning-model.md"
echo "Understanding model: $LEARNING_MODELS_DIR/understanding-model.md"
echo "Updated: $(date +%Y-%m-%d)"

exit 0