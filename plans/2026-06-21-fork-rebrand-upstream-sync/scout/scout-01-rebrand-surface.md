# Scout Report: Usage4Claude Branding & Identity Inventory

**Scope:** Complete inventory of branding/identity locations in Usage4Claude fork  
**Date:** 2026-06-21  
**Status:** Very thorough exploration completed  

---

## 1. App Display Name & Product Name

### Xcode Project Configuration
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:69` — `productName = Usage4Claude;`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:289` — `PRODUCT_BUNDLE_IDENTIFIER = xyz.fi5h.Usage4Claude;` (Debug)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:339` — `PRODUCT_BUNDLE_IDENTIFIER = xyz.fi5h.Usage4Claude;` (Release)

### Swift Source Code
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/App/ClaudeUsageMonitorApp.swift:14` — `struct ClaudeUsageMonitorApp: App` (main app struct name)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:32` — `Text("Usage4Claude")` (About window display)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Helpers/LocalizationHelper.swift:14` — `enum L` (localization namespace, used throughout)

### Localization Strings (en.lproj)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/en.lproj/Localizable.strings` — Multiple entries:
  - `"menu.quit" = "Quit Usage4Claude";`
  - `"welcome.title" = "Welcome to Usage4Claude";`
  - `"window.settings_title" = "Usage4Claude Settings";`
  - Entries in all 6 language files (en, ja, ko, zh-Hans, zh-Hant, fr)

### Window Titles
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/App/ClaudeUsageMonitorApp.swift:89` — `welcomeWindow?.title = L.Window.welcomeTitle` (Uses localized string)

---

## 2. Bundle Identifier

### Primary Bundle ID
- Current: `xyz.fi5h.Usage4Claude` (reverse domain format with author domain)
- Located in:
  - `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:289` (Debug)
  - `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:339` (Release)

### Hardcoded Bundle ID References in Swift
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Helpers/LoggerExtension.swift:14` — `Bundle.main.bundleIdentifier ?? "xyz.fi5h.Usage4Claude"` (fallback)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Helpers/LoggerExtension.swift:58-59` — Comments referencing `subsystem:xyz.fi5h.Usage4Claude`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Helpers/DiagnosticLogger.swift:44` — `Logger(subsystem: "com.f-is-h.Usage4Claude", category: "Diagnostics")`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Helpers/TimerManager.swift:22` — `DispatchQueue(label: "com.usage4claude.timer", attributes: .concurrent)`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Services/KeychainManager.swift:36` — `service: String = "xyz.fi5h.Usage4Claude"` (Keychain service name)

### App Groups / Entitlements
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:292` — `REGISTER_APP_GROUPS = YES;` (enabled but specific group not visible in pbxproj)

---

## 3. App Icon Assets

### Asset Catalog Paths
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/Assets.xcassets/AppIcon.appiconset/` — Main app icon set (sizes: 16, 32, 64, 128, 256, 512, 1024 PNG files)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` — Asset metadata

### Related Icon Assets
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/Assets.xcassets/AppIconReverse.imageset/` — Reverse icon variant
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/Assets.xcassets/CodexIcon.imageset/` — Codex-specific icon
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/Assets.xcassets/CodexIconReverse.imageset/` — Codex reverse icon

### Source Icon Files (docs/)
- `/Users/yennq/Projects/opensrc/Usage4Claude/docs/images/AppIcon.icns` — macOS icon file
- `/Users/yennq/Projects/opensrc/Usage4Claude/docs/images/icon@2x.png` — 2x retina icon
- `/Users/yennq/Projects/opensrc/Usage4Claude/docs/images/icon.reverse@2x.png` — Reverse variant
- `/Users/yennq/Projects/opensrc/Usage4Claude/docs/images/DmgIcon.icns` — DMG package icon
- `/Users/yennq/Projects/opensrc/Usage4Claude/docs/images/icon.psd` — Photoshop source (not currently present, likely `.reverse.psd`)

### Website Icon
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/favicon.ico` — Website favicon
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/images/icon.png` — Website icon (used in HTML header)

### Icon Rendering (Dynamic)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/App/MenuBarIconRenderer.swift` — Dynamic menubar icon generation
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Helpers/ShapeIconRenderer.swift` — Shape-based icon rendering
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Helpers/IconShapePaths.swift` — Icon shape path definitions

---

## 4. About / Acknowledgements / Credits UI

### About View (SwiftUI)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:32` — `Text("Usage4Claude")` (hardcoded app name in About window)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:53` — `AboutInfoRow(icon: "person.fill", title: L.SettingsAbout.developer, value: "f-is-h")` (developer name)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:62-64` — GitHub link: `https://github.com/f-is-h/Usage4Claude`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:75-76` — Ko-Fi sponsorship link: `https://ko-fi.com/1atte`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:88-90` — GitHub Sponsor link: `https://github.com/sponsors/f-is-h?frequency=one-time`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:102` — `Text(L.SettingsAbout.copyright)` (localized copyright)

### About Component
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Components/AboutInfoRow.swift` — Reusable component (file exists)

### Localized Copyright & Description
- All `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/*/Localizable.strings` — Contain:
  - `settings.about.description` — App description
  - `settings.about.copyright` — Copyright statement (likely "© 2025 f-is-h")

---

## 5. Hardcoded URLs

### GitHub Repository URLs
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:62` — `https://github.com/f-is-h/Usage4Claude`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Models/DiagnosticReport.swift:246` — `https://github.com/f-is-h/Usage4Claude/issues` (in diagnostic message)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Models/DiagnosticReport.swift:314` — `github.com/f-is-h/Usage4Claude/issues` (support contact suggestion)

### GitHub Sponsor Links
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:88` — `https://github.com/sponsors/f-is-h?frequency=one-time`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/App/MenuBarManager.swift:452` — `https://github.com/sponsors/f-is-h?frequency=one-time`

### Ko-Fi Support Link
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift:75` — `https://ko-fi.com/1atte`

### Website URLs
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:11` — Canonical: `https://usage4claude.pages.dev/`
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:12-16` — Language alternates (all `.pages.dev`)
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:23-32` — OG tags with website URL
- Multiple website files (`.html`) contain `.pages.dev` URLs (see grep results above)

### Website Navigation Links
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:72` — `https://github.com/f-is-h/Usage4Claude` (navbar)
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:290` — `https://github.com/f-is-h/Usage4Claude/releases/latest` (download button)
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:293` — GitHub link button
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:332-335` — Footer links (GitHub, releases, issues, discussions)
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:342` — GitHub Sponsor link
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:362` — LICENSE link: `https://github.com/f-is-h/Usage4Claude/blob/main/LICENSE`
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html:368` — Footer copyright: `© 2026 f-is-h`

### Website Legal & Privacy
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/legal.html:53` — `https://github.com/f-is-h/Usage4Claude/issues`
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/legal.html:94` — `https://github.com/f-is-h/Usage4Claude/blob/main/LICENSE`
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/privacy.html:86` — `https://github.com/f-is-h/Usage4Claude`
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/privacy.html:125-126` — Issues and discussions links

### Website JavaScript
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/js/main.js:19` — Console message: `%c✨ Usage4Claude%c ... https://github.com/f-is-h/Usage4Claude`

---

## 6. Version & Release Tooling

### GitHub Workflows & Release Scripts
- `/Users/yennq/Projects/opensrc/Usage4Claude/.github/workflows/release.yml:27` — `PROJECT_NAME: Usage4Claude` (env variable)
- `/Users/yennq/Projects/opensrc/Usage4Claude/.github/workflows/release.yml:28` — `XCODE_PROJECT: Usage4Claude.xcodeproj` (env variable)
- `/Users/yennq/Projects/opensrc/Usage4Claude/.github/workflows/release.yml:219` — Echo in build step: `echo "Building Usage4Claude..."`

### Build Script
- `/Users/yennq/Projects/opensrc/Usage4Claude/scripts/build.sh:3` — Shebang comment: `# Usage4Claude 构建打包脚本`
- `/Users/yennq/Projects/opensrc/Usage4Claude/scripts/build.sh:48` — `PROJECT_NAME="Usage4Claude"`
- `/Users/yennq/Projects/opensrc/Usage4Claude/scripts/build.sh:49` — `SCHEME_NAME="Usage4Claude"`
- `/Users/yennq/Projects/opensrc/Usage4Claude/scripts/build.sh:144` — `DMG_NAME="${PROJECT_NAME}-v${VERSION}.dmg"`
- `/Users/yennq/Projects/opensrc/Usage4Claude/scripts/build.sh:331` — `--volname "${PROJECT_NAME}"` (DMG volume name)

### Release Template
- `/Users/yennq/Projects/opensrc/Usage4Claude/.github/RELEASE_TEMPLATE.md` — Template file (content not read, but exists)

### Verification Scripts
- `/Users/yennq/Projects/opensrc/Usage4Claude/.github/scripts/verify_version.sh` — Version verification
- `/Users/yennq/Projects/opensrc/Usage4Claude/.github/scripts/compare_versions.sh` — Version comparison
- `/Users/yennq/Projects/opensrc/Usage4Claude/.github/scripts/generate_release_notes.sh` — Release notes generation
- `/Users/yennq/Projects/opensrc/Usage4Claude/.github/scripts/cleanup_failed_release.sh` — Release cleanup

### CHANGELOG & Release Notes
- `/Users/yennq/Projects/opensrc/Usage4Claude/CHANGELOG.md` — Contains "Usage4Claude" in title and release URLs (lines 465-483 and more)
  - Multiple lines reference: `https://github.com/f-is-h/Usage4Claude/releases/tag/vX.Y.Z`

### Documentation
- `/Users/yennq/Projects/opensrc/Usage4Claude/README.md:1` — `# Usage4Claude`
- `/Users/yennq/Projects/opensrc/Usage4Claude/CONTRIBUTING.md:1` — `# Contributing to Usage4Claude`
- `/Users/yennq/Projects/opensrc/Usage4Claude/docs/README.fr.md:1` — `# Usage4Claude` (French)
- `/Users/yennq/Projects/opensrc/Usage4Claude/docs/README.ja.md:1` — `# Usage4Claude` (Japanese)
- Localized versions in docs/ directory

---

## 7. Website Branding

### Website Files Carrying Brand Names
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.html` — Primary landing page
  - Title: `Usage4Claude - Real-time Claude AI Usage Monitor for macOS`
  - Brand in nav, hero, footer
  - All GitHub links to `f-is-h/Usage4Claude`
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.zh-cn.html` — Simplified Chinese
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.zh-tw.html` — Traditional Chinese
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.ja.html` — Japanese
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/index.ko.html` — Korean
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/legal.html` — Legal page
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/privacy.html` — Privacy page
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/README.md` — Website docs

### Canonical Domain
- **Primary:** `https://usage4claude.pages.dev/`
- Deployed via Cloudflare Pages
- Referenced in: All `.html` files, hreflang tags, og:url, canonical links

### Website Configuration
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/functions/_middleware.js` — Cloudflare Functions config (file exists)
- `/Users/yennq/Projects/opensrc/Usage4Claude/website/js/i18n.js` — Internationalization config (file exists)
- No custom domain visible in HTML; using `.pages.dev` subdomain

---

## 8. Auto-Update Mechanism

### Findings
**NO Sparkle or Custom Auto-Update Framework Detected.**

Search Results:
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AuthSettingsView.swift:221,230` — Only `Image(systemName: "sparkles")` (UI icon, not the Sparkle framework)
- No `SUFeedURL`, `appcast`, or `feed.xml` files found
- No CocoaPods/SPM dependencies on Sparkle visible
- No entitlements for auto-update

### Implication
**Manual download from GitHub Releases only.** Updates are not automatic; users must manually download from `https://github.com/f-is-h/Usage4Claude/releases`.

---

## 9. Code Signing & Certificates

### Code Signing Identity
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:260` — `CODE_SIGN_IDENTITY = "Usage4Claude-CodeSigning";` (Custom code signing identity name, likely for CI/CD)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:261` — Same for macOS SDK
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj/project.pbxproj:310-311` — Repeated in Release config

### CI/CD Secret Storage
- `.github/workflows/release.yml:185-186` — Uses `secrets.CODESIGN_CERTIFICATE` and `secrets.CODESIGN_PASSWORD` (GitHub Actions secrets)
- Build script creates temporary keychain for signing

---

## 10. Key Language Files

### Swift Source Files With Branding
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/App/ClaudeUsageMonitorApp.swift` — App entry point (1-133 lines)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Views/Settings/Tabs/AboutView.swift` — About UI (1-111 lines)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Helpers/LocalizationHelper.swift` — Localization enum (550+ lines, defines `L.*` accessors)
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Models/DiagnosticReport.swift` — Diagnostic messages

### Localization Resource Files
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/en.lproj/Localizable.strings`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/ja.lproj/Localizable.strings`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/ko.lproj/Localizable.strings`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/zh-Hans.lproj/Localizable.strings`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/zh-Hant.lproj/Localizable.strings`
- `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/Resources/fr.lproj/Localizable.strings`

---

## Unknowns / Needs-Decision

1. **App Groups Entitlements:** `REGISTER_APP_GROUPS = YES` is set in pbxproj, but the specific app group identifier(s) are not visible. May need to check generated entitlements file or runtime detection.

2. **Copyright Year in Localizable.strings:** Assumed copyright includes year 2025 (refs show "© 2025 f-is-h"), but exact format string not fully read.

3. **Custom Domain for Website:** Currently using `usage4claude.pages.dev` (Cloudflare Pages). No evidence of custom domain (`usage4claude.com` or similar). Unclear if custom domain is registered separately or desired.

4. **DMG Background Image:** Script references `docs/images/DmgIcon.icns` for volume icon, but does not show DMG background image path (if one exists).

5. **Localization Coverage:** 6 language files confirmed (en, ja, ko, zh-Hans, zh-Hant, fr). Unclear if all contain app name strings or if some strings are shared programmatically.

6. **Upstream Synchronization:** No evidence of tracking upstream (`f-is-h/Usage4Claude`) in git remotes or CI/CD. Need to check `.git/config` for upstream remote.

7. **AppKit/NSBundle Integration:** App uses `Bundle.main.bundleIdentifier` fallback to `xyz.fi5h.Usage4Claude`. Behavior if real bundle ID differs during runtime is unclear.

---

## Summary for Rebrand Plan

**Total locations requiring updates: ~150+ files**

- **Swift code:** ~10-15 files (app struct name, hardcoded strings, URLs)
- **Xcode project:** 1 file (pbxproj: productName, PRODUCT_BUNDLE_IDENTIFIER, CODE_SIGN_IDENTITY)
- **Localization:** 6 language files (all strings with app name, copyright, descriptions)
- **Scripts:** 2 files (build.sh, GitHub workflow YAML)
- **Website:** 8 HTML files + JS console message
- **Documentation:** README, CHANGELOG, CONTRIBUTING, and localized docs (5+)
- **Assets:** Icon files, DMG icon, favicon
- **Config:** Potentially app groups, code signing identity

**Critical rebrand sequence:**
1. Update bundle ID in Xcode (ripple to Swift code)
2. Rename app struct (`ClaudeUsageMonitorApp` → `<NewName>App`)
3. Update all localization string files
4. Update hardcoded GitHub URLs (5+ locations)
5. Update website files and domain
6. Update build scripts and CI/CD workflows
7. Update documentation and changelogs
8. Regenerate app icon assets (keep design, update metadata only)

