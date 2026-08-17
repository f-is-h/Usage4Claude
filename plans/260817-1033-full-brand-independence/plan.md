---
title: "Full Brand Independence — UsagePaceCC"
description: "Detach + rename the GitHub fork, take over main, rename the Xcode project/target/scheme/source-dir, sweep residual Usage4Claude branding, and downgrade upstream coupling to manual-only — while keeping every MIT attribution intact."
status: pending
priority: P1
effort: 10h  # Phases 01–06 in scope; 07–08 deferred (+5h)
branch: feat/rebrand-usagepacecc
tags: [infra, refactor, docs, critical]
created: 2026-08-17
---

# Full Brand Independence — UsagePaceCC

Sequel to `plans/2026-06-21-fork-rebrand-upstream-sync/` (7/9 done). That plan changed
the *product*: `PRODUCT_NAME=UsagePaceCC`, bundle id `com.quangyendn.usagepacecc`, UI
strings, icon, build/CI. This plan changes the *project*: repo identity, main line,
Xcode structure, residual strings, upstream coupling.

## Goal

`quangyendn/Usage4Claude` becomes a standalone `quangyendn/UsagePaceCC` repo:
own name, own `main`, own Xcode project/target/scheme/source dir, zero
non-attribution `Usage4Claude` strings, upstream watched only on demand — with
every MIT obligation preserved.

## Phases

| # | Phase | Status | Effort | Link |
|---|-------|--------|-------:|------|
| 01 | Pre-flight safety net & confirm gate | **Done (2026-08-17)** | 1h | [phase-01](./phase-01-preflight-safety.md) |
| 02 | Branch takeover: `main` = rebrand line | **Done (2026-08-17)** | 1.5h | [phase-02](./phase-02-branch-takeover.md) |
| 03 | Xcode project/target/scheme/source-dir rename | **Done (2026-08-17)** | 2.5h | [phase-03](./phase-03-xcode-rename.md) |
| 04 | Residual string sweep (MIT exclusion list) | **Done (2026-08-17)** | 3h | [phase-04](./phase-04-string-sweep.md) |
| 05 | GitHub identity: detach → rename → re-point | Pending | 1.5h | [phase-05](./phase-05-github-identity.md) |
| 06 | Upstream decoupling + signing cleanup | Pending | 1.5h | [phase-06](./phase-06-upstream-decoupling.md) |
| 07 | Code-signing cert + first release publish | **Deferred (out of scope)** | 2h | [phase-07](./phase-07-signing-release.md) |
| 08 | Website rebrand + Cloudflare domain rename | **Deferred (out of scope)** | 2.5h | [phase-08](./phase-08-website.md) |

**This run covers Phases 01–06 only (decision V4).** Plan-level "done" == Phase 06
complete. Phases 07 and 08 are deferred to a later run and are not executed here;
their acceptance criteria live in a separate "Deferred acceptance criteria" subsection.
In-scope effort ~10h.

## Dependency Graph

```
01 (safety net + CONFIRM GATE)
 └─► 02 (main takeover, force-push)
      └─► 03 (Xcode rename)  ─┐
           └─► 04 (string sweep) ─┬─► 05 (detach → rename → re-point → enable Issues)
                                  │        └─► 06 (upstream manual-only + signing cleanup)
                                  │             ╌╌► 07 (cert + release)   [DEFERRED]
                                  └────────────────╌► 08 (website)        [DEFERRED]
```

- 01 gates everything. Nothing irreversible before the user confirms.
- 02 before 03: rename on the wrong branch line is wasted work.
- 03 before 04: 03 owns build-critical refs (`release.yml`, `build.sh`,
  `verify_version.sh`); 04 owns everything else. Do not overlap them.
- 04 before 05: land the `quangyendn/UsagePaceCC` URL edits, then rename so they
  resolve. Transient 404 window is acceptable (zero releases shipped — see Insights).
- 06 after 05: the workflow edits reference the renamed repo. 06 is the **last in-scope
  phase** — the plan is done when it passes.
- 07 and 08 are **deferred** (`╌╌►` = not executed in this run). Nothing in 01–06 depends
  on them; they depend on 06 only if/when they are picked up later.

## Reality Check (verified live, 2026-08-17)

These facts materially de-risk the plan — recorded because several inputs assumed worse:

| Fact | Source | Consequence |
|---|---|---|
| Repo public, 20 MB, **0 child forks** | `gh repo view` | Self-service "Leave fork network" eligible; no Support ticket needed |
| **0 stars, 0 watchers, Issues DISABLED, 0 PRs, 0 releases** | `gh repo/pr/release list` | Detach destroys essentially nothing. Backup step is cheap insurance, not a rescue |
| **No GitHub Pages** on the repo | `gh api .../pages` → 404 | Rename cannot break Pages. Website is Cloudflare-only |
| **Zero published releases** | `gh release list` empty | No shipped binary has a stale update endpoint. The "cannot retro-patch shipped builds" risk is currently NIL — but only until Phase 07 publishes the first release |
| Labels `security`, `upstream-sync` already exist; `dependencies` missing | `gh label list` | Labels are repo-scoped → survive rename+detach. Only `dependencies` needs creating |
| `upstream-mirror` branch exists on origin | `gh api .../branches` | Upstream-sync bootstrap already done |
| `Assets.xcassets` is generically named | `ls Usage4Claude/Resources/` | Resolves researcher-02 uncertainty: no asset-catalog rename needed |
| `build/` is gitignored & untracked | `git ls-files build` → 0 | Stale `build/Usage4Claude-*` dirs are local-only; delete freely |

**Ordering consequence:** the only truly irreversible act is the fork detach, and its
blast radius here is near-zero. The genuinely dangerous step is the **`main` force-push**
in Phase 02.

## Branch Takeover Audit (pre-computed)

`main` has 4 commits not on `feat/rebrand-usagepacecc`; `git cherry` marks 3 as
unmatched by patch-id. Content audit performed during planning:

| Commit | Content | On rebrand branch? |
|---|---|---|
| `ca794fb` feat: GraphDisplayType setting | `GraphDisplayType` ×3 in `UserSettings.swift`, ×1 in `GeneralSettingsView.swift` | **YES** — identical counts both branches |
| `9ed35b9` feat: linear usage graph view | `Usage4Claude/Views/Components/LinearUsageGraphView.swift` | **YES** — present; rebrand version is a *superset* (adds `.codexPrimary`/`.codexSecondary`/`.codexExtraUsage` cases) |
| `cfa427a` refactor: inline percentage labels | — | **YES** — `git cherry` matches by patch-id (`-`) |
| `6e677c4` docs: project overview / serena memories | `.serena/` (6 files) | **NO** — only genuine `main`-only tracked content |

Full `git ls-tree` diff `main` → rebrand shows exactly two categories of main-only paths:
1. `.serena/` (6 files) — local agent tooling; currently present on disk **untracked**.
2. 11 `docs/images/*.png` — **not lost**, moved to `docs/images/old/` on the rebrand branch
   (`git diff --stat` shows them as `{ => old}` pure renames).

**Verdict: no feature or content loss from the takeover.** `.serena/` is **not** re-tracked
(decision V5) — it and `.codex/` go into `.gitignore` in Phase 02.

## Locked Constraints (do not violate)

- **MIT keeps — the string sweep MUST NOT touch these:**
  - `LICENSE`: `Copyright (c) 2025 f-is-h` line — never remove/alter. Yen NQ 2026 line stays alongside.
  - Per-file Swift headers: `//  Created by f-is-h on ...` and `//  Copyright © 2025 f-is-h. All rights reserved.` — keep verbatim in all 54 files.
    (The separate `//  Usage4Claude` **project-name** line in the same header block is NOT a copyright notice and IS in scope for renaming.)
  - `.strings` file headers (6 locales): `Created by f-is-h ... Copyright © 2025 f-is-h.`
  - `"settings.about.copyright" = "© 2025 f-is-h · © 2026 Yen NQ"` (6 locales)
  - `"settings.about.based_on" = "Based on Usage4Claude by f-is-h (MIT License)"` (6 locales) — the literal string `Usage4Claude` here is the *upstream product name*, keep it.
  - `README.md` attribution block (L26), copyright (L571), footer credit (L605); same blocks in the 5 translated READMEs. **The sponsor block is NOT on this list** — see "Sponsor links" below.
  - `CHANGELOG.md` historical release links → `f-is-h/Usage4Claude/releases/tag/v*` (19 links) — genuinely upstream's history, do not rewrite.
  - `AboutView.swift` L106/L108 attribution block (comment + `f-is-h/Usage4Claude` link behind `settings.about.based_on`) — keep verbatim.
- **Sponsor / funding links — IN SCOPE FOR REMOVAL (decision V1 overrides prior-plan D8):**
  D8 said "keep upstream funding links as credit". **V1 reverses that.** MIT requires
  attribution, not funding. Remove — do not repoint to the fork, just delete:
  - `AboutView.swift` L88 — `https://github.com/sponsors/f-is-h?frequency=one-time` button.
  - `README.md` L545 sponsor block (the `### ☕ Buy Me a Coffee` sub-section) and the
    equivalent block in the 5 translated READMEs under `docs/README.*.md`.
  - `.github/FUNDING.yml` — **verified present**, contains `github: f-is-h` + `ko_fi: 1atte`
    → delete the file.
  - **Decision V9 (user-confirmed 2026-08-17):** the same-category occurrences found while
    revising this plan are ALSO removed — the About-tab Ko-fi button (`AboutView.swift`
    L73–85), the Ko-fi anchors in all 6 READMEs, and the menu-bar **Coffee** + **GitHub
    Sponsor** items (`MenuBarUI.swift`, `MenuBarManager.swift`, `UsageDetailView.swift`).
    No replacement funding links are added. Their localization keys
    (`settings.about.coffee`, `settings.about.github_sponsor`, `menu.coffee`,
    `menu.github_sponsor`, 6 locales) are deleted with them — the one sanctioned exception
    to "never touch localization keys". Full table in Phase 04, "Sponsor removal — full
    surface". No `[USER] confirm` rows remain.
  Removing these does **not** touch any attribution: `settings.about.based_on`,
  `settings.about.copyright`, `LICENSE`, and the per-file headers all stay.
- **Three distinct tokens — never conflate:**
  | Token | Occurrences (excl. `plans/`, `build/`) | Action |
  |---|---:|---|
  | `f-is-h/Usage4Claude` | 196 | Split: **keep** where it is attribution/history/upstream-config; **repoint** where it routes users to upstream for *fork* support (README/CONTRIBUTING issues, discussions, clone, releases) |
  | `quangyendn/Usage4Claude` | 22 | **Always** → `quangyendn/UsagePaceCC` |
  | bare `Usage4Claude` (project/product/dir/scheme/prose) | rest of 666 | → `UsagePaceCC`, except the MIT keeps above |
- Keychain migration stays **decided against** (re-auth on bundle-id change). Do not reopen.
- Commit messages in English. **Never** add a `Co-Authored-By` trailer.
- GitHub ops via `gh` CLI only. Never GitHub MCP.
- Detach + rename + force-push are **user-executed, explicitly confirmed** steps.

## Acceptance Criteria (plan-level "done" == Phase 06 complete)

- [ ] Backup tag `backup/main-pre-takeover-<date>` + branch `backup/main-pre-takeover` exist on `origin`.
- [ ] `main` on `origin` == rebrand line; `git ls-tree` diff vs. old main shows only the audited `.serena/` delta.
- [ ] `UsagePaceCC.xcodeproj` + `UsagePaceCC/` source dir + 3 `UsagePaceCC*.xcscheme` exist; old paths gone.
- [ ] `git log --follow` on a moved Swift file traverses the rename (R100 rename commit).
- [ ] `scripts/build.sh` and `xcodebuild -scheme UsagePaceCC` both succeed from a clean DerivedData.
- [ ] `git grep -c "Usage4Claude"` outside `plans/`, `build/`, `docs/archive/` returns only entries on the MIT keep list (documented count, not zero).
- [ ] `git grep "quangyendn/Usage4Claude"` → **0 hits**.
- [ ] `git grep -n "sponsors/f-is-h"` → **0 hits**; `.github/FUNDING.yml` deleted.
- [ ] `.agents/skills/capture-usage4claude-screenshots/` deleted (not renamed).
- [ ] `.gitignore` contains `.serena/` and `.codex/`; neither is tracked.
- [ ] `git grep "usage4claude.pages.dev"` → **0 hits** (docs point at the not-yet-live
      `usagepacecc.pages.dev`; the Cloudflare rename that makes it resolve is Phase 08).
- [ ] Repo is no longer a fork (`gh repo view --json isFork` → `false`) and is named `UsagePaceCC`.
- [ ] Repo description + homepage updated; Issues **enabled** (currently disabled, but docs point users at fork issues).
- [ ] `https://github.com/quangyendn/UsagePaceCC` resolves; old path redirects.
- [ ] `.github/workflows/upstream-watch.yml` has no `schedule:` block, `workflow_dispatch` only; passes a manual dispatch run on the renamed repo.
- [ ] `docs/UPSTREAM_SYNC.md` rewritten for the occasional-manual model, names `quangyendn/UsagePaceCC`.
- [ ] Signing cleanup landed (Phase 06): no cert-import step in `.github/workflows/release.yml`,
      `CODESIGN_CERTIFICATE` + `CODESIGN_PASSWORD` secrets deleted, `docs/CODE_SIGNING.md`
      states plainly that builds are ad-hoc-signed and Gatekeeper will warn.

### Deferred acceptance criteria (Phases 07–08 — NOT required for plan-level "done")

These are carried forward to a later run. Do not treat them as blockers for this run.

- [ ] *(Phase 07)* `UsagePaceCC-CodeSigning` cert exists in login keychain; Xcode GUI build signs cleanly.
- [ ] *(Phase 07)* First release published under the new repo with `UsagePaceCC-v<version>.dmg`; UpdateChecker resolves it.
- [ ] *(Phase 08)* Cloudflare Pages project renamed so `usagepacecc.pages.dev` actually resolves.
- [ ] *(Phase 08)* `website/**` rebranded (only the `pages.dev` domain token is swept in Phase 04).

## Answers to Scout's Unresolved Questions

| # | Question | Answer |
|---|---|---|
| 1 | Delete stale `build/Usage4Claude-*` dirs? | **Yes**, Phase 03. `build/` is gitignored and untracked → zero git impact. |
| 2 | Website domain rename? | **Decided (V8)** — rename to `usagepacecc.pages.dev`. Phase 04 sweeps the docs token now; the Cloudflare-side rename is the deferred Phase 08. |
| 3 | Code-signing identity hardcoded elsewhere? | Already `UsagePaceCC-CodeSigning` in `project.pbxproj` (both configs) and documented in `docs/CODE_SIGNING.md`. The **cert itself does not exist yet** → deferred Phase 07. `build.sh` uses ad-hoc `-`, unaffected. The repo-side signing cleanup (CI step, secrets, docs) is **Phase 06** per V3. |
| 4 | Release asset naming? | Already correct: `release.yml` `PROJECT_NAME: UsagePaceCC` → `UsagePaceCC-v<ver>.dmg`. Only `SCHEME_NAME`/`XCODE_PROJECT` (L28/29) are stale → Phase 03. |
| 5 | Labels recreated after rename? | **No** — labels are repo-scoped, survive rename and detach. `security` + `upstream-sync` already exist; only `dependencies` is missing → create in Phase 06. |
| 6 | Upstream archived/deleted behavior? | `git fetch` on a deleted repo fails the workflow step → visible red run, not silent. With cron removed (Phase 06) this can only surface on a manual dispatch, which is the intended "thỉnh thoảng check" model. Acceptable. |
| 7 | `docs/CLOUDFLARE_DEPLOYMENT.md` hardcoded refs? | **Yes** — 3 × `Usage4Claude` incl. the `usage4claude.pages.dev` domain. The domain token is swept in **Phase 04** (V8); the Cloudflare project rename stays in Phase 08. |

## Open Questions

All but two are now closed by the Validation Summary below.

1. ~~**Website domain**~~ — **CLOSED by V8**: rename to `usagepacecc.pages.dev`. Docs swept in Phase 04, Cloudflare rename deferred to Phase 08.
2. ~~**`.serena/` re-tracking**~~ — **CLOSED by V5**: do **not** re-track. Add `.serena/` and `.codex/` to `.gitignore` in Phase 02. No user call remains.
3. ~~**`docs/archive/*`**~~ — **CLOSED by V6**: keep frozen, excluded from the sweep and from the sweep counts.
4. ~~**`.agents/skills/capture-usage4claude-screenshots/`**~~ — **CLOSED by V7**: the skill is no longer used → `rm -rf` it in Phase 04. Not renamed.
5. **Notarization / Apple Developer ID** — still open, but out of scope for this run: deferred with Phase 07. Builds stay ad-hoc-signed and Gatekeeper will warn (stated plainly in `docs/CODE_SIGNING.md` per Phase 06).
6. **Upstream cross-links post-detach** — still open. researcher-01 could not confirm whether links between the two repos still resolve after detach. Zero PRs/issues exist here, so impact is nil; verify opportunistically.

## Risks (plan-level)

| Risk | Severity | Mitigation |
|---|---|---|
| `main` force-push destroys unreviewed work | **High** | Phase 01 backup tag + backup branch pushed to origin *before* any rewrite; Phase 02 content audit (pre-computed above) |
| Detach is irreversible | Medium | Blocking confirm gate in Phase 01; verified blast radius ≈ 0 (no stars/issues/PRs/forks) |
| Xcode rename leaves a project that opens but won't build | Medium | Phase 03 splits pure `git mv` from content edits; clean-DerivedData build gate before commit is considered done |
| Sweep strips an MIT attribution | **High** | Explicit keep-list above; Phase 04 uses targeted token replacement, never blanket `sed s/Usage4Claude/UsagePaceCC/g`; post-sweep `git diff` review of `LICENSE`, `*.strings`, `AboutView.swift`, `README*.md`, `CHANGELOG.md` |
| Rename breaks Actions refs | Low | Only one workflow (`Build and Release`) is registered; no external composite-action references. Enumerated in Phase 05 |
| Future upstream cherry-picks conflict on renamed paths | Medium | Phase 03 pure-rename commit maximizes `-M` detection; Phase 06 documents `cherry-pick -X find-renames` in `UPSTREAM_SYNC.md` |

## Validation Summary

**Validated:** 2026-08-17
**Questions asked:** 8

### Confirmed Decisions

| # | Topic | User choice |
|---|---|---|
| V1 | About screen links | Keep MIT attribution; **remove upstream sponsor link** |
| V2 | Issues tab after rename | **Enable** Issues |
| V3 | Code-signing | **Clean up**: drop the no-op cert-import step from CI, delete `CODESIGN_*` secrets, correct `docs/CODE_SIGNING.md` to state builds are ad-hoc |
| V4 | Run scope | **Phases 01–06 only.** 07 (cert + release publish) and 08 (website) deferred |
| V5 | `.serena/` / `.codex/` | Do **not** track; add both to `.gitignore` |
| V6 | `docs/archive/` | **Freeze** — excluded from sweep |
| V7 | `.agents/skills/capture-usage4claude-screenshots/` | **Delete** the skill (no longer used) |
| V8 | Website domain | Rename to `usagepacecc.pages.dev`; sweep docs to the new domain now, Cloudflare rename in Phase 08 |

### Action Items (plan revisions required before execution)

- [x] **V1 overrides prior decision D8.** Remove `AboutView.swift` L88 sponsor URL and the
      matching sponsor blocks in `README.md` L545 + the 5 translated READMEs (and
      `.github/FUNDING.yml` if it points at f-is-h). **Still KEEP**: `AboutView.swift`
      L106/L108 attribution, `settings.about.based_on` and `settings.about.copyright`
      strings (6 locales), `LICENSE` dual copyright, per-file Swift/`.strings` headers,
      `CHANGELOG.md` historical links. Update the "Locked Constraints" keep-list accordingly.
- [x] **V7 changes Phase 04**: `rm -rf .agents/skills/capture-usage4claude-screenshots/`
      instead of renaming it. Removes 22 refs from the sweep surface.
- [x] **V3 + V4**: the CI/docs half of the signing cleanup (`release.yml` cert-import step,
      `docs/CODE_SIGNING.md`, secret deletion) is repo work, not manual cert work —
      pull it **into Phase 06**. Phase 07 keeps only cert creation + release publish, deferred.
- [x] **V5**: add `.serena/` and `.codex/` to `.gitignore` in Phase 02; do not re-track the
      6 `.serena/` files. Resolves Open Question 2.
- [x] **V8**: Phase 04 sweeps `usage4claude.pages.dev` → `usagepacecc.pages.dev` across
      `docs/CLOUDFLARE_DEPLOYMENT.md`, `docs/WEBSITE_GUIDE.md`, READMEs, `website/`.
      The actual Cloudflare Pages project rename stays in the deferred Phase 08 —
      **docs will point at a domain that does not resolve yet**; note this in Phase 04.
- [x] **V2**: enable Issues via `gh repo edit --enable-issues` in Phase 05 **before** the
      sweep's "report an issue" links go live. Already in Acceptance Criteria.
- [x] Update the Phases table: mark 07 and 08 **Deferred (out of this run's scope)**;
      plan-level "done" = Phase 06 complete. Acceptance criteria rows for cert/release
      move to the deferred set.

### Resolved Open Questions

Q1 → V8 (rename domain). Q2 → V5 (gitignore, don't track). Q3 → V6 (freeze).
Q4 → V7 (delete). Q5 (notarization) → still open, deferred with Phase 07.
Q6 (post-detach cross-links) → still open, impact nil.
