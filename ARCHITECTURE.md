# Document 1: OS-Level Deterministic Imprinting (The Soul)

## The Core Philosophy
Large Language Models are inherently probabilistic. If you rely on a system prompt to maintain an agent's memory, identity, or discipline across hundreds of sessions, the model will eventually drift, hallucinate, or suffer from context collapse. 

This project explores the hypothesis that **identity and memory shouldn't just be suggestions within the prompt; they can be treated as system-level requirements verified by the OS.**

We are testing an **OS-Level High-Probability Compliance Engine** prototype. By using native UNIX mechanisms (bash wrappers, file locks, atomic writes, and EXIT traps), we attempt to verify the agent's context and inject a compiled truth state into its environment before execution begins.

---

## The Architecture: How It Works

This open-source blueprint intercepts the standard execution of agentic coding tools (like OpenCode, Claude Code, or Aider) and wraps them in a deterministic lifecycle.

### 1. The Pre-Flight Wrapper (The Imprint)
Instead of running the agent directly, the user runs a wrapper script (`superoc`).
This script performs rigorous pre-flight checks:

1. **State Compilation**: A background script aggregates data from various markdown files (Identity, Long-term Memory, User Context) into a single, compact `state.json`.
2. **File Locking**: Uses `flock` to ensure no two sessions can corrupt the memory state simultaneously.
3. **Mandatory Injection**: The wrapper dynamically injects a strict directive into the agent's core instructions file (e.g., `AGENTS.md`).
   * *The Directive*: `"🚨 MANDATORY FIRST ACTION: Read ~/.superoc/state.json BEFORE responding to ANY user message. VIOLATION = IMMEDIATE FAILURE."*

### 2. The Execution Phase (The Bound Agent)
When the agent boots, its underlying framework feeds it the newly modified instructions file. The LLM is explicitly warned with "immediate failure" if it does not read `state.json`. Because modern LLMs are highly instruction-aligned, this prompt-level threat strongly biases its first autonomous action to be a `read_file` tool call.

* **Result**: The agent loads its entire long-term memory, identity, and current goals into its working context window with high reliability, significantly reducing initial hallucination before the user has even spoken. *(Note: This relies on LLM alignment compliance; there is no physical OS mechanism to force a specific token generation).*

### 3. The Post-Flight Trap (The Learning Loop)
How does the system remember what happened during the session? 

The wrapper script utilizes a bash `trap EXIT` mechanism. When the user closes the agent (via `exit` or `Ctrl+C`), the OS intercepts the termination signal and fires a teardown sequence:

1. **Log Extraction**: The system parses the session's chat transcript.
2. **Background Distillation**: A lightweight, background LLM process (the "Learning Parser") reads the transcript. It extracts new facts, updated preferences, or corrected mistakes.
3. **Atomic State Update**: The background process atomically updates the source markdown files (Memory, User Context), ensuring that the next time the wrapper is called, `state.json` reflects the newly learned realities.

---

## Technical Blueprint: Repository Structure

To open-source this, the repository should be structured as a drop-in installation script for Linux/macOS environments:

```text
superoc-memory-stack/
├── install.sh                  # Sets up directories, crons, and aliases
├── bin/
│   └── superoc                 # The main bash wrapper (intercepts the agent CLI)
├── lib/
│   ├── compile_state.sh        # Compiles markdown into state.json safely
│   ├── post_session_audit.sh   # The EXIT trap script for parsing logs
│   └── monitor_health.sh       # Background daemon checking file locks and PIDs
├── templates/
│   ├── USER.md                 # Template: Who the user is
│   ├── IDENTITY.md             # Template: Who the agent is
│   └── MEMORY.md               # Template: Long-term facts
└── README.md                   # Installation & Architecture Guide
```

## Why This Beats Standard "Memory" Features

Most agent tools attempt to handle memory natively by keeping an internal SQLite database or vector store, relying on the LLM to "decide" when to query its memory. 

**The SuperOC approach shifts the burden to the OS:**
1. **Zero Guesswork**: The agent doesn't "decide" to check its memory unprompted. The OS injects a strict rule verifying the state compilation is ready upon boot.
2. **Tool Agnostic**: Because this operates at the bash layer, it works with *any* CLI-based LLM agent that reads local config files.
3. **Pre-flight Integrity**: If the state compiler fails, the bash wrapper can (and ideally should) abort the launch. By checking the exact environment state beforehand, we minimize the risk of the agent starting in an amnesiac state.

This is the foundational layer. By securing the agent's identity via OS-level verification, we pave the way for Phase 2: The Waterfall Caching Engine.

---

## Architectural Fragilities & Mitigation

While the architecture drastically improves compliance via the OS, it relies on underlying system behaviors that require careful handling in an open-source distribution. It is not infallible.

### 1. The Wrapper Bypass Vulnerability
The entire system's integrity relies on the user invoking the wrapper script (`superoc`). If a user accidentally runs the underlying agent directly (e.g., calling `opencode` or `claude` bypassing the wrapper bin path), all memory compilation and enforcement are bypassed.

**Mitigation Protocol:** 
The setup script must map the system's `PATH` to override the default binary, or the wrapper must pass a secure environment variable (e.g., `SUPEROC_ACTIVE=1`) that the agent's internal prompt relies on, breaking gracefully if missing.

### 2. The `trap EXIT` Edge Cases
The post-flight learning loop depends on catching the agent's exit. However, `trap EXIT` alone is insufficient:
- **Caught:** `SIGTERM` (15), graceful exit, and (usually) `SIGINT` (Ctrl+C).
- **Missed:** `SIGKILL` (9), out-of-memory (OOM) killer terminations, and abrupt SSH/terminal disconnects (`SIGHUP`).

**Mitigation Protocol:** 
The wrapper must bind multiple signals. Additionally, a future implementation requires a periodic checkpoint cronjob to ensure state isn't lost during hard kills (this cronjob is a planned feature, not natively present in the v1 bash script).
```bash
# Strict trap binding
trap 'post_session_audit' EXIT INT TERM HUP
```

### 3. Fail-Open Compilation
Currently, standard implementations of this wrapper often fail "open." If `opencode-memory-loader.sh` fails, the bash script might log a warning but still boot the agent. 

**Mitigation Protocol:**
The wrapper must be configured with a strict `set -e` or an explicit abort if verification fails, guaranteeing the agent never runs with a broken memory state.

### 4. OS Portability & Locking Failures
The architecture relies on atomic file operations to compile `state.json`. 
- **The `flock` problem:** `flock` is native to Linux but missing or behaves differently on macOS and BSD systems (which use `shlock` or `lockf`). 
- **Bash Versions:** macOS ships with an ancient Bash 3.2 (GPLv2), which lacks native associative arrays and `pipefail` features.

**Mitigation Protocol:** 
The setup script must dynamically resolve the lock command and enforce a minimum bash version.
```bash
if command -v flock >/dev/null 2>&1; then
    LOCK_CMD="flock"
elif command -v lockf >/dev/null 2>&1; then
    LOCK_CMD="lockf"
else
    # Fallback to atomic directory creation (POSIX compliant)
    LOCK_CMD="mkdir" 
fi
```

### 5. The Fragility of Dynamic Injection
Injecting the "MUST READ" rule into wildly different agent configurations (OpenCode's `AGENTS.md`, Claude Code's `.claudecode`, OpenHands' workspace) is structurally brittle. Agents parse system prompts differently; some prepend, some append, and some overwrite.

**Mitigation Protocol:**
Instead of raw sed/awk replacements on arbitrary config files, the architecture defines a standard adapter interface. Each supported agent gets a dedicated integration script (`adapters/opencode.sh`, `adapters/claudecode.sh`) that understands the exact injection boundary for that specific tool.
