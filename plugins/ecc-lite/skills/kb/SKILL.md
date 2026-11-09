---
name: kb
description: Queries project memory (ecc-lite-brain) via 2-stage progressive search (index -> detail) and NotebookLM cloud notebook with zero token bloat.
---

# Project Memory & Dual-Layer Knowledge Protocol (Dual-MCP)

## 1. Layer 1: Local & Global Knowledge Base (`ecc-lite-brain`)

To prevent context bloat, always follow the **2-stage progressive search** standard:

1. **Stage 1 — Fast and Compact Index Search (`search_knowledge_index`):**
   - Search relevant keywords (e.g., `Avatar`, `EF-Core`, `Auth`).
   - This tool returns a single-line compact header and ID consuming only ~40–60 tokens per match:
     `[ID: instincts.md#9 | Global] **[Avatar-Layer-Hierarchy]** (2026-11-02): Avatar layer hierarchy ordering...`
   - Massive full texts are not dumped into the main context.

2. **Stage 2 — Surgical Detail Retrieval (`get_knowledge_detail`):**
   - Select relevant block IDs from the index (e.g., `"instincts.md#8, instincts.md#9"`).
   - Retrieve full text only for these specific blocks into the context.

*(Note: When necessary, the backward-compatible `search_project_knowledge` tool can also be used for direct full-text search.)*

3. **Saving Learned Decisions (`save_instinct`):**
   - Whenever a bug is resolved, a new architectural decision is made, or a critical layer hierarchy is established, invoke `save_instinct(topic, rule)` immediately.
   - The knowledge is written to persistent memory and retained across future sessions.

---

## 2. Layer 2: Comprehensive Docs & Skills Notebook (`notebooklm`)

For comprehensive architectural references, external API documentation, and global guides, use the NotebookLM MCP:
- **Skills Notebook**: `https://gemini.google.com/notebook/063f74b6-7230-4a4f-8232-7663ff1ee9dd`
- **ECC-Lite Architecture Notebook**: `https://gemini.google.com/notebook/f144c149-848c-403f-85dd-24377028a4d7`
- When needed, use the `ask_question` tool to pose pinpoint queries and pull only the concise synthesis.
