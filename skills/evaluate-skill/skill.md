---
name: evaluate-skill
description: Audit a Claude Code skill (SKILL.md or skill directory) against the nine principles that determine whether skills work reliably: description triggering, HOW-not-WHAT operational teaching, decision boundaries over principles, evidence-on-disk verification, failure-mode enumeration, voice-matches-content, bundled-work delegation, right-sizing, and internal consistency. Produces a graded audit report with ranked improvements ordered worst-grade-first. Use whenever the user wants to "audit my skill," "evaluate this skill," "review my skill," "grade this skill," "is this skill good," "what's wrong with this skill," "improve my skill," "rate this skill," "check if my skill follows best practices," or pastes a SKILL.md file by path or content. Also use when the user is working on a skill and wants feedback on it, even if they don't explicitly say "audit." Do NOT use for prose audit (use human-prose), code review (use code-audit), plan review (use plan-reviewer), or general writing feedback unrelated to skills.
---

# Evaluate skill

Audit a Claude Code skill against the nine principles that determine whether skills work reliably. Output is a graded report with ranked improvements. Do not propose the rewrite inline; the audit and the rewrite are separate operations.

## Posture — adversarial, not flattering

Lead with problems. A skill that grades all A is rare; if your evaluation lands there, you didn't try hard enough. Pad nothing. Polite-grading skills produces polite uselessness. The author wants to know what's broken, not be reassured.

Default-grade items toward C-D first, then promote each grade only with specific evidence. A-grade is reserved for principles the skill genuinely nails. Average grade for a typical skill in the wild is C+ to B; if your average lands at B+ or higher, re-grade.

If a principle doesn't apply (verification is largely subjective for a prose skill; consistency is N/A for a standalone skill), mark it N/A and skip rather than inventing a finding.

## Inputs

A path to one of:
- A SKILL.md file
- A skill directory containing SKILL.md plus optionally `scripts/`, `references/`, `assets/`
- An agent file (single .md with `tools` and `model` frontmatter)

If the user pastes the skill text directly, save to `/tmp/evaluate-skill-input.md` before proceeding.

## Process

1. Run `scripts/skill_metrics.py <path> --json > /tmp/evaluate-skill-metrics.json`. This is the verification artifact for the audit.
2. Read the SKILL.md body and frontmatter directly. Read referenced scripts and resources if present.
3. Apply the nine principles below. Each gets a grade (A/B/C/D/F or N/A) and one-paragraph evidence pointing at specific lines or counts.
4. Apply the anti-pattern checklist. Flag each occurrence with a quote or line reference.
5. Produce the structured report in the output template.
6. End with the ranked action items (worst grade first) and offer to rewrite based on findings if the user wants.

## The nine principles

### 1. Description triggers correctly

A skill that never triggers does nothing. A skill that triggers wrongly creates noise. The description is load-bearing.

Required elements:
- Action verb plus object naming the work (not "A skill for X")
- 5+ specific phrasings the user might actually say (mix of casual and formal)
- Explicit Do-NOT clauses preventing false positives on adjacent territory
- "Pushy" markers per skill-creator: "whenever," "even if," "also use," "including"

From `skill_metrics.json`: `description.word_count`, `description.quoted_phrase_count`, `description.has_explicit_non_triggers`, `description.pushy_marker_count`.

Grades:
- A: 80+ words, 5+ quoted phrasings, explicit non-triggers, pushy markers present
- B: Three of four elements solid
- C: Two of four; commonly missing non-triggers
- D: One of four
- F: Empty, generic ("a skill for X"), or actively misleading

### 2. Body teaches HOW, not WHAT

Skills are operational guides for a model that already knows the domain. Pedagogical content should be brief and load-bearing for operational guidance that follows.

How to check:
- For each section, ask: does this change what the model does, or just explain what the topic is?
- A section that explains theory without producing a decision is pedagogical bloat.
- Background should occupy under ~10% of the body for substantive skills.

Grades:
- A: 90%+ operational; pedagogy is minimal and sets up specific operations
- B: 80-90% operational
- C: 60-80% operational
- D: 40-60%
- F: Mostly pedagogical; reads like a tutorial or essay

### 3. Decision boundaries, not principles

"Use X when Y, use Z when W" is operational. "Use the right approach for the situation" is not.

How to check:
- Look for explicit decision rules with named alternatives
- Concrete thresholds, numerical caps, enumerated cases
- Vague guidance ("be thorough," "use appropriately," "consider context") fails this principle

From metrics: `body.decision_rule_signals` is a rough indicator (count of "use X when," "if Y then," "stage N," "cap:" patterns).

Grades:
- A: Decision rules throughout; every section produces clear branches
- B: Decision rules in core sections; some softness around the edges
- C: Some decision rules but principles dominate
- D: Mostly principles
- F: All vibes, no rules

### 4. Verification built into the process

Self-asserted "I verified it works" is the canonical AI hallucination pattern. Evidence on disk (logs, JSON, scripts that produce checkable artifacts) is the fix.

How to check:
- Does the skill mandate producing artifacts the model can't fabricate?
- File paths under `/tmp/` or named output locations?
- Reference to scripts that produce verifiable output?

From metrics: `body.has_verification_artifact`.

Grades:
- A: Required artifact, specific path and format
- B: Required artifact, looser format
- C: Optional verification ("you can check by...")
- D: Self-asserted verification only
- F: No verification mentioned

N/A: For skills where output is fundamentally subjective (creative writing, brainstorming, opinion). Note the limitation; don't invent a verification step.

### 5. Failure modes enumerated

The model doesn't generalize from "be careful" to specific failure modes. The skill has to enumerate them.

What to look for:
- Lazy-patch lists (specific things NOT to do; the alternatives that look like fixes but aren't)
- Layered retry ladders (Stage 1 retry, Stage 2 fix, Stage 3 reconsider, Stage 4 escalate)
- Edge-case branches (heisenbug, missing input, conflicting evidence, unreachable state)
- Stop-out cases (when to halt and escalate rather than push through)

From metrics: `body.failure_mode_signals` (lazy-patch list, retry ladder, stop-out cases present or absent).

Grades:
- A: Multiple specific failure modes enumerated with named alternatives
- B: At least one strong enumeration (e.g., lazy-patch list OR retry ladder)
- C: Generic mentions of edge cases without enumeration
- D: "Be careful" only
- F: No failure-mode awareness

N/A: Truly simple skills with no plausible failure modes (rare; usually the failure modes exist and the skill is just ignoring them).

### 6. Written in voice it teaches

If the skill teaches conciseness, the body should be concise. If it teaches "minimal headers," the body should have minimal headers. If it teaches structured output, it should model the structure.

How to check:
- Identify any voice/style rules the skill explicitly teaches
- Verify the body follows them
- Common violation: skill teaches "no preamble" while preambling. Skill teaches "minimal bolds" while bolding every paragraph header.

Run the relevant counter (e.g., for a prose skill, run `format_scan.py` on the SKILL.md itself).

Grades:
- A: Body fully embodies the rules
- B: Embodies with documented carveouts (instructional-reference carveout is legitimate)
- C: Embodies in spirit, violates specific rules
- D: Violations frequent enough to undermine credibility
- F: Contradicts itself

N/A: Skill teaches a domain (code review, planning) with no applicable voice rules.

### 7. Bundles repeated work

Per skill-creator: if every invocation will produce a similar script or check, that work belongs in `scripts/`. The body delegates to the script instead of describing the procedure.

How to check:
- Does the skill describe procedures that could be a script?
- If `scripts/` exists, does the body reference the scripts as the canonical source?
- Repeated multi-step workflows inline = high-leverage cut candidates

From metrics: `bundled_resources.scripts_dir_exists`, `bundled_resources.scripts_files`.

Grades:
- A: Repeated work in `scripts/`; body delegates
- B: Some bundled, some inline; the inline is short and simple
- C: All inline; procedures are short
- D: All inline; procedures are long and complex (high-leverage cuts possible)
- F: The model is being asked to do work that should be a script

N/A: Skills where the work is fundamentally non-procedural (high-level guidance, philosophy).

### 8. Right-sized for scope

Skill-creator targets under 500 lines per SKILL.md. In words, roughly 2,000-3,500 for a substantive skill; well under 1,500 for a simple one. Bloat is content the skill doesn't need; under-sizing is missing gates.

How to check:
- Body word count from `body.word_count`
- 10-15% trim test: could 10-15% of the prose be cut without losing operational content?
- Compare scope to size: a single-purpose skill at 4,000 words is bloated; a multi-step orchestrator at 1,500 words is missing structure

Grades:
- A: Tightly sized; trim test fails (nothing cuttable)
- B: Slightly long or short; small trim opportunities
- C: 20-30% bloat; concrete cuts available
- D: 30-50% bloat
- F: 50%+ bloat OR critically under-sized (missing process)

### 9. Internal consistency

If the skill belongs to a system (a suite of related skills + agents), contracts should match across siblings and cross-reference rather than duplicate.

Examples of contracts: shared verification artifacts, shared retry ladders, shared anti-lazy patterns, shared commit-hygiene rules, shared output schemas.

How to check:
- Are contracts defined once and referenced, or duplicated across the suite?
- Where duplicated, do the duplicates match?
- Are there gaps where this skill should follow a declared contract but doesn't?

Grades:
- A: Cross-references; consistent with declared siblings
- B: Mostly consistent; minor duplication or drift
- C: Significant duplication or drift
- D: Inconsistent with siblings; multiple sources of truth
- F: Contradicts siblings on shared contracts

N/A: Standalone skill with no sibling system.

## Anti-patterns to flag

Each finding gets a quote or line reference. The metrics script catches some of these automatically (`anti_patterns` field); read the rest manually.

Aspirational preamble: "This skill empowers...", "Welcome to...", "This comprehensive guide...". Cut.

Generic AI advice: "Be careful," "Be thorough," "Consider all stakeholders," "Think step by step," "Handle edge cases," "Use your judgment." The model already does these. Concrete failure-mode enumeration replaces them.

Restating model defaults: "Use markdown for formatting," "Be clear and concise." Default behavior; stating it adds noise.

Long problem-space explanation: More than 2-3 sentences naming why the skill exists is pedagogical bloat.

MUSTs/NEVERs in all caps without reasoning: Per skill-creator, a yellow flag. Reframe and explain the underlying reason.

Repetition across sections: Same principle stated in three places dilutes rather than reinforces. One canonical statement, references elsewhere.

Vague bullet lists of exhortations: "Be specific," "Be honest" without operational content.

Decorative organization: Headers and lists that don't aid retrieval.

Content belonging in bundled resources: Long examples, reference data, executable templates that should live in `references/` or `scripts/`.

Self-congratulation: Meta-commentary about how well-designed the skill is.

## Output format

Reply with this structure exactly. No preamble.

```
# Skill audit: <skill name>

## Metrics summary
[Paste a short summary of the key metrics from skill_metrics.py output: word count, anti-pattern counts, presence of bundled resources, description quality]

## Grades

| # | Principle | Grade | Evidence (one line) |
|---|-----------|-------|---------------------|
| 1 | Description triggers | A/B/C/D/F/N/A | ... |
| 2 | HOW not WHAT | ... | ... |
| 3 | Decision boundaries | ... | ... |
| 4 | Verification | ... | ... |
| 5 | Failure modes | ... | ... |
| 6 | Voice it teaches | ... | ... |
| 7 | Bundles work | ... | ... |
| 8 | Right-sized | ... | ... |
| 9 | Consistency | ... | ... |

## Anti-patterns flagged
- <pattern>: at <line / section> — <quote>
- ... (or "None found" if clean)

## Ranked improvements (worst grade first)
1. **Principle N — Grade: action.** Concrete change: <what to do>. Source of truth: <line / section to change>.
2. ...

## Offer
If you'd like, I can rewrite the skill incorporating these findings, or apply specific fixes from the list above. Say which.
```

## Verification

The audit requires:
- `/tmp/evaluate-skill-metrics.json` exists and contains the skill_metrics output
- Every principle has a grade (or explicit N/A with reason)
- Every grade has at least one specific quote, line reference, or metric value as evidence
- Anti-patterns either flagged with quotes or explicitly listed as "None found"

Self-asserted "I evaluated it" without the metrics JSON is rejected. Re-run the script.

## Reject the lazy audit

Common failure modes that produce useless audits:

- Grading all A/B with no specific evidence. This is flattery, not audit.
- Generic improvements that could apply to any skill ("add more examples," "be more specific"). Each improvement should reference a specific principle and a specific change.
- Skipping principles because they're "hard to judge." Mark N/A with a reason; don't skip silently.
- Praising the skill's strengths at length while burying problems. Lead with problems.
- Repeating the metrics output verbatim without judgment. The metrics are inputs to the audit, not the audit itself.

If your draft audit hits any of these, restart the relevant sections.

## When not to apply

This skill audits SKILL.md files and skill directories. Do NOT use for:
- Prose audit — use `human-prose`
- Code review — use `code-audit`
- Plan review — use `plan-reviewer`
- General writing feedback unrelated to skills

For agent files (`.md` with `tools` and `model` frontmatter), the same nine principles apply with #9 (consistency) carrying more weight, since agents usually belong to orchestrated systems where shared contracts matter most.

## Self-check before delivering

- Metrics JSON captured to `/tmp/evaluate-skill-metrics.json`?
- Every principle has a grade or explicit N/A?
- Average grade is in the C+ to B range (not B+ or higher unless the skill is genuinely excellent)?
- Each finding has a quote, line reference, or metric value?
- Anti-patterns either flagged or explicitly noted as absent?
- Ranked improvements are concrete and ordered worst-grade-first?
- The report leads with problems, not strengths?

If all yes, deliver. If the average grade is high without specific evidence, you're flattering rather than auditing. Re-grade adversarially.