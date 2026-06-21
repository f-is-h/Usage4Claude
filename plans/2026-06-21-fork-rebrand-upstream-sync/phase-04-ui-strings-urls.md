# Phase 04 — Rebrand: UI/Localization Strings + About + URLs + UpdateChecker

## Context links
- plan.md → D8; Acceptance criteria (UpdateChecker, URLs, About)
- Scout §1 (strings), §4 (About), §5 (URLs), §8/§10
- Phase 01 (attribution scaffolding already added), Phase 03 (bundle id resolved)

## Overview
De-brand all user-facing text and repoint all GitHub URLs to the fork. CRITICAL:
repoint `UpdateChecker` so rebranded users receive the fork's releases, not
upstream's. Finalize the About brand text + copyright started in Phase 01.

## Insights (verified file:line)
- **UpdateChecker** `Services/UpdateChecker.swift:19` `repoOwner = "f-is-h"`; `:21` `repoName = "Usage4Claude"`; `:72,120` hit `api.github.com/repos/{owner}/{name}/releases/latest`. → change `repoOwner = "quangyendn"` (keep repoName `Usage4Claude` since repo name unchanged — see Phase 02). Two-line fix, but highest user-impact.
- AboutView.swift: `:32` `Text("Usage4Claude")`; `:53` developer `"f-is-h"`; `:62-64` GitHub link `f-is-h/Usage4Claude`; `:75-76` Ko-Fi `ko-fi.com/1atte`; `:88-90` Sponsor `sponsors/f-is-h`; `:102` `Text(L.SettingsAbout.copyright)`.
- en strings: `menu.quit = "Quit Usage4Claude"`, `welcome.title = "Welcome to Usage4Claude"`, `window.settings_title = "Usage4Claude Settings"`, `settings.about.copyright = "© 2025 All Rights Reserved"`, `diagnostic.suggestion_contact_support` contains `github.com/f-is-h/Usage4Claude/issues`. Same set across 6 lprojs.
- Other URL sites: `Models/DiagnosticReport.swift:246` issues URL; `:314` support contact `github.com/f-is-h/Usage4Claude/issues`; `App/MenuBarManager.swift:452` sponsor link.
- `App/ClaudeUsageMonitorApp.swift:89` welcome title uses localized string (no literal — fixed via strings).

## Requirements
- No user-facing `Usage4Claude` / `f-is-h` brand strings remain (except attribution block from Phase 01 + LICENSE).
- UpdateChecker verifiably hits quangyendn releases.
- Decide D8 (funding links) before editing AboutView/MenuBarManager.

## Files
- `Usage4Claude/Services/UpdateChecker.swift` (repoOwner)
- `Usage4Claude/Views/Settings/Tabs/AboutView.swift` (name, developer, links, copyright)
- `Usage4Claude/App/MenuBarManager.swift:452` (sponsor URL — per D8)
- `Usage4Claude/Models/DiagnosticReport.swift:246,314` (issues/support URLs)
- 6 × `Resources/*.lproj/Localizable.strings` (quit, welcome, settings_title, copyright, diagnostic support)
- `Usage4Claude/Helpers/LocalizationHelper.swift` (any literal strings; verify)

## Steps
1. UpdateChecker: `repoOwner = "f-is-h"` → `"quangyendn"`. Update file header comment (`f-is-h` / copyright) optionally.
2. AboutView:
   - `:32` `Text("Usage4Claude")` → `Text("UsagePaceCC")` (or pull from `Bundle.main` displayName).
   - `:53` developer row: set to `Yen NQ` (and keep the Phase-01 "Based on f-is-h/Usage4Claude" attribution row above/below).
   - `:62-64` GitHub link → `https://github.com/quangyendn/Usage4Claude`.
   - `:75-76` Ko-Fi + `:88-90` Sponsor (D8): default = move under attribution as "support original author" OR replace with own; remove if none.
   - `:102` copyright row already localized — fix the string (step 4).
3. MenuBarManager.swift:452 sponsor URL → per D8.
4. Localizable.strings (all 6): replace literal `Usage4Claude` in `menu.quit`, `welcome.title`, `window.settings_title` with `UsagePaceCC`; set `settings.about.copyright` to `© 2026 Yen NQ` (or `© 2025 f-is-h, © 2026 Yen NQ` to credit both — recommended); update `diagnostic.suggestion_contact_support` URL to `quangyendn`.
5. DiagnosticReport.swift:246,314 → `quangyendn` URLs.
6. Grep sweep for any remaining literal brand/URL across `Usage4Claude/` Swift + strings.

## Todos
- [x] UpdateChecker repoOwner = quangyendn
- [x] AboutView name/developer/links/copyright rebranded (D8 applied)
- [x] MenuBarManager sponsor URL handled
- [x] DiagnosticReport URLs → quangyendn
- [x] 6 localization files de-branded + copyright updated
- [x] grep sweep clean (excluding LICENSE/attribution/CHANGELOG)
- [x] build + launch; About renders correctly in ≥2 languages

## Success
- `grep -rn "f-is-h\|Usage4Claude\b" Usage4Claude/ --include=*.swift --include=*.strings` → only attribution/LICENSE-credit lines.
- Run app → menu "Quit UsagePaceCC", welcome + settings titles show new name, About shows new name + Yen NQ + upstream attribution + Anthropic disclaimer.
- Trigger update check → network/log shows request to `api.github.com/repos/quangyendn/Usage4Claude/releases/latest`.

## Risks
- Missing a localization key in one language → falls back to key string (visible bug). Verify each lproj has all edited keys.
- Forgetting UpdateChecker is the single most damaging miss (users get upstream's updates / version-compare confusion). Prioritize + verify.

## Next
Converge with Phases 05/06 into Phase 09 verification.
