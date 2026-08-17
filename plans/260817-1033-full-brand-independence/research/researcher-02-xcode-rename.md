# Research Report: Xcode Rename (project/target/scheme/source dir) Usage4Claude → UsagePaceCC

## Summary
Repo state verified: single target, `GENERATE_INFOPLIST_FILE = YES` (no `INFOPLIST_FILE` key), no `TEST_HOST`/`BUNDLE_LOADER` (no test target), no `CODE_SIGN_ENTITLEMENTS` currently set. `PRODUCT_NAME` and `PRODUCT_BUNDLE_IDENTIFIER` are already `UsagePaceCC` / `com.quangyendn.usagepacecc`. Remaining rename surface is purely structural: project name (`Usage4Claude.xcodeproj`), target name, scheme names/files, group `path`/`name` = `Usage4Claude`, and the `Usage4Claude/` source folder. Xcode's built-in rename (select project in Navigator → Identity inspector → type new name) handles project+primary target+group+folder-on-disk together in modern Xcode, but scheme files and `.xcuserdata` are NOT touched and must be handled separately. `PRODUCT_MODULE_NAME` is currently unset (defaults to `PRODUCT_NAME`, already `UsagePaceCC`), so Swift symbol/module identity is *not* changing in this step — de-risks storyboard/`NSClassFromString`/`Bundle(for:)` concerns significantly since module name stays the same.

## Key Findings

1. **project.pbxproj occurrences found** (grep, `Usage4Claude.xcodeproj/project.pbxproj`):
   - Line 10: `8873E4CF... /* Usage4Claude.app */ = {... path = Usage4Claude.app; ...}` — build product filename.
   - Line 16: `path = Usage4Claude;` — main group path (source folder reference).
   - Line 66: `name = Usage4Claude;` — target name.
   - `PRODUCT_NAME = UsagePaceCC;` already set at both Debug/Release config lines (289/290, 339/340) — no change needed here.
   - No `INFOPLIST_FILE`, `TEST_HOST`, `BUNDLE_LOADER`, or `CODE_SIGN_ENTITLEMENTS` keys present — fewer manual edits than a typical rename guide assumes.

2. **Scheme files found** (all reference old name, in `xcshareddata` — these ARE tracked in git and shared with the team):
   - `Usage4Claude.xcodeproj/xcshareddata/xcschemes/Usage4Claude.xcscheme`
   - `Usage4Claude.xcodeproj/xcshareddata/xcschemes/Usage4Claude-Debug.xcscheme`
   - `Usage4Claude.xcodeproj/xcshareddata/xcschemes/Usage4Claude-Release.xcscheme`
   - Xcode's "Manage Schemes" rename UI updates the `.xcscheme` filename and its internal `BuildableName`/`BlueprintName` attributes, but does not rewrite `container:` path components inside `BuildableReference` if the `.xcodeproj` itself is also being renamed in the same pass — verify manually after rename. [createwithswift.com](https://www.createwithswift.com/safely-renaming-your-xcode-project/)

3. **Recommended procedure (Xcode 16/26 era)**, per multiple guides ([createwithswift.com](https://www.createwithswift.com/safely-renaming-your-xcode-project/), [gist.github.com/jyshnkr](https://gist.github.com/jyshnkr/23cf9c470e129f417940f32924cfb481), [delasign.com](https://www.delasign.com/blog/xcode-rename-project/), [johncodeos.com](https://johncodeos.com/how-to-change-your-project-name-bundle-id-in-xcode/)):
   - **Do NOT rename the `.xcodeproj` package or folder on disk manually first** — Xcode's built-in rename (click project root in Navigator → Identity & Type inspector, edit Name field, Enter) is the supported path; it prompts "Rename project content" and updates the project name, the primary target's `PRODUCT_NAME`-independent target name, the main group, and (in recent Xcode) offers to rename the source folder too. This is the mechanism Apple intends and is the safest starting point.
   - This built-in rename does **NOT** reliably rename: scheme names/files (must use Product → Scheme → Manage Schemes → double-click to rename, separately for each of the 3 schemes here), `.xcuserdata` (user-specific, gitignored, safe to ignore/delete), any hardcoded strings in scripts (build phases, fastlane, CI workflows, README).
   - After Xcode's rename, close Xcode, open `project.pbxproj` in a text editor (`Show Package Contents` on the `.xcodeproj`), and grep/replace any leftover literal `Usage4Claude` strings the UI rename missed (build product filename references, comments `/* Usage4Claude.app */`, any Info.plist-generation-adjacent keys). Since `GENERATE_INFOPLIST_FILE = YES`, no `Info.plist` file path to fix.
   - No entitlements file currently referenced — if one is added later, its path key (`CODE_SIGN_ENTITLEMENTS`) must be updated in lockstep with folder rename.

## Analysis

**Module name / runtime-identity risk is low here** because `PRODUCT_MODULE_NAME` was never customized and currently resolves from `PRODUCT_NAME = UsagePaceCC` — i.e., the Swift module name is *already* `UsagePaceCC` even under the old project/folder name. Renaming project/target/folder does not change `PRODUCT_MODULE_NAME` again, so:
- `@main` entry point: unaffected (attribute-based, not name-dependent).
- `Bundle(for:)`, `NSClassFromString("ModuleName.ClassName")`: unaffected — module name already `UsagePaceCC`.
- Storyboard/XIB module references: this is a pure-SwiftUI app (per project type), so likely N/A — confirm no `.storyboard`/`.xib` files exist; if `Bundle.main` lookups by app name string exist in code (rare), grep for literal `"Usage4Claude"` strings.
- SwiftUI Previews: previews resolve via the module the file compiles into; unaffected by folder/project rename since module name is stable. Preview provider cache in DerivedData can go stale — clean DerivedData after rename regardless (see below).
- `#if canImport(ModuleName)`: only relevant if code imports the app's own module by name (unusual for an app target) — grep to confirm none exist; if none, no risk.
- Localization `.strings` tables and asset catalog names are referenced by string literal, not by project/module name — unaffected by this rename unless the `.xcassets` file itself is literally named `Usage4Claude.xcassets` (check; rename the file too if so, via `git mv`).

**Runtime-identity risks unrelated to folder rename** — flagged because bundle ID was *already* changed to `com.quangyendn.usagepacecc` in a prior step (per MEMORY.md), separate from this folder/project rename:
- Keychain items keyed by old bundle ID (`kSecAttrService`/access-group tied to bundle id) will not be found under the new ID — any stored credentials need migration or user re-auth.
- `UserDefaults.standard` is keyed by bundle id (the app's own container) — a bundle-id change means the app reads a *fresh* empty defaults domain; old settings under `com.<old>.usage4claude`-style ID are orphaned. If not already handled, needs an explicit one-time migration read from old domain.
- `SMAppService`/login-item registration and any LaunchAgent plist must reference the new bundle id — a stale LaunchAgent plist pointing at the old bundle id will fail silently or launch a ghost registration. Existing users upgrading from an old-bundle-id build will have TWO login-item registrations until the old one is deregistered.
- Sandbox container path (`~/Library/Containers/<bundle-id>/`) changes with bundle id — any user data stored under the sandbox container from the old bundle id is orphaned unless explicitly migrated.
- Notification authorization is per-bundle-id — users will be re-prompted for notification permission after a bundle-id change (already true from the prior bundle-id-change step, not newly introduced by this folder rename).
- Code signing: a Developer ID / provisioning profile tied to the old bundle id needs a matching profile for the new one; for Developer ID (non-App-Store) direct distribution this is usually automatic via Xcode-managed signing, but verify signing identity resolves cleanly post-rename.
- These bundle-id-migration risks are **pre-existing** (bundle id already changed in an earlier phase per MEMORY.md) — this Xcode-rename step does not add new ones, but is a good place to flag/verify they were addressed, since the two changes (bundle id + project rename) compound the "is this the same app to macOS" question for existing installed users.

**Git-history / merge-conflict-minimization strategy**, since this repo cherry-picks from an upstream fork:
- Perform the rename as a **pure rename commit** with zero content changes where possible: `git mv Usage4Claude Usage4Claude.xcodeproj` → wait, correct form: `git mv Usage4Claude.xcodeproj UsagePaceCC.xcodeproj` and `git mv Usage4Claude UsagePaceCC` (source folder) as a standalone commit, *before* editing any file contents (`.pbxproj`, `.xcscheme` internals). Git's rename detection (`git diff -M`, default ~50% similarity) works on content similarity, not path — a `git mv` alone (no content change) will show as 100% rename with zero diff noise, maximizing detectability.
- Do content edits (`project.pbxproj` string replacements, scheme XML renames) in a **separate follow-up commit** after the pure move, so the rename commit stays a clean R100 in `git log --follow`/`git blame` and cherry-picks from upstream on the old paths can still be manually re-pathed with `git apply --directory` or `-p` adjustments if needed.
- Rename scheme files with `git mv` too (`git mv Usage4Claude.xcscheme UsagePaceCC.xcscheme` etc.) rather than delete+recreate, to preserve history linkage.
- `.xcuserdata` and other user-specific/gitignored paths need no git treatment — confirm they're excluded via `.gitignore` (standard Xcode gitignore templates exclude `xcuserdata/`, `DerivedData/`).
- After rename commit(s), future `git cherry-pick` from upstream (which still uses old paths `Usage4Claude/...`) will conflict on path since the file moved — expect to need `git cherry-pick -X find-renames` or manual conflict resolution routing upstream's edits to the new path each time; document this in the upstream-sync notes (per existing MEMORY.md plan reference).

## Recommendations
1. Close Xcode and any running DerivedData watchers before starting; delete stale DerivedData for this project after rename (`~/Library/Developer/Xcode/DerivedData/Usage4Claude-*`) to avoid stale module-cache/index confusing SwiftUI Previews and build.
2. Sequence: (a) `git mv` project folder/xcodeproj/source-dir/scheme-files in one commit with no content edits, verify `git status` shows renames not add+delete, (b) open in Xcode, use Identity inspector to confirm/re-sync project display name, (c) Manage Schemes to rename the 3 schemes (or confirm the git-mv'd `.xcscheme` filenames already match if Xcode auto-picks them up), (d) manually diff/grep `project.pbxproj` for any remaining literal `Usage4Claude` strings and fix, (e) commit content-only changes separately, (f) build clean, verify app launches, verify login-item/notification/sandbox behavior for both fresh install and upgrade-from-old-bundle-id scenarios.
3. Grep entire source tree for literal string `"Usage4Claude"` (not just project files) to catch any UI-facing strings, `.xcassets` catalog name, or `CFBundleName` overrides missed by `GENERATE_INFOPLIST_FILE` defaults.
4. Since bundle id already changed separately, verify (or explicitly scope out of this task) whether old-bundle-id → new-bundle-id data migration for UserDefaults/Keychain/sandbox container has already been addressed elsewhere in the brand-independence plan — flag to architect if not yet covered, this is a correctness gap, not a naming cosmetic.

## Sources
- [Safely Renaming Your Xcode Project — createwithswift.com](https://www.createwithswift.com/safely-renaming-your-xcode-project/)
- [How to Rename the Xcode Project (Including all files & folders) — gist.github.com/jyshnkr](https://gist.github.com/jyshnkr/23cf9c470e129f417940f32924cfb481)
- [How to rename a project in Xcode — delasign.com](https://www.delasign.com/blog/xcode-rename-project/)
- [How to change your Project Name & Bundle ID in Xcode — johncodeos.com](https://johncodeos.com/how-to-change-your-project-name-bundle-id-in-xcode/)
- [Renaming The Project Source Folder In Xcode — Medium (Joe Rocca)](https://medium.com/@joe.rocca/renaming-the-project-source-folder-in-xcode-1cfdeeb91d0e)
- [If Product Module Name is set, swiftClassTypeFromString() fails — EVReflection issue #65](https://github.com/evermeer/EVReflection/issues/65)
- [Changing the Product (Module) Name of a released app — Apple Developer Forums](https://developer.apple.com/forums/thread/68306)
- Direct repo inspection: `Usage4Claude.xcodeproj/project.pbxproj` (grep for PRODUCT_NAME, PRODUCT_MODULE_NAME, PRODUCT_BUNDLE_IDENTIFIER, INFOPLIST_FILE, CODE_SIGN_ENTITLEMENTS, TEST_HOST, BUNDLE_LOADER, path/name = Usage4Claude), scheme file glob.

## Uncertainties
- Did not verify Xcode version installed on the dev machine (16 vs 26) or confirm current Xcode's exact rename-dialog wording/behavior (e.g., whether it now offers folder rename by default) — verify interactively before executing, behavior has changed across Xcode versions.
- Did not inspect whether `.xcassets` catalog or other resource files are literally named `Usage4Claude.*` (not covered by the pbxproj grep scope in this pass) — check separately.
- Did not verify whether any Keychain/UserDefaults/SMAppService migration code already exists in the Swift source for the prior bundle-id change — recommend a follow-up grep/read of app source (e.g., `AppDelegate`/`App` entry file) before treating this as resolved.
- Did not test actual `git cherry-pick -X find-renames` behavior against the specific upstream fork's commit history — recommend a dry-run cherry-pick after the rename commit to validate conflict ergonomics.
