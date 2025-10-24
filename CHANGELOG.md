# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-10-24

### Fixed
- Fixed potential "Request Exceeded" errors by optimizing refresh intervals
- Adjusted default refresh interval from 1 minute to 3 minutes for better API rate limit compliance
- Modified available refresh options to more conservative values (1min, 3min, 5min)
- Updated all localization files for adjusted refresh interval options

## [1.0.0] - 2025-10-22

### Added

**Core Features**
- Real-time monitoring of Claude AI 5-hour usage quota
- Smart color-coded progress ring (green/orange/red)
- Precise reset time display with countdown
- Auto-refresh with configurable intervals (30s/1min/5min)
- Native macOS menu bar integration

**Personalization**
- Three display modes (percentage/icon/combined)
- Multi-language support (English, Japanese, Simplified Chinese, Traditional Chinese)
- Visual settings interface
- First-launch welcome wizard

**Convenience**
- Automatic update checking
- One-click access to Claude usage page
- Detailed usage view window

**Security**
- macOS Keychain encryption for sensitive data
- App Sandbox protection
- Local-only data storage
- Self-signed code signing

### Technical

- Built with Swift 5.0+ and SwiftUI
- MVVM architecture
- Combine framework for reactive programming
- Minimum macOS 13.0 support

### Known Issues

- App not notarized by Apple (requires manual authorization on first launch)
- Authentication credentials must be obtained manually from browser developer tools

---

## [Unreleased]

### Planned

- Launch at login option
- Keyboard shortcuts
- Usage notifications
- Historical usage tracking
- Browser extension for auto-authentication

---

[1.0.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.0.0
[Unreleased]: https://github.com/f-is-h/Usage4Claude/compare/v1.0.0...HEAD
