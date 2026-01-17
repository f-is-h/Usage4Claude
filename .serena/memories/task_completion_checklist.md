# Task Completion Checklist

When completing a coding task, verify the following:

## Before Committing

### Code Quality
- [ ] No compilation warnings (Swift 6 concurrent mode compliant)
- [ ] Code follows existing patterns and conventions
- [ ] No over-engineering or unnecessary abstractions
- [ ] Changes are minimal and focused on the task

### Localization
- [ ] If UI text was added/changed, all 5 language files updated:
  - `en.lproj/Localizable.strings`
  - `ja.lproj/Localizable.strings`
  - `zh-Hans.lproj/Localizable.strings`
  - `zh-Hant.lproj/Localizable.strings`
  - `ko.lproj/Localizable.strings`

### Security
- [ ] No hardcoded secrets or credentials
- [ ] Sensitive data uses KeychainManager

### Testing (Manual)
- [ ] Build succeeds in Xcode (Cmd+B)
- [ ] Run and verify functionality (Cmd+R)
- [ ] Test with Debug Mode if applicable
- [ ] Test on target macOS version (13.0+)

## Commit
```bash
git add .
git commit -m "type: concise description"
```

Commit types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

## Release (if applicable)
Include `[release]` in commit message to trigger GitHub Actions:
```bash
git commit -m "feat: new feature [release]"
```
