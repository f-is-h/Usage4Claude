# GitHub 后续版本发布指南

> Usage4Claude 功能更新、Bug 修复版本发布流程

**预计时间：** 15-30 分钟  
**难度：** 初级

---

## 📋 目录

1. [版本规划](#版本规划)
2. [代码准备](#代码准备)
3. [版本号更新](#版本号更新)
4. [更新 CHANGELOG](#更新-changelog)
5. [Git 提交和标签](#git-提交和标签)
6. [创建 Release](#创建-release)
7. [发布后验证](#发布后验证)
8. [快速参考](#快速参考)

---

## 版本规划

### 确定版本号

根据改动类型选择合适的版本号（遵循语义化版本 Semver）：

| 改动类型 | 版本号变化 | 示例 | 说明 |
|---------|-----------|------|------|
| **重大更新** | 主版本号 +1 | 1.0.0 → 2.0.0 | 不兼容的 API 改动 |
| **新功能** | 次版本号 +1 | 1.0.0 → 1.1.0 | 向下兼容的功能新增 |
| **Bug 修复** | 修订号 +1 | 1.0.0 → 1.0.1 | 向下兼容的问题修正 |

**本次示例：**
- 当前版本：`1.0.0`
- 改动内容：修改刷新间隔选项（30秒→1分钟，1分钟→3分钟），默认值改为3分钟
- 改动类型：Bug 修复（解决了默认一分钟设置下潜在的导致请求超限问题）
- 新版本号：`1.0.1`（修订号 +1）

### ✅ 检查清单

发布前确认：

- [ ] 所有改动已完成并测试通过
- [ ] 代码编译无错误、无警告
- [ ] 所有多语言文件已同步更新
- [ ] 本地测试所有功能正常
- [ ] 在 Xcode 中更新版本号
- [ ] 准备好 Release Notes 描述

---

## 代码准备

### 步骤 1：确认所有改动

```bash
# 切换到项目目录
cd /Users/iMac/Coding/Projects/Usage4Claude

# 查看当前状态
git status

# 查看改动详情
git diff
```

### 步骤 2：最终测试

1. **在 Xcode 中编译**
   ```
   Cmd + B (编译)
   Cmd + R (运行)
   ```

2. **功能完整性测试**
   
   - ✅ 数据刷新正常
   - ✅ 菜单栏图标正常
   - ✅ 弹出窗口显示正常
   - ✅ 设置窗口各标签正常

---

## 版本号更新

### 步骤 3：更新 Info.plist

**文件位置：** `Usage4Claude.xcodeproj/project.pbxproj`

**在 Xcode 中操作（推荐）：**

1. 在 Xcode 中打开项目
2. 选择项目名称（最上方的蓝色图标）
3. 选择 `Usage4Claude` Target
4. 切换到 `General` 标签
5. 在 `Identity` 部分找到：
   - **Version:** 改为 `1.0.1`
   - **Build:** 改为 `1`（新版本从 1 开始，或递增）

**或者手动编辑：**

```bash
# 在项目中搜索 MARKETING_VERSION
# 修改为新版本号 1.0.1
```

---

## 更新 CHANGELOG

### 步骤 4：编辑 CHANGELOG.md

**文件位置：** `/Users/iMac/Coding/Projects/Usage4Claude/CHANGELOG.md`

在文件顶部添加新版本记录（**保持 Keep a Changelog 格式**）：

```markdown
# Changelog

All notable changes to Usage4Claude will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-10-24

### Fixed
- Fixed potential "Request Exceeded" errors by optimizing refresh intervals
- Adjusted default refresh interval from 1 minute to 3 minutes for better API rate limit compliance
- Modified available refresh options to more conservative values (1min, 3min, 5min)
- Updated all localization files for adjusted refresh interval options

## [1.0.0] - 2025-10-23

### Added
- Initial release
- Real-time Claude Pro usage monitoring
- Multi-language support (EN/JA/ZH-CN/ZH-TW)
- ...（之前的内容保持不变）
```

**格式说明：**
- `## [版本号] - 日期`
- 使用以下类型标记：
  - `Added` - 新功能
  - `Changed` - 功能改动
  - `Deprecated` - 即将废弃的功能
  - `Removed` - 已移除的功能
  - `Fixed` - Bug 修复
  - `Security` - 安全相关改动

---

## Git 提交和标签

### 步骤 5：提交改动

```bash
# 查看待提交的文件
git status

# 添加所有改动
git add .

# 创建提交（使用 Conventional Commits 格式）
git commit -m "fix: resolve Request Exceeded errors with optimized refresh intervals

- Remove 30-second refresh option (too aggressive)
- Add 3-minute refresh option (better balance)
- Change default from 1 minute to 3 minutes
- Update all localization files (EN/JA/ZH-Hans/ZH-Hant)
- Reduce risk of hitting API rate limits"

# 查看提交历史
git log --oneline -3
```

**Commit Message 格式：**
```
<type>: <subject>

<body>
```

**Type 类型：**

- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具链更新

### 步骤 6：创建 Git 标签

```bash
# 创建带注释的标签
git tag -a v1.0.1 -m "fix: resolve Request Exceeded errors with optimized refresh intervals

- Remove 30-second refresh option (too aggressive)
- Add 3-minute refresh option (better balance)
- Change default from 1 minute to 3 minutes
- Update all localization files (EN/JA/ZH-Hans/ZH-Hant)
- Reduce risk of hitting API rate limits"

# 验证标签
git tag -l
git show v1.0.1
```

### 步骤 7：推送到 GitHub

```bash
# 推送代码
git push origin main

# 推送标签
git push origin v1.0.1
```

**预期输出：**
```
To https://github.com/f-is-h/Usage4Claude.git
   abc1234..def5678  main -> main
To https://github.com/f-is-h/Usage4Claude.git
 * [new tag]         v1.0.1 -> v1.0.1
```

---

## 创建 Release

### 步骤 8：构建新的 DMG

**在 Xcode 中：**

1. 选择 `Product` → `Archive`
2. 等待构建完成
3. 在 Organizer 中选择刚才的 Archive
4. 点击 `Distribute App` → `Custom` → `Copy App`
5. 导出到 `build/Usage4Claude-1.0.1/` 目录
6. 创建 DMG（参考构建文档）

**最终文件：**
```
/Users/iMac/Coding/Projects/Usage4Claude/build/Usage4Claude-1.0.1/Usage4Claude-v1.0.1.dmg
```

### 步骤 9：准备 Release Notes

**标题：**
```
Usage4Claude v1.0.1 - Fix Request Rate Limiting
```

**描述内容：**

````markdown
## 🐛 Bug Fix Release

This release addresses potential "Request Exceeded" errors by adjusting refresh intervals to better comply with API rate limits.

### Fixed
- 🔧 **Fixed "Request Exceeded" errors**: Optimized refresh intervals to prevent hitting rate limits
- 🔧 **Adjusted default interval**: Changed from 1 minute to **3 minutes** for safer API usage
- 🔧 **Updated refresh options**: More conservative choices (1min, 3min, 5min)
  - Removed: 30-second option (too aggressive)
  - Added: 3-minute option (better balance)
- 🌍 Updated all localization files (English, Japanese, Simplified Chinese, Traditional Chinese)

### Technical Details
- Better compliance with Claude API rate limits
- Existing users: Your current settings will be preserved
- New users: Start with the safer 3-minute default
- No breaking changes - all existing functionality remains the same

### 📦 Installation

**For New Users:**
1. Download `Usage4Claude-v1.0.1.dmg` below
2. Open the DMG file
3. Drag app to Applications folder
4. Right-click and select "Open" on first launch

**For Existing Users:**
1. Download the new version
2. Replace the old app in Applications
3. Your settings (including current refresh interval) will be preserved

### 📝 Full Changelog
See [CHANGELOG.md](https://github.com/f-is-h/Usage4Claude/blob/main/CHANGELOG.md) for complete version history.

### 🐛 Bug Reports
Found an issue? Please [open an issue](https://github.com/f-is-h/Usage4Claude/issues/new) on GitHub.

---

**Previous Version:** [v1.0.0](https://github.com/f-is-h/Usage4Claude/releases/tag/v1.0.0)
````

### 步骤 10：在 GitHub 创建 Release

1. **访问 Releases 页面**
   ```
   https://github.com/f-is-h/Usage4Claude/releases
   ```

2. **点击 `Draft a new release`**

3. **填写信息：**

   **Choose a tag:**
   - 选择 `v1.0.1`（应该在下拉列表中）

   **Target:**
   - 保持 `main` 分支

   **Release title:**
   ```
   Usage4Claude v1.0.1 - Fix Request Rate Limiting
   ```

   **Description:**
   - 粘贴上面准备的 Release Notes

4. **上传文件：**
   
   - 拖拽 `Usage4Claude-v1.0.1.dmg` 到附件区域
   - 等待上传完成
   
5. **Release 选项：**
   - ✅ **Set as the latest release**
   - ❌ 不勾选 "Set as a pre-release"

6. **点击 `Publish release`**

---

## 发布后验证

### 步骤 11：检查 Release

**访问 Release 页面验证：**
```
https://github.com/f-is-h/Usage4Claude/releases/tag/v1.0.1
```

**检查清单：**
- [ ] Release 标题正确显示
- [ ] Tag `v1.0.1` 正确
- [ ] Release Notes 格式正确
- [ ] DMG 文件可下载
- [ ] 显示 "Latest" 标签
- [ ] 文件大小合理

### 步骤 12：测试更新检查

**在旧版本应用中：**

1. 打开 Usage4Claude v1.0.0
2. 点击菜单 → `Check for Updates`
3. **应该提示：** "New Version Available! Latest: 1.0.1, Current: 1.0.0"
4. 点击 "Download Update" 应该跳转到 Release 页面

**如果没有检测到更新：**
- 等待 5-10 分钟（GitHub API 可能有延迟）
- 检查网络连接
- 手动访问 Release 页面确认发布成功

### 步骤 13：测试新版本安装

1. 下载 `Usage4Claude-v1.0.1.dmg`
2. 安装到 Applications
3. 替换旧版本
4. 启动应用
5. **验证：**
   - [ ] 版本号显示为 1.0.1（在 About 页面）
   - [ ] 刷新频率选项正确（1分钟、3分钟、5分钟）
   - [ ] 默认值为3分钟
   - [ ] 所有功能正常工作

### 步骤 14：更新文档链接（如需要）

如果在其他地方引用了版本号或下载链接，记得更新：

- [ ] 个人网站
- [ ] 博客文章
- [ ] 社交媒体帖子
- [ ] 相关论坛/社区

---

## 快速参考

### 完整发布流程（命令速查）

```bash
# 1. 确认当前状态
git status
git diff

# 2. 提交改动
git add .
git commit -m "feat: your commit message"

# 3. 创建标签
git tag -a v1.0.1 -m "Release v1.0.1"

# 4. 推送
git push origin main
git push origin v1.0.1

# 5. 在 GitHub 创建 Release（Web 界面）
# 6. 上传 DMG 文件
# 7. 发布
```

### 版本号规则速查

| 改动 | 示例 | 说明 |
|-----|------|------|
| 重大更新 | 1.0.0 → 2.0.0 | 不兼容改动 |
| 新功能 | 1.0.0 → 1.1.0 | 兼容的功能添加 |
| Bug 修复 | 1.0.0 → 1.0.1 | 兼容的修复 |
| 多个修复 | 1.0.1 → 1.0.2 | 多个小修复 |
| 功能+修复 | 1.0.0 → 1.1.0 | 按最高优先级 |

### Commit Message 模板

```bash
# 新功能
git commit -m "feat: add new feature description"

# Bug 修复
git commit -m "fix: resolve issue with specific problem"

# 文档更新
git commit -m "docs: update README with new instructions"

# 性能优化
git commit -m "perf: improve data fetching performance"

# 代码重构
git commit -m "refactor: restructure settings management"
```

### 常用 Git 命令

```bash
# 查看状态
git status
git diff
git log --oneline -5

# 查看标签
git tag -l
git show v1.0.1

# 撤销操作
git restore <file>              # 撤销工作区改动
git restore --staged <file>     # 取消暂存
git reset --soft HEAD~1         # 撤销上次提交（保留改动）

# 修改上次提交
git commit --amend -m "new message"

# 删除远程标签（谨慎！）
git tag -d v1.0.1               # 删除本地标签
git push origin :refs/tags/v1.0.1  # 删除远程标签
```

---

## 📝 Release Notes 模板

### 功能更新版本（次版本）

```markdown
## 🎉 What's New

### Added
- ✨ New feature description
- 🎨 UI improvement description

### Changed
- 🔄 Changed behavior description
- ⚡ Performance improvement

### Fixed
- 🐛 Bug fix description

### 📦 Installation
[Installation instructions]

### 📝 Full Changelog
See [CHANGELOG.md]

---

**Previous Version:** [v1.0.0]
```

### Bug 修复版本（修订号）

```markdown
## 🐛 Bug Fixes

This is a maintenance release with bug fixes and stability improvements.

### Fixed
- 🔧 Fixed issue with [specific problem]
- 🔧 Resolved crash when [scenario]
- 🔧 Corrected display issue in [location]

### 📦 Installation
[Installation instructions]

---

**Previous Version:** [v1.0.0]
```

### 重大更新版本（主版本）

```markdown
## 🚀 Major Update!

This is a major release with significant changes and improvements.

### ⚠️ Breaking Changes
- 🔴 [Description of incompatible change]
- 🔴 [Migration guide if needed]

### Added
- ✨ [New major feature]
- ✨ [Another feature]

### Changed
- 🔄 [Major change]

### Removed
- ❌ [Deprecated feature removed]

### Migration Guide
[How to upgrade from previous version]

---

**Previous Version:** [v1.x.x]
```

---

## 🎯 最佳实践

### 发布频率建议

- **Bug 修复（patch）：** 发现严重问题后尽快发布
- **小功能（minor）：** 累积 2-5 个功能后发布
- **大更新（major）：** 谨慎规划，充分测试

### 发布时机

**推荐：**
- ✅ 工作日发布（周二-周四最佳）
- ✅ 避免周五发布（周末无法及时处理问题）
- ✅ 避免节假日发布

**发布前：**
- 确保有时间处理可能的问题
- 通知测试用户帮助验证
- 准备好回退方案

### 版本号建议

**稳定递增：**
```
1.0.0 → 1.0.1 → 1.0.2 → 1.1.0 → 1.1.1 → 2.0.0
```

**不要跳过：**
```
❌ 1.0.0 → 1.2.0 (跳过 1.1.0)
❌ 1.0.0 → 1.0.3 (跳过 1.0.1, 1.0.2)
```

---

## 🆘 问题排查

### 问题：更新检查功能检测不到新版本

**排查步骤：**

1. **验证 Release 已发布**
   ```bash
   curl -s https://api.github.com/repos/f-is-h/Usage4Claude/releases/latest | grep tag_name
   ```
   应该显示 `"tag_name": "v1.0.1"`

2. **检查 UpdateChecker 代码**
   ```swift
   // 确认仓库信息正确
   private let repoOwner = "f-is-h"
   private let repoName = "Usage4Claude"
   ```

3. **检查版本比较逻辑**
   - 确保版本号格式正确（vX.Y.Z）
   - 测试版本比较函数

4. **等待 GitHub API 更新**
   - API 可能有 5-15 分钟延迟
   - 尝试清除应用缓存

### 问题：DMG 文件上传失败

**可能原因：**
- 文件太大（>2GB）
- 网络不稳定
- 浏览器问题

**解决方案：**
1. 检查文件大小：`ls -lh Usage4Claude-v1.0.1.dmg`
2. 尝试其他浏览器
3. 使用 GitHub CLI 上传：
   ```bash
   gh release upload v1.0.1 Usage4Claude-v1.0.1.dmg
   ```

### 问题：推送标签冲突

**错误信息：**
```
error: tag 'v1.0.1' already exists
```

**解决：**
```bash
# 删除本地标签
git tag -d v1.0.1

# 重新创建
git tag -a v1.0.1 -m "Release v1.0.1"

# 如果远程也有，先删除远程标签
git push origin :refs/tags/v1.0.1

# 然后推送新标签
git push origin v1.0.1
```

---

## 📚 相关资源

- **语义化版本规范：** https://semver.org/lang/zh-CN/
- **Keep a Changelog：** https://keepachangelog.com/zh-CN/
- **Conventional Commits：** https://www.conventionalcommits.org/zh-hans/
- **GitHub Release 文档：** https://docs.github.com/en/repositories/releasing-projects-on-github

---

## ✅ 发布后清单

完成发布后，记得：

**立即：**
- [ ] 验证 Release 页面正常
- [ ] 测试下载和安装
- [ ] 测试更新检查功能
- [ ] 在 Discussions 或社交媒体公告

**24小时内：**
- [ ] 监控 GitHub Issues
- [ ] 回复用户反馈
- [ ] 修复紧急问题（如有）

**本周：**

- [ ] 收集用户反馈
- [ ] 规划下个版本
- [ ] 更新路线图

---

**祝发布顺利！** 🎉

*遇到问题？查看 [第一次发布指南](GITHUB_FIRST_TIME_RELEASE_GUIDE.md) 或在 GitHub Issues 提问。*
