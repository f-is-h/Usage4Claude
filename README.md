# Usage4Claude

[English](README.md) | [日本語](docs/README.ja.md) | [简体中文](docs/README.zh-CN.md) | [繁體中文](docs/README.zh-TW.md) | [한국어](docs/README.ko.md) | [Français](docs/README.fr.md) | [Deutsch](docs/README.de.md)

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/hero.en.dark@2x.png">
  <img src="docs/images/hero.en.light@2x.png" width="948" alt="Usage4Claude menu bar icons and detail window">
</picture>

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange?style=flat-square)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/f-is-h/Usage4Claude?style=flat-square)](https://github.com/f-is-h/Usage4Claude/releases)
[![Downloads](https://img.shields.io/github/downloads/f-is-h/Usage4Claude/total?style=flat-square)](https://github.com/f-is-h/Usage4Claude/releases)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%99%A5-EA4AAA?style=flat-square&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/f-is-h?frequency=one-time&metadata_project=usage4claude&metadata_source=readme&metadata_placement=header&metadata_lang=en)

**Track your Claude and Codex subscription usage from the menu bar.**

[Features](#-features) · [Installation](#-installation) · [Usage](#-usage) · [Privacy & Security](#-privacy--security) · [FAQ](#-faq) · [Contributing](#-contributing)

</div>

---

## ✨ Features

### What It Tracks

Claude and Codex can be configured individually or together. All apps of a service share one quota, and the menu bar always shows its total usage.

| Service | Apps | Limits |
|---|---|---|
| **Claude** | claude.ai, Claude Code, desktop, mobile, Cowork | 5-hour, 7-day, Extra Usage, plus weekly usage per model (Opus, Sonnet, Fable, etc., as returned for the account) |
| **Codex** | Codex CLI, IDE extension, Codex web | 5-hour, 7-day, credits balance |

With one service configured, the interface has a single column. With both, the detail window splits into two columns and the menu bar shows both icons side by side.

Claude Pro, Max, Team and Enterprise are supported. Free accounts have no usage dashboard and cannot be read. On Team and Enterprise, an admin must enable the member usage dashboard.

### Two Graph Styles

**Ring** shows the used share of each limit, with reset times listed below.

**Pace** plots each limit against elapsed time, with a diagonal marking even consumption. Above the diagonal means usage is outpacing time; below means there is headroom. Weekly limits can count weekdays only.

Switch between them in Settings → Display → Graph Style. Clicking the limit list toggles between "used share and reset time" and "available share and time remaining".

<div align="center">
<img src="docs/images/detail.toggle@2x.gif" width="606" alt="Clicking the limit list toggles between used and remaining">
</div>

### Menu Bar Icons

Each limit type has its own shape and color, and the color changes as usage rises.

| | Icon | 5-Hour | 7-Day | Extra Usage | Model 1 Weekly<br>(e.g. Fable) | Model 2 Weekly<br>(e.g. Opus, Sonnet) | Monochrome |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Claude** | <img src="docs/images/bar.icon@2x.png" width="40" alt="Claude icon"> | <img src="docs/images/bar.5h@2x.png" width="45" alt="5-hour"> | <img src="docs/images/bar.7d@2x.png" width="45" alt="7-day"> | <img src="docs/images/bar.ex@2x.png" width="45" alt="Extra Usage"> | <img src="docs/images/bar.7do@2x.png" width="45" alt="Model 1 weekly"> | <img src="docs/images/bar.7ds@2x.png" width="45" alt="Model 2 weekly"> | <img src="docs/images/bar.mono.b@2x.png" height="35" alt="Monochrome, light menu bar"><br><img src="docs/images/bar.mono.w@2x.png" height="35" alt="Monochrome, dark menu bar"> |
| **Codex** | <img src="docs/images/bar.icon.codex@2x.png" width="40" alt="Codex icon"> | <img src="docs/images/bar.5h.codex@2x.png" width="45" alt="5-hour"> | <img src="docs/images/bar.7d.codex@2x.png" width="45" alt="7-day"> | <img src="docs/images/bar.ex.codex@2x.png" width="45" alt="credits"> | | | <img src="docs/images/bar.mono.b.codex@2x.png" height="35" alt="Monochrome, light menu bar"><br><img src="docs/images/bar.mono.w.codex@2x.png" height="35" alt="Monochrome, dark menu bar"> |

Weekly per-model usage takes the Model 1 and Model 2 styles in the order the API returns the models, with names as returned for the account. The menu bar shows at most the first two models; the detail window lists every model, alternating between the two styles.

Claude colors:

- **5-Hour**: ![macOS Green](https://img.shields.io/badge/macOS_Green-34C759) → ![macOS Orange](https://img.shields.io/badge/macOS_Orange-FF9500) → ![macOS Red](https://img.shields.io/badge/macOS_Red-FF3B30)
- **7-Day**: ![Light Purple](https://img.shields.io/badge/Light_Purple-C084FC) → ![Purple](https://img.shields.io/badge/Purple-B450F0) → ![Deep Purple](https://img.shields.io/badge/Deep_Purple-B41EA0)
- **Extra Usage**: ![Pink](https://img.shields.io/badge/Pink-FF9ECD) → ![Rose](https://img.shields.io/badge/Rose-EC4899) → ![Magenta](https://img.shields.io/badge/Magenta-D946EF)
- **Model 1 Weekly** (e.g. Fable): ![Light Orange](https://img.shields.io/badge/Light_Orange-FFC864) → ![Amber](https://img.shields.io/badge/Amber-FBBF24) → ![Orange Red](https://img.shields.io/badge/Orange_Red-FF6432)
- **Model 2 Weekly** (e.g. Opus, Sonnet): ![Light Blue](https://img.shields.io/badge/Light_Blue-64C8FF) → ![Blue](https://img.shields.io/badge/Blue-007AFF) → ![Indigo](https://img.shields.io/badge/Indigo-4F46E5)

Codex colors:

- **5-Hour**: ![Bright Teal](https://img.shields.io/badge/Bright_Teal-2DD4BF) → ![Deep Teal](https://img.shields.io/badge/Deep_Teal-0D9488) → ![Darkest Teal](https://img.shields.io/badge/Darkest_Teal-134E4A)
- **7-Day**: ![Sky Blue](https://img.shields.io/badge/Sky_Blue-60A5FA) → ![Blue](https://img.shields.io/badge/Blue-2563EB) → ![Deep Blue](https://img.shields.io/badge/Deep_Blue-1E3A8A)
- **credits**: ![Gold](https://img.shields.io/badge/Gold-F59E0B) → ![Deep Gold](https://img.shields.io/badge/Deep_Gold-D97706) → ![Darkest Amber](https://img.shields.io/badge/Darkest_Amber-78350F)

In the monochrome theme, limits stay distinguishable by shape, and the icons invert automatically with the menu bar. Menu bar brightness follows the wallpaper, not the system Light or Dark appearance.

| Option | Values |
|---|---|
| Display Content | Percentage Only, Icon Only, Icon and Percentage |
| Icon Size | Compact, Standard, Prominent |
| Theme | Color Translucent, Color with Background, Monochrome |

By default the menu bar shows every limit that has data. To pick them individually, switch to Custom Display in Settings → Display → Limit Types.

### Notifications

A system notification is sent when usage reaches a threshold, and again when a quota resets. Thresholds are set per category, from 50% to 100% in steps of 5%.

| Category | Levels | Default |
|---|---|---|
| 5-Hour | 1 | 90% |
| Weekly (including per-model weekly usage) | 2 | 75%, 90% |
| Extra Usage / credits | 2 | 75%, 90% |

### Refresh

**Smart mode** adapts to how usage changes: once a minute while usage moves, then stepping down to every 3, 5 and 10 minutes when nothing changes, and back to once a minute as soon as a change is detected. While idle, it sends about a tenth of the requests.

**Fixed mode** refreshes every 1, 3, 5 or 10 minutes.

Rate limits trigger an automatic backoff. When a refresh fails, the previous data stays on screen with a marker next to the title. The app refreshes on wake from sleep and when the detail window opens; clicking the ring or graph refreshes manually, with a 10-second debounce.

### Accounts

Claude supports multiple accounts and multiple organizations under one account; Codex accounts are managed separately. Each account can have an alias. Switch accounts from the "…" menu in the detail window or the menu bar icon's right-click menu.

Sign-in runs in the system browser, so Google, Microsoft, enterprise SSO and passkeys all work. Claude also accepts a manually entered Session Key.

### Codex Reset Announcement (Beta)

When OpenAI announces an upcoming global quota reset, a badge appears next to the Codex column title; otherwise nothing is shown. The data comes from the third-party community project [codex-reset.com](https://codex-reset.com), not an official API, and can be turned off in Settings.

### Languages

English, 日本語, 简体中文, 繁體中文, 한국어, Français ([@mtreize](https://github.com/mtreize)), Deutsch ([@schaitl](https://github.com/schaitl)). The system language is used by default. New translations are welcome; see [Contributing](#-contributing).

---

## 💾 Installation

### Download

1. Download the latest `.dmg` from [Releases](https://github.com/f-is-h/Usage4Claude/releases) and drag the app into Applications
2. Gatekeeper blocks the first launch; see the first [FAQ](#-faq) entry to allow it
3. When the app first reads its credentials, grant Keychain access and choose "Always Allow"

Requires macOS 13 (Ventura) or later, on Intel or Apple silicon.

Updates are installed in-app by [Sparkle](https://sparkle-project.org). Each update is verified against an EdDSA signature before it is installed. Homebrew is not offered at this time.

### Build from Source

Requires Xcode 26 or later.

```bash
git clone https://github.com/f-is-h/Usage4Claude.git
cd Usage4Claude
open Usage4Claude.xcodeproj
```

Press ⌘R in Xcode to run. The app is written in Swift and SwiftUI, with AppKit for the menu bar and window management.

---

## 📖 Usage

### Signing In

The first launch opens an onboarding window where both Claude and Codex can be signed in. Onboarding can be skipped; accounts can be added later in Settings → Accounts.

**Browser Login**: click the sign-in button, authorize in the system browser, and the app picks up the result automatically. The callback is received on a temporary local port. If a firewall blocks local connections, the browser stays on a `localhost` address; paste that address into the sign-in window to finish.

**Manual Session Key** (Claude only):

1. Open the claude.ai usage page in a browser
2. Open the developer tools (⌥⌘I), switch to the Network tab and reload the page
3. Find the `usage` request and copy the full `sessionKey=sk-ant-...` value from the Cookie request header
4. Paste it into the input field. The Organization ID is fetched automatically, and every organization under the Session Key is added

### Everyday Use

Left-click the menu bar icon to open the detail window; right-click for the menu. The menu holds account switching, Settings, Check for Updates, and links to the Claude and Codex status pages.

When a new version is available, the menu bar icon shows a badge and Check for Updates is marked in the menu.

### Settings

<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/settings.display.en.dark@2x.png">
  <img src="docs/images/settings.display.en.light@2x.png" width="400" alt="The Display tab of the Settings window">
</picture>
</div>

| Tab | Contents |
|---|---|
| **Display** | Menu bar appearance, limit types, graph style, appearance, time format |
| **Data** | Refresh mode, notification thresholds, Codex reset announcement |
| **Accounts** | Claude and Codex accounts, browser login, manual Session Key, connection diagnostics |
| **General** | Interface language, launch at login, restore defaults |
| **About** | Version information and links |

---

## 🔒 Privacy & Security

- No server; data stays on the Mac, with no analytics or telemetry
- Network requests fall into three groups only: the Claude and Codex sign-in and usage endpoints, Sparkle checking GitHub for updates, and codex-reset.com when the Codex reset announcement is on
- Session Keys and tokens are stored in the Keychain, never in plain text; API responses are not written to the disk cache
- App Sandbox is enabled. Beyond network access, it only opens the local port used by the sign-in callback and the system services Sparkle needs to install updates
- Diagnostic reports are redacted before export, with tokens and other sensitive fields replaced
- The source code is fully public and open to audit

---

## ❓ FAQ

<details>
<summary><b>The app won't open: "cannot verify the developer"</b></summary>

The app is not notarized by Apple, so the first launch has to be allowed manually:

- **macOS 15 and later**: double-click the app and click "Done" in the dialog. Then go to System Settings → Privacy & Security and click "Open Anyway" at the bottom of the page
- **macOS 14 and earlier**: Control-click the app, choose "Open", and confirm in the dialog

This is needed once. After that the app opens normally, and in-app updates don't require it again.

</details>

<details>
<summary><b>Keychain access is requested again after an update</b></summary>

The Keychain identifies an app by its signature. This app uses a self-signed certificate, so some updates cause the system to ask again. Choose "Always Allow". Credentials in the Keychain can only be read by this app.

</details>

<details>
<summary><b>"Request blocked by security system"</b></summary>

The Cloudflare protection in front of claude.ai blocks requests it judges to be automated. Visit claude.ai once in a browser and complete the human check; the app usually recovers after that. It is triggered more often behind a VPN or proxy. This block is unrelated to the account itself, and signing in again is not needed.

</details>

<details>
<summary><b>"Session expired"</b></summary>

Session Keys and sign-in tokens expire periodically, anywhere from a few weeks to a few months. Sign in again in Settings → Accounts.

</details>

<details>
<summary><b>"Too many requests"</b></summary>

The usage endpoint has hit its rate limit. The app backs off automatically and retries later, keeping the previous data on screen. Refreshing manually again and again extends the backoff.

</details>

<details>
<summary><b>Codex keeps asking to sign in again</b></summary>

With "Advanced Security" enabled on a ChatGPT account, sign-in tokens expire much sooner, so the app has to sign in again frequently. For long-term Codex monitoring, consider turning that option off.

</details>

<details>
<summary><b>No usage data for a Claude account</b></summary>

The message "Your plan does not provide usage data" means the account has no usage dashboard on claude.ai. Free accounts have none; on Team and Enterprise, ask an admin to enable the member usage dashboard. Signing in again does not change this.

</details>

<details>
<summary><b>The menu bar icon is missing</b></summary>

macOS hides some icons when the menu bar runs out of space, and tools like Bartender or Hidden Bar may also collapse it. Hold ⌘ and drag menu bar icons to rearrange them.

</details>

<details>
<summary><b>The app quits unexpectedly</b></summary>

Export a diagnostic report from Settings → Accounts → Connection Diagnostics and attach it to an [issue](https://github.com/f-is-h/Usage4Claude/issues). The report states whether the last exit was abnormal and includes recent logs. It is redacted before export.

</details>

---

## 🗺 Roadmap

Changes in each release are recorded in [CHANGELOG.md](CHANGELOG.md).

**In progress**: ongoing improvements and issue fixes

**Under consideration**: more interface languages, desktop widgets, usage history charts

**Not planned**

- **Services other than Claude and Codex.** Menu bar space is limited, and every added provider takes space from every user's menu bar. The project focuses on doing these two well rather than becoming a general usage dashboard.
- **Uploading data of any kind.** The project has no server and has no plans to add one.
- **App Store distribution.** The app reads usage through undocumented APIs, which does not meet App Store requirements.

---

## 🤝 Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md) for the process.

**Adding a language**: copy `Usage4Claude/Resources/en.lproj/Localizable.strings` into a new `<language-code>.lproj` folder and translate the values. CI checks that every language has the same keys.

### Contributors

**Code**

<a href="https://github.com/f-is-h/Usage4Claude/graphs/contributors"><img src="docs/images/contributors.code.svg" alt="Code contributors"></a>

**Translation**

<img src="docs/images/contributors.translation.svg" alt="Translation contributors">

**Feedback and Feature Requests**

<img src="docs/images/contributors.feedback.svg" alt="Contributors who reported issues or proposed features">

### Support

<a href="https://github.com/sponsors/f-is-h?frequency=one-time&amp;metadata_project=usage4claude&amp;metadata_source=readme&amp;metadata_placement=badge&amp;metadata_lang=en"><img src="https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?style=for-the-badge&logo=github" alt="GitHub Sponsors"></a>
<a href="https://ko-fi.com/1atte"><img src="https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=for-the-badge&logo=ko-fi" alt="Ko-fi"></a>

---

## 📄 License

MIT License; see [LICENSE](LICENSE). Copyright © 2025-2026 f-is-h.

This is an independent third-party tool with no official affiliation with Anthropic or OpenAI. Follow each service's terms when using it.

Most of the code was written by Claude and Codex. The icon design draws on both companies' official branding.

Report problems in [Issues](https://github.com/f-is-h/Usage4Claude/issues); for everything else, use [Discussions](https://github.com/f-is-h/Usage4Claude/discussions).

<div align="center">

[⬆ Back to top](#usage4claude)

</div>
