# Phase 03 — Xcode Project / Target / Scheme / Source-Dir Rename

## Context links

- Plan: [plan.md](./plan.md)
- Research: [researcher-02 — Xcode rename](./research/researcher-02-xcode-rename.md)
- Scout: [scout-01 §A, §E](./scout/scout-01-residual-branding-surface.md)
- Depends on: [Phase 02](./phase-02-branch-takeover.md)

## Overview

Rename `Usage4Claude.xcodeproj` → `UsagePaceCC.xcodeproj`, the target, the 3 shared
schemes, and the `Usage4Claude/` source directory. Split into a **pure `git mv` commit**
then a **content-edit commit**, so git records R100 renames and future upstream
cherry-picks stay tractable. Also updates the three build-critical refs
(`release.yml`, `build.sh`, `verify_version.sh`) because the build must stay green.

## Key Insights

- Rename surface is unusually small: **no test target, no `INFOPLIST_FILE`
  (`GENERATE_INFOPLIST_FILE = YES`), no entitlements file, no `TEST_HOST`/`BUNDLE_LOADER`.**
  Generic rename guides over-warn.
- **`PRODUCT_MODULE_NAME` is unset** → module name already resolves from
  `PRODUCT_NAME = UsagePaceCC`. Swift module identity does **not** change here.
  `@main`, `Bundle(for:)`, `NSClassFromString`, SwiftUI Previews are all unaffected.
- `Assets.xcassets` is generically named (verified) — no asset-catalog rename.
- Schemes are already half-renamed: `BuildableName` = `UsagePaceCC.app` but
  `BlueprintName` / `container:` still say `Usage4Claude`. Mismatch must be fixed or
  `xcodebuild -scheme` breaks.
- `release.yml` already has `PROJECT_NAME: UsagePaceCC` (artifacts are correct);
  only `SCHEME_NAME` (L28) and `XCODE_PROJECT` (L29) are stale.
- Do the rename with `git mv` from the CLI, **not** Xcode's Identity-inspector rename —
  the inspector produces a mixed rename+content commit, defeating R100 detection.
  Xcode is used afterwards only to verify it opens and builds.

## Requirements

- Commit 1: pure moves, zero content bytes changed → `git show --stat -M` shows R100.
- Commit 2: content edits in `project.pbxproj`, 3 `.xcscheme` files, `release.yml`,
  `build.sh`, `verify_version.sh`.
- Clean-DerivedData build passes via both `scripts/build.sh` and `xcodebuild`.
- Xcode.app opens the renamed project without a repair prompt.

## Architecture

```
Usage4Claude.xcodeproj/                       →  UsagePaceCC.xcodeproj/
  project.pbxproj                (14 refs)    →     4 real edits + comment refs
  xcshareddata/xcschemes/
    Usage4Claude.xcscheme        (9 refs)     →  UsagePaceCC.xcscheme
    Usage4Claude-Debug.xcscheme  (9 refs)     →  UsagePaceCC-Debug.xcscheme
    Usage4Claude-Release.xcscheme(9 refs)     →  UsagePaceCC-Release.xcscheme
Usage4Claude/                                 →  UsagePaceCC/            (54 .swift + Resources)
```

pbxproj keys to edit (line numbers from researcher-02, re-locate before editing):
| Key | Current | New |
|---|---|---|
| product ref `path` (~L10) | `Usage4Claude.app` | `UsagePaceCC.app` |
| main group `path` (~L16) | `Usage4Claude` | `UsagePaceCC` |
| target `name` (~L66) | `Usage4Claude` | `UsagePaceCC` |
| `PRODUCT_NAME` | `UsagePaceCC` | **unchanged** |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.quangyendn.usagepacecc` | **unchanged** |
| `CODE_SIGN_IDENTITY` | `UsagePaceCC-CodeSigning` | **unchanged** |

## Related code files

| Path | Action | Change |
|---|---|---|
| `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude.xcodeproj` | move | → `UsagePaceCC.xcodeproj` |
| `…/Usage4Claude.xcodeproj/project.pbxproj` | modify | 3 structural keys + comment strings |
| `…/xcshareddata/xcschemes/Usage4Claude.xcscheme` | move + modify | + `BlueprintName`, `container:` |
| `…/xcshareddata/xcschemes/Usage4Claude-Debug.xcscheme` | move + modify | same |
| `…/xcshareddata/xcschemes/Usage4Claude-Release.xcscheme` | move + modify | same |
| `/Users/yennq/Projects/opensrc/Usage4Claude/Usage4Claude/` | move | → `UsagePaceCC/` (source root) |
| `/Users/yennq/Projects/opensrc/Usage4Claude/.github/workflows/release.yml` | modify | L28 `SCHEME_NAME`, L29 `XCODE_PROJECT` |
| `/Users/yennq/Projects/opensrc/Usage4Claude/scripts/build.sh` | modify | L49 `SCHEME_NAME`, L50 `XCODEPROJ` |
| `/Users/yennq/Projects/opensrc/Usage4Claude/.github/scripts/verify_version.sh` | modify | L126/127 usage-example strings |
| `/Users/yennq/Projects/opensrc/Usage4Claude/build/Usage4Claude-Release-*` | delete | untracked, gitignored |

## Implementation Steps

1. Quit Xcode. Delete stale derived data and old local build dirs:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Usage4Claude-*
   rm -rf build/Usage4Claude-Release-2.6.0 build/Usage4Claude-Release-3.0.0
   ```
2. **Commit 1 — pure moves, no content edits:**
   ```bash
   git mv Usage4Claude.xcodeproj UsagePaceCC.xcodeproj
   git mv UsagePaceCC.xcodeproj/xcshareddata/xcschemes/Usage4Claude.xcscheme \
          UsagePaceCC.xcodeproj/xcshareddata/xcschemes/UsagePaceCC.xcscheme
   git mv UsagePaceCC.xcodeproj/xcshareddata/xcschemes/Usage4Claude-Debug.xcscheme \
          UsagePaceCC.xcodeproj/xcshareddata/xcschemes/UsagePaceCC-Debug.xcscheme
   git mv UsagePaceCC.xcodeproj/xcshareddata/xcschemes/Usage4Claude-Release.xcscheme \
          UsagePaceCC.xcodeproj/xcshareddata/xcschemes/UsagePaceCC-Release.xcscheme
   git mv Usage4Claude UsagePaceCC
   git status --porcelain            # expect only R entries, zero M
   git commit -m "refactor: rename Xcode project, schemes, and source directory to UsagePaceCC"
   git show --stat -M HEAD | grep -c 'R100\|=>'    # renames detected
   ```
   The project will NOT build between commit 1 and commit 2. That is expected.
3. **Commit 2 — content edits.** Targeted, not blanket:
   - `UsagePaceCC.xcodeproj/project.pbxproj`: replace the 3 structural keys above; then
     replace remaining `Usage4Claude` literals (they are comment strings like
     `/* Usage4Claude.app */`). Do NOT touch `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER`,
     `CODE_SIGN_IDENTITY`.
   - Each `.xcscheme`: `BlueprintName="Usage4Claude"` → `UsagePaceCC`;
     `container:Usage4Claude.xcodeproj` → `container:UsagePaceCC.xcodeproj`.
     `BuildableName` is already `UsagePaceCC.app`.
   - `.github/workflows/release.yml` L28/29 → `UsagePaceCC` / `UsagePaceCC.xcodeproj`.
   - `scripts/build.sh` L49/50 → `UsagePaceCC` / `${PROJECT_ROOT}/UsagePaceCC.xcodeproj`.
   - `.github/scripts/verify_version.sh` L126/127 usage examples → `UsagePaceCC.xcodeproj`.
   ```bash
   git commit -m "refactor: update project, scheme, and build references to UsagePaceCC"
   ```
4. Verify no stale refs remain in the Xcode/build surface:
   ```bash
   grep -rn "Usage4Claude" UsagePaceCC.xcodeproj scripts/build.sh \
        .github/workflows/release.yml .github/scripts/verify_version.sh   # → 0 hits
   ```
5. **[USER][MANUAL]** Open `UsagePaceCC.xcodeproj` in Xcode. Confirm: project navigator
   root reads `UsagePaceCC`, target reads `UsagePaceCC`, scheme selector lists the 3
   `UsagePaceCC*` schemes, no "project file cannot be opened / needs repair" dialog.
   Build (⌘B) and Run (⌘R); confirm the menu-bar item appears.
6. CLI build gate:
   ```bash
   xcodebuild -project UsagePaceCC.xcodeproj -scheme UsagePaceCC -configuration Release \
              -showBuildSettings > /dev/null && echo "scheme OK"
   ./scripts/build.sh
   ```
7. Confirm rename history survives: `git log --follow --oneline -- UsagePaceCC/Services/UpdateChecker.swift | wc -l`
   → same count as before the move (not 1).
8. Sanity-check the cherry-pick ergonomics note for Phase 06:
   `git cherry-pick -X find-renames <some upstream sha> --no-commit` on a scratch branch,
   then abort. Record whether renames auto-route to `UsagePaceCC/`.

## Todo list

- [ ] Quit Xcode; purge DerivedData + stale `build/Usage4Claude-*` dirs
- [ ] Commit 1: 5 × `git mv`, verify status shows only `R`
- [ ] Commit 2: pbxproj 3 keys + comments
- [ ] Commit 2: 3 × `.xcscheme` `BlueprintName` + `container:`
- [ ] Commit 2: `release.yml` L28/29
- [ ] Commit 2: `build.sh` L49/50
- [ ] Commit 2: `verify_version.sh` L126/127
- [ ] Grep Xcode/build surface → 0 hits
- [ ] **[USER][MANUAL]** Xcode opens, builds (⌘B), runs (⌘R), menu bar OK
- [ ] `xcodebuild -showBuildSettings` + `scripts/build.sh` pass
- [ ] `git log --follow` traverses the rename
- [ ] Dry-run `cherry-pick -X find-renames`, record result for Phase 06

## Success Criteria

- [ ] `UsagePaceCC.xcodeproj`, `UsagePaceCC/`, 3 × `UsagePaceCC*.xcscheme` exist; no `Usage4Claude*` build paths remain
- [ ] Commit 1 shows renames (R100) with zero content modification
- [ ] `grep -rn Usage4Claude` over the Xcode + build-script surface → 0
- [ ] `scripts/build.sh` produces `build/UsagePaceCC-Release-<ver>/UsagePaceCC.app`
- [ ] Xcode GUI build succeeds; app launches; menu bar renders
- [ ] `git log --follow` on a moved Swift file spans pre-rename history

## Verification commands

```bash
ls -d UsagePaceCC.xcodeproj UsagePaceCC
ls UsagePaceCC.xcodeproj/xcshareddata/xcschemes/
xcodebuild -project UsagePaceCC.xcodeproj -list
xcodebuild -project UsagePaceCC.xcodeproj -scheme UsagePaceCC -configuration Release -showBuildSettings \
  | grep -E 'PRODUCT_NAME|PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_MODULE_NAME'
# expect PRODUCT_NAME=UsagePaceCC, bundle id com.quangyendn.usagepacecc
./scripts/build.sh && ls build/UsagePaceCC-Release-*/
```

## Rollback

Both commits are local until pushed. `git reset --hard HEAD~2` restores the old layout
byte-for-byte (moves are tracked, no data outside git). If already pushed:
`git revert` both commits in reverse order — reverting a pure-rename commit is clean.

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| pbxproj hand-edit corrupts the project | High | Commit 1 is a safe restore point; step 5 opens Xcode before anything is pushed; keep edits to the 3 identified keys |
| Scheme `container:` left stale → `xcodebuild -scheme` fails | Medium | Step 4 grep + step 6 `-showBuildSettings` gate |
| CI breaks because `release.yml` scheme not updated in the same push | Medium | `release.yml`/`build.sh` edits are in commit 2, same push as the rename |
| Stale DerivedData produces phantom build errors | Low | Purged in step 1; re-purge if anything looks impossible |
| Upstream cherry-picks now conflict on paths | Medium | Pure-rename commit maximizes `-M`; step 8 dry-run; documented in Phase 06 |
| Accidentally changing `PRODUCT_NAME`/bundle id | High | Explicitly listed as unchanged; verified by `-showBuildSettings` in step 6 |

## Security Considerations

- Bundle id and code-sign identity are deliberately untouched — changing them here would
  silently re-trigger the Keychain/UserDefaults reset already accepted in the prior plan.
- The `UsagePaceCC-CodeSigning` identity referenced by `project.pbxproj` still does not
  exist in the keychain → Xcode GUI build may warn. The deferred Phase 07 creates it (not in
  this run). `scripts/build.sh`
  uses ad-hoc `-` and is unaffected.

## Next steps

→ [Phase 04 — Residual string sweep](./phase-04-string-sweep.md).
