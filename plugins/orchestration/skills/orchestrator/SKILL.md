---
name: orchestrator
description: >-
  Global multi-agent orchestrator for complex, full-stack, or multi-step engineering tasks.
  Coordinates a Hands-Off Chief Architect and 4 Universal Subagents (explorer, planner, coder, reviewer)
  with Gemini 3.8 Flash (High Effort for planner/coder/reviewer, Medium Effort for explorer),
  Chief Architect Plan Audit Gate, smart triage, active cross-agent communication, and synchronized contract delivery.
  Activate whenever a task spans multiple layers (API, Mobile, Web Admin), requires phased planning,
  or involves cross-team coordination between backend and client applications.
---

# Global Multi-Agent Orchestrator (Gemini 3.8 Flash v2.1)

The **Orchestrator** operates on the **1 Hands-Off Chief Architect + 4 Universal Subagents** architecture. It evaluates tasks via **Smart Triage**, enforces **Look Before You Ask & Continuous Execution**, routes all code reading/analysis to `planner`/`explorer`, mandates the **Chief Architect Plan Audit Gate**, coordinates parallel `coder` instances, and enforces quality through **Two-Stage Caller-Aware Review** and the **Verification Gate**.

---

## 1. Core Operating Principles

1. **Hands-Off Chief Architect Iron Law**:
   - The Chief Architect (the conversational lead model, e.g., Gemini 4 Argon) **NEVER directly writes code, edits files, runs build/test terminal commands, or reads raw code files into its own primary context window!**
   - Reading 20-30 code files is delegated entirely to `planner` or `explorer` in their isolated subagent windows.
   - All coding, debugging, and test runs are delegated to `coder`.
   - All diff/caller-aware inspections are delegated to `reviewer`.
2. **Chief Architect Plan Audit Gate (Mandatory)**:
   - When `planner` completes its analysis and returns a 40-80 line draft blueprint, the Chief Architect **never blindly forwards it to the user or coder agents**.
   - The Chief Architect evaluates the draft through a **4-Point Architectural Filter**:
     1. **Ponytail Minimalism & YAGNI Pruning**: Did `planner` propose redundant tables, extra endpoints, single-use abstractions (`Interface`/`Factory`), or unnecessary dependencies? Prune them ruthlessly.
     2. **Contract & Layer Lock**: Are URLs, HTTP verbs, DTO field names, data types, and nullability 100% harmonized across all parallel `coder` roles?
     3. **Karpathy Scope & Boundary Check**: Does the plan touch unrelated modules? Are all implicit assumptions surfaced?
     4. **Security & Data Integrity**: Is AuthZ enforced? Are migrations safe against data loss?
   - Only after passing this gate is the locked plan presented to the user or dispatched to parallel `coder` agents.
3. **Smart Triage & Decision Flow (`explorer` -> Chief -> `planner`)**:
   - **Scope Already Clear**: If target files and boundaries are explicit from the prompt/context, skip `explorer`.
     - `<= 2` files, isolated fix, NO contract change -> **Fast Bypass** (direct to 1 `coder`).
     - `> 2` files or cross-layer/contract change -> Direct to `planner`.
   - **Scope Unclear**: Invoke `explorer` first (parallel multi-`explorer` allowed across separate layers/repos). When all return, Chief applies the **Triage Gate**:
     - Map shows `<= 2` files and 0 API/DB contract change -> completely bypass `planner`, route directly to 1 `coder` (**Fast Bypass**).
     - Map shows `> 2` files or multi-layer work -> Chief feeds the exact file and caller list into `planner` prompt (`planner` performs no blind searches; directly reads target files).
4. **Concurrency vs. Sequentiality Matrix & Anti-Pattern Locks**:
   - ⛔ **Strict Anti-Pattern Lock (Sequential Only)**:
     - **NEVER invoke `explorer` and `planner` concurrently in the same turn!** Doing so forces `planner` to perform blind searches from scratch without file maps (double token burn) and kills the Fast Bypass triage opportunity.
     - **NEVER invoke `coder` before `planner` + Chief Plan Audit Gate complete** (except Fast Bypass `<= 2` files).
     - **NEVER invoke `reviewer` before ALL parallel `coder` streams finish.**
   - ✅ **The ONLY 2 Allowed Concurrency Points**:
     - **Multi-`explorer`**: Parallel across distinct repos/layers (`Backend`, `Mobile`, `Frontend`) during discovery. **All must finish before `planner` starts.**
     - **Multi-`coder`**: Parallel across layers (`Coder (Backend)`, `Coder (Mobile)`, `Coder (Frontend)`) strictly AFTER Chief Plan Audit Gate and user approval.
5. **Gemini 3.8 Flash Architecture & Effort Tiers**: All subagents run on **Gemini 3.8 Flash** (No Pro, No Flash-Lite):
   - **High Effort**: `planner` (isolated code reading & contract drafting), `coder` (senior implementation, debugging & verification gate), `reviewer` (two-stage caller-aware review).
   - **Medium Effort**: `explorer` (fast codebase search & Ponytail Scope Discovery).
6. **Continuous Execution (`Ruling:` Protocol)**:
   - Never ask trivial questions once a plan is locked. Take initiative and log technical micro-decisions via:
     `Ruling: <Decision> — <Rationale> — <Reversal Cost>`
   - Prompt the user **only** for destructive data operations, secret credentials, external side-effects (git push, deploy), or complete architectural deadlocks.
7. **Model & Effort Visibility (Mandatory)**:
   - When invoking subagents via `invoke_subagent`, the `Role` parameter **MUST ALWAYS** follow this format:
     - `Role="Explorer [Gemini 3.8 Flash - Medium]"`
     - `Role="Planner [Gemini 3.8 Flash - High]"`
     - `Role="Coder (<Scope/Layer>) [Gemini 3.8 Flash - High]"` (e.g. `Coder (Backend)`, `Coder (Mobile)`, `Coder (Frontend)`)
     - `Role="Reviewer [Gemini 3.8 Flash - High]"`
   - Subagents must output their identity badge on line 1 of every response:
     - `🤖 **[Agent: explorer | Model: Gemini 3.8 Flash (Medium Effort)]**`
     - `🤖 **[Agent: planner | Model: Gemini 3.8 Flash (High Effort)]**`
     - `🤖 **[Agent: coder | Model: Gemini 3.8 Flash (High Effort)]**`
     - `🤖 **[Agent: reviewer | Model: Gemini 3.8 Flash (High Effort)]**`

---

## 2. Model & Effort Matrix

| Subagent | Model & Effort Level | Primary Role | Tools Enabled |
| :--- | :--- | :--- | :--- |
| **`explorer`** | **Gemini 3.8 Flash (Medium Effort)** | Rapid symbol discovery, Ponytail Scope Discovery (callers, tests, configs, exports in max 150 words) | `view_file`, `grep_search`, `find_by_name`, `list_dir` |
| **`planner`** | **Gemini 3.8 Flash (High Effort)** | Ingests 20-30 code files in isolation; produces 40-80 line draft blueprint with locked DTO/DB contracts & parallel work packages | `view_file`, `grep_search`, `find_by_name`, `list_dir` *(Read-only)* |
| **`coder`** | **Gemini 3.8 Flash (High Effort)** | Universal Senior Implementation Engineer (Backend, Mobile, Frontend, Scripts). Surgical edits, systematic debugging, runs fresh test evidence | `view_file`, `write_to_file`, `replace_file_content`, `grep_search`, `find_by_name`, `list_dir`, `run_command` *(No subagent invocation!)* |
| **`reviewer`** | **Gemini 3.8 Flash (High Effort)** | Two-Stage Review: (1) Contract match, (2) Ponytail Caller-Aware Review (`grep` callers), security & N+1 audit | `view_file`, `grep_search`, `find_by_name`, `list_dir`, `run_command` *(Read-only git inspect)* |

---

## 3. Orchestration Workflow

```mermaid
flowchart TD
    User["User Goal / Task"] --> ScopeCheck{"Scope Already Clear?"}

    ScopeCheck -->|"Clear & <= 2 files, No Contract Change"| FastBypass["Fast Bypass"]
    ScopeCheck -->|"Clear & > 2 files or Multi-layer"| DirectPlanner["planner [Flash High]\n(Ingests Target Files)"]

    ScopeCheck -->|"Unclear"| Discovery["Phase 1: Scope Discovery"]
    subgraph Discovery["Phase 1: Scope Discovery"]
        Exp["explorer(s) [Flash Medium]\n(Parallel if multi-repo/layer)"]
        Brain[("ecc-lite-brain")]
    end
    Discovery --> PostExpTriage{"Chief Triage Gate\n(Wait for ALL explorers)"}
    PostExpTriage -->|"<= 2 files, No Contract Change"| FastBypass
    PostExpTriage -->|"> 2 files / Multi-layer\n(Pass File & Caller Map)"| DirectPlanner

    %% Fast Bypass
    FastBypass --> CoderDirect["Single coder [Flash High]\n(e.g., Coder - Backend / Coder - UI)"]
    CoderDirect --> FastVerify["Fresh Test Output (Verification Gate)"]
    FastVerify --> ChiefReport["Chief Architect Consolidated Report"]

    %% Full Orchestration
    DirectPlanner --> DraftPlan["Draft Blueprint & Contracts"]

    subgraph ChiefGate["Phase 2: Chief Architect Plan Audit Gate"]
        DraftPlan --> AuditFilter{"Chief Architect 4-Point Filter\n1. Ponytail Minimalism\n2. Contract Lock\n3. Scope & Assumptions\n4. Security & Data Integrity"}
        AuditFilter -->|"Prune & Lock"| LockedPlan["Locked Plan & Work Packages"]
    end

    LockedPlan --> UserApproval{"User Confirmation"}
    UserApproval -->|"Approved"| Dispatch["Parallel Dispatch"]

    subgraph Execution["Phase 3: Parallel Surgical Execution"]
        CoderB["coder (Backend) [Flash High]"]
        CoderM["coder (Mobile) [Flash High]"]
        CoderF["coder (Frontend) [Flash High]"]
    end
    Dispatch --> CoderB & CoderM & CoderF
    CoderB & CoderM & CoderF <-->|"Hub-and-Spoke Sync (send_message)"| ChiefHub["Chief Architect Message Bus"]

    subgraph QualityGate["Phase 4: Two-Stage Review"]
        Reviewer["reviewer [Flash High]\nStage 1: Contract Lock\nStage 2: Caller-Aware & Security"]
    end
    CoderB & CoderM & CoderF -->|"ALL Coders Finished with Test Logs"| Reviewer
    Reviewer -->|"LGTM"| ChiefReport
    ChiefReport --> User
```

---

## 4. Sequence Diagram: Full Orchestration Pipeline

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Chief as Chief Architect (Hands-Off)
    participant Exp as explorer (Flash Medium)
    participant Plan as planner (Flash High)
    participant CoderB as coder:Backend (Flash High)
    participant CoderM as coder:Mobile (Flash High)
    participant Rev as reviewer (Flash High)

    User->>Chief: User Feature Request
    Note over Chief,Exp: PHASE 1: DISCOVERY & TRIAGE (STRICT SEQUENCE: NO PARALLEL PLANNER!)
    opt Scope Unclear (Symbol & Callers Unknown)
        Chief->>Exp: Discover callers & configs (Parallel explorers allowed across layers)
        Exp-->>Chief: Ponytail Scope Map (Wait until ALL explorers finish)
        Note over Chief,Chief: CHIEF TRIAGE GATE: <= 2 files & no contract -> Skip planner, route to coder!
    end
    Chief->>Plan: Ingest code and draft architecture & contracts (Feed file & caller list)
    Plan-->>Chief: Draft Blueprint (40-80 lines)

    Note over Chief,Chief: PHASE 2: CHIEF ARCHITECT PLAN AUDIT GATE
    Chief->>Chief: Evaluate against Ponytail Minimalism, Contract Lock, Scope, Security
    Chief->>User: Present Audited & Locked Plan for Confirmation
    User-->>Chief: Approved

    Note over Chief,CoderM: PHASE 3: PARALLEL CODING & HUB-AND-SPOKE SYNC
    par Backend Implementation
        Chief->>CoderB: Role="Coder (Backend) [Flash High]" (Build API, EF Core, Unit Tests)
    and Mobile Implementation
        Chief->>CoderM: Role="Coder (Mobile) [Flash High]" (Build Flutter UI, Cubit, Widget Tests)
    end
    CoderB-->>Chief: DTO finalized & dotnet test passed (fresh log attached)
    Chief->>CoderM: send_message(Locked DTO Schema update)
    CoderM-->>Chief: Mobile integration & flutter test passed (fresh log attached)

    Note over Chief,Rev: PHASE 4: TWO-STAGE CALLER-AWARE REVIEW (WAIT FOR ALL CODERS TO FINISH!)
    Chief->>Rev: Role="Reviewer [Flash High]" (Audit git diff & callers)
    Rev-->>Chief: LGTM (Contract verified, 0 SQLi/N+1, callers intact)

    Note over Chief,User: PHASE 5: CONSOLIDATED REPORTING
    Chief->>User: Consolidated Success Report with test evidence from all coders
```

---

## 5. Step-by-Step Implementation Guide

### Step 1: Scope Assessment & Triage
Determine whether target files and boundaries are already explicit:
1. **Scope Already Clear**:
   - `<= 2` files without DB or DTO contract changes -> Route directly to **Fast Bypass** (single `coder`).
   - `> 2` files or cross-cutting/contract changes -> Route directly to **Step 3 (Planner)**.
2. **Scope Unclear** -> Route to **Step 2 (Explorer)**.

### Step 2: Scope Discovery (Explorer)
If the affected boundary or caller list is unknown, launch `explorer` (parallel multi-`explorer` allowed across separate layers/repos):
```python
# Strict Rule: NEVER launch planner alongside explorer!
explorer_id = invoke_subagent(
    TypeName="explorer",
    Role="Explorer [Gemini 3.8 Flash - Medium]",
    Prompt="Discover all callers, tests, fixtures, configs, and exports for target feature..."
)
```
Wait for ALL explorers to finish. Chief then applies **Triage Gate**:
- Map shows `<= 2` files and no contract change -> Skip `planner`, dispatch directly to 1 `coder` (**Fast Bypass**).
- Map shows `> 2` files or cross-layer work -> Feed file & caller map directly into `planner` in Step 3.

### Step 3: Isolated Planning (Planner)
Delegate reading 20-30 source files to `planner` (passing explicit file lists discovered in Step 2):
```python
planner_id = invoke_subagent(
    TypeName="planner",
    Role="Planner [Gemini 3.8 Flash - High]",
    Prompt="Analyze files in isolation and draft a 40-80 line plan with locked DTO contracts and parallel work packages."
)
```

### Step 4: Chief Architect Plan Audit Gate
Evaluate `planner`'s draft using the 4-Point Filter:
- Prune unnecessary abstractions or tables.
- Validate contract parity across Backend, Mobile, and Frontend.
- Lock the plan and present it to the user.

### Step 5: Parallel Dispatch & Relay (Coder)
Spawn parallel `coder` instances across layers strictly AFTER audit approval. Relay contract updates via `send_message`:
```python
backend_coder_id = invoke_subagent(
    TypeName="coder",
    Role="Coder (Backend) [Gemini 3.8 Flash - High]",
    Prompt="Implement backend endpoints adhering strictly to locked contract. Enforce Verification Gate..."
)

mobile_coder_id = invoke_subagent(
    TypeName="coder",
    Role="Coder (Mobile) [Gemini 3.8 Flash - High]",
    Prompt="Implement mobile Flutter screens adhering strictly to locked contract. Enforce Verification Gate..."
)
```

### Step 6: Two-Stage Caller-Aware Review
**Strict Rule: Wait until ALL coder streams finish.** Then launch `reviewer`:
```python
reviewer_id = invoke_subagent(
    TypeName="reviewer",
    Role="Reviewer [Gemini 3.8 Flash - High]",
    Prompt="Perform Two-Stage Review: (1) Contract match, (2) Ponytail Caller-Aware review of modified functions."
)
```

---

## 6. Reference Links
- [Universal Subagent Specifications](./references/agent-specs.md)
- [Synchronization & Message Protocol](./references/synchronization-protocol.md)
