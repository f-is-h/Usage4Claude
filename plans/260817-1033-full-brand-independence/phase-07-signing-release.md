# Phase 07 — Code-Signing Cert + First Release (Manual User Steps)

> **Status: DEFERRED — out of scope for this run (decision V4).**
> This run executes Phases 01–06 only; the plan is "done" at Phase 06. Nothing here is
> executed now. The repo-side signing cleanup that used to live in this phase (CI
> cert-import removal, `CODESIGN_*` secret deletion, `docs/CODE_SIGNING.md` correction)
> **moved to [Phase 06](./phase-06-upstream-decoupling.md)** per V3 and is done there.
> What remains below is only the two genuinely manual acts: creating the certificate and
> publishing the first release.

## Context links

- Plan: [plan.md](./plan.md)
- Existing docs: `/Users/yennq/Projects/opensrc/Usage4Claude/docs/CODE_SIGNING.md`,
  `/Users/yennq/Projects/opensrc/Usage4Claude/docs/DAILY_RELEASE_WORKFLOW.md`
- Prior plan: `plans/2026-06-21-fork-rebrand-upstream-sync/plan.md` D7 + Phase 09 USER TODOs
- Depends on: [Phase 05](./phase-05-github-identity.md), [Phase 06](./phase-06-upstream-decoupling.md)

## Overview

Close the two outstanding USER TODOs from the prior plan: create the
`UsagePaceCC-CodeSigning` self-signed certificate, and publish the first release under the
new repo identity. **Mostly manual — Keychain Access has no scriptable path, and publishing
is a deliberate act.**

## Key Insights

- `project.pbxproj` already references `CODE_SIGN_IDENTITY = "UsagePaceCC-CodeSigning"`
  for both Debug and Release, but **the certificate does not exist yet**. Xcode GUI builds
  therefore fail or fall back; `scripts/build.sh` is unaffected (it forces ad-hoc `-`).
- `release.yml` already emits `UsagePaceCC-v<version>.dmg` (`PROJECT_NAME: UsagePaceCC`) —
  no artifact-naming work remains after Phase 03 fixed `SCHEME_NAME`/`XCODE_PROJECT`.
- **The CI cert-import question is already answered and already implemented.** V3 chose
  "remove"; Phase 06 deleted the step, deleted the `CODESIGN_*` secrets, and corrected
  `docs/CODE_SIGNING.md`. Do not reopen it here, and do not expect those secrets to exist.
  CI ships ad-hoc-signed artifacts by design.
- **This is the moment the "shipped binaries can't be retro-patched" risk becomes real.**
  Before publishing, verify `UpdateChecker` points at `quangyendn/UsagePaceCC` (Phase 04
  Pass C). After the first release exists, that endpoint is frozen into every copy.
- Signing stays self-signed → Gatekeeper will warn. Release notes must tell users to
  right-click → Open. Notarization is out of scope.

## Requirements

- `UsagePaceCC-CodeSigning` present in the login keychain; Xcode GUI build signs cleanly.
- A release published from the renamed repo, with a working DMG + SHA256.
- `UpdateChecker` finds that release at runtime.

*(CI cert-import + `docs/CODE_SIGNING.md` accuracy are **Phase 06** requirements, not
this phase's — already satisfied before this phase is ever picked up.)*

## Architecture

```
Keychain Access → Certificate Assistant → Create a Certificate
  Name: UsagePaceCC-CodeSigning
  Identity Type: Self Signed Root
  Certificate Type: Code Signing
        │
        └─► Xcode.app GUI build ONLY  (CODE_SIGN_IDENTITY from pbxproj)
              CI is unaffected: scripts/build.sh forces ad-hoc "-" and the
              cert-import step was removed in Phase 06. No .p12, no secrets.

release: tag vX.Y.Z ──► .github/workflows/release.yml
   validate → build (scripts/build.sh) → UsagePaceCC-v<ver>.dmg + .sha256 → GitHub Release
        │
        └─► UpdateChecker GET api.github.com/repos/quangyendn/UsagePaceCC/releases/latest
```

## Related code files

| Path | Action | Note |
|---|---|---|
| `/Users/yennq/Projects/opensrc/Usage4Claude/docs/CODE_SIGNING.md` | **no change** | already corrected in Phase 06 |
| `/Users/yennq/Projects/opensrc/Usage4Claude/.github/workflows/release.yml` | **no change** | cert-import step already removed in Phase 06 |
| `/Users/yennq/Projects/opensrc/Usage4Claude/scripts/build.sh` | **no change** | keeps forcing ad-hoc `-` — decided (V3) |
| `/Users/yennq/Projects/opensrc/Usage4Claude/CHANGELOG.md` | modify | new version entry (fork's own release, link to the new repo) |
| `/Users/yennq/Projects/opensrc/Usage4Claude/UsagePaceCC.xcodeproj/project.pbxproj` | verify only | `MARKETING_VERSION` matches the CHANGELOG |

## Implementation Steps

1. **[USER][MANUAL]** Create the certificate — Keychain Access → Certificate Assistant →
   Create a Certificate:
   - Name `UsagePaceCC-CodeSigning`, Identity Type **Self Signed Root**,
     Certificate Type **Code Signing** → Create → Done.
   Verify: `security find-identity -v -p codesigning | grep UsagePaceCC-CodeSigning`
2. **[USER][MANUAL]** Open `UsagePaceCC.xcodeproj`, build Release in Xcode (⌘B).
   Confirm no "code signing identity not found" error. Verify the product:
   ```bash
   codesign -dvv ~/Library/Developer/Xcode/DerivedData/UsagePaceCC-*/Build/Products/Release/UsagePaceCC.app 2>&1 | head
   ```
3. Confirm the Phase 06 signing cleanup is still in place (no work, just a check):
   ```bash
   git grep -n "CODESIGN_" -- .github/ scripts/   # → 0
   grep -in "ad-hoc\|gatekeeper" docs/CODE_SIGNING.md
   ```
   If any of it has regressed, fix it there — do not re-litigate the decision here.
4. *(removed — `docs/CODE_SIGNING.md` was corrected in Phase 06)*
5. Pre-release verification (the point of no return for the update endpoint):
   ```bash
   grep -n 'repoOwner\|repoName' UsagePaceCC/Services/UpdateChecker.swift
   # expect quangyendn / UsagePaceCC
   ./scripts/build.sh
   .github/scripts/verify_version.sh verify CHANGELOG.md UsagePaceCC.xcodeproj
   ```
6. Prepare the release: add a CHANGELOG entry for the fork's first release under the new
   identity. Note the rebrand, the bundle-id change, and the **one-time re-auth**
   (users must re-enter Org ID + Session Key — Keychain migration was deliberately skipped).
7. **[USER]** Dry-run first: trigger `release.yml` in whatever draft/test mode it supports
   (or push a `test-release`-style tag — that branch already exists) and confirm the
   artifacts:
   ```bash
   gh run list --workflow=release.yml --repo quangyendn/UsagePaceCC --limit 1
   gh run view <id> --repo quangyendn/UsagePaceCC --log | tail -40
   ```
   Expect `UsagePaceCC-v<ver>.dmg` + `.dmg.sha256`.
8. **[USER][MANUAL]** Publish the real release (tag → workflow → review the draft →
   publish). Release notes must include:
   - Gatekeeper right-click → Open instruction (self-signed).
   - One-time re-auth notice.
   - MIT attribution: "based on Usage4Claude by f-is-h".
9. Post-release verification:
   ```bash
   gh release list --repo quangyendn/UsagePaceCC
   curl -s https://api.github.com/repos/quangyendn/UsagePaceCC/releases/latest | grep -E '"tag_name"|"name"'
   shasum -a 256 -c <downloaded>.dmg.sha256
   ```
   Install the DMG on a clean-ish account: app launches, menu bar renders, About tab shows
   dual copyright, in-app update check reports "up to date".

## Todo list

- [ ] **[USER][MANUAL]** Create `UsagePaceCC-CodeSigning` in Keychain Access
- [ ] Verify with `security find-identity -v -p codesigning`
- [ ] **[USER][MANUAL]** Xcode Release build signs cleanly; `codesign -dvv` OK
- [ ] Confirm the Phase 06 signing cleanup still holds (`CODESIGN_` grep → 0; doc states ad-hoc)
- [ ] Verify `UpdateChecker` repo path **before** publishing
- [ ] CHANGELOG entry (rebrand + bundle-id + re-auth notice)
- [ ] **[USER]** Release dry-run; verify DMG + SHA256 artifact names
- [ ] **[USER][MANUAL]** Publish the release with the 3 required notes
- [ ] Post-release: `releases/latest` API, checksum, clean-install smoke test

## Success Criteria

- [ ] `security find-identity -v -p codesigning` lists `UsagePaceCC-CodeSigning`
- [ ] Xcode GUI Release build succeeds with no signing error
- [ ] `gh release list --repo quangyendn/UsagePaceCC` shows the published release
- [ ] Asset names `UsagePaceCC-v<ver>.dmg` + `.dmg.sha256`; checksum verifies
- [ ] Fresh install launches; About tab correct; in-app update check resolves the release
- [ ] Release notes carry Gatekeeper + re-auth + attribution notes

## Verification commands

```bash
security find-identity -v -p codesigning
./scripts/build.sh && ls -l build/UsagePaceCC-Release-*/
.github/scripts/verify_version.sh verify CHANGELOG.md UsagePaceCC.xcodeproj
gh release list --repo quangyendn/UsagePaceCC
curl -s https://api.github.com/repos/quangyendn/UsagePaceCC/releases/latest | grep tag_name
codesign -dvv build/UsagePaceCC-Release-*/UsagePaceCC.app 2>&1 | head
```

## Rollback

- Certificate: delete from Keychain Access and recreate; no repo impact.
- Release: `gh release delete <tag>` + `git push --delete origin <tag>` — but only before
  anyone downloads it. Prefer publishing a corrected patch release over deleting.
- CI changes: single-commit revert.

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Release ships with a stale update endpoint | **High** | Step 5 hard-checks `UpdateChecker` before publishing; this is the last moment it is cheap to fix |
| Cert name mismatch vs. `project.pbxproj` | Medium | Exact string `UsagePaceCC-CodeSigning`; verified via `security find-identity` |
| Gatekeeper blocks users, no explanation | Medium | Mandatory right-click→Open note in release notes and README |
| Users lose stored credentials silently | Medium | Re-auth notice in release notes + onboarding (decision locked in the prior plan) |
| CI cert-import ambiguity resurfaces | Low | Closed by V3 and implemented in Phase 06; step 3 is a regression check only |
| Version/CHANGELOG mismatch fails the release job | Low | `verify_version.sh` run locally in step 5 |

## Security Considerations

- Self-signed ≠ trusted. Do not imply notarization in release notes.
- The `CODESIGN_*` secrets are already gone (Phase 06). Do not re-create them. If a `.p12`
  is ever exported locally, treat it as a credential — never commit it; `.gitignore`
  already excludes `*.p12`/`*.cer`.
- Publish the SHA256 alongside the DMG so users can verify an unsigned download.
- The release is public and permanent — re-check that no diagnostic/log sample in the
  release notes leaks an Org ID or Session Key.

## Next steps

Both this phase and [Phase 08 — Website](./phase-08-website.md) are **deferred**. The plan
itself is complete at Phase 06; these two are picked up in a later run, in this order
(08's download links need a release from 07).
