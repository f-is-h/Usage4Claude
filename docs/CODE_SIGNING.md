# Code Signing Guide for UsagePaceCC

## Overview

UsagePaceCC currently produces **ad-hoc-signed** artifacts from both the local
`scripts/build.sh` path and CI. Ad-hoc signing satisfies the build system but is
not accepted by macOS Gatekeeper — end-users must right-click the app and choose
"Open" on first launch, or Gatekeeper will block it.

| Context | Signing used | Notes |
|---------|--------------|-------|
| Xcode.app GUI build | `UsagePaceCC-CodeSigning` (self-signed) | Must be in your login keychain |
| `scripts/build.sh` (local) | ad-hoc (`-`) | No cert required; Gatekeeper warns |
| CI (GitHub Actions, calls `build.sh`) | ad-hoc (`-`) | `build.sh` overrides the imported cert; see note below |

---

## Local Xcode GUI Builds

The project's `project.pbxproj` sets:

```
CODE_SIGN_IDENTITY = "UsagePaceCC-CodeSigning";
"CODE_SIGN_IDENTITY[sdk=macosx*]" = "UsagePaceCC-CodeSigning";
```

When building directly inside Xcode.app, the cert named `UsagePaceCC-CodeSigning` must
be present in your login keychain.

### Creating the Self-Signed Certificate (Manual Step)

This cannot be scripted via GUI; it must be done manually in Keychain Access:

1. Open **Keychain Access** (Applications → Utilities → Keychain Access).
2. From the menu bar: **Keychain Access → Certificate Assistant → Create a Certificate...**
3. Fill in the form:
   - **Name**: `UsagePaceCC-CodeSigning`
   - **Identity Type**: Self Signed Root
   - **Certificate Type**: Code Signing
   - Leave "Let me override defaults" unchecked unless you need custom validity.
4. Click **Create**, then **Done**.
5. The certificate now appears in your **login** keychain under "My Certificates".

> **Note**: This certificate is required ONLY for Xcode.app GUI builds (Manual signing
> set in `project.pbxproj`). It is NOT required for `scripts/build.sh` or CI.

---

## Local Script Builds (`scripts/build.sh`)

`scripts/build.sh` unconditionally overrides code signing at invocation time:

```bash
CODE_SIGN_IDENTITY="-"
CODE_SIGN_STYLE=Manual
DEVELOPMENT_TEAM=""
```

The `-` value is macOS ad-hoc signing — the app is signed with a per-build ephemeral
identity. The resulting `.app` and `.dmg` run on the build machine but will be flagged
by Gatekeeper on other machines. Users must right-click → "Open" on first launch.

---

## CI (GitHub Actions)

CI (`.github/workflows/release.yml`) imports a `.p12` certificate from GitHub Secrets
before calling `scripts/build.sh`:

| Secret Name | Content |
|-------------|---------|
| `CODESIGN_CERTIFICATE` | Base64-encoded `.p12` export of the `UsagePaceCC-CodeSigning` cert |
| `CODESIGN_PASSWORD` | Password used when exporting the `.p12` |

**Important — the cert import is currently unused.** Because `build.sh` sets
`CODE_SIGN_IDENTITY="-"` unconditionally, CI artifacts are ad-hoc-signed regardless
of what is imported into the keychain. The import step adds no signing benefit today.

Optional cleanup (either is acceptable):
- **Remove** the "Import code signing certificate" step from `release.yml` to keep CI
  simple and avoid requiring secrets that have no effect.
- **OR** make `build.sh` respect an environment variable override (e.g.
  `CODE_SIGN_IDENTITY` if already set) so CI can pass a real identity when desired.

---

## Future: Proper Distribution Signing

For Gatekeeper-transparent distribution (no right-click workaround), you would need:

1. An **Apple Developer ID Application** certificate (requires paid Apple Developer
   Program membership).
2. **Notarization** via `xcrun notarytool submit` after signing.
3. **Stapling** with `xcrun stapler staple`.

This is out of scope for the current project and is documented here only for reference.

> **Repo note**: The repo is `quangyendn/UsagePaceCC`. The `.xcodeproj` filename
> (`Usage4Claude.xcodeproj`) is unchanged — only the certificate identity name and the
> built product name (`UsagePaceCC.app`) have changed.
