# SuperOC Troubleshooting Guide

## Installation Issues

### 1. "ERROR: Bash 4.0 or newer is required"
**Symptom**: The install.sh script fails on macOS with a bash version error.
**Cause**: macOS natively ships with Bash 3.2 due to GPL licensing restrictions.
**Solution**: `brew install bash` or run `/usr/local/bin/bash install.sh`

### 2. "ERROR: Neither 'jq' nor 'python3' was found"  
**Symptom**: install.sh fails.
**Solution**: Install jq (`brew install jq` or `sudo apt install jq`) or Python 3.

## Execution Issues

### 1. The Agent Boots but Forgets Its Identity
**Cause**: 
A) Ran agent directly instead of `superoc <agent>`
B) `$PATH` not patched correctly
C) state.json failed to compile

**Solution**:
1. Always use: `superoc opencode` not just `opencode`
2. Check: `echo $PATH | grep .superoc`
3. Verify: `cat ~/.superoc/state.json`

### 2. "WARNING: Another SuperOC process is compiling state"
**Cause**: Background post-session audit running.
**Solution**: Wait up to 5 seconds. Or: `rm -rf /tmp/superoc.lock.*`

### 3. State.json is Corrupted
**Solution**: 
```bash
rm ~/.superoc/state.json
superoc opencode  # Recompiles automatically
```
Or run: `~/.superoc/lib/compile_state.sh`

## Health Check
Run health check manually:
```bash
~/.superoc/lib/monitor_health.sh
cat ~/.superoc/logs/health.log
```

## Log Locations
- Audit log: `~/.superoc/logs/audit.log`
- Health log: `~/.superoc/logs/health.log`
- State: `~/.superoc/state.json`