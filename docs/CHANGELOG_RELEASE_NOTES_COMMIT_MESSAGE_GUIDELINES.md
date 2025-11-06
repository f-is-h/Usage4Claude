# 如何编写 CHANGELOG，RELEASE NOTES，COMMIT MESSAGE

## CHANGELOG

参照项目根目录下 CHANGELOG.md 文件，编写最新版本的 CHANGELOG 说明。
提醒需要更新最下方处链接，如 [1.2.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.2.0

## RELEASE NOTES

**要求**: 
- 简洁不赘述
- 每个变更点使用一条说明文字
- 不同一变更点只出现一次

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
