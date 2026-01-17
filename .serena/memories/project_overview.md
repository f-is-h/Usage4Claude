# Usage4Claude - Project Overview

## Purpose
Usage4Claude is a native macOS menu bar application that monitors Claude AI usage quotas in real-time. It tracks usage across all Claude platforms: Web, Claude Code, Desktop, and Mobile App.

## Tech Stack
- **Language**: Swift 5.0+
- **Frameworks**: SwiftUI + AppKit (hybrid approach)
- **Platform**: macOS 13.0+ (Ventura and later)
- **IDE**: Xcode 15.0+
- **Dependencies**: Zero third-party dependencies (fully native)

## Architecture
MVVM pattern with 4 core classes:

1. **MenuBarManager** (App/) - Coordination layer, manages UI↔data binding
2. **MenuBarUI** (App/) - Menu bar icon, popover, and click handling
3. **MenuBarIconRenderer** (App/) - Renders ring indicators with usage percentages
4. **DataRefreshManager** (Helpers/) - Smart 4-level adaptive refresh logic

### Data Flow
```
ClaudeAPIService → DataRefreshManager → MenuBarManager → MenuBarUI → MenuBarIconRenderer
```

## Directory Structure
```
Usage4Claude/
├── App/           # Core app: MenuBarManager, MenuBarUI, MenuBarIconRenderer
├── Views/         # SwiftUI views (Settings, UsageDetail, Welcome)
├── Models/        # UserSettings, DiagnosticReport
├── Services/      # ClaudeAPIService, KeychainManager, UpdateChecker
├── Helpers/       # DataRefreshManager, LocalizationHelper, ColorScheme, TimerManager
└── Resources/     # Assets + localization strings (en, ja, zh-Hans, zh-Hant, ko)
```

## Key Features
- Real-time usage monitoring
- Multi-limit support (5-hour/7-day/Extra)
- Smart 4-level adaptive refresh (1/3/5/10 min)
- 5 language support (English, Japanese, Chinese Simplified/Traditional, Korean)
- Native macOS experience with no external dependencies
