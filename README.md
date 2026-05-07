# SuperOC Memory Stack

[![GitHub stars](https://img.shields.io/github/stars/muntasirrmahdi/superoc?style=social)](https://github.com/muntasirrmahdi/superoc/stargazers)
[![GitHub license](https://img.shields.io/github/license/muntasirrmahdi/superoc)](https://github.com/muntasirrmahdi/superoc/blob/main/LICENSE)
[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

A philosophical prototype exploring how to shift LLM agent memory from the prompt level to the OS level. 

**Affiliation Notice**: SuperOC is an independent project. It is **not** built by the OpenCode team and is **not** affiliated with Anomaly or the official OpenCode project in any way.

**Disclaimer**: This is a personal experiment / proof-of-concept. It is not currently meant for mission-critical production environments.

It works by intercepting the agent's CLI execution, compiling your long-term memory into a locked `state.json`, and dynamically injecting a strict directive into the agent's prompt to force it to read the state before responding.

Read the [ARCHITECTURE.md](ARCHITECTURE.md) for a deep dive.

---

## The TL;DR

**Pros:**
* **Zero Context Collapse**: The agent doesn't have to "remember" to read its memory; the system forces it to.
* **Tool Agnostic**: Works across different CLI-based AI agents using the exact same `state.json`.
* **Local & Private**: Your identity and memory files live on your machine, not in a vendor's cloud database.
* **OS-Level Locking**: Prevents two concurrent agent sessions from corrupting your memory file at the same time.

**Cons:**
* **Terminal Only**: Does not work with GUI editors (Cursor, Windsurf) or web interfaces.
* **Brittle Exit Traps**: Post-session memory extraction relies on catching bash `EXIT` signals, which fail during hard crashes or power loss.
* **Alignment Dependent**: The OS injects the rule, but it still relies on the LLM's behavioral alignment to actually obey the "mandatory" instruction.

---

## Version History

| Version | Status | Notes |
|---------|--------|-------|
| 0.1.x | Experimental | Core functionality proof-of-concept |
| 0.1.1+ | Current | Security fixes, health monitoring |

**Current Version**: 0.1.1-alpha (see [CHANGELOG.md](CHANGELOG.md))

---

## Quick Start: 3-Step Installation

### 1. Run the Installer
```bash
curl -fsSL https://raw.githubusercontent.com/muntasirrmahdi/superoc/main/install.sh | bash
```

### 2. Configure Your Identity
Edit templates in `~/.superoc/templates/`:
- `user.md` - Who you are
- `identity.md` - How the agent should behave
- `memory.md` - Long-term facts

### 3. Start the Agent
```bash
superoc opencode
```

---

## Known Limitations & V2 Roadmap

This is a v0.1 proof-of-concept. Senior engineers will immediately notice these architectural realities:

1. **The Illusion of Guarantee:** There is no physical OS mechanism to force a specific LLM token generation. The "mandatory injection" relies heavily on LLM alignment (penalty avoidance).
2. **The Brittle `trap EXIT`:** Post-session learning relies on `trap EXIT`, which misses `SIGKILL` and Out-Of-Memory (OOM) crashes.
3. **The Bypass Vulnerability:** If a user directly runs `opencode` or `claude` (bypassing the `superoc` wrapper script), the entire memory stack is ignored.
4. **The Stub Learning Loop:** Currently, it acts mostly as a memory *injector*. True autonomous recursive memory distillation is slated for v2.0.

*If you see how to fix these, PRs are welcome.*

---

## Compatibility

Because this is an OS-level wrapper that intercepts execution at the terminal layer, it has strict compatibility boundaries.

**✅ What it Works With:**
* Any **CLI-based** AI agent that executes in a terminal and reads local configuration or prompt files on boot.
* *Examples:* OpenCode, Claude Code, Aider, OpenHands.

**❌ What it Won't Work With:**
* **GUI-based AI Editors:** Cursor, Windsurf, GitHub Copilot. (We cannot intercept their closed-source UI boot sequence).
* **Web Interfaces:** ChatGPT, Claude.ai, Gemini web.
* **API-only implementations:** Scripts that just hit the OpenAI endpoint without a local configuration file to inject into.

### Out-of-the-box Adapters

| Agent | Adapter | Status |
|-------|---------|--------|
| OpenCode | opencode.sh | Tested |
| Claude Code | claudecode.sh | Experimental |

---

## How to Apply This to Any CLI Agent (DIY)

If you use a CLI agent that isn't listed above (like Aider or Goose), you can easily build your own adapter. You don't need to write complex code; you just need to append a specific string to whatever local file the agent reads when it starts.

**The Goal:** Inject this exact payload into the agent's system prompt or local config file:
```text
🚨 MANDATORY FIRST ACTION: Read ~/.superoc/state.json BEFORE responding to ANY user message. VIOLATION = IMMEDIATE FAILURE.
```

**How to do it:**
1. Find out where your agent stores its local instructions (e.g., OpenCode uses `AGENTS.md`, Claude Code uses `.claudecode`).
2. Create a new file in `~/.superoc/lib/adapters/myagent.sh`.
3. Add a simple bash script that appends the payload.

*Example DIY Adapter (`lib/adapters/myagent.sh`):*
```bash
#!/usr/bin/env bash
PAYLOAD="🚨 MANDATORY FIRST ACTION: Read ~/.superoc/state.json BEFORE responding."
CONFIG_FILE="$HOME/.myagent_config.md"

if ! grep -q "MANDATORY FIRST ACTION" "$CONFIG_FILE"; then
    echo -e "\n$PAYLOAD" >> "$CONFIG_FILE"
fi
```
The SuperOC wrapper will handle the rest (compiling the JSON, locking the file, catching the exit).

---

## Uninstallation

```bash
~/.superoc/uninstall.sh
```

---

## Features

- State compilation from markdown templates
- Atomic JSON generation with validation
- Per-user private locking
- Health monitoring and recovery
- Post-session audit hooks
- Agent memory enforcement

---

## Requirements

- Bash 4.0+
- jq or python3 (for JSON)
- POSIX-compliant system