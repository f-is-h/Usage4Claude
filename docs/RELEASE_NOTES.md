# Release Notes

面向用户的发布说明。发版时 CI 提取**当前版本段落**（`## [X.Y.Z]` 到下一个 `## [` 之间），
同时用于两处：

- **Sparkle 应用内更新弹窗**（注入 `appcast.xml` 的 `<description>`）
- **GitHub Release 正文**（拼接 `.github/RELEASE_TEMPLATE.md` 的固定段落）

因此这里**只写用户可感知的现象**：口语化、去技术词，可在条目末尾致谢
`(thanks @author, #N)`。完整技术变更（含内部重构、CI、安全加固）记录在
[CHANGELOG.md](./CHANGELOG.md)，那份不进 Sparkle。

> 版本号权威源仍是 CHANGELOG.md（与 Xcode `MARKETING_VERSION` 校验一致）。
> 发版时本文件必须有对应的 `## [X.Y.Z]` 段落，否则 Sparkle / Release 正文会为空。

## [3.4.0] - 2026-09-04

### Added
- **Menu bar icon size**: Pick Compact, Standard or Prominent in Settings → General → Display. Menu bar height and eyesight vary, so the icons no longer come in one fixed size
- **Codex reset announcement badge (Beta)**: A badge appears next to the Codex ring when OpenAI has publicly announced a pending global usage reset. It shows announcements only, never a prediction, and can be turned off in settings

### Changed
- **Brief network errors no longer blank the popover**: A rate limit or dropped connection now keeps your last usage on screen with a small notice on top, instead of replacing everything with an error page (thanks @KurtGood, #75)

### Fixed
- **Free Tier and Team accounts wrongly told to sign in again**: Plans without a usage dashboard were reported as a credential problem, sending people to re-enter credentials that were fine. They now get a clear message explaining the plan does not provide usage data (thanks @yairixStudio, #80; reported by @genu, #74 and @Yohan-Janolin, #83)
- **Signing in to Codex failing with a connection error**: The browser could come back to a closed door if the sign-in window was recreated mid-flow. If it still gets stuck, you can now paste the callback link to finish (thanks @realjoenguyen, #77)
- **Accounts signed out after switching during a refresh**: Switching accounts while usage was refreshing could write one account's renewed credentials into another's, signing both out for good. Renewed credentials now always go back to the account that requested them
- **"Go to Settings" button missing outside English and Chinese**: The button now appears for sign-in errors in every language
- **Menu bar icon resizing when data loaded**: The icon no longer changes size the moment usage data arrives

## [3.3.0] - 2026-07-14

### Added
- **German localization**: Full German UI translation, README, and language switcher entry (thanks @schaitl, #66)
- **Per-model weekly usage rows**: Show weekly usage for any number of models (e.g. Opus, Sonnet, Fable), no longer limited to two fixed slots (thanks @Springs-Tea, #67)
- **Claude OAuth manual paste fallback**: When browser sign-in gets stuck, paste the callback link to complete sign-in (thanks @jessicalynn, #68)

### Fixed
- **Codex usage window mislabeling**: The 5-hour/7-day usage windows are no longer mislabeled
- **Missed usage warning notifications**: Notifications now show even while the app is open
- **Codex sign-in expiring unexpectedly**: Fixed an issue that could log some Codex accounts out too early
- **Menu bar icon not updating**: The icon now updates immediately when switching between light and dark mode
