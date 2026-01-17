# Suggested Commands for Usage4Claude

## Build Commands

### Open in Xcode
```bash
open Usage4Claude.xcodeproj
```
Then press Cmd+R to build and run.

### Build Release with DMG
```bash
# Standard release build (clean + build + DMG)
./scripts/build.sh

# Skip clean step (faster rebuilds)
./scripts/build.sh --no-clean

# Debug build
./scripts/build.sh --config Debug

# Verbose output (show full xcodebuild logs)
./scripts/build.sh --verbose
```

**Note**: DMG creation requires `create-dmg`:
```bash
brew install create-dmg
```

### Build Output
Release artifacts are placed in:
```
build/Usage4Claude-Release-{version}/Usage4Claude-v{version}.dmg
```

## Development Commands

### View Build Logs
```bash
# After a build failure
tail -n 50 build/Usage4Claude-Release-*/build.log
```

### Clean Build Artifacts
```bash
rm -rf build/
```

## Git Commands
```bash
# Standard git operations
git status
git add .
git commit -m "feat: description"
git push

# View recent commits
git log --oneline -10

# GitHub CLI for PRs
gh pr create --title "Title" --body "Description"
```

## Testing
No automated test suite. Manual testing:
- Enable Debug Mode in Settings for fake data
- Test on both Intel and Apple Silicon Macs
- Verify 0 compilation warnings

## Release
Include `[release]` in commit message to trigger GitHub Actions release workflow.
