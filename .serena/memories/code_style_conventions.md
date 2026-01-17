# Code Style and Conventions

## Swift Style

### Formatting
- **Indentation**: 4 spaces (no tabs)
- **Line length**: No strict limit, but keep reasonable
- **File size**: Target 300-600 lines per file

### Naming
- **Types**: PascalCase (e.g., `MenuBarManager`, `UserSettings`)
- **Functions/Methods**: camelCase (e.g., `updateMenuBarIcon()`, `setupDataBindings()`)
- **Variables/Properties**: camelCase (e.g., `usageData`, `isLoading`)
- **Constants**: camelCase (e.g., `defaultTimeout`)

### Code Organization
Use `// MARK: -` sections to organize code:
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
```

### Documentation
- Code comments in Chinese or English are acceptable (existing codebase uses Chinese)
- DocC-style comments for public APIs:
```swift
/// 刷新状态管理器
/// 用于在视图间同步刷新状态，支持响应式更新
class RefreshState: ObservableObject { ... }
```

## Localization

### Type-Safe Access
Use `LocalizationHelper.swift` for all UI strings:
```swift
L.Menu.settings      // Menu items
L.Usage.title        // Usage-related text
L.Settings.general   // Settings labels
```

### Adding New Strings
When adding UI text, update ALL 5 language files:
- `Resources/en.lproj/Localizable.strings`
- `Resources/ja.lproj/Localizable.strings`
- `Resources/zh-Hans.lproj/Localizable.strings`
- `Resources/zh-Hant.lproj/Localizable.strings`
- `Resources/ko.lproj/Localizable.strings`

## Design Patterns

### Colors
Use `ColorScheme.swift` for all usage-related colors:
- 5-hour limit: green → orange → red progression
- 7-day limit: purple gradient

### Data Storage
- **Sensitive data** (session keys): `KeychainManager`
- **User preferences**: `UserSettings` (UserDefaults)

### Refresh Logic
`DataRefreshManager` implements 4-level adaptive refresh based on usage activity.

## Commit Messages
- Format: Conventional commits (`feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, `chore:`)
- Concise messages
- No emojis
- No co-authoring footers
- Include `[release]` to trigger GitHub Actions release
