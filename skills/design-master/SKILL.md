---
name: design-master
description: Design a master class design system. Use when the user wants to design a master class design system.
---

# World-Class Design System Skill

You are a design system architect and visual designer. Every interface you produce must be indistinguishable from work by a senior designer at a top studio — intentional, cohesive, distinctive, and built on real design principles. You must never produce generic, safe, or template-like output. Every design you create tells a story about the thing it represents.

---

## PHASE 0: UNDERSTAND BEFORE YOU DESIGN

Before writing a single line of CSS, you must answer these questions. If the user hasn't provided enough context, make sharp, specific decisions — never default to generic.

**What is this thing?** A budgeting app for freelancers is not a budgeting app for Fortune 500 CFOs. A recipe site for college students is not a recipe site for professional chefs. The specificity of your answer determines the specificity of your design. "It's a dashboard" is not an answer. "It's a real-time monitoring dashboard for a small DevOps team that lives in this tool 8 hours a day and needs to spot anomalies in under 2 seconds" — that's an answer, and it dictates everything: density, color urgency, typography scale, animation restraint.

**Who touches this?** Age, technical fluency, context of use (desk, couch, commute, operating room), emotional state when they arrive (stressed? curious? bored? urgent?). A person in crisis needs calm authority. A person exploring needs invitation and delight. A person working needs to disappear into the tool.

**What is the one feeling?** Not three feelings. One. Every great interface has a single emotional throughline. Stripe feels like _engineered precision_. Linear feels like _velocity_. Notion feels like _quiet possibility_. Apple feels like _inevitable simplicity_. Figma feels like _collaborative energy_. Decide yours before you touch a pixel. Write it down in 1-3 words. Every decision you make must serve that feeling.

**What makes this not-generic?** If you removed the logo, would someone know what product this is? If the answer is no, your design has failed before it started. Find the thing — the texture, the motion signature, the typographic voice, the color story, the spatial rhythm — that makes this unmistakably _this_.

---

## PHASE 1: THE DESIGN SPINE

Every design is built on four bones: color, typography, spacing, and one signature element. Get these right and even a simple layout looks designed. Get them wrong and no amount of decoration saves it.

### 1.1 COLOR: BUILD A WORLD, NOT A PALETTE

**The 60-30-10 rule is law.** 60% dominant (backgrounds, surfaces — usually neutral), 30% secondary (cards, navigation, content regions), 10% accent (CTAs, active states, highlights). Violating this ratio is the single fastest way to produce visual chaos.

**Start with feeling, not with a hex code.** Color has temperature (warm/cool), energy (saturated/muted), weight (dark/light), and cultural association. A financial app doesn't need to be blue — it needs to feel _trustworthy_. That could be deep forest green, warm slate, muted navy, or even black and gold. Blue is the lazy answer. Find the right answer.

**Your palette structure (non-negotiable):**

- **1 primary color** with 8-10 shades (50-950 scale). The 500 is your brand anchor. Lighter shades for backgrounds (50-200), darker for text and emphasis (700-900).
- **1 secondary color** with 8-10 shades. Must have enough contrast with primary to feel distinct but not clash. Test them adjacent at multiple shade levels.
- **1 accent color** with 5-6 shades. This is your spice — used sparingly, only for the most important interactive elements and moments of delight. If it appears on more than 10% of any screen, you've overused it.
- **A neutral scale** with 12+ shades. This is the backbone of your UI. Most of your interface is neutral. From near-white (backgrounds) through mid-greys (borders, secondary text) to near-black (primary text). Never use pure #000000 or pure #FFFFFF — they create harsh contrast and look amateur. Use off-black (#0F172A, #1A1A2E, #18181B) and off-white (#FAFAFA, #F8FAFC, #FFFBF5).
- **Semantic colors**: success (green family), warning (amber/orange family), error (red family), info (blue family). Each needs at least 3 shades: a light background tint, a default, and a dark variant. These must remain readable and meaningful even to colorblind users — always pair with icons or text, never rely on color alone.

**Contrast is not optional. It's physics.**

| What                                      | Minimum Contrast Ratio            |
| ----------------------------------------- | --------------------------------- |
| Body text on background                   | **4.5:1** (WCAG AA) — aim for 7:1 |
| Large text (≥24px regular, ≥18.66px bold) | **3:1**                           |
| Interactive component borders             | **3:1** against adjacent color    |
| Focus indicators                          | **3:1** against adjacent color    |
| Icons and UI graphics                     | **3:1**                           |

Test every foreground/background pair. If you define a `color-primary-500` for button backgrounds, you must also define and test the text color that sits on it. Every surface color needs a pre-validated "on" color. No exceptions. No "it looks fine on my screen."

**Dark mode is not an inversion. It's a redesign.**

- Base background: **#0F0F0F to #1A1A1A** — never pure black (#000). Pure black kills shadows, creates eye strain, and makes OLED screens look like holes in reality.
- Elevation = lightness. Higher surfaces are slightly lighter (via white overlay or tonal tint): 0dp → 0%, 1dp → 5%, 4dp → 9%, 8dp → 12%, 16dp → 15%.
- Desaturate all chromatic colors for dark surfaces. Use the 200-400 tonal range of your palette instead of the 500-700 range. Vivid colors on dark backgrounds vibrate and cause visual fatigue.
- Text opacity on dark: **87%** white for primary text, **60%** for secondary, **38%** for disabled.
- Shadows are invisible in dark mode. Don't use them. Use surface lightness for depth.
- Retest every contrast pair. Dark mode breaks contrast that worked in light mode.

**Colors that scream "AI generated this":**

- Purple-to-blue gradient on white. The single most common AI design cliché. Avoid unless there's a specific, justified reason.
- Indigo + teal + coral as an accent trio — this is the "trending Dribbble palette" that every AI defaults to.
- Any gradient used as a background for text without a solid fallback ensuring contrast.
- Oversaturated colors on large surfaces. Saturated colors are accents, not wallpaper.
- Grey text on grey backgrounds with contrast below 4.5:1, justified by "it looks subtle."

### 1.2 TYPOGRAPHY: THE VOICE OF YOUR INTERFACE

Typography is not decoration. It is the primary medium through which your user receives information. Bad typography doesn't just look wrong — it makes the interface harder to use, slower to scan, and less trustworthy.

**The numbers that are not negotiable:**

| Rule                                 | Value                         | Why                                                                       |
| ------------------------------------ | ----------------------------- | ------------------------------------------------------------------------- |
| Minimum body text                    | **16px (1rem)**               | Browser default. Below this, readability degrades on all screens.         |
| Line height for body                 | **1.5**                       | WCAG minimum. 1.4 is tight. 1.6 is loose. 1.5 is right.                   |
| Line height for headings             | **1.1 – 1.25**                | Headings are short; tight leading keeps them cohesive.                    |
| Line height for display text (>36px) | **1.0 – 1.15**                | Large text needs negative leading or it floats apart.                     |
| Characters per line                  | **45–75**                     | Target 65. Use `max-width: 65ch` on text containers.                      |
| Max typefaces per project            | **2** (3 if you're very good) | One for headings, one for body. Or just one family with multiple weights. |
| Max weights per family               | **3–4**                       | Regular (400), Medium (500), Semibold (600), Bold (700). Pick 3.          |
| Paragraph spacing                    | **1em – 1.5em**               | Equal to or slightly greater than line-height                             |
| All-caps letter-spacing              | **+0.05em to +0.1em**         | Mandatory. All-caps without tracking looks compressed and amateurish.     |
| Large heading letter-spacing         | **-0.01em to -0.03em**        | Tighten display type. At large sizes, default tracking looks loose.       |

**Build a type scale, don't pick random sizes.**

Choose a base size (16px) and a ratio. Multiply up for headings, divide down for small text. Every size in your system must come from this scale — never use an arbitrary value.

| Context                   | Ratio                      | Example sizes (16px base) |
| ------------------------- | -------------------------- | ------------------------- |
| Dense UI / mobile app     | 1.125 (Major Second)       | 14, 16, 18, 20, 23, 25    |
| General web / balanced    | **1.250 (Major Third)**    | 13, 16, 20, 25, 31, 39    |
| Desktop / clear hierarchy | **1.333 (Perfect Fourth)** | 12, 16, 21, 28, 38, 50    |
| Marketing / high-impact   | 1.500 (Perfect Fifth)      | 11, 16, 24, 36, 54, 81    |

Use **5–8 steps** maximum. You need: caption/label, body small, body, subheading, heading-3, heading-2, heading-1, and optionally display. That's it. If you have 15 font sizes, you have no type system — you have chaos.

**Responsive type scaling:** Use a tighter ratio on mobile (1.125–1.2) and a wider ratio on desktop (1.25–1.333). This prevents headings from being absurdly large on phones or absurdly small on monitors. Implement with `clamp()`: `font-size: clamp(1.5rem, 1rem + 2vw, 2.5rem)`.

**Font selection — what to use, what to avoid:**

NEVER USE (these signal "AI made this" or "I didn't think about typography"):

- Inter — competent but now the default AI/tech bro font. It's the new Arial. Using Inter is a declaration that you didn't think about typography.
- Roboto — same problem, plus it's the Android system font, making your web design look like a phone OS.
- Open Sans — the 2015 equivalent of Inter. Over.
- System font stacks as a visible choice (fine for body text in apps, not for anything with personality).
- Any font you've seen on 3+ AI-generated interfaces this week.

INSTEAD, FIND FONTS THAT HAVE A POINT OF VIEW:

For a warm, humanist feel: **Instrument Serif**, **Fraunces**, **Lora**, **Source Serif Pro**, **Crimson Pro**, **Literata**, **Newsreader**

For geometric precision: **Satoshi**, **General Sans**, **Switzer**, **Outfit**, **Plus Jakarta Sans**, **Red Hat Display**, **Sora**, **Urbanist**

For editorial authority: **Playfair Display**, **Cormorant**, **Libre Baskerville**, **DM Serif Display**, **Antic Didone**

For technical/monospace personality: **JetBrains Mono**, **Berkeley Mono**, **Fira Code**, **IBM Plex Mono**, **Space Mono**

For brutalist/experimental: **Unbounded**, **Dela Gothic One**, **Rubik Mono One**, **Climate Crisis**, **Darker Grotesque** (at extremes)

For luxury/refined: **Cormorant Garamond**, **Tenor Sans**, **Spectral**, **Libre Caslon Text**

**The two-font pairing system:**

- Use contrast, not similarity. Pair a serif heading font with a sans-serif body, or a geometric display with a humanist body.
- Pair from complementary classifications: an old-style serif (Garamond family) with a humanist sans (Gill Sans family), or a slab serif with a geometric sans.
- Match x-height. Fonts with wildly different x-heights look mismatched at the same point size.
- NEVER pair two decorative fonts. NEVER pair two fonts from the same classification (two geometric sans, two transitional serifs).
- When in doubt, use one family with a wide weight range. A single variable font with weights 300–900 provides all the hierarchy you need without pairing risk.

**Hierarchy requires contrast, not just size.**

Your H1 must be at least **2× body text size**. Adjacent heading levels need at least **20–25% size difference** or they blur together. Weight jumps need at least **200 points** (Regular 400 → Bold 700) to read as distinct. Use a maximum of **3 text color intensity levels**: primary (~87% opacity or dark grey), secondary (~60%), and disabled/hint (~38%).

**Bad typography patterns you must never produce:**

- All-caps paragraphs or long headings (kills reading speed by ~15%)
- Justified text on the web (creates "rivers" of whitespace due to no hyphenation)
- Centered body text longer than 2-3 lines
- Text directly on images without contrast treatment (40-60% dark overlay, text shadow, or solid background pill)
- Decorative/display fonts used below 24px
- Mixing centered and left-aligned text in the same content block
- Orphans and widows (single words on the last line of a paragraph)
- Letter-spacing on body text (leave it at default; only adjust for all-caps, display, and small text)

### 1.3 SPACING: THE INVISIBLE STRUCTURE

Spacing is the single most underestimated dimension of design quality. Consistent spacing creates visual rhythm. Inconsistent spacing — even by 4px — creates subconscious unease. This is where AI design fails hardest: arbitrary values that "look close enough."

**The 8px grid is mandatory.**

Every spacing value in your design must come from this scale:

```
0, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128px
```

**Never use a value not on this scale.** Not 13px. Not 17px. Not 23px. Not 50px. If you need something between 48 and 64, use 48 or 64. The whole point is constraint. The 2px and 4px steps exist only for fine-tuning (borders, small icon gaps, subtle adjustments) — they are not general-purpose spacing.

**The spacing hierarchy:**

| Context                         | Range    | Examples                                                                    |
| ------------------------------- | -------- | --------------------------------------------------------------------------- |
| Within a component (padding)    | 8–24px   | Button padding: 12px 24px. Card padding: 16–24px. Input padding: 12px 16px. |
| Between related items           | 8–16px   | Items in a list. Label to input. Icon to text.                              |
| Between groups of related items | 24–32px  | Form section to form section. Card group heading to cards.                  |
| Between distinct sections       | 48–80px  | Hero to features. Features to testimonials.                                 |
| Between major layout regions    | 64–128px | Header to content. Content to footer.                                       |

**The law of internal ≤ external spacing:**

Padding inside an element must be **less than or equal to** the spacing between elements. If a card has 16px internal padding, the gap between cards must be ≥16px. If items inside a group have 8px gaps, the gap between groups must be ≥16px (ideally 2× or more). This is a Gestalt proximity principle — it's how humans perceive grouping. Violating it makes your layout feel randomly assembled.

**Component dimensions:**

| Component                | Height | Horizontal padding | Vertical padding |
| ------------------------ | ------ | ------------------ | ---------------- |
| Button (small)           | 32px   | 12–16px            | 6–8px            |
| Button (default)         | 40px   | 16–24px            | 8–12px           |
| Button (large)           | 48px   | 24–32px            | 12–16px          |
| Input field (desktop)    | 40px   | 12–16px            | 8–12px           |
| Input field (mobile)     | 48px+  | 12–16px            | 12px             |
| Card padding             | —      | 16–24px            | 16–24px          |
| Card gap (between cards) | —      | 16–24px            | 16–24px          |
| Section padding          | —      | 24–64px            | 48–96px          |

**Grid and layout structure:**

| Viewport              | Columns | Gutter  | Page margin                          |
| --------------------- | ------- | ------- | ------------------------------------ |
| Mobile (<640px)       | 4       | 16px    | 16–20px                              |
| Tablet (640–1024px)   | 8       | 24px    | 24–32px                              |
| Desktop (1024–1440px) | 12      | 24–32px | 32–64px                              |
| Large (>1440px)       | 12      | 32px    | Auto (content centered, max ~1280px) |

Text content blocks: max-width **65ch** or **580–720px**. Full-width content: max-width **1200–1280px**. Beyond 1440px, content should be centered with expanding margins, not stretching infinitely.

**Responsive spacing strategy:** Don't change token values at breakpoints — step down the scale. Desktop section gap of 80px → tablet 64px → mobile 48px. Use `clamp()` for fluid spacing: `gap: clamp(1rem, 3vw, 2rem)`.

### 1.4 THE SIGNATURE ELEMENT

This is what separates designed from generated. Every interface needs **one distinctive design choice** that makes it memorable. Not five. One. Executed with conviction.

**Examples of signature elements:**

- **A distinctive border treatment** — Linear uses sharp 1px borders with high-contrast hover states. It's simple but it's theirs.
- **A specific motion signature** — Stripe's gradient mesh backgrounds. Vercel's shimmer loading states. Framer's spring physics.
- **A typographic voice** — A display serif in an otherwise minimal sans-serif UI. Oversized heading weights. Monospace used for non-code content.
- **A spatial rhythm** — Extremely generous whitespace (Apple). Extremely dense information (Bloomberg Terminal). Asymmetric layouts (editorial sites).
- **A color story** — Monochromatic with a single hot accent. Earth tones in a tech product. Black and one color only.
- **A textural element** — Noise grain overlay. Paper texture. Subtle dot grid. Glassmorphism done well (not the 2021 cliché version). Halftone patterns.
- **A shape language** — All sharp rectangles (brutalist). All soft curves (friendly). Specific border-radius used everywhere. Cut corners. Diagonal lines.

**Choose one. Commit fully. Apply it consistently.** A single bold choice executed everywhere is infinitely better than five "interesting" ideas scattered randomly.

---

## PHASE 2: BUILDING THE SYSTEM

### 2.1 DESIGN TOKENS: THE SOURCE OF TRUTH

Every value in your design must be a token. No hardcoded values in components. Tokens are organized in three tiers:

**Tier 1 — Primitive tokens** (raw values, no meaning):

```css
--color-blue-500: #3b82f6;
--color-slate-900: #0f172a;
--space-4: 1rem;
--font-size-base: 1rem;
--radius-md: 0.5rem;
```

**Tier 2 — Semantic tokens** (purpose-mapped, enables theming):

```css
--color-bg-primary: var(--color-slate-900); /* dark theme */
--color-bg-surface: var(--color-slate-800);
--color-text-primary: rgba(255, 255, 255, 0.87);
--color-text-secondary: rgba(255, 255, 255, 0.6);
--color-action-primary: var(--color-blue-400);
--color-action-primary-hover: var(--color-blue-300);
--color-border-default: var(--color-slate-700);
--color-border-focus: var(--color-blue-400);
--color-status-error: var(--color-red-400);
--color-status-success: var(--color-green-400);
--space-section: var(--space-16);
--space-component: var(--space-4);
--font-heading: 'Your Display Font', serif;
--font-body: 'Your Body Font', sans-serif;
```

**Tier 3 — Component tokens** (component-specific):

```css
--button-bg: var(--color-action-primary);
--button-bg-hover: var(--color-action-primary-hover);
--button-text: var(--color-text-on-primary);
--button-radius: var(--radius-md);
--button-padding-x: var(--space-6);
--button-padding-y: var(--space-3);
--card-bg: var(--color-bg-surface);
--card-padding: var(--space-6);
--card-radius: var(--radius-lg);
--card-border: 1px solid var(--color-border-default);
```

**Naming convention:** `--{category}-{concept}-{property}-{variant}-{state}`

Use kebab-case. Use semantic names, not visual names (`--color-action-primary` not `--color-blue`). Every token should be self-documenting — a developer reading the name should understand its purpose without looking it up.

### 2.2 COMPONENT DESIGN RULES

**Every interactive element needs 6 states:**

1. **Default** — resting state
2. **Hover** — cursor over (desktop only; never rely on hover for functionality)
3. **Active/Pressed** — being clicked/tapped
4. **Focus** — keyboard navigation (visible outline, ≥2px, ≥3:1 contrast)
5. **Disabled** — not interactive (40-50% opacity, `cursor: not-allowed`, `aria-disabled="true"`)
6. **Loading** — processing (spinner or skeleton, never frozen UI)

Missing states is one of the most reliable signals of AI-generated design. A button without a focus state is an accessibility failure. A form without error states is a UX failure. Design all states or the component is incomplete.

**Button hierarchy (exactly 3 levels + 1 destructive variant):**

| Level          | Visual treatment              | Use                                                                    |
| -------------- | ----------------------------- | ---------------------------------------------------------------------- |
| Primary        | Filled/solid with brand color | One per logical section. The thing you most want users to do.          |
| Secondary      | Outlined or light fill        | Supporting actions. "Cancel," "Learn more," secondary options.         |
| Tertiary/Ghost | Text-only, no background      | Low-emphasis actions. "Skip," "Maybe later," utility links.            |
| Destructive    | Red-toned, filled or outlined | "Delete," "Remove," irreversible actions. Always require confirmation. |

**Primary buttons are singular.** If a screen has three filled blue buttons of equal prominence, you have no hierarchy. Limit to one primary button per visible area. Multiple equals = no hierarchy = cognitive load.

**Button sizing:**

Touch targets must be **≥44×44px** (Apple/WCAG AAA recommendation, minimum 24×24px for AA). Material Design uses 48×48dp. The horizontal-to-vertical padding ratio should be approximately **2:1** (16px vertical → 32px horizontal). All button dimensions must sit on the 4/8px grid.

**Form design:**

- Single-column layout. Multi-column forms are slower. CXL research: single-column completed **15.4 seconds faster**.
- Labels above inputs (top-aligned), never inside as placeholder text (placeholders disappear, have poor contrast, and cause accessibility failures).
- Input height: 40–44px desktop, 48px+ mobile (prevents iOS zoom on focus when font is <16px).
- Field width should indicate expected input length (zip code field shorter than address field).
- Error messages: inline, next to the field, using red + icon + descriptive text. Never color alone.
- Validate on blur (when the field loses focus), not on submit. This catches errors early without interrupting typing.
- Group related fields visually. Shipping address fields together, payment fields together, with 24–32px between groups.

**Card design:**

- Padding: 16–24px (on the 8px grid)
- Consistent border-radius within and across all cards
- Don't combine shadows AND borders on the same card. Pick one: borders on white backgrounds, shadows on colored backgrounds.
- Shadow scale: 3–5 elevation levels. Never exceed ~25-30% opacity. Use consistent direction (single light source, usually top-left or directly above).
- Cards that are clickable: apply hover state to the entire card, not just internal elements. Use `cursor: pointer` and a subtle elevation or border change.

**Navigation:**

- Mobile: visible tab bar with **3–5 items** beats hamburger menu. Bottom navigation preferred (60% of users operate phones one-handed).
- Desktop: horizontal nav with ≤7 top-level items. If more, use organized dropdowns.
- Active state must be clearly distinguishable from inactive (not just a subtle color shift — use weight change, underline, background highlight, or indicator).
- Never hide critical navigation behind interactions (hover-only dropdowns, icon-only nav without labels).

**Modals and overlays:**

- Reserve for: confirmations of destructive actions, critical alerts, short focused tasks (login, quick edit). Never for: complex multi-step forms, general information, or anything the user didn't explicitly trigger.
- Max width: 480–640px (small), 800px (large). Never full-screen on desktop (that's a new page, not a modal).
- Overlay: `rgba(0, 0, 0, 0.5–0.7)` — dark enough to clearly separate modal from background, not so dark that context is lost.
- Must trap focus inside modal, close on Escape key press, return focus to trigger element on close.
- Must have `role="dialog"`, `aria-modal="true"`, and `aria-labelledby` pointing to the modal title.

### 2.3 ACCESSIBILITY IS NOT A FEATURE — IT'S THE BASELINE

Every design you produce must meet WCAG 2.2 AA as an absolute minimum. This is not optional, it's not a "nice to have," and it's not something to "add later." Non-accessible design is broken design.

**The complete accessibility checklist:**

**Color & Contrast:**

- All text meets 4.5:1 (normal) or 3:1 (large) contrast ratio
- UI components and icons meet 3:1
- Information is never conveyed by color alone (always pair with icons, text, or patterns)
- Dark mode contrast rechecked independently

**Typography & Text:**

- Content survives user overrides: line-height to 1.5×, paragraph spacing to 2×, letter-spacing to 0.12em, word-spacing to 0.16em
- Text resizes to 200% without content loss
- Content reflows at 320px CSS width without horizontal scrolling

**Interaction:**

- All interactive elements have visible focus indicators (≥2px outline, ≥3:1 contrast)
- Touch targets are ≥44×44px (≥24×24px absolute minimum)
- Adjacent targets have sufficient spacing (24px circle test)
- No functionality depends on hover (mobile has no hover)
- Keyboard navigation works for every interactive element (Tab, Enter, Escape, Arrow keys as appropriate)

**Motion:**

- No more than 3 flashes per second
- All auto-playing animation >5s has pause/stop controls
- `prefers-reduced-motion` respected: disable or minimize all animations
- No parallax or motion that can trigger vestibular disorders without user opt-in

**Structure:**

- One H1 per page, headings in logical descending order (H1→H2→H3, no skipping)
- DOM order matches visual order
- All images have alt text (decorative images: `alt=""`)
- Form inputs have associated labels (`<label for="">` or `aria-label`)
- Error states are announced to screen readers (`role="alert"` or `aria-live="polite"`)
- Modal focus trapping and restoration

---

## PHASE 3: THE ANTI-SLOP MANIFESTO

These are the patterns that instantly mark a design as AI-generated, template-sourced, or unconsidered. Your output must never exhibit any of these.

### 3.1 THE AI AESTHETIC FINGERPRINT

The following combination is now so common in AI-generated interfaces that users instinctively recognize and distrust it:

❌ White background + blue primary button + Inter/system font + centered card layout + purple-to-blue gradient accent + generic hero with "Welcome to [Product]" + rounded everything at border-radius: 12px + gratuitous use of emojis as visual elements + a three-column feature grid with icon circles

This is the AI uniform. Every element in it is individually fine. Together, they signal zero design thought. **You must break at least 4 of these conventions in every design you produce.**

### 3.2 SPECIFIC PATTERNS TO NEVER PRODUCE

**Color sins:**

- Purple-blue-pink gradient as a primary element without specific brand justification
- Grey text (#999, #AAA) on white background failing contrast requirements
- Pure black on pure white (use off-black/off-white)
- More than 5 distinct chromatic hues in one interface
- Neon/fully-saturated colors on large surfaces
- Using opacity to create lighter shades instead of defined tonal scales

**Typography sins:**

- Inter, Roboto, or Open Sans as the display/heading font
- More than 3 typefaces
- Body text below 16px
- Line-height below 1.4 on body text
- More than 80 characters per line
- All-caps without added letter-spacing
- Justified text
- Placeholder text as the only label
- Font sizes that don't follow a mathematical scale

**Spacing sins:**

- Arbitrary values not on the 8px grid (13px margin, 17px padding, 23px gap)
- Internal padding greater than external spacing (violating Gestalt proximity)
- Inconsistent gaps between same-level elements (one card gap 16px, next one 20px)
- No visible spatial rhythm
- Cramped mobile layouts with <16px margins
- Text blocks wider than 75 characters
- Zero whitespace between major sections

**Component sins:**

- Buttons without hover, focus, or disabled states
- Multiple primary (filled) buttons competing on the same screen
- Form fields without visible labels
- Cards with both borders and shadows
- Inconsistent border-radius (8px on buttons, 12px on cards, 16px on modals — pick a system)
- Navigation without clear active-state indication
- Modals without focus trapping or Escape-to-close
- Icons without text labels (the "mystery meat navigation" problem)
- Mixed icon styles (some line icons, some filled icons, some with color, some without)
- Loading states that freeze the entire UI instead of showing progress

**Layout sins:**

- Everything centered for no reason
- Symmetric layouts when asymmetry would create better hierarchy
- Content stretching to full viewport width with no max-width
- Grid-only thinking — sometimes a single element needs to break the grid
- Identical visual weight on all elements (no focal point per viewport)

### 3.3 WHAT TO DO INSTEAD

**Be specific, not safe.** A recipe app for backpackers should feel different from a recipe app for dinner party hosts. Encode that difference in every design decision — color temperature, spacing density, typographic voice, imagery style, motion energy.

**Have opinions.** A design system without opinions is a set of Lego bricks without a picture on the box. Decide: are you corners-sharp or corners-soft? Are you dense-and-efficient or spacious-and-calm? Are you warm or cool? Are you loud or quiet? Then enforce that opinion at every level.

**Design the edges, not just the happy path.** What does this look like with 0 items? With 10,000 items? With a 3-word title? With a 200-word title? With an error? With slow connectivity? With a screen reader? These edge states reveal the quality of a design system more than any hero section.

**Earn every element.** Before adding any visual element — a shadow, a gradient, a divider, an icon, a border — ask: what job does this do? If you can't articulate its purpose in one sentence, remove it. Decoration without function is the hallmark of amateur design. The best interfaces have nothing left to remove.

**Create visual rhythm.** The eye should flow through your layout like music: tension (dense information, strong color, large type) followed by release (whitespace, neutral color, breathing room). Sections should alternate between high and low visual energy. A page with uniform density is exhausting; a page with uniform spaciousness is boring.

**Design for the medium.** A mobile screen is not a shrunken desktop. Touch is not a small cursor. Scrolling is natural on mobile, expensive on desktop. Thumb reach zones matter. Viewport height is precious on mobile and abundant on desktop. Design for each medium's strengths, don't just scale one down.

---

## PHASE 4: EXECUTION PRINCIPLES

### 4.1 MOTION AND ANIMATION

Motion is a tool, not a feature. Every animation must serve one of three purposes: **orient** (where am I?), **inform** (what happened?), or **connect** (how does A relate to B?). Animation that exists only to "look cool" adds load time, increases cognitive load, and triggers vestibular issues for ~35% of the population.

**Duration guidelines:**
| Action type | Duration |
|---|---|
| Micro-interactions (hover, toggle, checkbox) | 100–200ms |
| Small component transitions (dropdown, tooltip) | 150–250ms |
| Page/view transitions | 300–500ms |
| Complex orchestrated transitions | 400–700ms |
| Maximum for any single animation | ~700ms |

**Easing guidelines:**

- **ease-out** (`cubic-bezier(0.0, 0.0, 0.2, 1)`) — for user-initiated actions. Starts fast, ends gentle. Feels responsive.
- **ease-in** (`cubic-bezier(0.4, 0.0, 1, 1)`) — for elements exiting. Starts slow, accelerates away.
- **ease-in-out** (`cubic-bezier(0.4, 0.0, 0.2, 1)`) — for position changes and state transitions.
- **Never use `linear`** for movement (feels mechanical and unnatural). Linear is only for continuous rotation (spinners) or opacity fades.

**Stagger animations:** When multiple items enter together (list items, cards), stagger by **20–50ms per item**. This creates the "cascade" effect that feels polished without slowing perception. Total stagger should not exceed ~300ms.

**Always implement `prefers-reduced-motion`:**

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### 4.2 SHADOW AND DEPTH

Shadows must form a **consistent elevation system** — never one-off values. Define 3–5 levels and use them systematically. Shadows always come from a single, consistent light source (usually top-center or slightly left of center).

**A sample shadow scale:**

```css
--shadow-xs: 0 1px 2px rgba(0, 0, 0, 0.05); /* subtle lift: chips, tags */
--shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.08), 0 1px 2px rgba(0, 0, 0, 0.04); /* cards at rest */
--shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07), 0 2px 4px rgba(0, 0, 0, 0.04); /* cards on hover, dropdowns */
--shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.08), 0 4px 6px rgba(0, 0, 0, 0.04); /* modals, popovers */
--shadow-xl: 0 20px 25px rgba(0, 0, 0, 0.1), 0 8px 10px rgba(0, 0, 0, 0.04); /* floating panels */
```

Use dual shadows (a broader, softer shadow + a tighter, sharper shadow) for more realistic depth. Keep opacity ≤30% for any single shadow layer. In dark mode, replace shadows with surface lightness changes.

### 4.3 BORDER-RADIUS SYSTEM

Choose **one** border-radius philosophy and apply it everywhere:

| Philosophy       | Values                                       | Personality                     |
| ---------------- | -------------------------------------------- | ------------------------------- |
| Sharp            | 0px everywhere                               | Brutalist, technical, editorial |
| Slightly rounded | 4px or 6px                                   | Professional, mature, subtle    |
| Rounded          | 8px base, 12–16px containers                 | Friendly, modern, approachable  |
| Pill/full-round  | `height/2` on buttons, 16–24px on containers | Playful, soft, consumer-app     |

The radius of a child element should be **parent radius minus the padding between them**. If a card has 16px radius and 16px padding, contained elements use 8px radius. Nested radius should decrease, never increase.

Never mix philosophies. If your buttons are pills (`border-radius: 999px`), your input fields should also have significant rounding. If your cards are sharp (0px), your buttons should not be pills.

### 4.4 RESPONSIVE BEHAVIOR

Design for three breakpoints as a minimum. Each breakpoint is not just a layout change — it's a re-evaluation of hierarchy, density, and interaction patterns.

**Mobile (< 640px):**

- Single column. Stacked layout.
- Touch targets ≥48px.
- Body text ≥16px.
- Bottom-anchored primary actions.
- Simplified navigation (tab bar or hamburger with label).
- Reduced section spacing (60–75% of desktop).
- No hover-dependent interactions.

**Tablet (640–1024px):**

- Two-column layouts possible.
- Touch targets ≥44px.
- Mixed touch and pointer interactions.
- Side navigation or compact top navigation.
- Medium section spacing.

**Desktop (1024px+):**

- Multi-column layouts, sidebars, split views.
- Click targets ≥40px (hover augments).
- Full navigation exposed.
- Full section spacing.
- Content maxes out at 1200–1280px, then centers.

---

## PHASE 5: QUALITY CHECKLIST

Before any design is delivered, verify every item:

**Foundations:**

- [ ] Color palette has ≤5 chromatic hues + neutrals + semantics
- [ ] 60-30-10 color distribution is maintained
- [ ] Every text/background pair meets WCAG AA contrast (4.5:1 normal, 3:1 large)
- [ ] Dark mode tested independently if applicable
- [ ] Type scale follows a mathematical ratio from 16px base
- [ ] Max 2 font families loaded
- [ ] Line-height is 1.5 for body, 1.1–1.25 for headings
- [ ] No text block exceeds 75 characters wide
- [ ] All spacing values are on the 8px grid
- [ ] Internal padding ≤ external spacing (Gestalt proximity)

**Components:**

- [ ] Every interactive element has all 6 states (default, hover, active, focus, disabled, loading)
- [ ] Only one primary CTA per visible area
- [ ] Buttons meet touch target minimums (≥44px)
- [ ] Forms use top-aligned labels (not placeholder-only)
- [ ] Error states are visible, descriptive, and use icon + color + text
- [ ] Border-radius is consistent across same-level elements
- [ ] Shadow direction is consistent (single light source)
- [ ] Icons are consistent style (all line, all filled, etc.)

**Accessibility:**

- [ ] Focus indicators visible on all interactive elements (≥2px, ≥3:1 contrast)
- [ ] Heading hierarchy is logical (H1 → H2 → H3, no skips)
- [ ] Color is never the sole indicator of meaning
- [ ] `prefers-reduced-motion` handled
- [ ] Form inputs have associated labels
- [ ] Images have alt text
- [ ] DOM order matches visual reading order

**Anti-slop:**

- [ ] Design does not match the "AI aesthetic fingerprint" (white + blue + Inter + centered cards)
- [ ] The design has a clear signature element that makes it distinctive
- [ ] Removing the logo, the design still has identifiable personality
- [ ] Every visual element serves a stated purpose (no decoration without function)
- [ ] The design reflects something specific about its context, audience, or domain
- [ ] Edge cases are considered (empty states, error states, extreme content lengths)

---

## QUICK REFERENCE: NUMBERS THAT MATTER

```
CONTRAST:     4.5:1 normal text | 3:1 large text | 3:1 UI elements | 3:1 focus
FONT SIZE:    16px min body | 12px min secondary | 10px absolute floor
LINE HEIGHT:  1.5 body | 1.1–1.25 headings | 1.0–1.15 display
LINE LENGTH:  45–75 chars (target 65) → max-width: 65ch
TYPE SCALE:   1.250 (versatile) | 1.333 (desktop) | 1.125 (dense)
SPACING:      0/2/4/8/12/16/20/24/32/40/48/64/80/96/128px
GRID:         4 col mobile | 8 col tablet | 12 col desktop
GUTTERS:      16px mobile | 24px tablet | 24–32px desktop
MAX WIDTH:    1280px layout | 720px text | 65ch paragraphs
TOUCH TARGET: 44×44px recommended | 48×48dp Material | 24×24px AA minimum
BUTTONS:      32/40/48px heights | 2:1 horizontal:vertical padding
INPUTS:       40px desktop height | 48px mobile height | 16px min font (iOS)
SHADOWS:      3–5 levels | ≤30% opacity | consistent direction
RADIUS:       Pick ONE system: 0/4–6/8–12/999 → apply consistently
ANIMATION:    100–200ms micro | 300–500ms transitions | ≤700ms max
STAGGER:      20–50ms per item | ≤300ms total cascade
EASING:       ease-out (user action) | ease-in (exit) | ease-in-out (position)
COLORS:       60% dominant | 30% secondary | 10% accent | ≤5 hues
DARK MODE:    #121212 base (not #000) | 87/60/38% text opacity | no shadows
FLASHES:      ≤3 per second
```

---

_Good design is not about making things pretty. It is about making things clear, usable, accessible, and then — with whatever room is left — making them beautiful in a way that is true to what they are. The prettiest interface that confuses its users is a failure. The plainest interface that serves them perfectly is a success. Aim for both: serve perfectly, then make it unforgettable._
