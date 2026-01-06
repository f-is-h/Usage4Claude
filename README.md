# Usage4Claude

[English](README.md) | [日本語](docs/README.ja.md) | [简体中文](docs/README.zh-CN.md) | [繁體中文](docs/README.zh-TW.md) | [한국어](docs/README.ko.md)

<div align="center">

<img src="docs/images/icon@2x.png" width="256" alt="icon">

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange?style=flat-square)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/f-is-h/Usage4Claude?style=flat-square)](https://github.com/f-is-h/Usage4Claude/releases)
[![Downloads (all assets, all releases)](https://img.shields.io/github/downloads/f-is-h/Usage4Claude/total)](https://github.com/f-is-h/Usage4Claude/releases)

**An elegant macOS menu bar app for real-time monitoring of your Claude AI usage.**

✨ **Monitors all Claude platforms: Web • Claude Code • Desktop • Mobile App** ✨

[Features](#-features) • [Installation](#-installation) • [User Guide](#-user-guide) • [FAQ](#-faq) • [Support](#-support)

</div>

---

## ✨ Features

### 🎯 Core Features

- **📊 Real-time Monitoring** - Display Claude subscription's usage quota in menu bar
- **🎯 Multi-Limit Support** - Show up to 5 limits simultaneously (5-hour/7-day/Extra/7-day Opus/7-day Sonnet)
- **🎨 Smart Display Mode** - Auto-detect and display all limit types with available data
- **⚙️ Custom Display** - Manually select which limit types to display, supports any combination
- **🎨 Smart Colors** - Automatic color changes based on usage (5-hour: green/orange/red; 7-day: purple gradient)
- **⏰ Precise Timing** - Quota reset time displayed with minute precision
- **🔄 Smart Refresh System** - Intelligent 4-level adaptive refresh or fixed intervals (1/3/5/10 min)
- **⚡ Manual Refresh** - Click refresh button to update data instantly (10-second debounce protection)
- **💻 Native Experience** - Pure native macOS app, lightweight and elegant

### 🌐 Cross-Platform Support

Works seamlessly with all Claude products:
- 🌐 **Claude.ai** (Web interface)
- 💻 **Claude Code** (CLI tool for developers)
- 🖥️ **Desktop App** (macOS/Windows)
- 📱 **Mobile App** (iOS/Android)

All platforms share the same usage quota, monitored in one place!

### 🎨 Personalization

- **🕓 Multiple Display Modes**
  - Percentage Only - Clean and intuitive, view at a glance
  - Icon Only - Subtle and elegant, detailed info on click
  - Icon + Percentage - Complete information, quick visual identification

- **🌍 Multilingual Support**
  - English
  - 日本語
  - 简体中文
  - 繁体中文
  - 한국어
  - More languages coming soon...

### 🔧 Convenient Features

- **⚙️ Visual Settings** - No code modification needed, GUI configuration for all options
- **🆕 Smart Update Alerts** - Menu bar badge and rainbow animation notify new versions
- **🚀 Launch at Login** - Optional automatic startup when system boots
- **⌨️ Keyboard Shortcuts** - Common operations support shortcuts (⌘R, ⌘,, ⌘Q)
- **👋 Friendly Onboarding** - Detailed setup wizard on first launch
- **… Menu Display** - Multiple menu access methods, detail view and right-click
- **🛠️ Debug Mode** - Developer options: fake data testing, simulated updates, instant refresh

### 🔒 Security & Privacy

- 🏠 **Local Storage Only** - All data stored locally only, never collect or upload any personal information
- 🔐 **Keychain Protection** - Sensitive information secured in Keychain, no plain text keys
- 📖 **Open Source Transparency** - Code fully public, anyone can audit
- 🛡️ **Sandbox Protection** - App Sandbox enabled for enhanced security

---

## 📸 Screenshots

### Menu Bar Display

- Icons and any limit type can be freely combined for display (at least one item must be shown)
- Dual indicators through shape and color ensure easy identification even in monochrome themes

| Icon | 5-Hour | 7-Day | Extra | 7-Day Opus | 7-Day Sonnet | Monochrome (Adaptive) |
|:---:|:---:|:---:|:---:|:---:|:---:|-----|
| <img src="docs/images/bar.icon@2x.png" width="40" height="40" alt="icon"> | <img src="docs/images/bar.5h@2x.png" width="45" height="45" alt="5h ring"> | <img src="docs/images/bar.7d@2x.png" width="45" height="45" alt="7d ring"> | <img src="docs/images/bar.ex@2x.png" width="45" height="45" alt="extra ring"> | <img src="docs/images/bar.7do@2x.png" width="45" height="45" alt="7d opus ring"> | <img src="docs/images/bar.7ds@2x.png" width="45" height="45" alt="7d sonnet ring"> | <img src="docs/images/bar.mono.b@2x.png" width="auto" height="35" alt="mono black"></br> <img src="docs/images/bar.mono.w@2x.png" width="auto" height="35" alt="mono white"> |

**Color Indicators**:

- **5-Hour Limit (incl. detail window)**: ![macOS Green](https://img.shields.io/badge/macOS_Green-34C759) → ![macOS Orange](https://img.shields.io/badge/macOS_Orange-FF9500) → ![macOS Red](https://img.shields.io/badge/macOS_Red-FF3B30)
- **7-Day Limit (incl. detail window)**: ![Light Purple](https://img.shields.io/badge/Light_Purple-C084FC) → ![Purple](https://img.shields.io/badge/Purple-B450F0) → ![Deep Purple](https://img.shields.io/badge/Deep_Purple-B41EA0)
- **Extra Usage**: ![Pink](https://img.shields.io/badge/Pink-FF9ECD) → ![Rose](https://img.shields.io/badge/Rose-EC4899) → ![Magenta](https://img.shields.io/badge/Magenta-D946EF)
- **7-Day Opus Limit**: ![Light Orange](https://img.shields.io/badge/Light_Orange-FFC864) → ![Amber](https://img.shields.io/badge/Amber-FBBF24) → ![Orange Red](https://img.shields.io/badge/Orange_Red-FF6432)
- **7-Day Sonnet Limit**: ![Light Blue](https://img.shields.io/badge/Light_Blue-64C8FF) → ![Blue](https://img.shields.io/badge/Blue-007AFF) → ![Indigo](https://img.shields.io/badge/Indigo-4F46E5)

### Detail Window

<table border="0">
<tr>
<td align="top" valign="top">
<img src="docs/images/detail.5.en@2x.png" width="280" alt="5-Hour Limit Mode">
<br/><br/><br/><br/>
<sub><i>5-Hour Limit Mode</i></sub>
</td>
<td align="center" valign="top">
<img src="docs/images/detail.all.en@2x.png" width="280" alt="All Limits Mode">
<br/>
<sub><i>All Limits Mode (Any combination freely selectable)</i></sub>
</td>
<td align="center" valign="top">
<img src="docs/images/detail@2x.gif" width="280" alt="Time Remaining Toggle Animation">
<br/>
<sub><i>Time Remaining Toggle Animation</i></sub>
</td>
</tr>
</table>

### Settings

**General** - Launch at login, customize display, theme settings, refresh, and language options
**Authentication** - Configure Claude account authentication, connection diagnostics
**About** - Version info and related links

### Welcome Screen

**Configure Authentication** - Session Key, auto-retrieve Organization ID
**Configure Display Options** - Display options and theme settings with live preview
**Set Up Later** - Close welcome screen, configure later in settings

---

## 💾 Installation

### Option 1: Download Pre-built (Recommended)

1. Go to [Releases page](https://github.com/f-is-h/Usage4Claude/releases)
2. Download the latest `.dmg` file
3. Double-click to open, drag app to Applications folder
4. Right-click the app and select "Open" on first launch (allow unsigned app)
5. Allow Keychain access for authentication info (Need to allow again after version updates. Authorization prompt appears once: Session Key)

### Option 2: Build from Source

#### Requirements
- macOS 13.0 or later
- Xcode 15.0 or later
- Git

#### Build Steps

```bash
# Clone repository
git clone https://github.com/f-is-h/Usage4Claude.git
cd Usage4Claude

# Open in Xcode
open Usage4Claude.xcodeproj

# Press Cmd + R to run in Xcode
```

---

## 📖 User Guide

### Initial Setup

1. **Launch App**  
   Welcome screen will appear on first run

2. **Configure Authentication**  
   Click "Go to Authentication Settings" button

3. **Get Session Key**
   - Click "Open Claude Usage Page in Browser"
   - Open browser developer tools (press F12 or Cmd + Option + I)
   - Switch to "Network" tab
   - Refresh the page
   - Find request named `usage`
   - View Headers, find `sessionKey=sk-ant-...` value in `Cookie`

4. **Enter Information**
   - Paste Session Key into "Session Key" field
   - Monitoring will start automatically after configuration

### Daily Usage

- **Default Display** - Menu bar shows usage percentage
- **View Details** - Click menu bar icon or percentage
- **Manual Refresh** - Click refresh button in detail window or use shortcut ⌘R
- **Show Menu** - Click "…" icon in detail window or right-click menu bar icon
- **Keyboard Shortcuts**
  - ⌘R - Manual refresh data
  - ⌘, - Open General Settings
  - ⌘⇧A - Open Authentication Settings
  - ⌘Q - Quit app
- **Update Alerts** - When new version available, menu bar icon shows badge and menu items display rainbow text
- **Check Updates** - Menu → Check for Updates

### Refresh Mode

**Smart Frequency (Recommended)**
- Automatically adjusts refresh rate based on usage patterns
- Active mode (1 min) - Fast refresh when actively using Claude
- Idle modes (3/5/10 min) - Progressively slower refresh when idle
- Significantly reduces API calls during idle periods (up to 10x)
- Instantly returns to 1-minute refresh when usage detected

**Fixed Frequency**
- **1 minute** - Recommended for consistent monitoring
- **3 minutes** - Balanced monitoring
- **5 minutes** - Low frequency monitoring
- **10 minutes** - Minimal API calls

---

## ❓ FAQ

<details>
<summary><b>Q: What if the app shows "Session Expired"?</b></summary>

A: Session Keys expire periodically (usually weeks to months), need to re-obtain:
1. Open Settings → Authentication
2. Follow configuration guide to get new Session Key
3. Paste new Session Key

</details>

<details>
<summary><b>Q: How to enable auto-launch on startup?</b></summary>

A: Two methods:

**Method 1: Using built-in option (Recommended)**
1. Open Settings → General
2. Check "Launch at Login" option

**Method 2: Via System Settings**
1. Open System Settings → General → Login Items
2. Click "+" to add Usage4Claude

</details>

<details>
<summary><b>Q: How much system resources does it use?</b></summary>

A: Very lightweight:
- CPU Usage: < 0.1% (idle)
- Memory: ~20MB
- Network: Only 1 request per minute

</details>

<details>
<summary><b>Q: Which macOS versions are supported?</b></summary>

A: Requires macOS 13.0 (Ventura) or later. Supports both Intel and Apple Silicon (M1/M2/M3) chips.

</details>

<details>
<summary><b>Q: Why does it need Keychain permission?</b></summary>

A:
- Keychain is macOS's system-level password manager
- Your Session Key is encrypted in Keychain
- Organization ID is stored in local config (non-sensitive identifier)
- This is Apple's recommended secure storage method
- Only this app can access the information, other apps cannot view it

</details>

<details>
<summary><b>Q: Is my data safe? How is privacy protected?</b></summary>

**Completely safe!** 

**Data Storage:**
- All data stored **only** on your local Mac
- No collection, no tracking, no statistics of any information
- No network requests except Claude API calls
- No third-party services used

**Authentication Security:**
- Session Key encrypted via macOS Keychain (system-level encryption)
- Keychain uses AES-256 encryption + hardware protection (T2 / Secure Enclave)
- Only this app can access your credentials, other apps cannot read them
- You can revoke access anytime via "Keychain Access" app

**Code Transparency:**
- 100% open source
- No obfuscation or hidden features
- Community can audit and verify

**Additional Protection:**
- App Sandbox enabled (limits system access)
- No access to your files, contacts, or other apps
- Minimal permissions (only network + Keychain)

You can verify all of this by reviewing the source code on GitHub!

</details>

<details>
<summary><b>Q: Does it work with Claude Code / Desktop App / Mobile App?</b></summary>

A: **Yes, it works with all Claude platforms!**

Since all Claude products (Web, Claude Code, Desktop App, Mobile App) share the same usage quota, Usage4Claude monitors your combined usage across all platforms.

Whether you're:
- Coding in terminal with `claude code`
- Chatting on claude.ai
- Using the desktop app
- Using mobile apps

You'll see your real-time total usage in the menu bar. No platform-specific configuration needed!

</details>

<details>
<summary><b>Q: Can't see the icon in menu bar?</b></summary>

A: macOS system or third-party software (like Bartender, Hidden Bar, etc.) may automatically hide menu bar icons.

**Solution:**
1. Hold **Command (⌘) key**
2. Drag icons in the menu bar with mouse
3. Drag Usage4Claude icon to the visible area on the right side of menu bar
4. Release mouse

**Note:**
- macOS Sonoma (14.0+) automatically hides infrequently used icons to "Control Center"
- You can adjust menu bar icon display in "System Settings" → "Control Center"

</details>

---

## 🛠 Tech Stack

Built with modern macOS native technologies:

- **Language**: Swift 5.0+
- **UI Framework**: SwiftUI + AppKit hybrid
- **Architecture**: MVVM
- **Networking**: URLSession
- **Reactive**: Combine Framework
- **Localization**: Built-in i18n support
- **Platform**: macOS 13.0+

---

## 🗺 Roadmap

### ✅ Completed
- [x] Basic monitoring features
- [x] Menu bar real-time display
- [x] Circular progress indicator
- [x] Smart color alerts
- [x] Real-time countdown
- [x] Multiple menu bar display modes
- [x] Visual settings interface
- [x] Multilingual support
- [x] First-launch onboarding
- [x] Update checking with visual alerts
- [x] Keychain authentication storage
- [x] Shell auto-package DMG
- [x] GitHub Actions auto-release
- [x] Settings interface display optimization
- [x] Launch at login option
- [x] Keyboard shortcuts support
- [x] Manual refresh feature
- [x] Three-dot menu dark mode adaptation
- [x] Dual limit mode support (5-hour + 7-day)
- [x] Dual-ring menu bar icon
- [x] Unified color scheme management
- [x] Debug mode (fake data, simulated updates)
- [x] Detail window remove Focus state
- [x] Multi-limit type support (5 types)
- [x] Smart/custom display mode
- [x] Auto-retrieve Organization ID
- [x] Optimized welcome flow
- [x] Monochrome theme icon display
- [x] Korean language support

### Short-term Plans
1. **Developer Experience**
    - 🚧 GitHub Actions check online version

### Mid-term Plans
2. **Display Optimization**

- 🚧 Settings interface dark mode adaptation

3. **Feature Addition**
    - Usage notifications
    - More language localizations

### Long-term Vision
4. **Auto Setup**

- Browser extension for auto-authentication
- Automatic credential configuration

5. **More Display Methods**

- Desktop widgets
- Browser extension icon usage display

6. **Data Analysis**
   - Usage history records
   - Trend charts

7. **Multi-platform Support**
   - iOS / iPadOS version
   - Apple Watch version
   - Windows version

---

## 🤝 Contributing

All contributions are welcome! Whether it's new features, bug fixes, or documentation improvements.

For detailed contribution guidelines, please see [CONTRIBUTING.md](CONTRIBUTING.md).

### How to Contribute

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Contributors

Thanks to all who have contributed to this project!

<!-- ALL-CONTRIBUTORS-LIST:START -->
<!-- Contributor list will be auto-generated here -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## 📝 Changelog

For detailed version history and updates, please see [CHANGELOG.md](CHANGELOG.md).

---

## 💖 Support

If this project helps you, please support in the following ways:

### ⭐ Star the Project
Giving a star is the biggest encouragement!

### ☕ Buy Me a Coffee

<!-- GitHub Sponsors -->
<a href="https://github.com/sponsors/f-is-h?frequency=one-time">
  <img src="https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?style=for-the-badge&logo=github" alt="GitHub Sponsor">
</a>

<!-- Ko-fi -->
<a href="https://ko-fi.com/1attle">
  <img src="https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=for-the-badge&logo=ko-fi" alt="Ko-fi">
</a>

<!-- Buy Me A Coffee -->
<!-- <a href="https://buymeacoffee.com/fish_">
  <img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee">
</a> -->

### 📢 Share the Project
If you like this project, please share it with more people!

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details

```
MIT License

Copyright (c) 2025 f-is-h

You are free to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software.
```

---

## 🙏 Acknowledgments

- Thanks to [Claude AI](https://claude.ai) - Most code written by AI
- Thanks to all contributors and users for their support
- Icon design inspired by Claude AI official branding

---

## 📞 Contact

- **Issues**: [Submit issues or suggestions](https://github.com/f-is-h/Usage4Claude/issues)
- **Discussions**: [Join discussions](https://github.com/f-is-h/Usage4Claude/discussions)
- **GitHub**: [@f-is-h](https://github.com/f-is-h)

---

## ⚖️ Disclaimer

This project is an independent third-party tool with no official affiliation with Anthropic or Claude AI. Please comply with Claude AI's Terms of Service when using this software.

---

<div align="center">

**If this project helps you, please give it a ⭐ Star!**

Made with ❤️ by [f-is-h](https://github.com/f-is-h)

[⬆ Back to Top](#usage4claude)

</div>
