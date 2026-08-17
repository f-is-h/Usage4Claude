# Contributing to UsagePaceCC

Thank you for your interest in contributing! We welcome all contributions.

## How to Contribute

### Reporting Bugs

Use the [Bug Report template](https://github.com/quangyendn/UsagePaceCC/issues/new?template=bug_report.md) and include:

- Clear description
- Steps to reproduce
- Expected vs actual behavior
- Environment (macOS version, app version, chip type)
- Screenshots if applicable

### Suggesting Features

Use the [Feature Request template](https://github.com/quangyendn/UsagePaceCC/issues/new?template=feature_request.md) and describe:

- What you want to achieve
- Why it's useful
- How you envision it working

### Submitting Code

1. **Fork the repository**

2. **Clone and create a branch**
   ```bash
   git clone https://github.com/quangyendn/UsagePaceCC.git
   cd UsagePaceCC
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the code style below
   - Add meaningful comments
   - Ensure code compiles without warnings
   - Test your changes

4. **Commit with conventional format**
   ```bash
   git commit -m "feat: add awesome feature"
   ```
   
   Prefixes:
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation
   - `style:` Code formatting
   - `refactor:` Code refactoring
   - `test:` Tests
   - `chore:` Build/tools

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then open a Pull Request on GitHub.

## Code Style

### Swift

- 4 spaces for indentation (no tabs)
- PascalCase for types
- camelCase for functions and variables
- Use `// MARK: -` to organize code
- Add meaningful comments

**Example:**
```swift
// MARK: - Properties

/// User settings singleton
private let settings = UserSettings.shared

// MARK: - Public Methods

/// Refresh usage data
/// - Parameter force: Whether to force refresh
func refreshUsageData(force: Bool = false) {
    // Implementation
}
```

### File Organization

```
UsagePaceCC/
├── App/              # Application entry
├── Views/            # UI views
├── Models/           # Data models
├── Services/         # Business services
├── Helpers/          # Helper utilities
└── Resources/        # Assets and localizations
```

## Testing Checklist

Before submitting PR:

- [ ] Builds successfully
- [ ] No compilation warnings
- [ ] Tested on different macOS versions (if possible)
- [ ] Tested on Intel and Apple Silicon (if possible)
- [ ] Features work as expected
- [ ] No new bugs introduced

## Documentation

If your contribution involves:

- **New features** → Update README.md
- **API changes** → Update code comments
- **Settings changes** → Update user documentation
- **New UI text** → Update all localization files

## Localization

To add a new language:

1. Duplicate `Resources/en.lproj/Localizable.strings`
2. Translate all strings
3. Add the `.lproj` folder to the project
4. Add the language enum to `LocalizationHelper.swift`

## Getting Help

- Check existing [Issues](https://github.com/quangyendn/UsagePaceCC/issues)
- Check existing [Pull Requests](https://github.com/quangyendn/UsagePaceCC/pulls)
- Ask in [Discussions](https://github.com/quangyendn/UsagePaceCC/discussions)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🙏
