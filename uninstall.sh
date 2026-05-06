#!/usr/bin/env bash

set -e

SUPEROC_DIR="$HOME/.superoc"

echo "⚡ Starting SuperOC Uninstallation..."

if [[ ! -d "$SUPEROC_DIR" ]]; then
    echo "=> SuperOC directory not found at $SUPEROC_DIR. Nothing to do."
    exit 0
fi

echo "=> Removing $SUPEROC_DIR..."
rm -rf "$SUPEROC_DIR"

echo "=> Cleaning up PATH entries in shell rc files..."

clean_rc() {
    local rc_file="$1"
    if [[ -f "$rc_file" ]]; then
        if grep -q "SuperOC Memory Stack" "$rc_file"; then
            sed -i.bak '/# SuperOC Memory Stack/d' "$rc_file"
            sed -i.bak '/export PATH="\$HOME\/.superoc\/bin:\$PATH"/d' "$rc_file"
            sed -i.bak '/export PATH="'"$(echo "$SUPEROC_DIR" | sed 's/\//\\\//g')"'\/bin:\$PATH"/d' "$rc_file"
            rm -f "$rc_file.bak"
            echo "   Cleaned $rc_file"
        fi
    fi
}

clean_rc "$HOME/.zshrc"
clean_rc "$HOME/.bashrc"
clean_rc "$HOME/.bash_profile"

echo ""
echo "✅ SuperOC Uninstalled Successfully!"
echo "   Please restart your terminal to apply PATH changes."
