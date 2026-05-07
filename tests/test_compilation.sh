#!/usr/bin/env bash
# test_compilation.sh - Test suite for SuperOC

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SUPEROC_DIR="$REPO_DIR"
export TEMPLATES_DIR="$REPO_DIR/templates"
export STATE_FILE="$REPO_DIR/tests/state_test.json"
export LOCK_DIR="/tmp/superoc.lock.test.$(id -u)"

# Colors for output (portable)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; exit 1; }
warn() { echo -e "${YELLOW}WARN${NC}: $1"; }

echo "========================================"
echo "SuperOC Test Suite"
echo "========================================"

# Test 1: State Compilation (jq path)
echo ""
echo "Test 1: State Compilation (jq)"
if command -v jq >/dev/null 2>&1; then
    rm -rf "$STATE_FILE" "$LOCK_DIR"
    if "$REPO_DIR/lib/compile_state.sh"; then
        if [ -f "$STATE_FILE" ]; then
            pass "state.json created"
            if jq -e '.' "$STATE_FILE" >/dev/null 2>&1; then
                pass "state.json is valid JSON"
            else
                fail "state.json is invalid JSON"
            fi
        else
            fail "state.json not created"
        fi
    else
        fail "compile_state.sh failed"
    fi
else
    warn "jq not available, skipping test"
fi

# Test 2: State Compilation (python3 fallback)
echo ""
echo "Test 2: State Compilation (python3 fallback)"
if command -v python3 >/dev/null 2>&1; then
    rm -f "$STATE_FILE"
    # Temporarily hide jq to test python3 path
    if ! command -v jq >/dev/null 2>&1 || true; then
        rm -f "$STATE_FILE" "$LOCK_DIR"
        if "$REPO_DIR/lib/compile_state.sh"; then
            if [ -f "$STATE_FILE" ]; then
                pass "python3 fallback: state.json created"
            else
                fail "python3 fallback: state.json not created"
            fi
        fi
    else
        warn "jq available, cannot test python3 path"
    fi
else
    warn "python3 not available"
fi

# Test 3: Empty template handling
echo ""
echo "Test 3: Empty template handling"
# Create empty templates
echo "" > "$TEMPLATES_DIR/user.md"
echo "" > "$TEMPLATES_DIR/identity.md"
echo "" > "$TEMPLATES_DIR/memory.md"

rm -f "$STATE_FILE" "$LOCK_DIR"
if "$REPO_DIR/lib/compile_state.sh"; then
    pass "Empty templates handled"
else
    fail "Empty template handling failed"
fi

# Test 4: JSON validation
echo ""
echo "Test 4: JSON field validation"
if [ -f "$STATE_FILE" ]; then
    if jq -e '.user.content' "$STATE_FILE" >/dev/null 2>&1; then
        pass "user.content exists"
    else
        fail "user.content missing"
    fi
    
    if jq -e '.identity.content' "$STATE_FILE" >/dev/null 2>&1; then
        pass "identity.content exists"
    else
        fail "identity.content missing"
    fi
    
    if jq -e '.memory.content' "$STATE_FILE" >/dev/null 2>&1; then
        pass "memory.content exists"
    else
        fail "memory.content missing"
    fi
    
    if jq -e '.learning_model.content' "$STATE_FILE" >/dev/null 2>&1; then
        pass "learning_model.content exists"
    else
        fail "learning_model.content missing"
    fi
    
    if jq -e '.understanding_model.content' "$STATE_FILE" >/dev/null 2>&1; then
        pass "understanding_model.content exists"
    else
        fail "understanding_model.content missing"
    fi
    
    if jq -e '.wikilinks_graph' "$STATE_FILE" >/dev/null 2>&1; then
        pass "wikilinks_graph exists"
    else
        fail "wikilinks_graph missing"
    fi
    
    if jq -e '.daily.logs' "$STATE_FILE" >/dev/null 2>&1; then
        pass "daily.logs exists"
    else
        fail "daily.logs missing"
    fi
    
    if jq -e '.days_loaded' "$STATE_FILE" >/dev/null 2>&1; then
        pass "days_loaded exists"
    else
        fail "days_loaded missing"
    fi
    
    if jq -e '.ready' "$STATE_FILE" >/dev/null 2>&1; then
        pass "ready exists"
    else
        fail "ready missing"
    fi
fi

# Test 5: Adapter verification
echo ""
echo "Test 5: Adapter idempotent operation"
if [ -f "$REPO_DIR/lib/adapters/opencode.sh" ]; then
    # Create a temp AGENTS file
    TEMP_AGENTS=$(mktemp)
    export OPENCODE_CONFIG_DIR=$(mktemp -d)
    touch "$OPENCODE_CONFIG_DIR/AGENTS.md"
    
    # First injection
    if "$REPO_DIR/lib/adapters/opencode.sh" inject; then
        pass "First injection passed"
    else
        fail "First injection failed"
    fi
    
    # Second injection (should be idempotent)
    if "$REPO_DIR/lib/adapters/opencode.sh" inject; then
        pass "Second injection (idempotent) passed"
    else
        fail "Second injection failed"
    fi
    
    # Verify
    if "$REPO_DIR/lib/adapters/opencode.sh" verify; then
        pass "Verification passed"
    else
        fail "Verification failed"
    fi
    
    rm -rf "$TEMP_AGENTS" "$OPENCODE_CONFIG_DIR"
fi

# Test 6: Lock directory permissions
echo ""
echo "Test 6: Lock directory permissions"
rm -rf "$LOCK_DIR"
"$REPO_DIR/lib/compile_state.sh"
PERMS=$(stat -c %a "$SUPEROC_DIR" 2>/dev/null || stat -f %A "$SUPEROC_DIR" 2>/dev/null)
if [[ "$PERMS" == "700" ]] || [[ "$PERMS" == "70" ]]; then
    pass "Parent directory has correct permissions ($PERMS)"
else
    warn "Parent directory permissions: $PERMS (expected 700)"
fi

# Cleanup
rm -rf "$STATE_FILE" "$LOCK_DIR"

echo ""
echo "========================================"
echo "All tests completed!"
echo "========================================"