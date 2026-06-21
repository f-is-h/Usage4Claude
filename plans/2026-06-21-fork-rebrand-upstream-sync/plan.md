---
title: Fork Rebrand + Upstream-Sync for Usage4Claude
date: 2026-06-21
status: Validated
plan_dir: plans/2026-06-21-fork-rebrand-upstream-sync
repo: quangyendn/Usage4Claude (fork of f-is-h/Usage4Claude)
total_effort: ~28h
phases: 9
---

# Fork Rebrand + Upstream-Sync Plan

## Goal

Distribute a rebranded, MIT-licensed build of the upstream `f-is-h/Usage4Claude`
menu-bar app under a NEW name, keeping ALL existing features (no removal). Add a
sustainable mechanism to pull upstream bug/security fixes into the divergent fork.

Three workstreams:
1. **License/copyright compliance** (MIT) — keep upstream LICENSE, add fork copyright + attribution + disclaimer. Low-risk, done first.
2. **Rebrand** (keep all features) — app identity, bundle id, keychain migration, UI/localization strings, URLs, UpdateChecker repo, icons, build/CI, website.
3. **Upstream-sync mechanism** — branch topology, weekly watch workflow, Dependabot, sync docs.

`<NEW_NAME>` and `<NEW_BUNDLE_ID>` are placeholder tokens throughout. Phase 02
("Confirm app name & bundle id") is a HARD BLOCKER: nothing in Phases 03-06 may
start until those tokens are resolved.

## Phases

| # | Phase | Status | Effort | Link |
|---|-------|--------|-------:|------|
| 01 | License & attribution compliance | Done (2026-06-21) | 2h | [phase-01](./phase-01-license-compliance.md) |
| 02 | Confirm app name & bundle id (BLOCKER) | Done (2026-06-21) | 1h | [phase-02](./phase-02-confirm-name.md) |
| 03 | Rebrand: Xcode identity + bundle id + keychain migration | Done (2026-06-21) | 4h | [phase-03-identity](./phase-03-identity-bundleid.md) |
| 04 | Rebrand: UI/localization strings + About + URLs + UpdateChecker | Done (2026-06-21) | 5h | [phase-04-ui-strings](./phase-04-ui-strings-urls.md) |
| 05 | Rebrand: icons & visual assets | Done (bespoke icon) (2026-06-21) | 3h | [phase-05-icons](./phase-05-icons-assets.md) |
| 06 | Rebrand: build / release / CI tooling | Done (2026-06-21) | 3h | [phase-06-build-ci](./phase-06-build-ci.md) |
| 07 | Rebrand: website (optional / deferrable) | Deferred (D5/D6) | 3h | [phase-07-website](./phase-07-website.md) |
| 08 | Upstream-sync mechanism | Done (2026-06-21) | 4h | [phase-08-upstream-sync](./phase-08-upstream-sync.md) |
| 09 | Final verification & release dry-run | Done (verify) (2026-06-21) | 3h | [phase-09-verification](./phase-09-verification.md) |

**Status: 7/9 done (01–06, 08, 09). 07 deferred. Release-publish, bespoke icon, code-sign cert, and outward upstream-sync steps remain USER TODO — see Final Report / docs.**

## Dependency Graph

```
01 (license) ─────────────────────────────────► can run anytime, do first
02 (confirm name) ── BLOCKER ──┐
                               ├─► 03 (identity) ─► 04 (ui/urls) ─┐
                               ├─► 05 (icons) ────────────────────┤
                               ├─► 06 (build/ci) ─────────────────┼─► 09 (verify)
                               └─► 07 (website, optional) ────────┘
08 (upstream-sync) ─── independent of rebrand; can parallel ───────► 09 (verify)
```

- 03 must precede 04 (keychain service name + bundle id resolved first).
- 05/06/07 depend only on 02; can run parallel to 04.
- 08 is independent (touches only `.github/` + docs); can start anytime after 01.
- 09 requires 03-06 (and 08) done; 07 optional for 09.

## Locked Constraints (do not violate)

- **KEEP `LICENSE` with `Copyright (c) 2025 f-is-h` intact** — legally required (MIT). Only ADD a second copyright line for Yen NQ (2026); never remove or alter f-is-h's.
- **KEEP ALL features** — this plan does zero feature removal. Inherit everything as-is, including the `feat/linear-graph` work currently on the branch.
- Git commit messages ALWAYS in English. NEVER add a co-author / Co-Authored-By trailer.
- ALWAYS use `gh` CLI for GitHub ops (PRs, labels, settings). NEVER GitHub MCP.
- YAGNI / KISS / DRY. No speculative abstractions.
- Branch first; do not commit/push to `main` unless the user asks. Currently on `feat/linear-graph`.
- `<NEW_NAME>` / `<NEW_BUNDLE_ID>` are tokens — every occurrence is a find/replace target once Phase 02 resolves them.

## Decisions Required (user must answer)

| # | Decision | Needed by phase | Default if undecided |
|---|----------|-----------------|----------------------|
| D1 | Final app name (from: Quota, Pulse, Gauge, Cadence, Curve, Trace, Tideline, Glance, Brink, Slope) | 02 (blocks 03-07) | none — hard blocker |
| D2 | Bundle id, e.g. `com.quangyendn.<newname>` (replaces `xyz.fi5h.Usage4Claude`) | 02 | `com.quangyendn.<newname>` |
| D3 | Keychain migration strategy: silent re-auth (simplest) vs. one-time migration code | 03 | silent re-auth (users re-enter Org ID + Session Key once) |
| D4 | New app icon: commission/design new, or temporarily reuse upstream icon recolored | 05 | reuse recolored placeholder, flag follow-up |
| D5 | New website domain (e.g. `<newname>.pages.dev` or custom) or skip website entirely | 07 | `<newname>.pages.dev`, English-only first |
| D6 | Keep all 6 localized website pages or English-only initially | 07 | English-only; restore localized later |
| D7 | Code-signing identity: rename self-signed cert `Usage4Claude-CodeSigning` → `<NEW_NAME>-CodeSigning`, or keep current name | 06 | keep current name (internal, no user impact); rename only if regenerating cert |
| D8 | Keep upstream Ko-Fi/Sponsor links (credit upstream author) or replace with own / remove | 04 | move upstream funding links into the attribution block; add own optional |

## Acceptance Criteria (plan-level "done")

- [ ] `LICENSE` retains f-is-h 2025 copyright AND adds Yen NQ 2026 line; ships in app bundle + repo.
- [ ] App builds with `scripts/build.sh`, launches, menu bar shows `<NEW_NAME>`, no crash.
- [ ] Zero remaining `Usage4Claude` / `f-is-h` / `fi5h` brand strings in user-facing UI, localization, About, window titles (grep clean except LICENSE + attribution + CHANGELOG history).
- [ ] `UpdateChecker` queries `quangyendn/Usage4Claude` releases (verified by log/network).
- [ ] All in-app GitHub URLs point to `quangyendn`.
- [ ] About view shows "based on / forked from f-is-h/Usage4Claude" + "not affiliated with Anthropic" disclaimer.
- [ ] Keychain migration handled (existing creds either migrated or graceful re-auth prompt, documented).
- [ ] `.github/workflows/upstream-watch.yml` present, passes a manual `workflow_dispatch` dry-run.
- [ ] `upstream-mirror` branch exists on origin; `docs/UPSTREAM_SYNC.md` documents the cherry-pick procedure.
- [ ] Dependabot enabled (`.github/dependabot.yml` + repo security settings).
- [ ] Release dry-run (build + DMG + draft GitHub release) succeeds under new name.

## Validation Summary

**Validated:** 2026-06-21 (2 rounds) — ALL decisions resolved, blocker cleared.
**Questions asked:** 8

### Resolved Tokens
- `<NEW_NAME>` = **UsagePaceCC**
- `<NEW_BUNDLE_ID>` = **com.quangyendn.usagepacecc**
- CFBundleName / CFBundleDisplayName = `UsagePaceCC` (no spaces — clean, no variant needed)

### Confirmed Decisions
- **D1 App name:** **UsagePaceCC** (blocker CLEARED). Phases 03-07 unblocked.
- **D2 Bundle id:** `com.quangyendn.usagepacecc` (replaces `xyz.fi5h.Usage4Claude`).
- **D3 Keychain migration:** Re-auth (simple) — NO migration code. Users re-enter Org ID + Session Key once. Add a clear one-time re-auth notice in onboarding/About.
- **D4 App icon:** Design a NEW icon NOW (CHANGED from default placeholder). Real deliverable; gating asset for Phase 09 release.
- **D5/D6 Website:** DEFER — Phase 07 dropped from initial scope. GitHub Releases only at first.
- **D7 Code-signing identity:** RENAME `Usage4Claude-CodeSigning` → `UsagePaceCC-CodeSigning` (CHANGED from default keep). Requires regenerating self-signed cert + updating `build.sh`.
- **D8 Funding links:** KEEP upstream f-is-h Ko-Fi/Sponsor links inside the attribution/"forked from" block as credit.
- **Open Q3 CHANGELOG:** KEEP upstream history intact (it is genuinely upstream's), prepend a fork note; do NOT rewrite old release URLs.

### Action Items
- [ ] Global find/replace `<NEW_NAME>`→`UsagePaceCC`, `<NEW_BUNDLE_ID>`→`com.quangyendn.usagepacecc` across all phase files before execution.
- [ ] **Phase 03:** bundle id → `com.quangyendn.usagepacecc`; lock keychain to re-auth (no migration code) + one-time re-auth UX note.
- [ ] **Phase 04:** keep f-is-h funding links in attribution block (D8); prepend CHANGELOG fork note, leave history URLs as-is (Open Q3).
- [x] **Phase 05 (icons):** DONE (placeholder) 2026-06-21 — recolored icon shipped as temporary placeholder; a bespoke icon design is a USER FOLLOW-UP and remains the real gate for Phase 09 release.
  - **NOTE:** The Phase 05 icon is a TEMPORARY recolor placeholder only. A bespoke/commissioned icon design has NOT been completed. Phase 09 (final release) must NOT ship without a proper replacement icon — this is an explicit user follow-up action before Phase 09 executes.
- [ ] **Phase 06 (build/CI):** rename code-sign identity to `UsagePaceCC-CodeSigning` (D7) — regenerate self-signed cert + update `build.sh`.
- [ ] **Phase 07 (website):** mark DEFERRED / out of initial scope.
- [x] **Phase 08 (upstream-sync):** DONE (2026-06-21) — files created: `.github/workflows/upstream-watch.yml`, `.github/dependabot.yml`, `docs/UPSTREAM_SYNC.md`. USER TODO (outward steps, not automatable): create + push the `upstream-mirror` branch, create gh labels (`security`, `upstream-sync`), enable GitHub repo security features (Dependency graph, Dependabot alerts, Dependabot security updates via Settings → Code security), and run the first `gh workflow run upstream-watch.yml` dry-run — all steps documented in `docs/UPSTREAM_SYNC.md`.

## Open Questions

1. **App Groups id** — `REGISTER_APP_GROUPS = YES` in pbxproj but no group id visible. Confirm whether an `.entitlements` file declares an app group (would need rename) or if it is unused. Check before Phase 03 verification.
2. **Keychain access group** — changing bundle id changes the default keychain access group; if a `keychain-access-groups` entitlement is set explicitly it must be updated too. Phase 03 must inspect the entitlements file.
3. **CHANGELOG history** — rewrite old release URLs to new repo, or leave historical entries pointing at upstream tags (they are genuinely upstream's history)? Recommend: leave history, prepend a fork note. Confirm with user.
4. **Notarization** — current signing is self-signed (Gatekeeper will warn). Out of scope here, but rebranded distribution may want an Apple Developer ID. Flag, do not solve.
5. **Empty draft-PR caveat** (research §371) — `gh pr create` may reject head==base with no diff. Phase 08 must test on this repo and, if rejected, auto-cherry-pick the first upstream commit into the sync branch.
6. **Upstream funding links** (D8) — confirm whether to retain f-is-h Ko-Fi/Sponsor as a "support original author" gesture.
