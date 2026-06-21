# Phase 02 — Confirm App Name & Bundle ID (HARD BLOCKER)

## Context links
- plan.md → Decisions D1, D2
- Scout §1, §2

## Overview
Pure decision phase. Resolve the `UsagePaceCC` and `com.quangyendn.usagepacecc` tokens.
**No rebrand work (Phases 03-07) may begin until this is done.** Phases 01 and 08
do not depend on this.

## Insights
- Candidates already shortlisted: Quota, Pulse, Gauge, Cadence, Curve, Trace, Tideline, Glance, Brink, Slope.
- Current bundle id `xyz.fi5h.Usage4Claude`; fork owner GitHub `quangyendn` → suggested `com.quangyendn.<newname>`.
- The repo name stays `Usage4Claude` on GitHub (origin is `quangyendn/Usage4Claude`); only the PRODUCT name + bundle id + UI strings change. Renaming the GitHub repo is optional and out of scope (would break upstream remote URL assumptions in Phase 08 — keep repo name).

## Requirements / Steps
1. User picks final name → set `UsagePaceCC` (e.g. `Pulse`). Lowercase form `<newname>` for ids/paths.
2. Verify name availability (quick check): macOS App Store search, existing GitHub repos, trademark sanity (not required for self-distribution but check for obvious conflicts).
3. User confirms bundle id → set `com.quangyendn.usagepacecc` (default `com.quangyendn.<newname>`).
4. Record both in plan.md frontmatter / a `DECISIONS.md` note so later find/replace is unambiguous.
5. Decide D7 (code-sign identity rename) and D8 (funding links) now if possible — they gate Phases 06/04.

## Todos
- [ ] `UsagePaceCC` chosen and recorded
- [ ] `com.quangyendn.usagepacecc` chosen and recorded
- [ ] availability sanity-check done
- [ ] D7 / D8 noted

## Success
- A single authoritative mapping exists:
  `Usage4Claude → UsagePaceCC`, `xyz.fi5h.Usage4Claude → com.quangyendn.usagepacecc`.

## Risks
- Choosing a name with an existing popular app/domain forces a re-do — verify before committing.

## Next
Phases 03, 05, 06, 07 unblocked.
