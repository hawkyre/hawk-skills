---
name: learn-system
description: Explore and explain how a system, module, or codebase works. Use when the user is onboarding, trying to understand unfamiliar code, or building a mental model.
---

# Learn How Something Works

## Process

1. **Entry point exploration**:
   - What triggers this code to run
   - High-level flow (what calls what, in what order)
   - Key data structures and how they transform
   - Where important decisions/branching happens

   In Claude Code, use the Explore subagent for this — it keeps the main context clean.

2. **Visual mental model**: Draw a diagram (mermaid or ASCII) showing:
   - Main components/modules
   - Data flow between them
   - External dependencies (DB, APIs, filesystem)
   - Error handling boundaries

   Save the diagram — visual models compress understanding.

3. **Trace a specific flow**: Walk through a concrete scenario step by step:
   - Which functions are called, in what order
   - What data looks like at each step
   - "Interesting" parts (complex logic, non-obvious behavior)

   Pick the most common scenario first, then trace edge cases.

4. **Socratic verification** (when the user states their understanding):
   - What did they get wrong?
   - What's missing?
   - What would surprise them?

   Telling the AI what you _think_ is true and asking for corrections is dramatically more effective than open-ended questions.

5. **Capture the understanding** (if asked): Write a brief architecture doc:
   - Purpose and scope
   - Key concepts and data flow
   - Common modification points
   - Gotchas and non-obvious behavior

## Rules

- Start broad, go deep on specific areas when asked
- Always trace at least one concrete scenario — abstract explanations don't stick
- When the user states their understanding, correct misconceptions specifically
- Use diagrams to compress understanding
- Write down what you learned — it compounds across sessions
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-learn-system-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-learn-system-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline. Explore subagents must apply the same recipe to their captures.
