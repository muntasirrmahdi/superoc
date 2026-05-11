#!/usr/bin/env bash

set -e

SUPEROC_DIR="$HOME/.superoc"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Starting SuperOC Installation..."

OS_NAME="$(uname -s)"
echo "=> Detected OS: $OS_NAME"

BASH_VERSION_MAJOR=${BASH_VERSINFO[0]:-0}
if [[ "$BASH_VERSION_MAJOR" -lt 4 ]]; then
    echo "[!] ERROR: Bash 4.0 or newer is required."
    if [[ "$OS_NAME" == "Darwin" ]]; then
        echo "   macOS ships with Bash 3.2. Please install a newer version:"
        echo "   brew install bash"
    fi
    exit 1
fi
echo "=> Bash version: $BASH_VERSION OK"

if ! command -v jq >/dev/null 2>&1; then
    if ! command -v python3 >/dev/null 2>&1; then
        echo "[!] ERROR: Neither 'jq' nor 'python3' was found. One of them is required for JSON compilation."
        echo "   Please install jq (e.g., 'apt install jq' or 'brew install jq') or Python 3."
        exit 1
    else
        echo "=> jq not found, but python3 is available. Will use python3 fallback for JSON compilation."
    fi
else
    echo "=> jq installed: OK"
fi

if command -v flock >/dev/null 2>&1; then
    LOCK_CMD="flock"
elif command -v lockf >/dev/null 2>&1; then
    LOCK_CMD="lockf"
else
    echo "[!] WARNING: 'flock' or 'lockf' not found. Will fallback to POSIX atomic directory locking."
    LOCK_CMD="mkdir"
fi
echo "=> Lock mechanism: $LOCK_CMD"

echo "=> Setting up $SUPEROC_DIR..."
mkdir -p "$SUPEROC_DIR/bin"
mkdir -p "$SUPEROC_DIR/lib/adapters"
mkdir -p "$SUPEROC_DIR/templates"
mkdir -p "$SUPEROC_DIR/scripts"
mkdir -p "$SUPEROC_DIR/monitoring"

if [ -d "$REPO_DIR/bin" ] && [ "$(ls -A "$REPO_DIR/bin")" ]; then
    cp -r "$REPO_DIR/bin/"* "$SUPEROC_DIR/bin/"
else
    echo "[!] ERROR: No files found in $REPO_DIR/bin to copy."
    exit 1
fi

if [ -d "$REPO_DIR/lib" ] && [ "$(ls -A "$REPO_DIR/lib")" ]; then
    cp -r "$REPO_DIR/lib/"* "$SUPEROC_DIR/lib/"
fi

if [ -d "$REPO_DIR/templates" ] && [ "$(ls -A "$REPO_DIR/templates")" ]; then
    cp -r "$REPO_DIR/templates/"* "$SUPEROC_DIR/templates/"
fi

if [ -d "$REPO_DIR/scripts" ] && [ "$(ls -A "$REPO_DIR/scripts")" ]; then
    cp -r "$REPO_DIR/scripts/"* "$SUPEROC_DIR/scripts/"
fi

cp "$REPO_DIR/uninstall.sh" "$SUPEROC_DIR/" 2>/dev/null || echo "[!] WARNING: uninstall.sh not found."
if [ -d "$REPO_DIR/tests" ]; then
    cp -r "$REPO_DIR/tests" "$SUPEROC_DIR/tests"
fi

chmod +x "$SUPEROC_DIR/bin/"* 2>/dev/null || true
chmod +x "$SUPEROC_DIR/lib/"*.sh 2>/dev/null || true
chmod +x "$SUPEROC_DIR/lib/adapters/"*.sh 2>/dev/null || true
chmod +x "$SUPEROC_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$SUPEROC_DIR/lib/compile_state.sh" 2>/dev/null || true

RC_FILE=""
if [[ "$SHELL" == *"zsh"* && -f "$HOME/.zshrc" ]]; then
    RC_FILE="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* && -f "$HOME/.bashrc" ]]; then
    RC_FILE="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    RC_FILE="$HOME/.bash_profile"
fi

if [[ -n "$RC_FILE" ]]; then
    SUPEROC_BIN_PATH="$SUPEROC_DIR/bin"
    if ! grep -qF "$SUPEROC_BIN_PATH" "$RC_FILE"; then
        echo "=> Patching PATH in $RC_FILE"
        echo "" >> "$RC_FILE"
        echo "# SuperOC Memory Stack" >> "$RC_FILE"
        echo "export PATH=\"$SUPEROC_DIR/bin:\$PATH\"" >> "$RC_FILE"
    else
        echo "=> PATH already patched in $RC_FILE"
    fi
else
    echo "[!] WARNING: Could not automatically determine your shell rc file."
    echo "   Please manually add the following line to your profile:"
    echo "   export PATH=\"$SUPEROC_DIR/bin:\$PATH\""
fi

if [[ -x "$SUPEROC_DIR/lib/load_memory.sh" ]]; then
    echo "=> Setting up memory environment..."
    "$SUPEROC_DIR/lib/load_memory.sh" || echo "[!] WARNING: Initial memory setup failed."
    echo "=> Memory environment ready."
fi

echo ""
echo "=> Setting up cron automation..."
CRON_TMP="/tmp/superoc_cron_$(date +%s)"
crontab -l 2>/dev/null > "$CRON_TMP" || true

SUPEROC_CRON="# SuperOC Memory Stack - Automated tasks
0 2 * * * $SUPEROC_DIR/lib/backup.sh >> $SUPEROC_DIR/monitoring/logs/backup_cron.log 2>&1
0 * * * * $SUPEROC_DIR/lib/sync_knowledge.sh >> $SUPEROC_DIR/monitoring/logs/sync_cron.log 2>&1
*/15 * * * * $SUPEROC_DIR/lib/monitor_health.sh >> $SUPEROC_DIR/monitoring/logs/health_cron.log 2>&1"

if ! grep -q "SuperOC Memory Stack" "$CRON_TMP" 2>/dev/null; then
    echo "$SUPEROC_CRON" >> "$CRON_TMP"
    crontab "$CRON_TMP"
    echo "=> Cron jobs installed (daily backup, hourly sync, health check every 15 min)"
else
    echo "=> Cron jobs already installed"
fi
rm -f "$CRON_TMP"

echo ""
echo "[OK] SuperOC Installed Successfully!"
echo "   Please restart your terminal or run: source ${RC_FILE:-~/.bashrc}"
echo "   To start an agent with memory enforced, type: opencode"
echo ""
echo "   NOTE: Edit ~/.superoc/templates/user.md first to set your identity."
echo "   Then your memory will be loaded each session."
