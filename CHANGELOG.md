# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-10-26

### Added
- **Smart Refresh Frequency**: Intelligent 4-level progressive refresh rate adjustment
  - Active mode (1 min): When usage is detected
  - Short-term idle (3 min): After 3 consecutive no-change detections
  - Medium-term idle (5 min): After 6 consecutive no-change detections
  - Long-term idle (10 min): After 12 consecutive no-change detections
- User-selectable refresh modes: Smart Frequency or Fixed Frequency
- Fixed refresh frequency options expanded to 4 levels (1/3/5/10 minutes)
- Automatic frequency recovery to active mode when usage changes are detected

### Changed
- Default refresh mode changed from fixed to smart frequency
- Refresh settings UI redesigned with mode selection and conditional fixed interval picker
- All localization files updated for smart refresh frequency feature (English, Japanese, Simplified Chinese, Traditional Chinese)

### Improved
- Significantly reduced API calls during idle periods (up to 10x reduction)
- Better responsiveness during active usage with 1-minute refresh
- Smoother transition between different monitoring modes
- Enhanced user experience with intelligent resource management

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

[1.1.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.1.0
[1.0.1]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.0.1
[1.0.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.0.0
[Unreleased]: https://github.com/f-is-h/Usage4Claude/compare/v1.1.0...HEAD
