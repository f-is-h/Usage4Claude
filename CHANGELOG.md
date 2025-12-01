# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2025-12-01

### Added
- **Menu Bar Icon Themes**: Three theme options for menu bar icon display
  - Color Translucent (default): Colored rings with transparent background
  - Color with Background: Colored rings with semi-transparent white background for better visibility on dark wallpapers
  - Monochrome: Template mode that automatically adapts to system menu bar style
- **Detail Window Auto Close**: Use global event monitor for better click detection outside app

### Changed
- **Icon size**: Increased from 18px to 20px for better readability
- **Text size**: Increased from 6-7pt to 8pt
- **Background ring opacity**: Increased from 0.3 to 0.7 for better contrast
- **5-hour limit color**: Updated to darker green (#28B446)
- **7-day limit colors**: Enhanced purple tones - medium purple (#B450F0) and deep magenta (#B41EA0)
- **Update badge**: Smaller and more compact positioning (2px radius)
- **Auto active**: Activate detail window when showing popover for proper focus management

### Improved
- **Settings UI**: Separated icon settings into "Theme" and "Display Content" sections with helpful descriptions
- **Menu bar display**: Fully optimize the display of existing menu bars

## [1.5.1] - 2025-11-27

### Fixed
- Fixed JSON decoding error for accounts with 7-day usage limits
- API now correctly handles floating-point usage percentages (e.g., `54.0` instead of `54`)
- Added support for new API fields (`seven_day_sonnet`, `seven_day_oauth_apps`)

### Technical Details
- Changed `utilization` field type from `Int` to `Double` to match actual API response format
- This fix resolves the "Data Parsing Error" issue reported by users with newer Claude Pro accounts

## [1.5.0] - 2025-11-27

### Added
- Dual limit support: 5-hour and 7-day limits can now be displayed
  simultaneously
- Dual-circle menu bar icon showing both limits with color-coded
  indicators
- Debug mode settings for development: toggle fake data, simulated
  updates, and instant refresh
- Unified color scheme management via ColorScheme.swift for consistent
  colors across UI

### Improved
- Enhanced color transparency in detail view for softer appearance

## [1.4.1] - 2025-11-22

### Fixed
- Critical crash caused by force unwrapping `NSApp.currentEvent` in menu bar click handler
- Four unsafe force cast operations that could crash under memory pressure
- Improved icon handling safety with proper nil checking

### Added
- Diagnostic logging system with automatic error/warning capture
- "Open Log Folder" button in diagnostics view for easy log access
- Automatic log sanitization to protect sensitive information (Session
Key, Organization ID)

### Changed
- Release builds now only log Error and Warning levels (minimal disk usage)
- Debug builds continue to log all levels for development
- Log files auto-rotate at 5MB with maximum 5 archives retained

## [1.4.0] - 2025-11-20

### Added
- **Launch at Login**: Option to automatically start app when macOS boots
  - Toggle in General Settings
  - Uses macOS ServiceManagement framework for native integration
- **Manual Refresh Button**: On-demand data refresh with visual feedback
  - Animated refresh icon during data fetching
  - 10-second debounce protection to prevent excessive API calls
  - Instant refresh capability for checking status before important tasks
- **Enhanced Menu UI**: SF Symbols icons and keyboard shortcuts throughout
  - Visual icons for all menu items (Refresh: ↻, Settings: ⚙️, Updates: 🔔)
  - Keyboard shortcuts: ⌘R (refresh), ⌘, (settings), ⌘⇧A (auth), ⌘Q (quit)
  - More professional and native macOS appearance
- **Connection Diagnostics Tool**: Built-in diagnostic system to troubleshoot connection issues
  - One-click connection testing with detailed technical analysis
  - Automatic error detection and classification (Cloudflare blocks, auth failures, network errors)
  - Privacy-safe diagnostic reports with automatic credential redaction
  - Export functionality for sharing reports with developers
  - Localized suggestions for different error types across all supported languages
  - Detects HTTP status codes, response types, and Cloudflare challenges

### Improved
- **Update Notification System**: Enhanced visual feedback for available updates
  - Menu bar badge indicator with rainbow gradient animation effect
  - Rainbow-colored text in menu items to highlight new versions
  - Multilingual notification messages (en/ja/zh-Hans/zh-Hant)
  - User acknowledgment tracking to avoid repetitive notifications
  - Clear visual distinction between up-to-date and update-available states
- **Dark Mode Compatibility**: Three-dot menu and all UI elements fully adapt to dark mode
  - Proper contrast and visibility in both light and dark themes
  - Consistent visual appearance across system theme changes
  - SwiftUI native appearance handling for automatic theme switching
- **Performance Optimization**: Significant improvements in speed and resource usage
  - Icon caching system: 80% faster rendering, 45% lower CPU usage
  - Background I/O operations: Non-blocking Keychain and settings saves
  - Optimized refresh scheduling with smart mode improvements
- **Stability Enhancements**: Critical fixes for long-term reliability
  - Fixed race condition in launch-at-login causing infinite loop (Thread-safe flag handling)
  - Memory leak prevention: Proper cleanup of Observers, Timers, and Combine subscriptions
  - Thread-safe I/O operations: Keychain saves moved to background threads
  - Observer accumulation fix: Remove old observers before adding new ones
- **Code Quality**: Major refactoring for better maintainability
  - Created `ImageHelper` utility class to eliminate code duplication (24 lines reduced to 0)
  - Complex methods split into smaller, testable functions (Average method size: 28→12 lines)
  - Migrated from NotificationCenter to Combine framework for better resource management
  - Improved code documentation with comprehensive inline comments
  - Method complexity reduced by 75% (Cyclomatic complexity: 8→2)

### Changed
- **Debug Mode Development**: Development builds now use UserDefaults for faster iteration
  - Production builds continue using secure Keychain storage
  - Improves developer experience without compromising user security in release builds

### Fixed
- **Memory Management**: Fixed potential memory leaks that could cause crashes
  - Event monitors properly removed when not needed
  - Timers invalidated and set to nil on cleanup
  - Combine subscriptions automatically managed with `Set<AnyCancellable>`
- **Settings Responsiveness**: Fixed occasional UI lag when changing settings
  - I/O operations moved to background threads (75% faster response time)
  - Main thread no longer blocked by Keychain or file operations

### Security
- **Diagnostic Reports**: All sensitive information automatically redacted
  - Organization ID masked (e.g., `1234...cdef`)
  - Session Key masked (e.g., `sk-ant-***...*** (128 chars)`)
  - Safe to share publicly without exposing credentials
- **Code Signing**: Improved stability with consistent signing across builds

## [1.3.0] - 2025-11-05

### Added
- **System Language Detection**: App now automatically detects and uses system language on first launch at Welcome Window
  - Intelligent language mapping for macOS system preferences
  - Supports English, Japanese, Simplified Chinese, and Traditional Chinese
  - Falls back to English for unsupported languages

### Changed
- **Real-Time Language Switching**: Language changes now take effect immediately without app restart
  - Redesigned localization system with reactive architecture
  - All UI elements update instantly when language is changed
  - Improved user experience for multilingual testing and usage

## [1.2.0] - 2025-11-04

### Changed
- **Settings UI Redesign**: Modern card-based layout for better visual hierarchy
  - Card-style design for each settings section
  - Toolbar-style navigation with icon and text labels
  - Elegant gradient dividers between navigation tabs

### Improved
- **Window Management**: Settings and Welcome windows now appear as independent apps in Dock
  - Windows display in Dock when opened for easy Cmd+Tab switching
  - Automatically hide from Dock when windows are closed
  - Popover remains as lightweight menu bar element

## [1.1.2] - 2025-11-01

### Fixed
- **Error Message Localization**: Fixed issue where error messages were displayed in system language instead of user's selected language
  - Network request failures now show localized error messages
  - Authentication/decoding failures now show localized error messages instead of cryptic system errors
  - Added `networkError` and `decodingError` cases to error handling system
- **Improved Error Clarity**: Users with incorrect credentials now see clear, actionable error messages
  - Before: "The data couldn't be read because it is missing" (system error)
  - After: "Failed to parse response data. Please check if your credentials are correct" (localized)
- Updated all 4 language files with new error message translations (English, Japanese, Simplified Chinese, Traditional Chinese)

## [1.1.1] - 2025-10-31

### Improved
- **Smart Reset Time Verification**: Intelligent verification system for quota reset detection
  - Automatic verification at 1/10/30 second after reset time
- **Intelligent Verification Cancellation**: Automatically cancels remaining verifications when reset is detected
  - Detects reset completion by monitoring reset time changes
  - Avoids unnecessary API calls when reset is confirmed

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

[1.6.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.6.0
[1.5.1]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.5.1
[1.5.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.5.0
[1.4.1]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.4.1
[1.4.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.4.0
[1.3.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.3.0
[1.2.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.2.0
[1.1.2]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.1.2
[1.1.1]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.1.1
[1.1.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.1.0
[1.0.1]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.0.1
[1.0.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.0.0
