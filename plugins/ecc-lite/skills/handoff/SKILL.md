---
name: handoff
description: Persists current progress and context to .agents/HANDOFF.md when context window starts filling up.
---

# Session Handoff Protocol

1. If any enduring architectural rule or critical bug resolution was learned during this session, record it in persistent memory using the `save_instinct` MCP tool.
2. Summarize current session progress in `.agents/HANDOFF.md` in at most 25 lines using the following sections:
   - **Completed Work & Modified Files**
   - **Architectural Decisions Made**
   - **Open Items & Immediate Next Step**
3. Inform the user that they can clear the session (`/clear`) and resume in a fresh session by referencing `@.agents/HANDOFF.md` with zero token bloat.
