#!/bin/bash
# SuperOC Session Extraction Layer
# Extracts meaningful patterns from session logs for learning models
# Usage: lib/extract_session.sh [LOG_FILE] [OUTPUT_JSON]

set -euo pipefail

# CONFIG: Override via environment or config file
EXTRACT_CONFIG_DIR="${SUPEROC_CONFIG_DIR:-$HOME/.superoc}"
SIGNIFICANT_KEYWORDS="${SIGNIFICANT_KEYWORDS:-FIXED,FIXING,CREATED,IMPLEMENTED,ANALYZED,RESEARCH,DECISION,FOUND,INSIGHT,PATTERN,LEARNING,ENHANCE,DESIGN,ARCHITECTURE,BUILD,DEPLOY,TEST,DEBUG,OPTIMIZE,REFACTOR,PLAN,STRATEGY,SOLUTION,PROBLEM,ISSUE,BUG,ERROR}"
NOISE_PATTERNS="${NOISE_PATTERNS:-Session Started,Initialized,Status: Initialized,User:}"

# Load config if exists
if [ -f "$EXTRACT_CONFIG_DIR/extract.conf" ]; then
    source "$EXTRACT_CONFIG_DIR/extract.conf"
fi

USE_LLM="${USE_LLM:-auto}"
LLM_EXTRACT_PATH="${LLM_EXTRACT_PATH:-$(dirname "$0")/llm_extract.py}"

semantic_extract() {
    local log_file="$1"
    local output_file="$2"
    
    if [ "$USE_LLM" = "no" ]; then
        return 1
    fi
    
    if [ ! -f "$LLM_EXTRACT_PATH" ]; then
        [ "$USE_LLM" = "yes" ] && echo "ERROR: LLM extract not found at $LLM_EXTRACT_PATH" >&2
        return 1
    fi
    
    if ! python3 -c "import sys; sys.path.insert(0, '$(dirname "$LLM_EXTRACT_PATH")'); from llm_extract import extract_with_openai, extract_with_anthropic" 2>/dev/null; then
        [ "$USE_LLM" = "yes" ] && echo "ERROR: LLM dependencies not available" >&2
        return 1
    fi
    
    echo "Using LLM semantic analysis..." >&2
    local temp_output=$(mktemp)
    if python3 "$LLM_EXTRACT_PATH" --transcript "$log_file" --superoc-dir "$EXTRACT_CONFIG_DIR" 2>&1 | tee "$temp_output"; then
        if [ -n "$output_file" ]; then
            grep "Extracted:" "$temp_output" > "$output_file" 2>/dev/null || true
        fi
        rm -f "$temp_output"
        return 0
    else
        rm -f "$temp_output"
        return 1
    fi
}

LOG_FILE="${1:-$HOME/.superoc/logs/$(date +%Y-%m-%d).md}"
OUTPUT_FILE="${2:-}"

# Convert comma-separated keywords to array
IFS=',' read -ra KEYWORDS <<< "$SIGNIFICANT_KEYWORDS"
IFS=',' read -ra NOISE <<< "$NOISE_PATTERNS"

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "{\"summary\": \"No session log found\", \"key_learnings\": \"\", \"new_observations\": \"Log file missing\"}" >&2
    exit 0
fi

LLM_SUCCESS=0
if [ "$USE_LLM" != "no" ]; then
    if semantic_extract "$LOG_FILE" "$OUTPUT_FILE"; then
        LLM_SUCCESS=1
    fi
fi

if [ "$LLM_SUCCESS" -eq 1 ]; then
    exit 0
fi

# Temporary files
TEMP_LOG=$(mktemp)
TEMP_ENTRIES=$(mktemp)

cleanup() {
    rm -f "$TEMP_LOG" "$TEMP_ENTRIES"
}
trap cleanup EXIT

cp "$LOG_FILE" "$TEMP_LOG"

# Extract entries
grep -n "^## \[" "$TEMP_LOG" > "$TEMP_ENTRIES" || true

# Process entries
MEANINGFUL_TITLES=()
MEANINGFUL_BULLETS=()

while IFS= read -r entry_line; do
    line_num=$(echo "$entry_line" | cut -d: -f1)
    title=$(echo "$entry_line" | sed 's/^[0-9]*:## \[[0-9:]*\] //')
    
    [ -z "$title" ] && continue
    
    # Check noise
    is_noise=0
    for noise in "${NOISE[@]}"; do
        if echo "$title" | grep -qiF "$noise"; then
            is_noise=1
            break
        fi
    done
    [ "$is_noise" -eq 1 ] && continue
    
    # Check significance
    is_significant=0
    for keyword in "${KEYWORDS[@]}"; do
        if echo "$title" | grep -qi "$keyword"; then
            is_significant=1
            break
        fi
    done
    
    # Check content for keywords
    if [ "$is_significant" -eq 0 ]; then
        next_line=$(grep -n "^## \[" "$TEMP_LOG" | awk -F: "\$1 > $line_num {print \$1; exit}")
        [ -z "$next_line" ] && next_line=$(($(wc -l < "$TEMP_LOG") + 1))
        content=$(sed -n "${line_num},$((next_line-1))p" "$TEMP_LOG")
        
        for keyword in "${KEYWORDS[@]}"; do
            if echo "$content" | grep -qi "$keyword"; then
                is_significant=1
                break
            fi
        done
    fi
    
    [ "$is_significant" -eq 0 ] && continue
    
    # Extract bullets
    bullets=$(echo "$content" | grep "^- " | sed 's/^- //' | tr '\n' '|' | sed 's/|$//')
    
    MEANINGFUL_TITLES+=("$title")
    MEANINGFUL_BULLETS+=("$bullets")
    
done < "$TEMP_ENTRIES"

# Generate output
if [ ${#MEANINGFUL_TITLES[@]} -eq 0 ]; then
    SUMMARY="No meaningful work detected"
    KEY_LEARNINGS=""
    NEW_OBSERVATIONS="Session contained routine operations"
else
    SUMMARY=$(printf "%s; " "${MEANINGFUL_TITLES[@]}" | sed 's/; $//')
    
    all_bullets=$(printf "%s|" "${MEANINGFUL_BULLETS[@]}" | tr '|' '\n' | grep -v "^$" | head -10)
    if [ -n "$all_bullets" ]; then
        KEY_LEARNINGS=$(echo "$all_bullets" | tr '\n' '; ' | sed 's/; $//')
    fi
    
    # Generate observations
    OBSERVATIONS=()
    
    if echo "$SUMMARY" | grep -qi "FIX\|DEBUG\|BUG\|ERROR"; then
        OBSERVATIONS+=("Debugging/fixing work")
    fi
    
    if echo "$SUMMARY" | grep -qi "CREATE\|BUILD\|IMPLEMENT"; then
        OBSERVATIONS+=("Building/creating new components")
    fi
    
    if echo "$SUMMARY" | grep -qi "ANALYZE\|RESEARCH"; then
        OBSERVATIONS+=("Research/analysis work")
    fi
    
    if echo "$SUMMARY" | grep -qi "PLAN\|DESIGN\|ARCHITECTURE"; then
        OBSERVATIONS+=("Planning/design work")
    fi
    
    OBSERVATIONS+=("Found ${#MEANINGFUL_TITLES[@]} meaningful entries")
    
    if [ ${#OBSERVATIONS[@]} -gt 0 ]; then
        NEW_OBSERVATIONS=$(printf "%s; " "${OBSERVATIONS[@]}" | sed 's/; $//')
    fi
fi

# Output JSON
JSON_OUTPUT=$(cat <<EOF
{
  "summary": "$SUMMARY",
  "key_learnings": "$KEY_LEARNINGS",
  "new_observations": "$NEW_OBSERVATIONS",
  "meaningful_entries_count": ${#MEANINGFUL_TITLES[@]},
  "log_file": "$LOG_FILE",
  "extracted_at": "$(date -Iseconds)"
}
EOF
)

if [ -n "$OUTPUT_FILE" ]; then
    echo "$JSON_OUTPUT" > "$OUTPUT_FILE"
else
    echo "$JSON_OUTPUT"
fi

exit 0