# 如何编写 CHANGELOG 与 Release Notes

## 注意事项

以下注意事项适用于 CHANGELOG 与 Release Notes 的生成：

- 如果一个功能是新增的（Added），那么对这个新功能的所有修改、调整、优化、bug 修复都应视为该新功能的一部分，不应单独在 Improved 或 Fixed 部分列出
- 生成英文内容的同时，请给出中文翻译
- 简洁不赘述
- 每个变更点使用一条说明文字
- 不同变更点只出现一次

## CHANGELOG

参照项目根目录下 `CHANGELOG.md` 文件，编写最新版本的 CHANGELOG 说明。
输出后提醒需要更新最下方的链接，如 `[1.2.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.2.0`

> **CHANGELOG 是 Sparkle 更新说明的唯一来源。** 发版时 CI 会自动提取当前版本段落
> （`## [X.Y.Z]` 到下一个 `## [` 之间的内容），注入 `appcast.xml` 的 `<description>`。
> 用户在应用内"检查更新"弹窗里看到的就是这段内容，所以 CHANGELOG 必须写清楚、面向用户。

## Release Notes

GitHub Release 的说明文字。现在由 CI **自动生成并直接发布**（不再是草稿）：

- **标题**：取自发版 commit 第一行（发版流程见 [DAILY_RELEASE_WORKFLOW.md](./DAILY_RELEASE_WORKFLOW.md)），例如 `v3.2.2 - Update Reliability Fix`。
- **正文**：默认取当前版本的 CHANGELOG 段落作为兜底，再拼上固定的"📦 Installation"等模板内容（模板见 `.github/RELEASE_TEMPLATE.md`）。
- **精修**：若想让 Release Notes 比 CHANGELOG 更丰富（总览段落、emoji 标题等），可在 release **发布后**到 GitHub 网页手工编辑覆盖。这不影响 Sparkle 更新弹窗（它读 CHANGELOG，与 GitHub Release Notes 无关）。

因此，**日常发版无需手动撰写 Release Notes**——写好 CHANGELOG 即可。只有在希望 Release 页面有更精致文案时，才需要事后手工精修。

### 标题示例

`v1.2.0 - Settings UI Redesign`

### 手工精修正文时的格式示例

```markdown
## 🎨 UI Improvements & Better Window Management

This release brings a refined user interface and improved window management for a more professional and intuitive experience.

### Changed
- **Modern Card-Based Settings UI**: Complete redesign of the settings interface
  - Card-style design for each settings section
  - Toolbar-style navigation with icon and text labels
  - Elegant gradient dividers between navigation tabs
  - Enhanced visual hierarchy for better readability

### Improved
- **Independent Window Experience**: Settings and Welcome windows now behave like standalone apps
  - Windows appear in Dock when opened (can use Cmd+Tab to switch)
  - Automatically hide from Dock when closed to maintain menu bar simplicity
  - Popover remains lightweight without affecting Dock
  - Better window management for improved workflow
```

## 相关文档

- [Commit Message 编写指南](./COMMIT_MESSAGE_GUIDELINES.md)
- [日常发版流程](./DAILY_RELEASE_WORKFLOW.md)
