# Scout Report 01: Residual Branding Surface

**Report ID:** scout-01-residual-branding-surface  
**Generated:** 2026-08-17 10:33 UTC  
**Repo:** `/Users/yennq/Projects/opensrc/Usage4Claude`  
**Branch:** `feat/rebrand-usagepacecc`  
**Note:** Excludes `build/` and `plans/` directories from all counts

---

## A. Xcode Rename Surface

| File/Item | Type | Old Name | Count | Notes |
|-----------|------|----------|-------|-------|
| `Usage4Claude.xcodeproj/project.pbxproj` | Project file | Usage4Claude | 14 | Xcode project target, product, build configs, group refs |
| `Usage4Claude.xcscheme` | Build scheme | Usage4Claude | 9 | Blueprint name refs × 3; container refs × 3; BuildableName already set to `UsagePaceCC.app` |
| `Usage4Claude-Release.xcscheme` | Build scheme | Usage4Claude | 9 | Blueprint name refs (3 locations) |
| `Usage4Claude-Debug.xcscheme` | Build scheme | Usage4Claude | 9 | Blueprint name refs (3 locations) |
| `Usage4Claude/` directory | Source root | Usage4Claude | 1 | Top-level source directory name |
| **No test target detected** | N/A | N/A | 0 | No Tests/ or *Tests/ subdirectory in Usage4Claude/ tree |
| **No Info.plist** | N/A | N/A | 0 | Xcode-managed in build settings |
| **No Entitlements** | N/A | N/A | 0 | Xcode-managed in build settings |

**Key finding:** Three xcscheme files have mismatched `BlueprintName` (Usage4Claude) vs `BuildableName` (UsagePaceCC.app) — already partially renamed.

---

## B. Source Code (.swift files)

| Category | Count | File Examples | Details |
|----------|-------|----------------|---------|
| Total Swift files | 54 | App/, Models/, Views/, Helpers/, Services/ | Subdirectories: App (6), Models (7), Views (10+), Helpers (16), Services (7) |
| Files with header comment | ~35 | Most files | `//  Usage4Claude` boilerplate comment (cosmetic, low-risk) |
| **User-visible upstream refs** | 3 files | AboutView.swift, DiagnosticReport.swift, WelcomeView.swift | GitHub URLs & attribution |

### User-Visible Strings (Non-Comment)

| File | Line(s) | Content | Type | Keep? |
|------|---------|---------|------|-------|
| `AboutView.swift` | 6 | `// Copyright © 2025 f-is-h. All rights reserved.` | Copyright header | YES (MIT) |
| `AboutView.swift` | 88 | `URL(string: "https://github.com/sponsors/f-is-h?frequency=one-time")` | Upstream sponsor link | NO (update to fork) |
| `AboutView.swift` | 106 | `// 归因信息 — 基于 f-is-h/Usage4Claude` | Attribution (Chinese) | YES (MIT) |
| `AboutView.swift` | 108 | `URL(string: "https://github.com/f-is-h/Usage4Claude")` | Upstream GitHub link | NO (update to fork) |
| `DiagnosticReport.swift` | (diagnostic text) | `"Contact developer for help at github.com/quangyendn/Usage4Claude/issues"` | Help text | Already uses fork URL |
| `WelcomeView.swift` | (baseURL) | `"https://github.com/quangyendn/Usage4Claude/blob/main"` | Fork URL | Already uses fork URL |

---

## C. Localization Files

| File | Lines | Key Occurrences | Keep Status |
|------|-------|-----------------|-------------|
| `en.lproj/Localizable.strings` | 443 | Line 3: "Usage4Claude" header; Line 5–6: f-is-h copyright; Line 102–103: dual copyright & attribution; Line 248: fork GitHub URL | Header: YES (MIT); String keys: YES (attribution) |
| `zh-Hans.lproj/Localizable.strings` | 441 | Same header pattern | YES (MIT) |
| `ja.lproj/Localizable.strings` | 443 | Same header pattern | YES (MIT) |
| `fr.lproj/Localizable.strings` | 442 | Same header pattern | YES (MIT) |
| `ko.lproj/Localizable.strings` | 441 | Same header pattern | YES (MIT) |
| `zh-Hant.lproj/Localizable.strings` | 443 | Same header pattern | YES (MIT) |

### Localization Strings (Must Preserve)

```
"settings.about.copyright" = "© 2025 f-is-h · © 2026 Yen NQ"
"settings.about.based_on" = "Based on Usage4Claude by f-is-h (MIT License)"
```

**Localized equivalents in ja, zh-Hans, zh-Hant, fr, ko also present** — all must preserve copyright attribution.

---

## D. Documentation

### Root .md Files

| File | Lines | Old Name Refs | Upstream Refs | Type |
|------|-------|----------------|-------------|------|
| `README.md` | 609 | 18 | 6 (GitHub f-is-h/Usage4Claude links, badges) | User-facing; fork attribution present |
| `CHANGELOG.md` | 483 | 19 release tags | 19 (all linked to f-is-h/Usage4Claude/releases/tag/) | User-facing; historical |
| `CONTRIBUTING.md` | 141 | 13 | 4 (clone, template, issue links) | User-facing; development guide |

### Translated README Files (docs/)

| File | Pattern | Content |
|------|---------|---------|
| `README.fr.md` | Same as `README.md` | Fork attribution + upstream GitHub links |
| `README.ja.md` | Same as `README.md` | Fork attribution + upstream GitHub links |
| `README.ko.md` | Same as `README.md` | Fork attribution + upstream GitHub links |
| `README.zh-CN.md` | (not analyzed, pattern expected) | Fork attribution + upstream GitHub links |
| `README.zh-TW.md` | (not analyzed, pattern expected) | Fork attribution + upstream GitHub links |

### Internal Documentation (docs/)

| File | Old Refs | Upstream Refs | Critical? | Notes |
|------|----------|-------------|-----------|-------|
| `PROJECT_SUMMARY.md` | 3+ | 0 | NO | Chinese development notes; cosmetic |
| `CODE_COMMENT_GUIDELINES.md` | 2 | 0 | NO | Chinese standards document |
| `CHANGELOG_RELEASE_NOTES_COMMIT_MESSAGE_GUIDELINES.md` | 0 | 1 (example link) | NO | Example release URL |
| `WEBSITE_GUIDE.md` | 6 | 0 | NO | Chinese website guide |
| **`UPSTREAM_SYNC.md`** | **68** | **68** | **YES** | CRITICAL: Extensive upstream procedure docs; lines 3–4 name fork/upstream repos |

### Upstream_Sync.md Details

```
Line 3: Fork: quangyendn/Usage4Claude
Line 4: Upstream: f-is-h/Usage4Claude
Lines 12–18: ASCII diagram (upstream-mirror ← upstream/main; main branch diverges)
Lines 34–77: One-time setup instructions (git remote add, branch creation, label creation)
Lines 180–221: Automated workflow config + env vars
Lines 224–238: Cherry-pick strategy rationale
```

**Critical sections:**
- Lines 44: `"origin git@github.com:quangyendn/Usage4Claude.git"` (fork remote config)
- Line 44: `"upstream https://github.com/f-is-h/Usage4Claude.git"` (upstream config)
- Lines 73–75: `gh label create` commands (one-time setup only)
- Line 215: Conditional note re: f-is-h/Usage4Claude branch renames
- Line 248: Last synced SHA log (f3446b9 merge commit reference)

---

## E. Build / CI / Scripts

### GitHub Workflows (.github/workflows/)

| File | Lines | Old Refs | Critical Refs | Notes |
|------|-------|----------|---|---------|
| `upstream-watch.yml` | 221 | 5 | env.UPSTREAM_REPO: "f-is-h/Usage4Claude" (line 20); env.UPSTREAM_BRANCH: "main" (line 21) | **CRITICAL**: Hardcoded upstream repo; runs every Monday 08:00 UTC + manual dispatch |
| `release.yml` | 359 | 2 | SCHEME_NAME: "Usage4Claude" (line 28); XCODE_PROJECT: "Usage4Claude.xcodeproj" (line 29) | Release build automation; scheme name needed (can rename) |

### Upstream-Watch.yml Trigger Config

```yaml
on:
  schedule:
    - cron: "0 8 * * 1"  # Every Monday 08:00 UTC
  workflow_dispatch: {}  # Manual trigger
```

### Release.yml Scheme Vars

```yaml
SCHEME_NAME: Usage4Claude
XCODE_PROJECT: Usage4Claude.xcodeproj
```

### Dependabot Config (.github/dependabot.yml)

- **Swift ecosystem:** NOT configured (Xcode-managed SPM)
- **GitHub Actions:** Weekly schedule; includes labels configuration
- **No old-name references**

### Scripts (scripts/)

| File | Old Refs | Details |
|------|----------|---------|
| `build.sh` | 2 | Line 49: `SCHEME_NAME="Usage4Claude"`; Line 50: `XCODEPROJ="${PROJECT_ROOT}/Usage4Claude.xcodeproj"` |

---

## F. Website (website/ directory)

### HTML Files

| File | Type | GitHub URLs | Old Name Refs | Details |
|------|------|-------------|---------------|---------|
| `index.html` | Main page | 6+ | 12 | Title: "Usage4Claude - Real-time Claude AI Usage Monitor for macOS"; Canonical: `https://usage4claude.pages.dev/`; Links: f-is-h/Usage4Claude (GitHub, releases, issues, discussions) + sponsors link |
| `index.zh-cn.html` | Localized | 6+ | 12 | Same pattern (Chinese) |
| `index.ja.html` | Localized | 6+ | 12 | Same pattern (Japanese) |
| `index.zh-tw.html` | Localized | 6+ | 12 | Same pattern (Traditional Chinese) |
| `index.ko.html` | Localized | 6+ | 12 | Same pattern (Korean) |
| `legal.html` | Legal | 2 | 4 | References to f-is-h/Usage4Claude (issues, LICENSE); English + Japanese sections |
| `privacy.html` | Legal | (likely similar) | (likely similar) | Not fully analyzed |

### JavaScript/Configuration

- `js/main.js`, `js/i18n.js`, `js/translations-privacy.js`, `functions/_middleware.js`
  - No old-name refs detected in basic file listing; may contain URLs in data

### Website Deployment Note

- Domain: `https://usage4claude.pages.dev/` (hardcoded in multiple pages)
- Generator: Cloudflare Pages (docs/CLOUDFLARE_DEPLOYMENT.md exists; not analyzed)

---

## G. Upstream Coupling

### Hardcoded Upstream Repository

```
Organization/Repo: f-is-h/Usage4Claude
URL: https://github.com/f-is-h/Usage4Claude.git
Hardcoded Locations:
  1. .github/workflows/upstream-watch.yml line 20: env.UPSTREAM_REPO
  2. docs/UPSTREAM_SYNC.md lines 3–4, 44, 215, 248
  3. README.md, CONTRIBUTING.md, CHANGELOG.md (user-facing references)
  4. Website HTML (6 files) — user-facing download/GitHub links
```

### Branch Topology

```
upstream/main (f-is-h/Usage4Claude)
  ↓ (tracked by CI)
upstream-mirror (fast-forward-only mirror, never committed to)
  ↓ (manually cherry-picked)
main (fork rebrand; diverges from upstream since 2026-06-21 merge commit f3446b9)
  ↓ (created by CI for review)
upstream-sync/<YYYY-MM-DD> (ephemeral branch, deleted after merge/close)
```

### Upstream-Watch Workflow Config (CRITICAL)

| Setting | Value | Trigger |
|---------|-------|---------|
| Schedule | `0 8 * * 1` | Every Monday 08:00 UTC |
| Manual dispatch | `workflow_dispatch: {}` | Manual via `gh workflow run` |
| Upstream repo | `f-is-h/Usage4Claude` | Hardcoded in env (line 20) |
| Upstream branch | `main` | Hardcoded in env (line 21) |
| Mirror branch | `upstream-mirror` | Local tracking branch |
| PR behavior | DRAFT | Never auto-merged; requires human review |
| Labels | `upstream-sync` (always); `security` (if CVE keywords detected) | Auto-applied by workflow |

### Upstream Sync Labels (One-Time Setup)

```bash
gh label create security      --color d73a4a
gh label create upstream-sync --color 0075ca
gh label create dependencies  --color 0075ca
```

(Defined in docs/UPSTREAM_SYNC.md lines 73–75; must exist before first workflow run)

---

## H. Legit Keeps (MIT Compliance)

### Files/Sections That MUST Preserve Old Brand Names

| Item | Location | Reason | Example |
|------|----------|--------|---------|
| **MIT License header** | LICENSE | Copyright attribution (original author) | `Copyright (c) 2025 f-is-h` |
| **Dual copyright** | LICENSE | Fork copyright | `Copyright (c) 2026 Yen NQ (Quang Yen)` |
| **Swift file headers** | All 54 .swift files | Copyright notice | `//  Copyright © 2025 f-is-h. All rights reserved.` |
| **Localization file headers** | All 6 .strings files | Copyright notice | `Created by f-is-h on 2025-10-15. Copyright © 2025 f-is-h.` |
| **Attribution string (en)** | Localizable.strings | User-facing attribution | `"settings.about.based_on" = "Based on Usage4Claude by f-is-h (MIT License)"` |
| **Dual copyright string** | All 6 .strings files | User-visible attribution | `"settings.about.copyright" = "© 2025 f-is-h · © 2026 Yen NQ"` |
| **README footer** | README.md line 605 | Author credit | `"Made with ❤️ by f-is-h"` |
| **CHANGELOG links** | CHANGELOG.md lines 465–483 | Historical release records | All 19 release links to `f-is-h/Usage4Claude/releases/tag/v*` |

### Rationale

MIT License requires preservation of original copyright notice. Dual copyright (f-is-h + Yen NQ) documents fork lineage and both contributions. User-visible attribution strings preserve acknowledgment of upstream. Historical release links provide version lineage context (users can trace back to upstream releases).

---

## Summary

### Branding Surface Area

| Category | Total Old-Name Refs | Critical? | Notes |
|----------|-------------------|-----------|-------|
| Xcode (.xcodeproj) | 41 | YES | Target, project, scheme names + 1 directory |
| Swift source (.swift) | ~35 (mostly comments; 3 user-visible) | NO | Cosmetic headers; 3 files with upstream URLs only |
| Localization (.strings) | 6 headers + 6 dual-copyright strings | YES (keep all) | File headers + string keys must preserve for MIT |
| Documentation (.md) | 100+ | MEDIUM | User guides + internal docs; upstream-sync critical |
| Website (HTML) | 60+ | YES | 6 files with hardcoded URLs + canonical domain |
| Workflows (CI/CD) | 5 | CRITICAL | `upstream-watch.yml` env var; `release.yml` scheme name |
| Scripts | 2 | MEDIUM | `build.sh` scheme/project names |

### Critical Dependencies for Rename

1. **Xcode project renaming** — Must update `project.pbxproj` + 3 xcscheme files + source directory name
2. **Workflow env vars** — `upstream-watch.yml` line 20 hardcodes upstream repo (intentional; documents external coupling)
3. **Website URLs** — 6 HTML files + canonical domain (usage4claude.pages.dev) must decide: rebrand or preserve historical name?
4. **Documentation** — README.md, CONTRIBUTING.md, translated READMEs describe fork + upstream; choose which to update
5. **Localization attribution** — MUST preserve dual copyright strings for MIT compliance

### Directory & Build Findings

- **No test target:** Usage4Claude/ tree has no Tests/ directory
- **No Homebrew cask:** No .rb or homebrew-related files detected
- **No Sparkle/appcast:** No appcast.xml or Sparkle setup files
- **Build artifacts:** `build/` excluded; contains mixed old/new app names (UsagePaceCC + Usage4Claude versions)

---

## Unresolved Questions

1. **Build artifacts cleanup:** Should `build/Usage4Claude-Release-3.0.0/` and `build/Usage4Claude-Release-2.6.0/` be deleted before rename plan executes? (Already have UsagePaceCC 3.0.0 build.)

2. **Website rebranding scope:** Rename `usage4claude.pages.dev/` to `usagepacecc.pages.dev/` or keep historical domain for backward compatibility? (Impacts Cloudflare, DNS, all 6 HTML files.)

3. **Code signing identity:** Does Xcode use `Usage4Claude-CodeSigning` identity (mentioned in docs/PROJECT_SUMMARY.md)? Is it hardcoded elsewhere beyond build settings?

4. **Release asset naming:** Does `release.yml` generate artifacts named `Usage4Claude-*.app` or `Usage4Claude-*.zip`? Need to verify output naming conventions.

5. **GitHub label recreation:** After renaming fork repo to `UsagePaceCC`, must `upstream-sync`, `security`, and `dependencies` labels be recreated, or do they persist?

6. **Upstream-watch manual trigger:** If upstream `f-is-h/Usage4Claude` is archived or deleted, does the workflow fail silently or error? Is this coupling acceptable long-term?

7. **Deployment docs:** Does `docs/CLOUDFLARE_DEPLOYMENT.md` contain hardcoded URLs or build commands that reference old names?

---

**Scout Report End**
