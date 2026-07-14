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
