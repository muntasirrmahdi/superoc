# SuperOC Troubleshooting Guide

## Quick Diagnostics

Run this first when something's wrong:
```bash
~/.superoc/lib/monitor_health.sh
cat ~/.superoc/logs/health.log
```

## Common Issues

### 1. "superoc: command not found"
**Cause**: PATH not set correctly
**Fix**:
```bash
echo 'export PATH="$HOME/.superoc/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 2. "ERROR: Bash 4.0 or newer is required"
**Cause**: macOS ships with Bash 3.2
**Fix**: `brew install bash` or run `/usr/local/bin/bash install.sh`

### 3. "ERROR: Neither 'jq' nor 'python3' was found"
**Fix**: Install jq
- macOS: `brew install jq`
- Ubuntu: `sudo apt install jq`

### 4. "WARNING: Another SuperOC process is compiling state"
**Cause**: Stale lock file
**Fix**: `rm -rf ~/.superoc/.lock`

### 5. Agent boots but forgets identity
**Cause**: 
- Ran `opencode` instead of `superoc opencode`
- PATH not patched
- state.json failed to compile

**Fix**:
```bash
# Always use this:
superoc opencode

# Check PATH:
echo $PATH | grep .superoc

# Verify compiled state:
cat ~/.superoc/state.json

# Manually recompile:
superoc compile
```

### 6. state.json is corrupted or empty
**Fix**:
```bash
rm ~/.superoc/state.json
superoc compile
# Or:
~/.superoc/lib/compile_state.sh
```

### 7. Memory not loading after restart
**Cause**: Templates cleared or state.json not rebuilt
**Fix**:
```bash
# Check templates exist:
cat ~/.superoc/templates/user.md

# Rebuild state:
superoc compile
```

### 8. Remember command not working
**Fix**: Make sure it's in your PATH
```bash
which remember
# If not found, add to PATH as above
```

## Log Locations

| Log | Location |
|-----|----------|
| Health | `~/.superoc/logs/health.log` |
| Audit | `~/.superoc/logs/audit.log` |
| Compliance | `~/.superoc/monitoring/compliance/` |
| State | `~/.superoc/state.json` |
| Backups | `~/.superoc/backups/` |