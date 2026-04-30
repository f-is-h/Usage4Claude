# Product Design Philosophy

## 1. Project Positioning

Usage4Claude is a menu bar utility the author built for personal use and for users with similar needs. It has the following non-negotiable attributes:

- **Small and beautiful**: Not chasing broad feature coverage, large user base, or market size
- **Restraint**: Not every reasonable request will be accepted; the author's aesthetic is the baseline
- **Open source, not commercial**: Open to more users, but not at the cost of the product's soul
- **Craftsmanship first**: Every new feature must first pass the "does this fit the product's soul" test

## 2. Core Design Principles

### 2.1 State-driven Progressive Disclosure

UI shape is determined by the user's actual account state, not by feature flags.

- The typical feature-flag approach: the user ticks "Enable Codex support" in settings → Codex elements appear. This pollutes the settings panel and makes Claude-only users aware of Codex.
- This project uses a state-driven approach: the user logs in to a Codex account in account management → the UI automatically adapts to the form that has Codex. With only Claude logged in, the word "Codex" never appears.

**Codex is not a feature — it is a state of existence.**

### 2.2 Provider Equality

Once the user enters multi-provider state, Claude and Codex are **two equal providers** with no hierarchy. Neither Codex is deliberately downplayed nor Claude deliberately elevated.

- Equal visual weight
- Equal naming, color, and icon recognizability
- Equal account management entry points in the settings panel
- Equal data refresh priority

### 2.3 No Extensibility Reserved for Extensibility's Sake

The product hard-limits itself to Claude + Codex as a deliberate design constraint.

- This tool is built for the class of users who "use both Claude and Codex simultaneously"
- Adding Gemini / Cursor / Copilot etc. would break the product form (three-column popover, three groups of menu bar icons — neither is elegant)
- When someone requests a third provider, the honest answer is "this is an intentional design trade-off"
- A clear boundary is worth more than unlimited promises

## 3. Boundaries of Design Decisions

### 3.1 When to say "yes"
- The new feature fits the product soul (small and beautiful, restrained)
- The implementation path does not pollute existing user experience
- The code forms a symmetric, clean abstraction

### 3.2 When to say "no"
- The new feature requires a settings toggle for existing users not to be disturbed → usually the wrong direction
- The new feature requires compromising the existing visual language for a specific user group
- The new feature "looks cool but is rarely used"
- The new feature expands TAM rather than solving a real need

## 4. Honest External Positioning

The first sentence of the README cannot pretend this is a "universal multi-AI tool", but also cannot pretend there is no Codex support.

Reference phrasing:
> Track your Claude (and optional Codex) subscription quota — beautifully, in your menu bar.

Codex's placement should be in the subtitle/Features section rather than the hero image, consistent with the true product state of "author's personal need + nice to have".

## 5. Technical Decisions Derived from Philosophy

The following technical choices are not engineering preferences — they are extensions of the philosophy:

| Philosophy principle | Derived technical decision |
|---|---|
| Claude-only users have zero awareness | Don't change Bundle ID, repo name, product name, or user data |
| State-driven UI | Popover width, menu bar icon grouping derived from `accounts.contains(where: provider == .codex)` |
| Provider equality | Abstract `UsageProvider` protocol; `Account` model with `provider` field; Claude doesn't "hold primary position" in code |
| Stopping at two providers | Don't introduce generic `[String: ProviderConfig]`; use enum to explicitly express "only these two" |
