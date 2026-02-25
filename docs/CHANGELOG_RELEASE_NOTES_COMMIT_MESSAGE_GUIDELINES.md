# 如何编写 CHANGELOG，RELEASE NOTES，COMMIT MESSAGE

## 注意事项
以下注意事项适用于CHANGELOG，RELEASE NOTES和Commit Message的生成
- 如果一个功能是新增的（Added），那么对这个新功能的所有修改、调整、优化、bug修复都应该被视为该新功能的一部分，所以不应该单独在 Improved 或 Fixed 部分列出
- 生成英文内容的同时，请给出中文翻译
- 简洁不赘述
- 每个变更点使用一条说明文字
- 不同变更点只出现一次



## CHANGELOG

参照项目根目录下 CHANGELOG.md 文件，编写最新版本的 CHANGELOG 说明。
输出后提醒需要更新最下方处链接，如 [1.2.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.2.0

## RELEASE NOTES

**示例**:

标题：

`v1.2.0 - Settings UI Redesign`

内容：
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

## Commit Message

**要求**: 
- Commit Message 格式：
   ```
   <type>: <subject>
   
   <body>
   ```
- Type 类型：
   - feat: 新功能
   - fix: Bug 修复
   - docs: 文档更新
   - style: 代码格式调整
   - refactor: 重构
   - perf: 性能优化
   - test: 测试相关
   - chore: 构建/工具链更新

**示例**:
```
feat: redesign settings UI with modern card-based layout

- Card-style design for each settings section
- Toolbar-style navigation with icon and text labels
- Elegant gradient dividers between navigation tabs
- Enhanced visual hierarchy for better readability

Improved window management:
- Settings and Welcome windows now appear in Dock when opened
- Support Cmd+Tab switching for better workflow
- Automatically hide from Dock when closed
- Popover remains lightweight menu bar element
```

**注意**:

- 不要使用任何的Emoji
- 不要在结尾添加与 Generated with [Claude Code]  类似的任何文字
- 不要在结尾添加与 Co-Authored-By: Claude 类似的任何文字
