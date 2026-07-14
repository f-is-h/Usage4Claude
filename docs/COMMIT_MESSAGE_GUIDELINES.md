# 如何编写 Commit Message

平时提交代码时遵循以下规范。

## 格式

```
<type>: <subject>

<body>
```

## Type 类型

- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具链更新

## 示例

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

## 注意事项

- Git commit message 只写英文，不要把中文翻译放入 commit message
- 不要使用任何 Emoji
- 不要出现多余的空行
- 不要在结尾添加与 Generated with [Claude Code] 类似的任何文字
- 不要在结尾添加与 Co-Authored-By: Claude 类似的任何文字
