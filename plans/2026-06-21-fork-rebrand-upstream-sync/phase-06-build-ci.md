# Phase 06 — Rebrand: Build / Release / CI Tooling

## Context links
- plan.md → D7 (code-sign identity)
- Scout §6, §9
- Phase 03 (scheme/product name), Phase 05 (DmgIcon)

## Overview
De-brand the build + release pipeline so artifacts are named/signed/published under
the fork. Depends on Phase 02 (name) and coordinates with Phase 03 (scheme name).

## Insights (verified file:line)
- `scripts/build.sh:3` comment header (Chinese, "Usage4Claude 构建打包脚本"); `:48` `PROJECT_NAME="Usage4Claude"`; `:49` `SCHEME_NAME="Usage4Claude"`; `:144` `DMG_NAME="${PROJECT_NAME}-v${VERSION}.dmg"`; `:331` `--volname "${PROJECT_NAME}"`. (build.sh currently has uncommitted changes — reconcile.)
- `.github/workflows/release.yml:27` `PROJECT_NAME: Usage4Claude`; `:28` `XCODE_PROJECT: Usage4Claude.xcodeproj`; `:219` echo "Building Usage4Claude...". Uses `secrets.CODESIGN_CERTIFICATE` / `CODESIGN_PASSWORD` (`:185-186`).
- `.github/RELEASE_TEMPLATE.md`, `.github/scripts/{verify_version,compare_versions,generate_release_notes,cleanup_failed_release}.sh` — scan for brand strings.
- `project.pbxproj` CODE_SIGN_IDENTITY `Usage4Claude-CodeSigning` (D7).
- `XCODE_PROJECT: Usage4Claude.xcodeproj` — the `.xcodeproj` filename: renaming it is invasive (breaks all paths). KEEP `Usage4Claude.xcodeproj` filename; only change product/scheme names. Document this.

## Requirements
- DMG named `UsagePaceCC-vX.Y.Z.dmg`, volume name `UsagePaceCC`.
- CI builds the (possibly renamed) scheme and publishes to `quangyendn/Usage4Claude` releases.
- Decide D7.

## Files
- `scripts/build.sh` (PROJECT_NAME, SCHEME_NAME, header, volname; reconcile existing edits)
- `.github/workflows/release.yml` (PROJECT_NAME, echo; keep XCODE_PROJECT filename)
- `.github/RELEASE_TEMPLATE.md`
- `.github/scripts/*.sh` (brand strings if any)
- `project.pbxproj` CODE_SIGN_IDENTITY (per D7)

## Steps
1. build.sh: `PROJECT_NAME` → `UsagePaceCC`; `SCHEME_NAME` → match the scheme decision from Phase 03 (if scheme renamed → `UsagePaceCC`; if kept → `Usage4Claude`). Update header comment + volname (derives from PROJECT_NAME). Reconcile the current uncommitted build.sh diff first (`git diff scripts/build.sh`).
2. release.yml: `PROJECT_NAME: UsagePaceCC`; keep `XCODE_PROJECT: Usage4Claude.xcodeproj`; update echo text. If scheme renamed, ensure `xcodebuild -scheme` arg matches.
3. RELEASE_TEMPLATE.md + `.github/scripts/*.sh`: replace brand strings; ensure release URLs/asset names use `UsagePaceCC`.
4. D7: if regenerating the self-signed cert, set CODE_SIGN_IDENTITY → `UsagePaceCC-CodeSigning` and update CI secret/cert; else leave (internal-only string, no user impact).
5. Local dry-run: `bash scripts/build.sh` → produces `UsagePaceCC-vX.Y.Z.dmg` with new volume name + new icon (Phase 05).
6. Verify CI: `xcodebuild -list` shows the scheme; confirm release.yml scheme arg resolves.

## Todos
- [x] build.sh rebranded + existing diff reconciled
- [x] release.yml PROJECT_NAME/echo updated; XCODE_PROJECT filename kept
- [x] RELEASE_TEMPLATE + .github/scripts de-branded
- [x] D7 decided/applied
- [x] local build.sh dry-run produces correctly named DMG
- [x] scheme arg resolves for CI

## Notes (2026-06-21)
- Local build.sh dry-run produced `UsagePaceCC-v3.0.0.dmg` with correct volume name and icon.
- D7 applied: CODE_SIGN_IDENTITY updated to `UsagePaceCC-CodeSigning` in `project.pbxproj` and `build.sh`; documented in `docs/CODE_SIGNING.md`.
- **MANUAL USER STEP — Keychain Access:** The self-signed certificate `UsagePaceCC-CodeSigning` must be created manually by the user via Keychain Access (or `security create-keychain` + Certificate Assistant). This cannot be automated in the repo.
- Current local builds and CI builds are **ad-hoc signed** (no Apple Developer ID). Gatekeeper will warn on first launch. Notarization is out of scope for this phase — flagged as a future follow-up.

## Success
- `bash scripts/build.sh` outputs `UsagePaceCC-vX.Y.Z.dmg`, volume + icon correct.
- `grep -rn "Usage4Claude" scripts/ .github/` → only `Usage4Claude.xcodeproj` filename refs + CHANGELOG history.

## Risks
- Renaming `.xcodeproj` filename would cascade-break CI/build paths — explicitly avoided.
- Scheme name mismatch between pbxproj and build.sh/CI → build fails. Keep all three in sync (Phase 03 ↔ here).
- CI signing secrets tied to old cert identity — if D7 = rename, update secrets or CI signing breaks. Rollback: revert CODE_SIGN_IDENTITY.

## Next
Phase 09 release dry-run uses this pipeline.
