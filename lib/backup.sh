#!/bin/bash
# SuperOC Backup System
# Creates automated snapshots for data safety
# Usage: lib/backup.sh [--restore|--list]

set -euo pipefail

# CONFIG
SUPEROC_DIR="${SUPEROC_DIR:-$HOME/.superoc}"
BACKUP_DIR="${SUPEROC_DIR}/backups"
TEMPLATE_DIR="${SUPEROC_DIR:-$HOME/.superoc}/templates"
MEMORY_FILES=("user.md" "identity.md" "memory.md")
TODAY=$(date +%Y-%m-%d)
WEEK_START=$(date -d "7 days ago" +%Y-%m-%d)

# Create backup directory
mkdir -p "$BACKUP_DIR"

ACTION="${1:-backup}"

case "$ACTION" in
    --backup|backup)
        echo "=== SuperOC Backup System ==="
        echo "Date: $TODAY"
        
        # Create dated backup
        BACKUP_SUBDIR="$BACKUP_DIR/$TODAY"
        mkdir -p "$BACKUP_SUBDIR"
        
        echo "Backing up templates..."
        
        for file in "${MEMORY_FILES[@]}"; do
            source_file="$TEMPLATE_DIR/$file"
            if [ -f "$source_file" ]; then
                cp "$source_file" "$BACKUP_SUBDIR/$file"
                echo "  Backed up: $file"
            else
                echo "  Missing (skipping): $file"
            fi
        done
        
        # Also backup AGENTS.md template if exists
        AGENTS_TEMPLATE="$TEMPLATE_DIR/AGENTS.md"
        if [ -f "$AGENTS_TEMPLATE" ]; then
            cp "$AGENTS_TEMPLATE" "$BACKUP_SUBDIR/AGENTS.md"
            echo "  Backed up: AGENTS.md"
        fi
        
        # Count backups
        BACKUP_COUNT=$(ls -1 "$BACKUP_DIR" | wc -l)
        
        echo ""
        echo "Backup complete: $BACKUP_SUBDIR"
        echo "Total backups: $BACKUP_COUNT"
        
        # Cleanup old backups (keep last 8)
        OLD_BACKUPS=$(ls -1 "$BACKUP_DIR" | head -n -8)
        if [ -n "$OLD_BACKUPS" ]; then
            echo ""
            echo "Cleaning up old backups (keeping 8)..."
            for old in $OLD_BACKUPS; do
                rm -rf "$BACKUP_DIR/$old"
                echo "  Removed: $old"
            done
        fi
        
        echo ""
        echo "Next backup: $(date -d "7 days" +%Y-%m-%d)"
        ;;
    
    --restore|restore)
        if [ -z "${2:-}" ]; then
            echo "Usage: lib/backup.sh --restore YYYY-MM-DD"
            ls -1 "$BACKUP_DIR"
            exit 1
        fi
        
        RESTORE_DATE="$2"
        RESTORE_DIR="$BACKUP_DIR/$RESTORE_DATE"
        
        if [ ! -d "$RESTORE_DIR" ]; then
            echo "No backup found for: $RESTORE_DATE"
            echo "Available backups:"
            ls -1 "$BACKUP_DIR"
            exit 1
        fi
        
        echo "Restoring from: $RESTORE_DATE"
        
        for file in "${MEMORY_FILES[@]}"; do
            backup_file="$RESTORE_DIR/$file"
            if [ -f "$backup_file" ]; then
                cp "$backup_file" "$TEMPLATE_DIR/$file"
                echo "  Restored: $file"
            fi
        done
        
        if [ -f "$RESTORE_DIR/AGENTS.md" ]; then
            cp "$RESTORE_DIR/AGENTS.md" "$TEMPLATE_DIR/AGENTS.md"
            echo "  Restored: AGENTS.md"
        fi
        
        echo ""
        echo "Restore complete!"
        ;;
    
    --list|list)
        echo "=== Available Backups ==="
        ls -1 "$BACKUP_DIR" | while read dir; do
            count=$(ls -1 "$BACKUP_DIR/$dir" | wc -l)
            echo "  $dir ($count files)"
        done
        ;;
    
    *)
        echo "Usage: lib/backup.sh [--backup|--restore|--list]"
        echo "  --backup     : Create new backup (default)"
        echo "  --restore  : Restore from backup"
        echo "  --list    : List available backups"
        ;;
esac

exit 0