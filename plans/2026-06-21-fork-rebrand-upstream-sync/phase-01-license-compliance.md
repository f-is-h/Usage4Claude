# Phase 01 — License & Attribution Compliance

## Context links
- plan.md (this dir)
- LICENSE (repo root) — currently `MIT License / Copyright (c) 2025 f-is-h`
- Scout §4 (About UI), §6 (README/docs)

## Overview
MIT requires keeping the original copyright + license notice. KEEP upstream LICENSE
intact; ADD fork copyright. Add upstream attribution in About UI + README, and an
"not affiliated with Anthropic" disclaimer. Low-risk, no name needed → do FIRST,
independent of Phase 02. (Brand strings in About are finalized in Phase 04; here we
add only attribution scaffolding + license text.)

## Insights
- `LICENSE` header confirmed: `MIT License` / `Copyright (c) 2025 f-is-h` (verified).
- en copyright string is `"settings.about.copyright" = "© 2025 All Rights Reserved";` — note it does NOT currently name f-is-h; will be updated in Phase 04.
- This phase is purely additive (LICENSE line + attribution rows + README block) so it can land before the name is chosen.

## Requirements
- Do NOT delete or modify the `Copyright (c) 2025 f-is-h` line.
- Add `Copyright (c) 2026 Yen NQ (Quang Yen)` as a second line.
- LICENSE must ship inside the distributed app bundle (or DMG) and in source.

## Files
- `LICENSE` (edit — add second copyright line)
- `README.md` (edit — add "Forked from / based on" + disclaimer)
- `docs/README.ja.md`, `docs/README.fr.md`, and other localized READMEs (edit — same attribution)
- `Usage4Claude/Views/Settings/Tabs/AboutView.swift` (edit — add attribution + disclaimer rows; brand text done in Phase 04)
- Localization `*.lproj/Localizable.strings` (add keys: `settings.about.based_on`, `settings.about.disclaimer`) for all 6 langs
- `Usage4Claude/Helpers/LocalizationHelper.swift` (add `L.SettingsAbout.basedOn`, `.disclaimer` accessors)
- `scripts/build.sh` / DMG packaging — ensure LICENSE copied into distributed artifact

## Steps
1. Edit `LICENSE`: keep line 3 as-is; add below it:
   ```
   Copyright (c) 2025 f-is-h
   Copyright (c) 2026 Yen NQ (Quang Yen)
   ```
   (two consecutive copyright lines under the single MIT grant — standard practice.)
2. README.md: add near top a block:
   > `UsagePaceCC` is an open-source fork of [Usage4Claude](https://github.com/f-is-h/Usage4Claude) by f-is-h, distributed under the MIT License.
   > Not affiliated with, endorsed by, or sponsored by Anthropic. "Claude" is a trademark of Anthropic.
   (Use `UsagePaceCC` token — find/replace after Phase 02.)
3. Mirror the attribution + disclaimer block into each localized README in `docs/`.
4. AboutView.swift: add two `AboutInfoRow`s (or a footer Text) — "Based on f-is-h/Usage4Claude" (link) and the Anthropic disclaimer. Wire to new localized keys.
5. Add localized keys `settings.about.based_on` and `settings.about.disclaimer` to all 6 `Localizable.strings` (English authoritative; provide best-effort translations or English fallback).
6. Add the matching accessors in `LocalizationHelper.swift` (`enum SettingsAbout`).
7. build.sh / packaging: confirm `LICENSE` ends up in the `.app` (e.g. `Contents/Resources/LICENSE`) or alongside the DMG; add a copy step if missing.

## Todos
- [x] LICENSE second copyright line added; f-is-h line untouched
- [x] README + localized READMEs attribution + Anthropic disclaimer
- [x] AboutView attribution + disclaimer rows wired to localized keys
- [x] 6 localization files get `based_on` + `disclaimer` keys
- [x] LocalizationHelper accessors added
- [x] LICENSE confirmed shipping in build artifact

## Success
- `head -6 LICENSE` shows both copyright lines, f-is-h first.
- App About shows attribution + "not affiliated with Anthropic".
- README opens with fork/MIT/disclaimer block.
- Build artifact contains LICENSE.

## Risks
- Translation quality for disclaimer — acceptable to fall back to English string; flag for later localization pass.
- AboutView brand text (`Text("Usage4Claude")` line 32) is deliberately NOT changed here — owned by Phase 04 to avoid double-editing.

## Next
Phase 02 (confirm name) — unblocks the `UsagePaceCC` find/replace that finalizes this phase's tokens.
