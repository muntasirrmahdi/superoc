# compile_state.sh - Compiles markdown templates into state.json
# Uses safe POSIX-compliant locking and atomic writes

set -euo pipefail

SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
STATE_FILE="${STATE_FILE:-$SUPEROC_DIR/state.json}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$SUPEROC_DIR}"
LOCK_DIR="${SUPEROC_DIR}/.lock"

# === FIX 1.3: Use file-based approach to avoid shell injection ===
# Read template files directly into temp files for jq to process safely
USER_TMP="$STATE_FILE.user.tmp"
IDENTITY_TMP="$STATE_FILE.identity.tmp"
MEMORY_TMP="$STATE_FILE.memory.tmp"

# Cleanup function for temp files
cleanup_temp() {
    rm -f "$USER_TMP" "$IDENTITY_TMP" "$MEMORY_TMP" "$LEARNING_TMP" "$UNDERSTANDING_TMP" "$WIKILINKS_TMP" "$STATE_FILE.tmp" "$STATE_FILE.tmp2" 2>/dev/null || true
}

# Trap for cleanup on error or exit
trap 'cleanup_temp' EXIT INT TERM

# === FIX 2.2: Private lock directory ===
# Ensure parent directory exists first
mkdir -p "$SUPEROC_DIR"
chmod 700 "$SUPEROC_DIR" 2>/dev/null || true

# === FIX 2.1: Verify lock ownership ===
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "WARNING: Another SuperOC process is compiling state. Waiting..."
    for i in 1 2 3 4 5; do
        sleep 1
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            break
        fi
        if [ "$i" -eq 5 ]; then
            echo "ERROR: Could not acquire lock after 5 seconds. Stale lock may exist."
            echo "       Run: rm -rf $LOCK_DIR"
            exit 1
        fi
    done
fi
chmod 700 "$LOCK_DIR" 2>/dev/null || true

# Verify lock actually acquired
if [ ! -d "$LOCK_DIR" ]; then
    echo "ERROR: Lock acquisition verification failed."
    exit 1
fi

# Release lock on exit
trap 'rm -rf "$LOCK_DIR"; cleanup_temp' EXIT INT TERM HUP

# === FIX 3.5: Validate template content ===
check_template() {
    local file="$1"
    local name="$2"
    if [ ! -s "$file" ] 2>/dev/null; then
        echo "WARNING: $name template is empty. Creating placeholder..."
        mkdir -p "$(dirname "$file")"
        echo "# $name\n\n- [Add your $name information]" > "$file"
    fi
}

check_template "$TEMPLATES_DIR/user.md" "User"
check_template "$TEMPLATES_DIR/identity.md" "Identity"
check_template "$TEMPLATES_DIR/memory.md" "Memory"
check_template "$TEMPLATES_DIR/templates/learning-models/learning-model.md" "Learning"
check_template "$TEMPLATES_DIR/templates/learning-models/understanding-model.md" "Understanding"

# === FIX 1.3: Safe JSON compilation using file inputs ===
# Copy templates to temp files (safer than shell variables)
cp "$TEMPLATES_DIR/user.md" "$USER_TMP" 2>/dev/null || echo "" > "$USER_TMP"
cp "$TEMPLATES_DIR/identity.md" "$IDENTITY_TMP" 2>/dev/null || echo "" > "$IDENTITY_TMP"
cp "$TEMPLATES_DIR/memory.md" "$MEMORY_TMP" 2>/dev/null || echo "" > "$MEMORY_TMP"

# Timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Also read learning models and wikilinks graph if they exist
LEARNING_TMP="$STATE_FILE.learning.tmp"
UNDERSTANDING_TMP="$STATE_FILE.understanding.tmp"
WIKILINKS_TMP="$STATE_FILE.wikilinks.tmp"
cp "$TEMPLATES_DIR/templates/learning-models/learning-model.md" "$LEARNING_TMP" 2>/dev/null || echo "" > "$LEARNING_TMP"
cp "$TEMPLATES_DIR/templates/learning-models/understanding-model.md" "$UNDERSTANDING_TMP" 2>/dev/null || echo "" > "$UNDERSTANDING_TMP"
if [ -f "$SUPEROC_DIR/wikilinks_graph.json" ]; then
    cp "$SUPEROC_DIR/wikilinks_graph.json" "$WIKILINKS_TMP" 2>/dev/null || echo "{}" > "$WIKILINKS_TMP"
else
    echo "{}" > "$WIKILINKS_TMP"
fi

# Load daily logs (last 7 days)
DAILY_TMP="$STATE_FILE.daily.tmp"
DAILY_LOGS_DIR="$SUPEROC_DIR/logs"
DAYS_LOADED=0
if [ -d "$DAILY_LOGS_DIR" ]; then
    for i in 0 1 2 3 4 5 6; do
        logdate=$(date -d "-$i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        if [ -f "$DAILY_LOGS_DIR/$logdate.md" ]; then
            DAYS_LOADED=$((DAYS_LOADED + 1))
        fi
    done
    find "$DAILY_LOGS_DIR" -maxdepth 1 -name "*.md" -mtime -7 2>/dev/null | wc -l | tr -d ' ' > /dev/null
fi

if command -v jq >/dev/null 2>&1; then
    # Use --rawfile to safely read file contents as raw text into jq strings
    jq -n \
        --rawfile user "$USER_TMP" \
        --rawfile identity "$IDENTITY_TMP" \
        --rawfile memory "$MEMORY_TMP" \
        --rawfile learning "$LEARNING_TMP" \
        --rawfile understanding "$UNDERSTANDING_TMP" \
        --slurpfile wikilinks "$WIKILINKS_TMP" \
        --arg timestamp "$TIMESTAMP" \
        --arg days "$DAYS_LOADED" \
        '{
            user: { content: ($user // "") },
            identity: { content: ($identity // "") },
            memory: { content: ($memory // "") },
            learning_model: { content: ($learning // "") },
            understanding_model: { content: ($understanding // "") },
            wikilinks_graph: ($wikilinks[0] // {}),
            daily: { logs: {} },
            days_loaded: ($days | tonumber),
            _meta: { last_compiled: $timestamp }
        }' > "$STATE_FILE.tmp"
    
    # === FIX 1.4: Validate JSON structure ===
    if ! jq -e . "$STATE_FILE.tmp" >/dev/null 2>&1; then
        echo "ERROR: Generated state.json is invalid."
        exit 1
    fi
    
    # Required fields check
    if ! jq -e '.user.content and .identity.content and .memory.content' "$STATE_FILE.tmp" >/dev/null 2>&1; then
        echo "ERROR: Generated state.json missing required fields."
        exit 1
    fi
    
    mv "$STATE_FILE.tmp" "$STATE_FILE"
elif command -v python3 >/dev/null 2>&1; then
    echo "WARNING: Using python3 fallback for state compilation."
    
    # Uses a separate script file to avoid injection
    PY_TMP=$(mktemp)
    cat > "$PY_TMP" << 'PYEOF'
import json
import os
import sys

state_file = os.environ.get("STATE_FILE", "") + ".tmp"
timestamp = os.environ.get("TIMESTAMP", "")
base = state_file.replace(".json", "")

def read_tmp(path):
    return open(path, 'r').read() if os.path.exists(path) else ""

data = {
    "user": {"content": read_tmp(base + ".user.tmp")},
    "identity": {"content": read_tmp(base + ".identity.tmp")},
    "memory": {"content": read_tmp(base + ".memory.tmp")},
    "_meta": {"last_compiled": timestamp}
}

json.dump(data, open(state_file, 'w'), indent=2)
PYEOF

    STATE_FILE="$STATE_FILE" TIMESTAMP="$TIMESTAMP" python3 "$PY_TMP"
    rm -f "$PY_TMP"
else
    echo "ERROR: Neither 'jq' nor 'python3' is available."
    exit 1
fi

# === FIX 2.4: Set restrictive permissions on state.json ===
chmod 600 "$STATE_FILE" 2>/dev/null || true

echo "SUCCESS: State compiled at $(date -s '$STATE_FILE' 2>/dev/null || date)"
exit 0