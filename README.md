# 🧠 Synapse Agents

> **Unified Multi-Agent Orchestration & Zero-Token Engineering Guardrails for Antigravity, Claude Code & Cursor**  
> 🌐 **Language / Dil:** **[🇬🇧 English](README.md)** | [🇹🇷 Türkçe](README.tr.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Architecture: Chief + 4 Subagents](https://img.shields.io/badge/Architecture-Chief_%2B_4_Agents-8A2BE2.svg)](#-agent-matrix--roles)
[![Model: Gemini 3.8 Flash](https://img.shields.io/badge/Model-Gemini_3.8_Flash-FF6F00.svg)](#-agent-matrix--roles)
[![OS Guards: 0--Token](https://img.shields.io/badge/OS_Guards-0--Token_Bash-success.svg)](#-0-token-os-shields--progressive-memory)
[![Compatibility: Triple--Platform](https://img.shields.io/badge/Compatibility-Antigravity_%7C_Claude_Code_%7C_Cursor-brightgreen.svg)](#-triple-platform-support)

---

## 🌐 Overview

**`synapse-agents`** is an enterprise-grade multi-agent engineering framework that transforms AI-assisted software development from hit-or-miss prompt experiments into a deterministic, surgical, and production-tested engineering discipline.

Designed for modern IDEs and autonomous development environments, the framework operates through a **Hands-Off Chief Architect** coordinating **4 Universal Subagents (`explorer`, `planner`, `coder`, `reviewer`)** exclusively running on **Gemini 3.8 Flash** (High & Medium Effort modes). Instead of exhausting the LLM context window with raw code files, `synapse-agents` fuses the proven core principles of 5 prominent open-source paradigms into a single, cohesive developer stack.

---

## 🏛️ Architectural Genesis: How & Why We Built Synapse Agents

Every resilient engineering system is born out of frustration with existing tools. In our daily production workflows, we observed three systemic failure modes when letting AI models write code:

1. **Context Window Exhaustion & Hallucination:** Asking a single lead conversational model to explore files, devise plans, write code across layers, and run tests rapidly inflates its context window with 20–30 raw source files and thousands of terminal output lines. The model inevitably suffers from recency bias, hallucinated API contracts, and catastrophic forgetting.
2. **Speculative Ad-Hoc Patching:** Without a mandatory root-cause isolation phase, models guess solutions and apply hasty symptom patches. One patch breaks another module, causing endless debugging loops.
3. **Bloated Abstractions & Unchecked Scope:** AI code generators eagerly introduce unneeded factory patterns, redundant DTO layers, single-use interfaces, and untrusted third-party dependencies that inflate tech debt.

### The 5-Repo Source Code Investigation

Rather than blindly adopting an existing framework or reinventing the wheel from scratch, we started from our local production setup (**ECC-Lite**—which already pioneered zero-token OS bash shields, domain instincts, and stateless MCP memory). We then cloned and deeply analyzed the source code of the 5 most popular engineering repositories in the open-source agentic ecosystem:

1. **[obra/superpowers](https://github.com/obra/superpowers)**
2. **[DietrichGebert/ponytail](https://github.com/dietrichgebert/ponytail)**
3. **[multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)**
4. **[thedotmack/claude-mem](https://github.com/thedotmack/claude-mem)**
5. **[JuliusBrussee/caveman](https://github.com/juliusbrussee/caveman)**

### The Architectural Synthesis & Rejection Matrix

Instead of adopting any single project dogma, we extracted the crowning jewels of each philosophy while ruthlessly pruning their operational liabilities:

| Source Repository | Extracted & Integrated Principle | Why We Integrated It into Synapse Agents | What We Deliberately Rejected & Why |
|---|---|---|---|
| **[obra/superpowers](https://github.com/obra/superpowers)** | **Systematic Debugging & The Verification Gate** | The iron law: *"No completion claims without fresh verification evidence."* We mandated automated test/build commands with exit code 0 evidence before any task is marked done. | Heavy agent orchestration scripts with rigid Python assumptions; we redesigned all workflows around decoupled, language-agnostic subagents. |
| **[DietrichGebert/ponytail](https://github.com/dietrichgebert/ponytail)** | **Ponytail Minimalism, YAGNI & Debt Ledger** | Relentlessly eliminates redundant abstractions, single-use factories, and unvetted third-party libraries. All intentional shortcuts are recorded with `// shortcut: <limit>, <trigger>`. | Single-file script execution limits; we elevated Ponytail into a full **Caller-Aware Review** stage and **Scope Discovery** pipeline. |
| **[multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)** | **Karpathy Surgical Changes & Low Cognitive Load** | Edits must touch only the precise lines required for the change. Neighboring code, unrelated formatting, and non-pertinent comments remain completely untouched. | Monolithic execution prompts; we isolated surgical coding into dedicated, parallel-capable `coder` subagents. |
| **[thedotmack/claude-mem](https://github.com/thedotmack/claude-mem)** | **2-Stage Progressive Memory Retrieval** | Instead of flooding the LLM context with entire documentation libraries, we query a lightweight topic index first, then retrieve only the exact required sections. | **Rejected the Daemon:** Background daemons (Bun, SQLite, ChromaDB, vector embeddings) cause socket leaks, runaway memory footprints, zombie processes, and CPU polling. We implemented the progressive concept as a zero-dependency, on-demand Python MCP server (`ecc-lite-brain`). |
| **[JuliusBrussee/caveman](https://github.com/juliusbrussee/caveman)** | *Conceptual Token Economy* | Inspired the pursuit of high token efficiency and zero context waste. | **Rejected the Methodology (Grammar Butchery):** Forcing models into telegraphic "caveman" speech degrades complex chain-of-thought, semantic nuance, and deep architectural reasoning in frontier models (Gemini 3.8 Flash). We achieve superior token savings via architectural triage and progressive search. |
| **[ecc-lite](https://github.com/muhammeteminozturk/ecc-lite)** | **0-Token OS Shields & Multi-Platform Symlinks** | Pre-tool parameter validation, dangerous command interception, and secret leakage prevention executed at OS speed via local bash hooks without consuming a single LLM token. | N/A — Served as the core bedrock foundation for the entire framework. |

### The Synapse Agents Breakthrough: Hands-Off Chief + 4 Universal Subagents

By synthesizing these principles, we architected **Synapse Agents**:
- **0% Raw Code Ingestion for the Chief Architect:** The lead model (Chief Architect) never ingests raw source files or terminal output directly into its conversational context. It delegates exploration to `explorer`, blueprinting to `planner`, surgical implementation to parallel `coder` streams, and rigorous audit to `reviewer`.
- **4-Point Chief Architect Plan Audit Gate:** Before any plan reaches the user or coder agents, the Chief audits it against Ponytail Minimalism, Contract & Layer Locks, Karpathy Scope Control, and Security/Data Integrity.
- **Strictly Gemini 3.8 Flash (High/Medium Effort):** Engineered specifically to harness the unprecedented deep reasoning and cost-efficiency of Gemini 3.8 Flash without falling into pro-tier token traps or flash-lite shallow hallucinations.

---

## 🖥️ Triple-Platform Support

`synapse-agents` natively equips three major AI developer platforms through a single unified installation:

```
┌────────────────────────────────────────────────────────────────────────┐
│                             synapse-agents                             │
│               Core Plugins, 10 Skills, 0-Token Shields                 │
└──────────────┬─────────────────────────┬───────────────────────────────┘
               │                         │
      ┌────────▼────────┐       ┌────────▼────────┐       ┌──────────────▼────────┐
      │   Antigravity   │       │   Claude Code   │       │      Cursor IDE       │
      │   (Gemini CLI)  │       │      (CLI)      │       │     (Global / Proj)   │
      └────────┬────────┘       └────────┬────────┘       └──────────────┬────────┘
               │                         │                               │
  • ~/.gemini/config/plugins/   • ~/.agents/                     • ~/.cursor/mcp.json
  • ~/.gemini/config/           • ~/.claude/agents/              • ~/.cursor/rules/*.mdc
    mcp_config.json             • ~/.claude/skills/              • ~/.cursor/skills/
                                • ~/.claude/rules                • ~/.cursor/agents/
                                                                 • <project>/.cursor/
```

### 1. Google Antigravity
* Full plugin registry located in `~/.gemini/config/plugins/ecc-lite` and `~/.gemini/config/plugins/orchestration`.
* MCP registration in `~/.gemini/config/mcp_config.json` running `ecc-lite-brain`.

### 2. Claude Code CLI
* Standardized symlinks mapped into `~/.agents/` (`hooks`, `kb`, `mcp`, `rules`, `skills`).
* Agent definitions linked into `~/.claude/agents/` and skill packages into `~/.claude/skills/`.

### 3. Cursor IDE (Global & Project-Specific)
* MCP server registered in `~/.cursor/mcp.json`.
* Rule sets synced as Cursor MDC rules in `~/.cursor/rules/*.mdc`.
* Global agents and skills in `~/.cursor/agents/` and `~/.cursor/skills/`.
* Dedicated project-level configuration via `./install.sh --cursor-project <path>`.

---

## 🏛️ Agent Matrix & Roles

The system is governed by **1 Hands-Off Chief Architect** and **4 Universal Subagents**. All subagents strictly run on **Gemini 3.8 Flash** to maximize speed, logical comprehension, and cost efficiency.

```mermaid
flowchart TD
    User([User Request / Prompt]) --> CA["Şef: Chief Architect\n(Hands-Off Orchestrator)"]
    
    CA -->|Scope Unclear| EXP["explorer [Gemini 3.8 Flash - Medium]\n(Ponytail Scope Discovery)"]
    EXP -->|Caller & Fixture Map| CA
    
    CA -->|Clear Scope / Cross-Layer| PLN["planner [Gemini 3.8 Flash - High]\n(Zero-Write System Architecture)"]
    PLN -->|Draft Plan & Contracts| GATE{"Chief Plan Audit Gate\n(4 Chief Architect Filters)"}
    
    GATE -->|Approved & Parallelized| C1["Coder (Backend) [Flash - High]"]
    GATE -->|Approved & Parallelized| C2["Coder (Mobile) [Flash - High]"]
    GATE -->|Approved & Parallelized| C3["Coder (Frontend) [Flash - High]"]
    
    C1 -->|Verification Gate: Exit Code 0| SYNC(("Barrier Synchronization"))
    C2 -->|Verification Gate: Exit Code 0| SYNC
    C3 -->|Verification Gate: Exit Code 0| SYNC
    
    SYNC --> REV["reviewer [Gemini 3.8 Flash - High]\n(Contract Lock + Caller-Aware Review)"]
    REV -->|Passed Verification| CA
    CA --> Done([Delivery & Final Success Report])

    style CA fill:#6C5CE7,stroke:#333,stroke-width:2px,color:#fff
    style GATE fill:#FD79A8,stroke:#333,stroke-width:2px,color:#fff
    style EXP fill:#0984E3,stroke:#333,stroke-width:1px,color:#fff
    style PLN fill:#00CEC9,stroke:#333,stroke-width:1px,color:#fff
    style C1 fill:#00B894,stroke:#333,stroke-width:1px,color:#fff
    style C2 fill:#00B894,stroke:#333,stroke-width:1px,color:#fff
    style C3 fill:#00B894,stroke:#333,stroke-width:1px,color:#fff
    style REV fill:#E17055,stroke:#333,stroke-width:1px,color:#fff
```

### Agent Roster & Permissions

| Agent | Model & Effort | Primary Mission | Tool Permissions |
|---|---|---|:---:|
| **Şef (Chief Architect)** | Top Orchestrator Model (e.g. Gemini 4 Argon) | Understands intent, performs triage, enforces audit gates, coordinates subagents. | **Coordinator Only:** Zero code writing (`write_to_file`, `replace_file_content`), zero terminal execution, zero raw source reading. |
| **`explorer`** | Gemini 3.8 Flash *(Medium Effort)* | **Ponytail Scope Discovery:** Maps callers, dependencies, fixtures, configs; produces a crisp summary (max 150 words). | Read-Only |
| **`planner`** | Gemini 3.8 Flash *(High Effort)* | Absorbs raw source files in an isolated context; outputs a 40–80 line architectural plan with locked DTO/DB contracts. | Read-Only |
| **`coder`** | Gemini 3.8 Flash *(High Effort)* | Spawned as N parallel roles (`Coder (Backend)`, `Coder (Mobile)`, etc.); performs surgical edits and runs the Verification Gate. | Write & Execute |
| **`reviewer`** | Gemini 3.8 Flash *(High Effort)* | Two-Stage Audit: 1) Strict Contract Adherence, 2) Ponytail Caller-Aware deep review, security, and N+1 query scans. | Read-Only |

---

## 🛡️ Chief Architect Plan Audit Gate (4 Filters)

When `planner` submits a draft plan, the Chief Architect **never blindly relays it** to the user or coder agents. The plan must pass through the **4 Chief Architect Audit Filters**:

1. **Ponytail Minimalism & YAGNI Pruning:** Strip superfluous database tables, one-off factory classes, unused endpoints, speculative abstractions, and unnecessary external dependencies.
2. **Cross-Layer Contract & Nullability Lock:** Ensure endpoint URLs, HTTP verbs, payload keys, casing conventions, data types, and nullability match 100% across Backend, Mobile, and Web Admin.
3. **Karpathy Scope & Assumptions Check:** Verify that no unrelated neighboring files are touched and eliminate unverified assumptions that require user clarification.
4. **Authorization & Data Safety:** Enforce proper authorization (AuthZ) guards, data integrity, non-destructive migrations, and backward compatibility.

> [!IMPORTANT]
> If any bloat or flaw is detected, the Chief either sends an immediate refinement request via `send_message` or prunes the plan directly. Only the audited and locked plan is delivered to developers.

---

## 🚦 Smart Triage: Fast Bypass vs. Full Orchestration

```
                      Is scope already clear?
                             │
              ┌──────────────┴──────────────┐
             YES                            NO
              │                             │
    Does change affect              Spawn explorer
     <= 2 files with                (Ponytail Scope Discovery)
    0 contract changes?                     │
      │              │              Does discovery show
     YES             NO             <= 2 files & 0 contracts?
      │              │                      │
      │              │            ┌─────────┴─────────┐
      │              │           YES                  NO
      ▼              ▼            │                   │
  [ FAST          [ FULL          ▼                   ▼
   BYPASS ]      ORCHESTRATION] [ FAST             [ FULL
  1x Coder        Planner        BYPASS ]         ORCHESTRATION]
  directly        required      1x Coder           Feed scope
                                directly           to Planner
```

* **Fast Bypass:** For localized tasks (`<= 2` files, 0 contract/schema modifications, bug fixes, UI tweaks), planning bureaucracy is completely bypassed. The Chief directly delegates to `1x coder`, who implements the fix and provides fresh verification evidence.
* **Full Orchestration:** For multi-layer features, schema updates, or changes spanning `> 2` files, the full pipeline (`explorer` → `planner` → Chief Audit Gate → Parallel `coder`s → `reviewer`) is strictly enforced.

---

## ⚖️ Concurrency vs. Sequentiality Matrix

To prevent race conditions, context waste, and merge conflicts, subagent transitions adhere to strict execution rules:

| Transition / Phase | Allowed Mode | Rationale & Architectural Rule |
|---|:---:|---|
| **`explorer` ↔ `planner`** | ⛔ **STRICTLY SEQUENTIAL** | **Never parallel!** If spawned concurrently, `planner` cannot leverage the discovery map, wasting tokens on redundant searches and breaking Fast Bypass triage. |
| **`planner` ↔ `coder`** | ⛔ **STRICTLY SEQUENTIAL** | **Never parallel!** Coding without an audited, contract-locked plan leads to severe integration drift and rework. |
| **`coder` ↔ `reviewer`** | ⛔ **STRICTLY SEQUENTIAL** | **Never parallel!** Partial reviews generate duplicate effort and false positive alerts. Review begins only after all coders clear barrier sync. |
| **Multi-`explorer`** | ✅ **PARALLEL ALLOWED** | Permitted across isolated directories or layers (e.g. backend vs. mobile). All must complete before `planner` begins. |
| **Multi-`coder`** | ✅ **PARALLEL ALLOWED** | After Chief Plan Audit approval, layer-specific coders (`Coder (Backend)`, `Coder (Mobile)`, `Coder (Frontend)`) execute completely in parallel. |

---

## 🔄 Continuous Execution (`Ruling:` Protocol)

During execution, agents maintain momentum without prompting the user for trivial decisions:

1. **Look Before You Ask:** Agents always search the codebase and `ecc-lite-brain` before asking questions.
2. **`Ruling:` Protocol:** Technical micro-decisions are recorded in the audit log in a standardized format:
   ```markdown
   Ruling: <Decision> — <Technical Rationale> — <Rollback Cost If Inverted>
   ```
3. **Escalation Triggers (Only 4 Permitted):**
   * Destructive actions (dropping database tables, permanent file deletions).
   * Sensitive secrets / credentials (new API keys, token generation).
   * External side-effects (git push, remote deployment, store publishing).
   * Irreconcilable architectural blockers.

---

## 🧰 10 Curated Engineering Skills

The workspace includes 10 production-tested engineering skills:

1. **`systematic-debugging`**: Enforces root-cause isolation and test reproduction before any fix is attempted.
2. **`tdd`**: Strict Test-Driven Development workflow across .NET (xUnit), Flutter (test), and Web (Vitest).
3. **`verification-gate`**: Mandates fresh build, lint, and test execution (Exit Code: 0) prior to claiming completion.
4. **`tech-debt`**: Aggregates all `// shortcut:` and `// ponytail:` tags into a unified, actionable debt ledger.
5. **`deep-review`**: Caller-aware differential code review covering edge cases, memory leaks, security, and load profiles.
6. **`repo-audit`**: Deep health audit detecting dead code, redundant dependencies, and structural rot.
7. **`using-git-worktrees`**: Automates isolated git worktrees to keep feature branches completely separate and clean.
8. **`handoff`**: Freezes runtime state, locked decisions, and outstanding work when context exhaustion approaches.
9. **`kb`**: Progressive 2-stage querying of `ecc-lite-brain` index and documentation with NotebookLM connectivity.
10. **`model-orchestrator`**: Dynamically orchestrates tasks and multi-model consensus across Gemini and NVIDIA NIM engines.

---

## 🛡️ 0-Token OS Shields & Progressive Memory

### 1. Zero-Token OS Shields (`plugins/ecc-lite/hooks/`)
* **`secret-guard.sh` (Pre-Tool Hook):** Evaluates file edits and commands via ultra-fast local regex patterns. Blocks leaked private keys, API secrets, `.env` dumps, and destructive commands at the OS layer without expending a single model token.
* **`verify-quiet.sh` (Stop Hook):** Triggered upon task completion. Analyzes modified file extensions (.NET, Flutter, Web/TS) and silently verifies compilation and typing. Remains completely silent on exit code 0, consuming 0 tokens.

### 2. 2-Stage Progressive Memory (`ecc-lite-brain`)
* **Stage 1 (`search_knowledge_index`):** Scans compact topic headers and summaries (low token footprint).
* **Stage 2 (`get_knowledge_detail`):** Loads full markdown documentation only for the matched topic.
* **Instincts Engine (`kb/instincts.md`):** Automatically registers project-specific naming conventions, architectural boundaries, and DTO rules.

---

## 🚀 Installation & Usage Guide

### Prerequisites
* **macOS** or **Linux**
* **Bash 4.0+**
* **Python 3.8+** (for standard-library MCP server)
* **Antigravity**, **Claude Code CLI**, or **Cursor IDE**

### 1. Installation

Clone the repository and run the idempotent installer:

```bash
git clone https://github.com/meminozturkk/synapse-agents.git
cd synapse-agents

# Default: Installs for Antigravity, Claude Code, and Cursor IDE (Global)
./install.sh

# Platform-specific targeted installations:
./install.sh --antigravity-only
./install.sh --claude-only
./install.sh --cursor-only

# Project-specific Cursor configuration:
./install.sh --cursor-project /path/to/your/project
```

#### What the Installer Does:
1. **Automated Backups:** Backs up existing plugin and agent configurations into `~/.claude/backups/pre-install-<timestamp>`.
2. **Antigravity Sync:** Synchronizes `ecc-lite` and `orchestration` plugins to `~/.gemini/config/plugins/`.
3. **Non-Destructive Instinct Preservation:** **Existing `instincts.md` files are never overwritten.** Learned team knowledge is safely preserved.
4. **MCP Brain Registration:** Atomically registers `ecc-lite-brain` into `~/.gemini/config/mcp_config.json` and `~/.cursor/mcp.json`.
5. **Claude & Cursor Symlinks:** Generates required symlinks in `~/.agents/`, `~/.claude/`, and `~/.cursor/`.

### 2. Uninstallation

Safely remove the framework while keeping your team's learned instincts intact:

```bash
# Safe uninstallation (removes symlinks and MCP entries; backs up instincts.md):
./uninstall.sh

# Complete wipe (removes all installed plugin files and configurations):
./uninstall.sh --all
```

---

## 📂 Repository Structure

```
synapse-agents/
├── install.sh              # Idempotent installer (Antigravity, Claude Code, Cursor)
├── uninstall.sh            # Safe uninstallation script with backup guarantees
├── README.md               # English master architecture & system documentation
├── README.tr.md            # Turkish complete architecture & system documentation
├── LICENSE                 # MIT License
├── .gitignore              # Ignores runtime states, Python bytecode, instincts.md
└── plugins/
    ├── ecc-lite/           # Core tools, 0-token hooks, KB brain & MCP server
    │   ├── hooks/          # secret-guard.sh, verify-quiet.sh
    │   ├── kb/             # instincts.example.md, knowledge topics
    │   ├── mcp/            # brain_server.py (Stateless Python MCP implementation)
    │   ├── rules/          # Karpathy surgical & Ponytail minimalism guidelines
    │   └── skills/         # 10 curated engineering skills
    └── orchestration/      # Chief Architect & 4 subagent definitions
        ├── agents/         # explorer.md, planner.md, coder.md, reviewer.md
        ├── rules/          # AGENTS.md (Chief gate, triage & parallelism matrix)
        └── skills/         # orchestrator skill
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
