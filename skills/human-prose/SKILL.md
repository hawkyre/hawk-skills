---
name: human-prose
description: Write prose that doesn't read as AI-generated. Use whenever the user asks for help writing or revising an article, essay, blog post, short story, social post, newsletter, op-ed, cover letter, personal email, marketing copy, speech, LinkedIn post, Substack post, or any standalone prose, including casually phrased requests like "write me a quick post about X," "draft a blog post," "help me write this up," or "make this sound better." Also use whenever the user wants writing to feel "natural," "human," "less AI," "less like ChatGPT," "less formal," "less stiff," "more like me," or asks to remove AI tells, slop, or stiffness from existing text. Use for any prose-writing task by default, including short ones. Do NOT use for structured technical writing where formal register is correct (API documentation, legal contracts, scientific abstracts, formal reports, code comments). Those have their own conventions and shouldn't be casualized.
---

# Human prose

The default LLM voice is identifiable, and many writing tasks want something that doesn't read that way. The voice has specific markers: a particular vocabulary, predictable sentence rhythms, abstraction over specifics, and a structural orientation called the markdown voice that bleeds into prose because RLHF rewarded the conventions of well-formatted documentation. Headers every two paragraphs, bolded keywords, em-dashes for asides, bulleted lists for parallel items, signpost transitions: all of it travels together. Em-dashes are the smallest unit of the same register, markdown's structural orientation surviving into prose where there are no headers to write. Vocabulary swaps alone don't escape it; the underlying voice has to go.

This is not a rule against formal prose. Academic writing, legal documents, and technical specifications use formal register correctly. The skill targets writing that should feel like a person wrote it: blog posts, essays, fiction, marketing copy, personal correspondence, speeches, op-eds, newsletters, social posts.

Apply this skill in its own voice. If a section reads like the failure modes it warns against, the section is wrong, not the rule.

The skill ships with three scripts in `scripts/` that produce the objective verification artifacts:

- `format_scan.py <draft>`: counts em-dashes, smart quotes, bold, italics, headers, bullets, numbered items against caps.
- `burstiness.py <draft>`: computes sentence-length standard deviation against the human range (4.8–7.2) and AI range (2.0–3.8).
- `voice_extract.py sample1 sample2 [sample3]`: extracts the user's stylistic features when they provide writing samples.

Self-asserted "I checked it" doesn't count. The script outputs do.

## The four failure modes

Fix all four. Fixing one without the others still ships AI-shaped prose.

### 1. The abstraction trap

Default LLM prose floats above the world. Latinate nouns. No specific people, places, dates, or numbers. Categories over instances. The fix is to drop in concrete detail: names, years, numbers with units, a specific anecdote, sensory weight.

Compare:

> Modern teams have begun to recognize the importance of clear communication in remote environments.

> When GitLab went fully remote in 2014, they wrote a 2,000-page handbook because nobody could grab anyone in a hallway.

The second one isn't more truthful. It's harder to skim past. The test: pick any paragraph and ask whether it could be cut and pasted into any article on any topic. If yes, it's floating.

### 2. The standardized shape

LLM responses follow a recognizable arc: restate the question, deliver a numbered or bulleted list, close with a summary. Headers every two paragraphs. Bullets where prose would carry the thought. This is the markdown voice in its full expression.

Write in paragraphs unless a list is genuinely the right form. Vary paragraph length. Vary sentence length (see Burstiness below). Avoid the four-part LLM essay shape: intro that restates the question, three named sections, conclusion that restates the intro. Either commit to a real argument that needs the scaffolding, or drop the scaffolding.

### 3. The vocabulary

A specific cluster of words appears at many times the human baseline rate in AI prose. The full list is below. Avoidance is mechanical and high-leverage. The right move usually isn't a thesaurus swap; rebuild the sentence so the verb does work, or cut the word.

### 4. The safe register

The failure mode that survives vocabulary cleanup. Three deeper habits, each with a concrete test.

No stance. The text talks about a topic rather than from a position on it. "GitLab wrote a 2,000-page handbook" is observational. "GitLab wrote a 2,000-page handbook, which sounds insane until you've tried to onboard a remote team without one" embeds a micro-judgment. Real prose embeds them throughout. Test: pick three sentences at random. Could any of them have been written by someone who disagrees with the piece's overall claim? If yes, the prose has no stance.

No risk. Humans say things they could be wrong about. AI hedges every claim to safety. Test: does the piece commit to any assertion someone could legitimately disagree with? If every claim is safe, the piece is AI-shaped regardless of vocabulary.

No surprise. AI defaults to the statistically expected next word. Real prose has unexpected word choices that reveal a specific angle. Test: find the most surprising word in the draft. If you can't, write toward one.

The four failure modes interact. Strong stance can carry abstractions humans would catch in safer prose. Strong specifics can absorb the occasional banned word. Fixing one usually fixes others.

## Vocabulary to avoid

Strong lexical tells. Avoid in prose meant to feel human. If a word genuinely fits and no alternative works, use it, but check whether a plainer word would do first.

Verbs: delve, underscore, showcase, leverage, harness, foster, garner, unlock, empower, streamline, navigate (the complexities of), embark, dive into, tap into, elevate, amplify.

Adjectives: meticulous, intricate, commendable, pivotal, robust, seamless, holistic, transformative, comprehensive, unparalleled, profound, multifaceted, nuanced, vibrant, crucial / key / essential (when not literally so).

Nouns: realm, tapestry, testament, landscape (metaphorical), journey (metaphorical), ecosystem (outside biology and software), framework (used loosely), insights (when "ideas" works), endeavor, treasure trove, plethora, myriad.

Openers and connectives: "It's worth noting that," "It's important to remember that," "In today's fast-paced world," "In the realm of," "When it comes to," "At the heart of," "More than just," "Not only... but also," "In essence," "Ultimately."

Filler intensifiers: truly, deeply, incredibly, remarkably, fundamentally (when not making a point about foundations), genuinely (when not contrasting with fake).

Newer formal-register tells (2025–2026): across the board, at scale, first-principles (as adjective), step-change, force multiplier, non-trivial (when "hard" works).

Newer casual-register tells: vibes, energy (metaphorical), rebel against, lean into, double down on, "the truth is" (reflexive opener), "here's the thing" (same), "the reality is" (same), "let me explain" (chat-context bleeding into prose).

"Showcase" doesn't become "exhibit." It becomes "show," or it gets cut, or the sentence is rebuilt so the verb does work. "Leverage" becomes "use," and almost always the sentence improves. "Foster collaboration" becomes "get people working together," or it gets specific about what that means.

While revising, ask: which words in this sentence are doing real work, and which are taking up space?

## Formatting and typography

Concrete numerical caps for prose meant to feel human. Run `scripts/format_scan.py <draft>` for the objective count.

- Em-dashes: cap 1 per 500 words. Claude defaults to several times that, the single highest-signal typographic tell in 2026 detection literature. Try comma, period, semicolon, or parentheses first; the em-dash earns its place only when no other mark works.
- Smart quotes (curly): cap 0. Use ASCII straight quotes. Smart quotes are a training-data fingerprint, and they break plain-text systems besides.
- Bold: cap 0 or 1 phrase per piece. Bold is for the moment a scanning reader must not miss. If you bolded a "key term," you wrote a textbook, not prose.
- Italics: titles, foreign words, true semantic emphasis (one word with the stress shifted). Not for "important" concepts.
- Headers: 0 or 1 in pieces under 2,000 words; 2 or 3 in pieces 2,000–5,000. Subheads are navigation aids for long-form, not paragraph signposts.
- Bullet lists: almost never in essays, blog posts, fiction, op-eds, newsletters, or social posts. Bullets are for parallel discrete items the reader will scan, compare, or check off (a packing list, an API reference). Ideas with logical connection want sentences.
- Numbered lists: same test. Seven numbered points means notes for an essay, not an essay.

These caps apply to prose. Reference documentation and instructional skills (like this one) legitimately use more structure; the carveouts in "When not to apply this" govern.

## Burstiness

Sentence rhythm has a measurable target. High-engagement human prose runs 4.8 to 7.2 standard deviation across sentence lengths; typical LLM output is 2.0 to 3.8. Too uniform.

Run `scripts/burstiness.py <draft>` for the actual number. While drafting (no file yet), use the easy proxy: count words in your last five sentences. If they're all within ±3 words of each other, you're in the AI default range. Drop a deliberate short sentence, or write one that sprawls past 35 words with two clauses and a turn before it lands.

Read drafts aloud. The ear catches sing-song cadence the eye misses.

## Patterns to avoid, and counter-moves

Each pattern has a positive replacement. Avoidance alone isn't enough; the positive move matters more.

The "It's not X, it's Y" antithesis appears at roughly six times the human baseline rate. Use once per piece at most. Pick the half that's load-bearing and write only that.

Tricolons used for rhythm rather than thought ("fast, reliable, and transformative"). Humans use tricolons but not constantly. A single strong noun phrase, sometimes with one qualifier, lands harder than three middling ones.

Sandwich endings that restate the opening. End on the strongest specific point or the most interesting open question, not a recap.

Hedged openings ("There are many ways to think about X"). Lead with the most specific thing first. Not "There are several reasons companies adopt remote work" but "Basecamp went remote in 1999, before the word was common, because Jason Fried lived in Chicago and his cofounder lived in Copenhagen."

Bothsidesism by default. Default LLM prose reaches for "on the other hand" reflexively, even when the writer has a clear position. Pick a stance. Acknowledge the counterargument once, fairly, and move on. Don't manufacture symmetry where the evidence isn't symmetric.

Generic transitions ("However," "Furthermore," "Additionally"). Earn the transition with a real sentence, or write the connection into the previous sentence so no connective is needed.

Polished claim without reasoning. Show your work. "I thought X, but then I noticed Y" is a move humans use constantly and AI almost never does.

Memo voice. Write the way you'd talk to a sharp friend. Contractions are fine. Sentence fragments are fine when they earn their place. Casual asides are fine. Profanity is fine if it fits the register.

Default to specifics over categories. "A study found" is weak; "Kobak and colleagues, analyzing 15 million PubMed abstracts, found" is strong. "Many users prefer" is weak; "67% of users in the December survey said" is strong.

Let opinions show. Personal essays and op-eds with no detectable position read as AI. If the piece has an argument, state it plainly somewhere. If it's reportage, let the reader feel which details the writer found striking.

## Sample-based voice matching

When the user provides writing samples or says "more like me," this section overrides the defaults above.

Run `scripts/voice_extract.py sample1.txt sample2.txt [sample3.txt]` to get the user's feature profile: sentence-length mean and stddev, paragraph length, em-dash density, contraction rate, top content words, top sentence openers, plus an explicit voice-match-guidance section that flags which defaults to relax. A user who legitimately uses "leverage" and em-dashes in their own writing should not have either stripped; the script's guidance section catches this.

If the user says "more like me" without samples, ask for two or three short ones before drafting. Don't guess. Research on stylistic mimicry shows that LLMs miss everyday writers' implicit styles without concrete examples; description-based voice instructions ("casual but professional") are too loose to land.

## Process

The best results come from writing once, then revising. Trying to apply everything during first drafting stalls the draft.

1. Get the draft down. Don't worry about tells. Worry about whether you're saying anything. If the draft is empty of specifics, the revision can't save it. Go research, find the specifics, then write.
2. Hunt vocabulary. Read with the banned-word list in mind. For every flagged word, ask whether a plainer word works.
3. Hunt structure. Patterns to avoid, counter-moves applied, abstractions pulled down to specifics. Read sections aloud.
4. Hunt stance. Does the piece commit to anything someone could disagree with? Are there micro-judgments per paragraph or just observations? Is there a surprising word, a writer's eye, a person on the page?
5. Trim and verify. Cut sentences that don't add information or rhythm. Cut openings that throat-clear. Cut closings that recap. Then run the scripts (see Self-check).

When revising someone else's draft, do these passes one at a time rather than all at once. Show the user the edited version with a brief note about what changed.

## Worked example

Before (default LLM voice):

> In today's rapidly evolving digital landscape, remote work has emerged as a transformative force that is fundamentally reshaping how organizations approach collaboration. It's not just a shift in location — it's a complete reimagining of what it means to work together. Companies that successfully navigate the complexities of distributed teams are unlocking unprecedented levels of productivity and employee satisfaction. By leveraging modern communication tools and fostering a culture of transparency, these organizations are showcasing what's possible when traditional boundaries are removed. The key is to embrace this new paradigm holistically.

Failures stacked: vocabulary (rapidly evolving digital landscape, transformative, unlocking, leveraging, fostering, showcasing, embrace, holistically), structure (the "not just X, it's Y" pattern with an unearned em-dash pair), abstraction trap (every claim category-level, no specifics), safe register (no stance, no risk, no surprise).

After:

> Basecamp went remote in 1999 because Jason Fried lived in Chicago and his cofounder lived in Copenhagen, and they couldn't think of a reason to fix that. Twenty-five years later, the question companies still get stuck on isn't whether remote work is possible (Basecamp settled that) but what they lose by giving up the office and what it takes to make up for it. GitLab's answer was a 2,000-page handbook. Stripe's was quarterly in-person offsites with travel paid. Both work. The companies that flail are the ones that went remote in 2020 and never picked a strategy beyond "let's see how it goes."

Different writing. Names, years, a claim, a specific failure pattern as the closing. Zero em-dashes (the em-dash pair in the original became a parenthetical). The short declarative "Both work." breaks the rhythm; the closing names a specific failure mode rather than recapping.

## When not to apply this

Several kinds of writing want the moves this skill bans.

Legal and contractual writing uses formal register because precision matters more than warmth. "Notwithstanding the foregoing" looks like AI slop and isn't.

Scientific abstracts and methods sections have register expectations that match what this skill flags. A passive-voice methods section is correct; making it conversational is wrong.

API documentation and technical reference wants to be skimmable, predictable, and information-dense. Headers and lists are correct there.

Instructional reference (like this skill, like internal docs) sits between prose and reference. It legitimately uses more structure than a blog post, because readers scan and revisit. Prose within sections still embodies the rules.

Some marketing copy is genre-bound to use the banned moves (pharmaceutical ads, certain B2B sales pages). If the user is writing in those genres deliberately, respect their choice.

The user's actual voice. If the user has supplied samples of how they write, those override every default. Match their cadence, vocabulary, structural habits, punctuation. The point is to escape the LLM default, not to impose a different default.

When uncertain whether the skill applies, ask the user one short question rather than guessing.

## Self-check before finishing

Verification artifact (run before claiming done):

```
python scripts/format_scan.py <draft>
python scripts/burstiness.py <draft>
```

If `format_scan` reports `all_pass: false`, a formatting cap is breached; another pass is required. If `burstiness` reports `range_class: ai_range` or `very_uniform`, the rhythm is too flat to ship.

Then a subjective content scan the scripts can't do:

- At least one or two specifics (name, date, number, anecdote) per few hundred words?
- Does the piece commit to a claim someone could legitimately disagree with?
- Could any three sentences have been written by someone who disagrees with the overall claim? If yes, the prose has no stance.
- What's the most surprising word in the draft? If there isn't one, find one or write toward one.

Read the first paragraph and the last paragraph aloud. Openings and closings are where AI sing-song cadence is loudest, and they're where readers form impressions.

If everything passes, ship it. If a few things still feel off, name them honestly when delivering: "I left 'comprehensive' in the third paragraph because the alternatives weakened the claim. Flag if you want it gone."
