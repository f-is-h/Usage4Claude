# Usage4Claude — Project Overview

A macOS menu bar app that monitors Claude / Codex / Grok subscription usage. Swift + SwiftUI + AppKit, targeting macOS 13+.

## Build & Test

- Unit tests: `swift test` (SwiftPM only tests pure functions, runs in seconds; `Package.swift` uses a sources allowlist — newly extracted pure-function files must be added manually before they're testable)
- Full build: `./scripts/build.sh --config Debug` (`.xcodeproj` is the authoritative build; SwiftPM exists only for testing)
- Localization consistency: `python3 scripts/check_l10n.py` (checks key sync across 7 languages; enforced in CI)

## Architecture Map

- `App/`: entry point, `MenuBarManager` (coordinates UI and data), icon rendering (`MenuBarIconRenderer`/`ShapeIconRenderer`)
- `Services/`: `ClaudeAPIService` (cookie and OAuth dual paths), `CodexAPIService` (two-step auth),
  `GrokAPIService` (OIDC refresh_token → access_token → billing API),
  `OAuthTokenCache` (actor: token caching + refresh single-flight), `KeychainManager` (uses UserDefaults in DEBUG!),
  `*OAuth/` (PKCE + local callback server; Grok also supports device-code + auth.json import)
- `Models/`: `UserSettings` is the settings facade; accounts/refresh policy/launch-at-login/appearance have been
  split out into `AccountStore`/`SmartRefreshPolicy`/`LaunchAtLoginManager`/`AppearanceManager`
- `Helpers/DataRefreshManager.swift`: scheduled refresh, Codex's three-tier token refresh chain, reset verification
- Localization: `L.xxx` accessors (`Helpers/LocalizationHelper.swift`) → `Resources/*.lproj/Localizable.strings`;
  new keys must be synced across all 7 languages (de/en/fr/ja/ko/zh-Hans/zh-Hant)
- `Tests/`: SwiftPM test target, only covers pure-function files listed in `Package.swift`'s sources
- `.agents/skills/`: ready-made skills exist for release and screenshot capture (capture-usage4claude-screenshots)

## Key Conventions

- Commits: English, no emoji, no Co-Authored-By — see `docs/COMMIT_MESSAGE_GUIDELINES.md` (release commits are hand-written by the owner)
- Releases: `CHANGELOG.md` is the authoritative version source and technical record; `docs/RELEASE_NOTES.md` is the
  user-facing text for the Sparkle popup/Release body. A commit message with a `[release]` prefix pushed to main
  triggers a fully automated CI release — see `docs/DAILY_RELEASE_WORKFLOW.md`
- Service-layer public completions must always be called back on the main thread
- `Config/Info.plist` is a static file (Xcode's auto-generation mode drops Sparkle keys) — edit it directly to change keys
- Outdated docs go into `docs/archive/`, not left in the `docs/` root

## Known Pitfalls

- SwiftUI Canvas's clockwise semantics are the opposite of NSBezierPath's (y-axis points down) — see `docs/SWIFTUI_CANVAS_PATH_DRAWING_GUIDE.md`
- DEBUG builds store credentials in UserDefaults (key prefix `DEBUG_`), separate from Release's Keychain
- OAuth refresh_tokens rotate on every renewal — any new token-fetching code path must reuse `OAuthTokenCache`'s single-flight mechanism
- New root-level `.md` files are gitignored by default via `/*.md` — add a `!/filename.md` allowlist entry to track them
