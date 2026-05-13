---
name: human-prose
description: Write prose that doesn't read as AI-generated. Use this skill whenever the user asks for help writing or revising an article, essay, blog post, short story, social-media post, newsletter, op-ed, cover letter, personal email, marketing copy, speech, LinkedIn post, Substack post, or any standalone prose — including casually phrased requests like "write me a quick post about X," "draft a blog post," "help me write this up," or "make this sound better." Also use whenever the user wants writing to feel "natural," "human," "less AI," "less like ChatGPT," "less formal," "less stiff," "more like me," or asks to remove AI tells, slop, or stiffness from existing text. Use this for any prose-writing task by default, including short ones. Do NOT use for structured technical writing where formality is correct (API documentation, legal contracts, scientific abstracts, formal reports, code comments) — those have their own conventions and shouldn't be casualized.
---

# Human prose

This skill exists because the default LLM voice is identifiable, and many writing tasks want something that doesn't read as AI-generated. The default voice has specific markers: a particular vocabulary, a few favored sentence structures, a habit of abstraction over specifics, and an overuse of headers and bullets. The fixes are also specific.

This is not a rule against formal prose. Academic writing, legal documents, and technical specifications use formal register correctly. The skill targets writing that should *feel* like a person wrote it: blog posts, essays, fiction, marketing copy, personal correspondence, speeches, op-eds, newsletters, social posts.

Before applying the patterns below, notice that this skill itself is written in the style it teaches. If a section feels wrong about how to write, check whether the skill is following its own advice. Where it isn't, fix the skill.

## The three failure modes

Most AI prose fails in three ways at once. Fix any one and the writing reads more human. Fix all three and it becomes hard to tell apart from competent human writing.

### 1. The abstraction trap

Default LLM prose floats above the world. It uses Latinate nouns (utilization, implementation, consideration), avoids naming specific people, places, dates, or numbers, and prefers categories over instances. The fix is to drop in concrete detail. Names. Years. Numbers with units. A specific anecdote. The shape of an actual room. A sentence with sensory weight.

Compare:

> Modern teams have begun to recognize the importance of clear communication in remote environments.

> When GitLab went fully remote in 2014, they wrote a 2,000-page handbook because nobody could grab anyone in a hallway.

The second one isn't more truthful. It's harder to skim past.

A useful test: pick any paragraph of the draft and ask whether it could be cut and pasted into any article on any topic. If yes, it's floating. Pull it down to something specific.

### 2. The standardized shape

Default LLM responses follow a recognizable arc: restate the question, deliver a numbered or bulleted list, close with a summary. Headers every two paragraphs. Bullets where prose would carry the thought.

Write in paragraphs unless a list is genuinely the right form (steps in a procedure, items that don't connect to each other, a true enumeration). Vary paragraph length. Let a one-sentence paragraph land alone when it should. Vary sentence length too — a long sentence with two clauses and a turn, then a short one. Then a medium one to settle the rhythm. The reader hears prose; sameness puts them to sleep.

Avoid the standard four-part LLM essay shape: introduction that restates the question, three named sections, conclusion that restates the introduction. Either commit to a real argument that needs that scaffolding or drop the scaffolding.

### 3. The vocabulary

A specific cluster of words appears at many times the human baseline rate in AI prose. Avoiding them is mechanical and high-leverage. See the next section.

## Vocabulary to avoid

These words and phrases are strong lexical tells. Avoid them in prose meant to feel human. If a word genuinely fits and no alternative works, use it — but check whether a plainer word would do first.

**Verbs:** delve, underscore, showcase, leverage, harness, foster, garner, unlock, empower, streamline, navigate (the complexities of), embark, dive into, tap into, elevate, amplify.

**Adjectives:** meticulous, intricate, commendable, pivotal, robust, seamless, holistic, transformative, comprehensive, unparalleled, profound, multifaceted, nuanced, vibrant, crucial (when not literally crucial), key (when not literally key), essential (same).

**Nouns:** realm, tapestry, testament, landscape (metaphorical), journey (metaphorical), ecosystem (outside biology and software), framework (used loosely), insights (when "ideas" works), endeavor, treasure trove, plethora, myriad.

**Openers and connectives:** "It's worth noting that," "It's important to remember that," "In today's fast-paced world," "In the realm of," "When it comes to," "At the heart of," "More than just," "Not only... but also," "In essence," "Ultimately."

**Filler intensifiers:** truly, deeply, incredibly, remarkably, fundamentally (when not making a point about foundations), genuinely (when not contrasting with fake).

The right move usually isn't a thesaurus swap. "Showcase" doesn't become "exhibit." It becomes "show," or it gets cut, or the sentence is rebuilt so the verb does work. "Leverage" becomes "use," and almost always the sentence improves. "Foster collaboration" becomes "get people working together," or it gets specific about what that means.

A useful prompt while revising: which words in this sentence are doing real work, and which are taking up space?

## Structural patterns to avoid

**The "It's not X, it's Y" antithesis.** It appears at over six times the human baseline rate. "It's not just a tool, it's a partner." "This isn't about avoiding mistakes, it's about learning from them." The structure feels rhetorically sharp but it's a tell, and overusing it flattens what should be a varied prose surface.

**The tricolon.** Three parallel items, especially when the third is heightened: "fast, reliable, and transformative." Humans use tricolons but not constantly. AI prose reaches for them every paragraph.

**Header-itis.** A header for each two-paragraph idea. Most prose pieces under 2,000 words need zero or one header. Long-form journalism uses subheads sparingly, often for navigation rather than structure. If a piece feels like it needs a header every few paragraphs, the prose probably isn't carrying the thought — strengthen the prose instead.

**Listicle-itis.** Converting prose ideas into bullets that don't deserve bullets. Bullets are for items the reader will scan, compare, or check off. They aren't for ideas with logical connection — those want sentences, because sentences encode the connections.

**Sandwich endings.** Closing paragraphs that restate the opening with slightly different words. End on the strongest specific point or the most interesting open question, not on a recap.

**Hedged openings.** Starting with "There are many ways to think about X" or "X is a complex topic with no easy answers." If the topic is complex, the prose will show it. The opening should do work.

**Bothsidesism by default.** Default LLM prose reaches for "on the other hand" reflexively, even when the writer has a clear position. Pick a stance. Acknowledge the counterargument once, fairly, and move on. Don't manufacture symmetry where the evidence isn't symmetric.

## What to do instead

The research on instruction-following finds that positive prescription beats negation — telling a model what *to* do works better than telling it what *not* to do. Avoiding the patterns above is necessary but not sufficient. The positive moves matter at least as much.

**Lead with the most specific thing first.** First sentences should anchor. Not "There are several reasons companies adopt remote work" but "Basecamp went remote in 1999, before the word was common, because Jason Fried lived in Chicago and his cofounder lived in Copenhagen."

**Use names, dates, and numbers.** Default to specifics over categories. "A study found" is weak; "Kobak and colleagues, analyzing 15 million PubMed abstracts, found" is strong. "Many users prefer" is weak; "67% of users in the December survey said" is strong.

**Write the way you'd talk to a sharp friend.** Not the way you'd write a memo. Contractions are fine. Sentence fragments are fine when they earn their place. Casual asides are fine. Profanity is fine if it fits the register (it usually doesn't, but it's allowed).

**Show your thinking, not just your conclusion.** Default LLM writing skips the reasoning and delivers the polished claim. Real essays let the reader see the writer change direction, notice a counterexample, reconsider. "I thought X, but then I noticed Y" is a move humans use constantly and AI prose almost never does.

**Vary sentence rhythm deliberately.** Long, medium, short. Two long ones in a row will tire the reader. Three short ones in a row sound choppy unless you mean it for effect. Read drafts aloud, or have a TTS tool read them. The ear catches what the eye misses.

**Earn your transitions.** "However," "Furthermore," "Additionally" are placeholders. Either the next idea connects to the previous one by logic that's already on the page, or the connection needs to be made with a real sentence, not a connective.

**Let opinions show.** Personal essays and op-eds with no detectable position read as AI. If the piece has an argument, state it plainly somewhere. If it's reportage, let the reader feel which details the writer found striking.

## Process: writing and revising

The best results come from writing once, then revising with this skill open. Trying to apply all of it during first drafting can stall the draft. Get the thinking down, then clean it.

**First pass: get the draft down.** Don't worry about tells. Worry about whether you're saying anything. If the draft is empty of specifics, the revision can't save it — go research, find the specifics, then write.

**Second pass: hunt vocabulary.** Read through with the banned-word list in mind. For every flagged word, ask whether a plainer word works. Usually yes.

**Third pass: hunt structure.** Look for "it's not X, it's Y" constructions, unnecessary tricolons, headers that don't earn their place, lists that should be prose. Read sections aloud and listen for rhythm.

**Fourth pass: pull abstractions down.** For every general claim, ask whether a specific instance, name, number, or anecdote could replace or anchor it. Usually one or two per page, well placed, transforms the piece.

**Fifth pass: trim.** Default LLM prose runs long. Cut every sentence that doesn't add information or rhythm. Cut openings that throat-clear. Cut closings that recap.

When revising someone else's draft, do these passes one at a time rather than all at once. Show the user the edited version with a brief note about what changed.

## Worked example

**Before (default LLM voice):**

> In today's rapidly evolving digital landscape, remote work has emerged as a transformative force that is fundamentally reshaping how organizations approach collaboration. It's not just a shift in location — it's a complete reimagining of what it means to work together. Companies that successfully navigate the complexities of distributed teams are unlocking unprecedented levels of productivity and employee satisfaction. By leveraging modern communication tools and fostering a culture of transparency, these organizations are showcasing what's possible when traditional boundaries are removed. The key is to embrace this new paradigm holistically.

Most paragraphs of that kind contain no information. Strip it for the failures: "rapidly evolving digital landscape" (abstraction trap, vocabulary), "transformative force" (vocabulary), "fundamentally reshaping" (filler intensifier), "It's not just X, it's Y" (banned structure), "navigate the complexities of" (banned phrase), "unlocking" (vocabulary), "unprecedented" (vocabulary), "leveraging" (vocabulary), "fostering" (vocabulary), "showcasing" (vocabulary), "embrace this new paradigm holistically" (everything wrong at once).

**After:**

> Basecamp went remote in 1999 because Jason Fried lived in Chicago and his cofounder lived in Copenhagen, and they couldn't think of a reason to fix that. Twenty-five years later, the question companies still get stuck on isn't whether remote work is possible — Basecamp settled that — but what they lose by giving up the office and what it takes to make up for it. GitLab's answer was a 2,000-page handbook. Stripe's was quarterly in-person offsites with travel paid. Both work. The companies that flail are the ones that went remote in 2020 and never picked a strategy beyond "let's see how it goes."

Same topic, different writing. The second version names companies, gives dates, makes a claim, and ends on a specific failure pattern rather than a recap. The paragraph could only be about its actual subject. The first one could be pasted into any article ever written about anything.

## When not to apply this

This skill is wrong for several kinds of writing.

**Legal and contractual writing** uses formal register because precision matters more than warmth, and the conventions exist for good reasons. "Notwithstanding the foregoing" looks like AI slop and isn't.

**Scientific abstracts and methods sections** have register expectations that match what this skill flags. A passive-voice methods section is correct; making it conversational is wrong.

**API documentation and technical reference** wants to be skimmable, predictable, and information-dense. Headers and lists are correct there. Concrete narrative is wrong.

**Some marketing copy** is genre-bound to use the moves this skill bans — pharmaceutical ads, certain B2B sales pages. If the user is writing in those genres deliberately, respect their choice.

**The user's actual voice.** If the user has supplied samples of how they write, those override every default in this skill. Match their cadence, their vocabulary, their structural habits. The point of the skill is to escape the LLM default, not to impose a different default.

When uncertain whether the skill applies, ask the user one short question rather than guessing.

## Self-check before finishing

Before delivering prose meant to feel human, scan once for these:

- Are there at least one or two specifics (name, date, number, anecdote) per few hundred words?
- Are any banned vocabulary words still in the draft, and do they survive the "is a plainer word better" test?
- Does the structure contain a header or bulleted list that isn't earning its place?
- Does any paragraph contain an "It's not X, it's Y" or an unnecessary tricolon?
- Does the opening do work, or does it throat-clear?
- Does the closing land on a specific thought or recap the opening?
- Read the first and last sentence aloud. Do they sound like a person wrote them?

If everything passes, ship it. If a few things still feel off, name them honestly when delivering: "I left the word 'comprehensive' in the third paragraph because the alternatives weakened the claim. Flag if you want it gone."
