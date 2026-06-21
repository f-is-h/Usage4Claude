# Phase 03 — Rebrand: Xcode Identity + Bundle ID + Keychain Migration

## Context links
- plan.md → D2, D3; Open Questions 1, 2
- Scout §1, §2, §9
- PROJECT_SUMMARY problem 7 (self-signed cert + Keychain stability)

## Overview
Set the app's machine identity: product name, bundle id, scheme names, and the 5
Swift files hardcoding bundle-id-derived strings. Changing the bundle id / keychain
service changes the keychain access group → existing users lose access to stored
Org ID + Session Key → plan migration. Prerequisite: Phase 02 (name + id resolved).

## Insights (verified file:line)
- `project.pbxproj:69` `productName = Usage4Claude;`
- `project.pbxproj:289` (Debug) & `:339` (Release) `PRODUCT_BUNDLE_IDENTIFIER = xyz.fi5h.Usage4Claude;`
- `project.pbxproj:260-261, 310-311` `CODE_SIGN_IDENTITY = "Usage4Claude-CodeSigning";`
- `project.pbxproj:292` `REGISTER_APP_GROUPS = YES;` (group id not visible — inspect entitlements, see OQ1/2)
- 3 scheme files: `Usage4Claude.xcodeproj/xcshareddata/xcschemes/{Usage4Claude,Usage4Claude-Debug,Usage4Claude-Release}.xcscheme`
- Hardcoded id refs:
  - `Helpers/LoggerExtension.swift:14` fallback `"xyz.fi5h.Usage4Claude"`; `:58-59` comment `subsystem:xyz.fi5h.Usage4Claude`
  - `Helpers/DiagnosticLogger.swift:44` `Logger(subsystem: "com.f-is-h.Usage4Claude", ...)` (note: DIFFERENT id form `com.f-is-h.` — fix to `com.quangyendn.usagepacecc`)
  - `Helpers/TimerManager.swift:22` `DispatchQueue(label: "com.usage4claude.timer", ...)`
  - `Services/KeychainManager.swift:36` `service: String = "xyz.fi5h.Usage4Claude"` ← KEYCHAIN MIGRATION TRIGGER
- Optional: `App/ClaudeUsageMonitorApp.swift:14` `struct ClaudeUsageMonitorApp` (internal name; rename optional, low value — YAGNI, skip unless trivial).

## Requirements
- After change: app builds, launches, keychain read/write works under new service name.
- Decide D3 migration strategy before editing KeychainManager.

## Files
- `Usage4Claude.xcodeproj/project.pbxproj` (productName, both PRODUCT_BUNDLE_IDENTIFIER, optionally CODE_SIGN_IDENTITY per D7)
- 3 `.xcscheme` files (rename BuildableName/BlueprintName references; renaming the scheme file itself is optional — schemes can keep working as-is, but for a clean rebrand rename to `UsagePaceCC*.xcscheme` and update internal refs)
- `Usage4Claude/Helpers/LoggerExtension.swift`
- `Usage4Claude/Helpers/DiagnosticLogger.swift`
- `Usage4Claude/Helpers/TimerManager.swift`
- `Usage4Claude/Services/KeychainManager.swift`
- entitlements file (inspect/locate first — see steps)

## Steps
1. **Inspect entitlements** (OQ1/2): `find . -name "*.entitlements"`. If `keychain-access-groups` or `com.apple.security.application-groups` present, note the ids → they embed the bundle id and must be updated.
2. pbxproj: replace `productName = Usage4Claude;` → `UsagePaceCC`; both `PRODUCT_BUNDLE_IDENTIFIER = xyz.fi5h.Usage4Claude;` → `com.quangyendn.usagepacecc`. Per D7, optionally `CODE_SIGN_IDENTITY` → `UsagePaceCC-CodeSigning` (only if regenerating the self-signed cert in Phase 06; otherwise leave).
3. Update the 4 hardcoded Swift refs to derive from `Bundle.main.bundleIdentifier` where possible, else the new literal:
   - LoggerExtension fallback → `com.quangyendn.usagepacecc`; update comments.
   - DiagnosticLogger subsystem → `com.quangyendn.usagepacecc` (replaces the stray `com.f-is-h.Usage4Claude`).
   - TimerManager queue label → `com.quangyendn.usagepacecc.timer` (label is cosmetic; just de-brand).
   - KeychainManager `service` default → `com.quangyendn.usagepacecc` (or keep a dedicated keychain key).
4. **Keychain migration (D3)** — implement chosen strategy in KeychainManager:
   - *Default (silent re-auth):* on first launch under new id, keychain read returns nil → existing welcome/auth flow prompts user to re-enter Org ID + Session Key. Add a one-line note in release notes + welcome screen. Zero migration code. Simplest, KISS.
   - *Optional (one-time migration):* attempt read from old service `"xyz.fi5h.Usage4Claude"`, copy into new service, then proceed. ~15 lines; only if seamless upgrade is required. Note: old self-signed cert access-group constraints may still block cross-id reads → test before relying on it.
5. (Optional) rename `ClaudeUsageMonitorApp` struct + `@main` file — skip unless quick.
6. Rename scheme files + internal `BuildableName="Usage4Claude.app"` / `BlueprintName` refs to `UsagePaceCC` if doing the clean rename (keep build.sh SCHEME_NAME in sync — Phase 06).

## Todos
- [x] entitlements inspected; app-group/keychain-group ids updated if present
- [x] pbxproj productName + both bundle ids updated
- [x] 4 hardcoded Swift id refs de-branded
- [x] keychain migration strategy implemented (D3) + documented in release notes
- [x] schemes renamed/updated (or consciously left)
- [x] builds clean, app launches

## Success
- `grep -rn "xyz.fi5h\|com.f-is-h\|com.usage4claude" Usage4Claude/` returns nothing.
- App launches; entering creds and restarting persists them under new service.
- Menu bar app appears (name finalized in Phase 04 strings).

## Risks
- **Keychain access-group mismatch** crashes keychain ops at runtime — test read/write immediately after change. Rollback: revert bundle id.
- Self-signed cert tied to old identity — re-signing may be required (Phase 06). If keychain breaks in dev, regenerate `UsagePaceCC-CodeSigning` cert.
- Renaming scheme files can break CI if `SCHEME_NAME` not updated → coordinate with Phase 06; verify with `xcodebuild -list`.

## Next
Phase 04 (UI strings / URLs / UpdateChecker) — needs the resolved bundle id + keychain service.
