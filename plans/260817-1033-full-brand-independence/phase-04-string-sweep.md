# Phase 04 — Residual String Sweep (with MIT Exclusion List)

## Context links

- Plan: [plan.md](./plan.md) — "Locked Constraints" holds the authoritative keep list
- Scout: [scout-01 §B–§F, §H](./scout/scout-01-residual-branding-surface.md)
- Depends on: [Phase 03](./phase-03-xcode-rename.md) (source dir is now `UsagePaceCC/`)

## Overview

Replace remaining `Usage4Claude` brand strings in Swift headers, localization,
docs, README translations, and CI templates; remove the upstream sponsor/funding links
(V1); delete the obsolete screenshots skill (V7); and repoint the website domain token
(V8) — while leaving every MIT attribution byte-for-byte intact. Blanket `sed` is **banned**.

## Key Insights

- Three tokens, three different rules. Conflating them is the failure mode:
  | Token | Count | Rule |
  |---|---:|---|
  | `quangyendn/Usage4Claude` | 22 | **always** → `quangyendn/UsagePaceCC` (fork's own repo path) |
  | `f-is-h/Usage4Claude` | 196 | **split**: keep attribution/history/upstream-config; repoint *fork support* links |
  | bare `Usage4Claude` | remainder of 666 | → `UsagePaceCC`, minus the keep list |
- The Swift header block contains a **project-name line** and **copyright lines**:
  ```
  //  UpdateChecker.swift
  //  Usage4Claude          ← project name, IN SCOPE (54 files)
  //
  //  Created by f-is-h on 2025-10-15.        ← KEEP verbatim
  //  Copyright © 2025 f-is-h. All rights reserved.   ← KEEP verbatim
  ```
  A regex anchored to `^//  Usage4Claude$` hits exactly the 54 project-name lines and
  cannot touch the copyright lines.
- README/CONTRIBUTING currently route **fork users to upstream** for issues, discussions,
  clone URL, and release downloads. That is actively wrong, not attribution.
  Repoint. Keep L26 attribution, L571 copyright, L605 footer credit.
- **Sponsor links are removed, not kept and not repointed (decision V1 overrides prior-plan
  D8).** D8 said "keep upstream funding links as credit"; V1 reverses it. MIT requires
  attribution, not funding. The scout report said "update to fork" — that is also wrong:
  **delete**, do not repoint. `AboutView.swift` L106/L108 attribution stays untouched.
- `"settings.about.based_on" = "Based on Usage4Claude by f-is-h (MIT License)"` — the
  literal `Usage4Claude` is upstream's *product name*. Keep in all 6 locales.
- **The screenshots skill is deleted, not renamed (V7).** `rm -rf` removes ~22 refs from
  the sweep surface outright, so the ~666 total shrinks to ~644 before any replacement
  work starts, and Pass F loses its skill-rename half.
- **Website domain token is swept here (V8), the Cloudflare rename is not.** Docs will name
  `usagepacecc.pages.dev` while that host still 404s until the deferred Phase 08 runs. This
  is accepted and must be stated in the docs that mention it — see the warning in Pass H.
- Issues are currently **disabled** on the repo, yet docs point users at fork issues.
  Enabling Issues is handled in Phase 05 — note the dependency.

## Requirements

- `git grep "quangyendn/Usage4Claude"` → **0 hits** after this phase.
- Every entry on the keep list byte-identical (verified by targeted `git diff` review).
- Post-sweep `Usage4Claude` count is a *documented non-zero number*, all accounted for.
- App still builds and localization still loads. String **keys** are unchanged **except**
  the funding keys deliberately deleted in Pass G alongside their buttons.
- No upstream sponsor/funding link anywhere in the tree (V1); `.github/FUNDING.yml` gone.
- `.agents/skills/capture-usage4claude-screenshots/` deleted, no dangling references (V7).
- `git grep "usage4claude.pages.dev"` → 0 (V8), with the pending-Cloudflare-rename caveat
  recorded in `docs/CLOUDFLARE_DEPLOYMENT.md`.

## Architecture — Change / Keep Matrix

### CHANGE

| File(s) | Count | Edit |
|---|---:|---|
| `UsagePaceCC/**/*.swift` (54 files) | 54 | `^//  Usage4Claude$` → `//  UsagePaceCC` |
| `UsagePaceCC/Services/UpdateChecker.swift` L21 | 1 | `repoName = "Usage4Claude"` → `"UsagePaceCC"` |
| `UsagePaceCC/Models/DiagnosticReport.swift` L246, L314 | 2 | `quangyendn/Usage4Claude` → `quangyendn/UsagePaceCC` |
| `UsagePaceCC/Views/Settings/Welcome/WelcomeView.swift` L597 | 1 | baseURL → `quangyendn/UsagePaceCC` |
| `UsagePaceCC/Views/Settings/Tabs/AboutView.swift` L62 | 1 | fork repo link → `quangyendn/UsagePaceCC` (L106/L108 KEEP) |
| `UsagePaceCC/Views/Settings/Tabs/AboutView.swift` L86–99 | 1 | **delete** the GitHub Sponsors button (`https://github.com/sponsors/f-is-h?frequency=one-time`) — V1 |
| `.github/FUNDING.yml` | file | **delete** — verified present, contains `github: f-is-h` + `ko_fi: 1atte` (both upstream) |
| `README.md` L541–556 | block | **delete** the `### ☕ Buy Me a Coffee` sponsor block (GitHub Sponsors anchor + Ko-fi anchor + the commented-out Buy Me A Coffee anchor) |
| `docs/README.{fr,ja,ko,zh-CN,zh-TW}.md` | 5 × block | **delete** the equivalent sponsor block per locale (`docs/README.fr.md` ~L476–493; the other four ~L541–558 — locate by the `<!-- GitHub Sponsors -->` marker, not by line number) |
| `UsagePaceCC/Resources/*.lproj/Localizable.strings` (6) | 6 × ~2 | file-header project-name line; `diagnostic.suggestion_contact_support` URL |
| `README.md` L1, L13–14 badges, L182, L199–200, L203, L291, L360, L392, L404, L589–590 | ~14 | title, badges, download, clone, `open UsagePaceCC.xcodeproj`, prose, issues/discussions → fork |
| `docs/README.{fr,ja,ko,zh-CN,zh-TW}.md` | 5 × ~14 | same pattern per locale |
| `CONTRIBUTING.md` L1, L9, L19, L31–32, L91, L131–133 | 9 | title, templates, clone, tree, issues/PRs/discussions → fork |
| `.github/RELEASE_TEMPLATE.md` | 3 | `quangyendn/Usage4Claude` → new |
| `docs/PROJECT_SUMMARY.md` | 4 | project name refs |
| `docs/CODE_COMMENT_GUIDELINES.md` | 2 | project name refs |
| `docs/DAILY_RELEASE_WORKFLOW.md` | 11 | project/repo refs |
| `docs/IMPLEMENTATION_PLAN_CODEX.md` | 13 (+1 domain) | project refs + 1 × `usage4claude.pages.dev` |
| `docs/FILESYSTEM_OPERATIONS_GUIDELINES.md` | 2 | project refs |
| `docs/CODE_SIGNING.md` | 2 | **brand tokens only.** The signing narrative and the stale repo note at L98–100 are rewritten in **Phase 06** (V3) — do not pre-empt it here |
| `docs/CHANGELOG_RELEASE_NOTES_...GUIDELINES.md` | 1 | example release URL |
| `docs/usage4claude-v2-spec.md` | 4 + filename | `git mv` → `docs/usagepacecc-v2-spec.md` |
| `docs/images/ICON_NOTES.md` | 1 | project ref |
| `.agents/skills/capture-usage4claude-screenshots/` | dir, ~22 refs | **`rm -rf` the whole directory** (V7 — the skill is no longer used). No rename, no in-file fixes. Removes ~22 refs from the sweep surface |
| `docs/WEBSITE_GUIDE.md` | 6 | project refs (no `pages.dev` literal in this file — verified; its one `.pages.dev` mention at L429 is generic, leave it) |
| `docs/CLOUDFLARE_DEPLOYMENT.md` | 3 (incl. 2 domain) | project refs + `usage4claude.pages.dev` → `usagepacecc.pages.dev` (V8) |
| `website/robots.txt`, `website/README.md`, `website/index*.html` (5) | 52 domain hits (5 × 10 + 1 + 1) | **domain token only** (`usage4claude.pages.dev` → `usagepacecc.pages.dev`). All other `website/**` branding stays with Phase 08 |
| `docs/UPSTREAM_SYNC.md` | 13 | **owned by Phase 06** — skip here |
| `website/**` (non-domain brand strings) | 60+ | **owned by Phase 08** — skip here |

### KEEP — do not touch (verify byte-identical after sweep)

| File(s) | What |
|---|---|
| `LICENSE` | `Copyright (c) 2025 f-is-h` + Yen NQ 2026 line |
| `UsagePaceCC/**/*.swift` (54) | `//  Created by f-is-h …` + `//  Copyright © 2025 f-is-h …` |
| `UsagePaceCC/Resources/*.lproj/Localizable.strings` (6) | header `Created by f-is-h … Copyright © 2025 f-is-h.` |
| same (6) | `"settings.about.copyright" = "© 2025 f-is-h · © 2026 Yen NQ"` |
| same (6) | `"settings.about.based_on" = "Based on Usage4Claude by f-is-h (MIT License)"` + localized equivalents |
| `AboutView.swift` | L106 attribution comment, L108 upstream repo link. **L88 sponsor URL is no longer on this list — it is deleted (V1)** |
| `README.md` | L26 attribution, L571 copyright, L605 footer credit. **The sponsor block is deleted (V1)** |
| `docs/README.{fr,ja,ko,zh-CN,zh-TW}.md` | the same 3 blocks per locale (sponsor block deleted) |
| `CHANGELOG.md` | all 19 `f-is-h/Usage4Claude/releases/tag/v*` links + historical entries |
| `docs/archive/*` (5 files, 143 refs) | frozen historical notes — **V6: freeze**, excluded from every pass |

### Sponsor removal — full surface

The revision brief named `AboutView.swift` L88, `README.md` L545 (+ 5 locales), and
`.github/FUNDING.yml`. Grepping the tree turned up **more of the same category**.
**Decision V9 (user-confirmed 2026-08-17): remove ALL of them — every funding/sponsor
entry point pointing at upstream, in both the About tab and the menu bar. No replacement
links are added.** MIT attribution is unaffected and stays.

| Path | What | Status |
|---|---|---|
| `AboutView.swift` L86–99 | GitHub Sponsors button → `sponsors/f-is-h` | **Remove** (V1) |
| `README.md` + 5 locale READMEs | `<!-- GitHub Sponsors -->` anchor | **Remove** (V1) |
| `.github/FUNDING.yml` | `github: f-is-h`, `ko_fi: 1atte` | **Remove** (verified present) |
| `AboutView.swift` L73–85 | Ko-fi button → `https://ko-fi.com/1atte` | **Remove** (V9) |
| `README.md` + 5 locales | Ko-fi anchor inside the same block | **Remove** (V9) |
| `MenuBarUI.swift` L373–390, `MenuBarManager.swift` L194–201, `UsageDetailView.swift` L54–55, L404–409 | menu-bar **Coffee** + **GitHub Sponsor** items | **Remove** (V9) |
| `LocalizationHelper.swift` L23–24, L140–141 + `settings.about.coffee`, `settings.about.github_sponsor`, `menu.coffee`, `menu.github_sponsor` in 6 `.strings` | the keys behind those buttons | **Remove** — all four buttons are gone, so all four key sets go. The one sanctioned exception to "never touch localization keys" |

No `[USER] confirm` rows remain in this table. Record the final removal count in the
accounting table. **Do not** remove `settings.about.based_on`, `settings.about.copyright`,
or the `AboutView.swift` L106/L108 attribution block — those are MIT keeps.

## Related code files

Full paths rooted at `/Users/yennq/Projects/opensrc/Usage4Claude/`. See the matrix above;
every CHANGE row is a modify unless marked `git mv`.

## Implementation Steps

1. Snapshot the before-counts (compare against Phase 01 baselines):
   ```bash
   git grep -o "Usage4Claude"            -- . ':!plans' ':!build' | wc -l
   git grep -o "quangyendn/Usage4Claude" -- . ':!plans' ':!build' | wc -l
   git grep -o "f-is-h/Usage4Claude"     -- . ':!plans' ':!build' | wc -l
   ```
2. **Pass A — fork repo path (mechanical, safe).** Exactly one rule, zero ambiguity:
   ```bash
   git grep -l "quangyendn/Usage4Claude" -- . ':!plans' ':!build' \
     | xargs sed -i '' 's|quangyendn/Usage4Claude|quangyendn/UsagePaceCC|g'
   ```
   Then `git grep "quangyendn/Usage4Claude"` → 0. Commit:
   `refactor: repoint fork repository URLs to quangyendn/UsagePaceCC`
3. **Pass B — Swift header project-name line (anchored, safe).**
   ```bash
   git grep -l '^//  Usage4Claude$' -- '*.swift' \
     | xargs sed -i '' 's|^//  Usage4Claude$|//  UsagePaceCC|'
   ```
   Verify copyright lines survived:
   ```bash
   git grep -c "Copyright © 2025 f-is-h" -- '*.swift' | wc -l   # → 54
   git grep -c "Created by f-is-h"       -- '*.swift' | wc -l   # → 54
   ```
   Commit: `refactor: update Swift file headers to UsagePaceCC`
4. **Pass C — UpdateChecker repo name.** `UsagePaceCC/Services/UpdateChecker.swift` L21
   `private let repoName = "UsagePaceCC"`. Verify the constructed URL:
   `https://api.github.com/repos/quangyendn/UsagePaceCC/releases/latest`.
   Commit with Pass B or separately.
5. **Pass D — localization (6 files, manual per file).** Change only the header
   project-name line and the `diagnostic.suggestion_contact_support` value (Pass A already
   fixed the URL). Never touch keys. Then:
   ```bash
   for f in UsagePaceCC/Resources/*.lproj/Localizable.strings; do plutil -lint "$f"; done
   ```
   *(if `plutil` rejects the format, fall back to a build + runtime language spot-check)*
6. **Pass E — docs & README family (manual, per file).** Work file by file using the
   matrix. For each README locale, repoint: title, badges, download link, clone URL,
   `open UsagePaceCC.xcodeproj`, issues, discussions. Leave the 4 attribution blocks.
7. **Pass F — rename the spec doc, delete the skill.**
   ```bash
   git mv docs/usage4claude-v2-spec.md docs/usagepacecc-v2-spec.md
   git rm -r .agents/skills/capture-usage4claude-screenshots/     # V7 — delete, do not rename
   ```
   Then grep for anything that still references the deleted skill path and drop those
   references too (do **not** re-create the skill):
   ```bash
   git grep -n "capture-usage4claude\|capture_usage4claude_window" -- . ':!plans'   # → 0
   ```
   Commit: `chore: remove unused screenshot-capture skill`.
8. **Pass G — sponsor / funding removal (V1 + V9).** Work the "Sponsor removal — full
   surface" table above. Every row is confirmed for removal; nothing to ask.
   - delete BOTH the GitHub Sponsors button block and the Ko-fi button block in
     `AboutView.swift`, plus the menu-bar Coffee + GitHub Sponsor items in
     `MenuBarUI.swift`, `MenuBarManager.swift`, `UsageDetailView.swift`;
   - delete the `### ☕ Buy Me a Coffee` sponsor block in `README.md` and each of the 5
     locale READMEs — locate it by the `<!-- GitHub Sponsors -->` marker;
   - `git rm .github/FUNDING.yml`;
   - remove the menu-bar Coffee / GitHub Sponsor items if confirmed, plus the now-dead
     `L.*` accessors and the matching `.strings` keys in all 6 locales.

   Verify nothing funding-related survives and no attribution was collaterally hit:
   ```bash
   git grep -n "sponsors/f-is-h\|ko-fi.com\|ko_fi" -- . ':!plans' ':!docs/archive' ':!CHANGELOG.md'
   git grep -c "settings.about.based_on"  -- 'UsagePaceCC/Resources/*.lproj/Localizable.strings'  # → 6
   git grep -c "settings.about.copyright" -- 'UsagePaceCC/Resources/*.lproj/Localizable.strings'  # → 6
   ```
   Build after this pass — removing `L` accessors that are still referenced is the obvious
   way to break the build. Commit: `refactor: remove upstream sponsor and funding links`.
9. **Pass H — website domain token (V8).** One mechanical rule, safe to `sed`:
   ```bash
   git grep -l "usage4claude.pages.dev" -- . ':!plans' ':!build' \
     | xargs sed -i '' 's|usage4claude\.pages\.dev|usagepacecc.pages.dev|g'
   git grep "usage4claude.pages.dev" -- . ':!plans'   # → 0
   ```
   Expected hit set (verified): `docs/CLOUDFLARE_DEPLOYMENT.md` ×2,
   `docs/IMPLEMENTATION_PLAN_CODEX.md` ×1, `website/README.md` ×1, `website/robots.txt` ×1,
   `website/index{,.ja,.ko,.zh-cn,.zh-tw}.html` ×10 each = **55 matching lines**
   (`git grep -c` counts lines, not occurrences — treat 55 as the floor).
   `docs/WEBSITE_GUIDE.md` has no literal old domain — leave it alone.

   > ⚠️ **The new domain does not resolve yet.** Renaming the Cloudflare Pages project is
   > the deferred **Phase 08**, which is *not* run here. Between this pass and Phase 08,
   > every doc and page that names `usagepacecc.pages.dev` points at a host that 404s,
   > while the still-live `usage4claude.pages.dev` is no longer referenced anywhere.
   > This is accepted (the site is unpromoted, zero external users). Add a one-line note
   > at the top of `docs/CLOUDFLARE_DEPLOYMENT.md` saying the domain rename is pending so
   > the discrepancy is not read as a bug.

   Commit: `docs: repoint website domain to usagepacecc.pages.dev`.
10. **Keep-list audit — the critical gate.** Review the diff of every keep-list file:
   ```bash
   git diff HEAD~N -- LICENSE CHANGELOG.md 'UsagePaceCC/Resources/*.lproj/Localizable.strings' \
     UsagePaceCC/Views/Settings/Tabs/AboutView.swift README.md docs/README.*.md
   ```
   `LICENSE` and `CHANGELOG.md` must show **zero** diff. The `.strings` diff must contain
   no line matching `f-is-h` **except** the deliberate removal of `settings.about.coffee` /
   `settings.about.github_sponsor` / `menu.*` funding keys from Pass G. `AboutView.swift`
   diff must show exactly: L62 repointed + the sponsor (and, if confirmed, Ko-fi) button
   blocks deleted — and **nothing** in the L106/L108 attribution block.
11. Build + runtime check:
   ```bash
   ./scripts/build.sh
   open build/UsagePaceCC-Release-*/UsagePaceCC.app
   ```
   In-app: About tab shows dual copyright + "Based on Usage4Claude by f-is-h" and **no
   sponsor button**; GitHub link opens `quangyendn/UsagePaceCC` (404 until Phase 05 —
   expected); menu bar has no Coffee / GitHub Sponsor items (if those were confirmed);
   switch language to ja/ko/zh-Hans and confirm no `???` / raw keys.
12. Record the final counts and the accounting table (see Success Criteria).

## Todo list

- [ ] Record before-counts (note: ~666 total drops to ~644 once the skill dir is deleted)
- [ ] Pass A: `quangyendn/Usage4Claude` → `quangyendn/UsagePaceCC` (22) + commit
- [ ] Pass B: 54 Swift header project-name lines + commit
- [ ] Pass C: `UpdateChecker.repoName`
- [ ] Pass D: 6 × `Localizable.strings` (header + diagnostic value only)
- [ ] Pass E: README.md, 5 translated READMEs, CONTRIBUTING.md
- [ ] Pass E: 8 × `docs/*.md` + `.github/RELEASE_TEMPLATE.md`
- [ ] Pass F: `git mv` spec doc; **`git rm -r` the screenshots skill** (V7 — delete, not rename)
- [ ] Pass F: `git grep "capture-usage4claude"` → 0 (no dangling references to the deleted skill)
- [x] Sponsor-removal surface CONFIRMED (V9): remove ALL Ko-fi + GitHub Sponsor entry points (About + menu bar)
- [ ] Pass G: remove sponsor/funding links — `AboutView.swift`, 6 READMEs, `.github/FUNDING.yml`
      (+ confirmed menu-bar items and their `L` accessors / `.strings` keys)
- [ ] Pass G verify: `git grep "sponsors/f-is-h"` → 0; `based_on`/`copyright` still 6 each
- [ ] Pass H: `usage4claude.pages.dev` → `usagepacecc.pages.dev` (55 matching lines) + pending-rename
      note in `docs/CLOUDFLARE_DEPLOYMENT.md`
- [ ] **Keep-list audit** — `LICENSE`/`CHANGELOG.md` zero diff; no attribution line touched
- [ ] `./scripts/build.sh` + launch + About tab (no sponsor button) + 3 locales spot-check
- [ ] Record final accounting table

## Success Criteria

- [ ] `git grep "quangyendn/Usage4Claude"` → 0
- [ ] `git grep -c "Copyright © 2025 f-is-h" -- '*.swift' | wc -l` → 54
- [ ] `git diff` on `LICENSE` and `CHANGELOG.md` across the whole phase → empty
- [ ] `git grep "sponsors/f-is-h" -- . ':!plans' ':!docs/archive' ':!CHANGELOG.md'` → 0
- [ ] `.github/FUNDING.yml` no longer exists
- [ ] `.agents/skills/capture-usage4claude-screenshots/` no longer exists; no references remain
- [ ] `git grep "usage4claude.pages.dev" -- . ':!plans'` → 0
- [ ] Remaining `Usage4Claude` occurrences fully accounted for:
      | Bucket | Expected |
      |---|---|
      | `docs/archive/*` (frozen, V6) | 143 |
      | `CHANGELOG.md` history | 19 |
      | README family attribution blocks (3 per file, sponsor block gone) | ~4/file |
      | `.strings` `based_on` + headers | 6 locales |
      | `website/**` non-domain brand strings (Phase 08) | 60+ |
      | `docs/UPSTREAM_SYNC.md` (Phase 06) | 13 |
      | `.agents/skills/capture-usage4claude-screenshots/` | **0 — directory deleted** |
      | anything else | **0** |
- [ ] App builds, launches, About tab correct (no sponsor button), 3 locales render

## Verification commands

```bash
git grep "quangyendn/Usage4Claude" -- . ':!plans' ':!build' ; echo "exit=$?"   # exit=1
git grep -n "Usage4Claude" -- . ':!plans' ':!build' ':!docs/archive' ':!website' \
  ':!CHANGELOG.md' ':!docs/UPSTREAM_SYNC.md'      # every hit must be on the keep list
git grep -n "based_on" -- 'UsagePaceCC/Resources/*.lproj/Localizable.strings'   # → 6
git grep -n "sponsors/f-is-h\|ko_fi" -- . ':!plans' ':!docs/archive' ':!CHANGELOG.md'  # → 0
git grep -n "capture-usage4claude\|capture_usage4claude_window" -- . ':!plans'         # → 0
git grep -n "usage4claude.pages.dev" -- . ':!plans'                                    # → 0
test ! -e .github/FUNDING.yml && echo "FUNDING.yml removed"
test ! -d .agents/skills/capture-usage4claude-screenshots && echo "skill removed"
./scripts/build.sh
```

## Rollback

Per-pass commits → `git revert <pass-sha>` isolates a bad pass. Passes A, B and H are
mechanical and idempotent; Passes D, E and G are hand edits, so keep them in separate
commits from the mechanical passes. Pass F is a deletion — reverting the commit restores
the skill directory intact, so no separate backup is needed.

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Blanket `sed` strips an MIT attribution | **High** | `sed` used only in Pass A (unique compound token) and Pass B (`^…$` anchored); all other passes are hand edits; step 8 keep-list audit is a hard gate |
| Localization key accidentally renamed → runtime `???` | Medium | Only values/headers edited; step 9 runtime check across 3 locales |
| Fork support links point at a 404 until Phase 05 | Low | Intentional; zero releases shipped and zero users. Phase 05 follows same day |
| Something still depends on the deleted screenshots skill | Low | V7 confirms the skill is unused; the Pass F grep proves no dangling references. Phase 08's "recapture screenshots" step is updated to note the skill is gone |
| Sponsor removal over-reaches into attribution | **High** | Pass G verifies `based_on` + `copyright` still 6 each and the `AboutView.swift` diff must not touch L106/L108; step 10 keep-list audit is the hard gate |
| Removing an `L` accessor whose button still exists → build break | Medium | Pass G ends with `./scripts/build.sh`; keys are removed only alongside their button |
| Docs name a domain that does not resolve | Medium | Accepted (V8). Pass H adds a "rename pending" note to `docs/CLOUDFLARE_DEPLOYMENT.md`; Phase 08 closes it. Site is unpromoted, zero external users |
| `docs/archive` swept by accident | Low | Excluded from every pass pathspec; counted in the accounting table |

## Security Considerations

- Removing upstream attribution would be an MIT violation and a reputational hit —
  step 8 exists solely to prevent that.
- No secrets or endpoints beyond public GitHub URLs are touched.
- `UpdateChecker` now queries `quangyendn/UsagePaceCC` — confirm no token or auth header
  is attached to that unauthenticated API call.

## Next steps

→ [Phase 05 — GitHub identity](./phase-05-github-identity.md). Push these commits before
the rename so the repo content matches the new name.
