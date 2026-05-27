# Sparkle in-app updates — setup + release workflow

This project uses [Sparkle](https://sparkle-project.org) for in-app
updates. Users get a one-click "Install Update" flow with EdDSA
signature verification, replacing the manual "download → drag to
/Applications → relaunch" cycle.

This doc covers the one-time maintainer setup and the per-release
workflow.

---

## One-time setup (only needed once, ever)

Before shipping the first Sparkle-enabled release, generate an
EdDSA signing keypair and embed the public key in `Config/Info.plist`.

### 1. Download Sparkle's command-line tools

Grab the latest release from
[github.com/sparkle-project/Sparkle/releases](https://github.com/sparkle-project/Sparkle/releases)
and extract. The two binaries that matter live in `bin/`:

- `generate_keys` — creates the EdDSA keypair (one-time)
- `sign_update` — signs DMGs at release time (every release)

Put them somewhere stable. The build script defaults to looking at
`/tmp/sparkle-tools/bin/sign_update`, so the simplest install is:

```bash
mkdir -p /tmp/sparkle-tools/bin
cp /path/to/extracted/Sparkle-*/bin/sign_update /tmp/sparkle-tools/bin/
cp /path/to/extracted/Sparkle-*/bin/generate_keys /tmp/sparkle-tools/bin/
chmod +x /tmp/sparkle-tools/bin/*
```

`/tmp/` clears on some macOS configurations; if that bites, drop the
binaries under `~/.local/bin/` (or wherever you keep custom CLI tools)
and set `SIGN_UPDATE=/your/path/to/sign_update` when running
`scripts/build.sh`.

### 2. Generate the keypair

```bash
/tmp/sparkle-tools/bin/generate_keys
```

Output looks like:

```
A pre-existing signing key was not found, so a new one has been generated and saved
in your keychain. Public key: hGTiB0kyn45HOB8WWKdAHc28+Bthe8Rv8O7asa4nG2c=
```

The **private key** lives in your **login keychain** (under
`https://sparkle-project.org`). It never touches disk in plaintext.
The public key is the string after `Public key:`.

### 3. Embed the public key in Config/Info.plist

Replace the placeholder in `Config/Info.plist`:

```xml
<key>SUPublicEDKey</key>
<string>REPLACE_WITH_YOUR_PUBLIC_KEY_AFTER_RUNNING_generate_keys</string>
```

with your actual public key:

```xml
<key>SUPublicEDKey</key>
<string>hGTiB0kyn45HOB8WWKdAHc28+Bthe8Rv8O7asa4nG2c=</string>
```

Commit. Once this is shipped in a release, **every future Sparkle
update must be signed by the matching private key** — this is the
trust anchor that lets clients reject tampered updates.

### 4. Back up the private key

Export it to a `.p12` and store somewhere safe (encrypted backup,
1Password, etc.). If the private key is lost, every existing install
becomes orphaned: Sparkle will reject all future signed updates whose
public key doesn't match the embedded `SUPublicEDKey`.

To export:

```
Keychain Access → "login" keychain → search "sparkle-project" → right-click → Export
```

Save as `.p12`, set a password, store outside the repo.

---

## Per-release workflow

After setup, every release follows this flow:

1. **Bump version** in `Usage4Claude.xcodeproj/project.pbxproj`
   (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`).
2. **Build the DMG** the usual way:
   ```bash
   ./scripts/build.sh
   ```
   The script ends with a `Sparkle 签名` step that prints something like:
   ```
       <enclosure
           url="https://github.com/f-is-h/Usage4Claude/releases/download/v3.2.0/Usage4Claude-v3.2.0.dmg"
           sparkle:edSignature="qZ0Y8nm..."
           length="9437184"
           type="application/octet-stream"/>
   ```
3. **Paste that into `appcast.xml`** as a new top `<item>` (above any
   existing items). Fill in `<title>`, `<pubDate>`, `<sparkle:version>`,
   `<sparkle:shortVersionString>`, `<link>`, and `<description>` —
   the template at the top of `appcast.xml` shows the shape.
4. **Commit, tag, push**, and create the GitHub release with the DMG
   attached.

Existing v1.6.x+ Sparkle users get the prompt within 24h via the
background poll (or instantly via Settings → Check for Updates).

---

## Why does the build skip Sparkle signing on Debug machines?

`scripts/build.sh` looks for `sign_update` at the default path and
prints a warning when it's missing, but **doesn't fail the build**.
This lets contributors compile and run the project locally without
having to install Sparkle's CLI tools — Sparkle signing is only
relevant when actually publishing a release.
