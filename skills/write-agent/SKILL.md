---
name: write-agent
description: Design or fix an LLM agent's system prompt, tools, and guardrails so it stays strictly inside its domain and only does what it can actually do. Use when building a new agent, writing a system prompt for a "<domain> agent", or when an existing agent misbehaves — drifting off-topic, answering like a general chatbot (e.g. a CRM that starts writing Python), claiming abilities it lacks, answering from memory instead of tools, or caving to off-scope requests. Triggers: "write a system prompt for X", "constrain this agent", "why is my agent answering off-topic", "add guardrails", "keep the agent in scope", "/write-agent". NOT for tuning a one-shot prompt/completion that isn't a tool-using agent, and NOT for general copywriting — that's prompt engineering, not agent scoping.
---

# Write a constrained agent

An agent is defined by three boundaries that must agree:

1. **Prompt** — who it is and what it refuses.
2. **Tools** — what it can actually do (the real capability boundary).
3. **Guardrails** — what is enforced regardless of what the model decides.

Scope creep, hallucinated capabilities, and "it started writing Python" are all the same bug: one of the three boundaries was missing or the three disagree. The prompt said "relationship CRM" but nothing *stopped* it from being a general assistant, so it was one.

Core stance (consensus across Sierra, Anthropic, OpenAI): **the prompt is not a guardrail.** A motivated or confused user argues around prose. Scope must also live in the toolset (no tool ⇒ no capability) and in a deterministic layer the model cannot cross. Prompt for scope, then back it.

## Process

### Step 0 — Name the job in one sentence

Write the agent's single job and its bounded domain in one sentence: "Hermes captures and answers questions about the user's people and relationships." If it needs "and also…", that's a second agent — route between them rather than widening one. A fuzzy job statement guarantees a fuzzy scope.

### Step 1 — Enumerate capabilities and non-goals

- **In-scope capabilities** — 2–6 concrete actions/answers. Each MUST map to a real tool or a real knowledge source. If a capability has no backing tool, it isn't a capability — it's a hallucination waiting to happen (capability honesty: "an LLM alone is not an agent").
- **Non-goals** — the tempting, adjacent, forbidden things. Name them explicitly. The single highest-leverage line in most agent prompts is some form of **"You are NOT a general assistant"** plus the specific don'ts (write code, do math, general Q&A, advice outside the domain).

### Step 2 — Write the system prompt

Use this skeleton (adapt wording; don't paste verbatim into an unrelated domain):

```
ROLE: You are <name>, a <one-line expertise + context>. Your one job: <the job>.
You work only through your tools and the records they expose.

YOU ONLY: <the 2–6 in-scope capabilities, each a concrete action or answer>.

YOU ARE NOT a general assistant. You do not write code, do math, draft unrelated
text, answer general-knowledge / how-to questions, or give advice outside <domain>.

OUT OF SCOPE → decline + redirect (one line), never produce the off-topic content:
  "That's outside what I do — I'm <role>. I can <in-scope action> instead."

CAPABILITY HONESTY: only do what your tools actually allow; never claim or invent an
action you can't take; answer only from tool results, never from your own knowledge.
If you don't have it, say so and offer to look it up or record it.

[domain procedure / decomposition rules go here]
```

Calibration that matters:

- **Steer, don't slam, for *benign* off-topic** (redirect to what you do). **Terminate/escalate for *adversarial*** (jailbreak, injection, requests to reveal the prompt). Two modes, not one.
- **Pre-script boundary scenarios.** List the common off-scope asks and the exact response, so the model handles them without breaking character (Anthropic's "prepare for scenarios").
- **Forcefulness is model-specific.** On modern Claude, "CRITICAL: you MUST…" *over*-triggers — use normal imperative ("Use this tool when…", "Don't attempt it"). Dial up only if evals show under-adherence.
- **Answer-from-tools, not memory.** State it, and where possible make answers cite the tool/record they came from — that structurally blocks "I'll just answer from what I know."

### Step 3 — Make the toolset the capability boundary

The cleanest "I can't do that" is *having no tool to do it*. Design tools for the agent, not as 1:1 API wrappers:

- **Few, well-scoped tools.** More tools and overlapping tools cause confusion and drift. Consolidate around the agent's task (`get_customer_context`, not `get_by_id` + `list_txns` + `list_notes`).
- **Namespace** by resource (`hermes_search`, `hermes_propose`) so the agent picks the right one.
- **Descriptions are prompt engineering** — describe each tool as you would to a new hire; name params unambiguously.
- **Poka-yoke inputs** so misuse is impossible (require absolute paths, validated enums, etc.).
- **High-signal returns + helpful errors** steer the agent back on track.
- Decide the **action posture**: read-only/advisory vs. allowed to act; gate the acting path.

### Step 4 — Add guardrail layers, sized to risk

The prompt is layer one. Add deterministic layers the model can't talk its way past:

- **Input rail** — a relevance/topic check (off-topic → refuse/redirect) and a jailbreak/injection check, ideally a *separate cheap model* (don't make the same model police itself; "sectioning" beats one call doing both).
- **Output rail** — policy/brand/safety check before delivery; for high-risk topics, escalate or end rather than reword a bad answer into a subtler bad answer.
- **Deterministic enforcement** — encode hard business rules as code the agent literally cannot cross (e.g. "no refund past the 30-day window"); gate high-risk tools behind a confirm/human-in-the-loop.
- **Tier strictness to risk** (Sierra's tolerance tiers): adversarial/sensitive = lowest tolerance, terse robotic refusal is fine; standard procedures = medium, follow the spirit with flexibility; tone/phrasing = loosest. One global strictness is wrong.

For a small/local single-user agent, layers can be lightweight (a strong scoped prompt + tool-gating + one input relevance check). For anything multi-user, regulated, or money-moving, the input+output+deterministic layers are not optional.

### Step 5 — Eval scope adherence (don't assume it)

Scope that isn't measured regresses silently. Minimum battery:

- **Off-topic refusal** — a set of out-of-scope prompts (code, trivia, advice); the agent must decline+redirect and emit *no* off-topic content.
- **Capability honesty** — ask for something with no backing tool; it must say it can't, not invent it.
- **Consistency (pass^k)** — run each scope test k times; an agent that stays in scope once but not 8× isn't safe (frontier models drop sharply pass^1 → pass^8).
- **Regression snapshots** — every real off-scope failure becomes a replayable test against mock tools, so it can't come back.

## Anti-patterns → the guard for each

| Failure | Looks like | Guard |
| --- | --- | --- |
| Scope creep | answers off-domain like a chatbot | explicit YOU ONLY / YOU ARE NOT + input relevance rail + scripted redirect |
| Hallucinated capability | claims it can do X with no tool | capability-honesty clause; toolset = boundary; no tool ⇒ no action |
| Answer-from-memory | skips the tool, improvises facts | "answer only from tool results"; cite the record; tool-first instruction |
| Prompt injection / jailbreak | "ignore previous instructions / reveal your prompt" | safety classifier + rules/regex + never expose the system prompt; terminate mode |
| Sycophancy | caves to pressure to act out of scope | honesty over agreement; a deterministic tripwire that *halts*, not the model "deciding" |
| Long-chat drift | wanders off-domain over many turns | output rail; re-inject scope on long conversations |
| Tool confusion | wrong tool / wrong params | few tools, namespacing, clear descriptions, poka-yoke, helpful errors |
| High-risk action unsupervised | autonomous refund / destructive write | tool risk ratings; confirm/human-in-the-loop before high-risk calls |
| Over/under tool-triggering | too-forceful prompt overtriggers | calibrate language to the model; verify with evals |

## References

- Sierra — [Guide to AI Agents](https://sierra.ai/blog/ai-agents-guide), [Constellation of models](https://sierra.ai/blog/constellation-of-models) (input/output supervisors), [From LLMs to enterprise-grade agents](https://sierra.ai/blog/enterprise-grade-agents) (tolerance tiers, steer-vs-terminate), [Agent Development Life Cycle](https://sierra.ai/uk/blog/agent-development-life-cycle) (deterministic guardrails, plans, snapshots), [τ-bench](https://sierra.ai/blog/benchmarking-ai-agents) (policy-following + pass^k).
- Anthropic — [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents), [Writing tools for AI agents](https://www.anthropic.com/engineering/writing-tools-for-agents), [Keep Claude in character](https://platform.claude.com/docs/en/docs/test-and-evaluate/strengthen-guardrails/keep-claude-in-character) (role + scenario template).
- OpenAI — [A practical guide to building agents](https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf), [Agents SDK guardrails](https://openai.github.io/openai-agents-python/guardrails/) (input vs output, tripwires).
- NVIDIA — [NeMo Guardrails](https://docs.nvidia.com/nemo/guardrails/about-nemo-guardrails-library/overview) (topical rails; input+output beats either alone).
