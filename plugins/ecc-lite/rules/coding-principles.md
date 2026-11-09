---
description: Core Engineering Principles (Karpathy 4 Principles + Ponytail 6-Step Minimalism Ladder & Debt Tracking)
alwaysApply: true
---
# Karpathy Surgical Coding Principles & Ponytail Minimalism Ladder

## Section 1 — Karpathy 4 Surgical Coding Principles

1. **Think Before Coding:**
   - State your assumptions explicitly. Never proceed on hidden or silent assumptions.
   - If there is ambiguity or contradiction, ask clarifying questions before continuing.
   - Pin down the root cause and boundaries precisely before touching code.

2. **Simplicity First:**
   - Add no unneeded abstraction, generic wrapper, factory, or speculative config layer (YAGNI).
   - Never write code for "future what-ifs"; apply only the leanest, most direct architecture solving the current requirement.

3. **Surgical Changes:**
   - Change only the targeted logic. Do not touch adjacent code, stylistic formatting, whitespace, or unrelated comments.
   - Keep the diff minimal and pristine. Clean up only orphaned imports or variables created by your own modifications.

4. **Goal-Driven Execution:**
   - Anchor every step to a verifiable target or test condition.
   - Never declare "it should work now"; do not consider a task complete without passing through the verification gate (build / test / analyze).

---

## Section 2 — Ponytail Minimalism Ladder & Debt Standard

Before writing code, stop at the **first working rung** on the 6-step ladder:
1. **Does it need to exist?** (Reject or delete unnecessary features or concepts upfront).
2. **Does it already exist in the codebase?** (Reuse existing helpers, extensions, or utilities rather than recreating them).
3. **Does the standard library or platform solve it?** (Use native language constructs and platform runtime capabilities).
4. **Does an installed dependency have it?** (Leverage existing project packages; never add a new NPM/NuGet/Pub dependency for a few lines of code).
5. **Can it be a readable one-liner?** (Solve cleanly with an expressive, readable line without introducing extra function or class wrappers).
6. **Minimum viable code + 1 small test for branch, loop, or security logic.**

### Debt Standard & Deliberate Shortcuts:
- Always tag deliberate and pragmatic shortcuts using the standard marker:
  `// shortcut: <ceiling>, <upgrade path>`
- At the end of your response, state intentional trade-offs and potential risks in 1–2 lines.
- **Non-Negotiables:**
  - Security and secret management,
  - Data loss prevention and transaction integrity,
  - Trust-boundary validation (validating user input / external API input),
  - Accessibility (a11y) standards.
