# GitHub 首次发布完整指南

> Usage4Claude v1.0.0 首次上传到 GitHub 的详细步骤

**预计时间：** 30-45 分钟  
**难度：** 初级-中级

---

## 📋 目录

1. [前置准备](#前置准备)
2. [本地代码清理](#本地代码清理)
3. [Git 初始化](#git-初始化)
4. [创建 GitHub 仓库](#创建-github-仓库)
5. [推送代码](#推送代码)
6. [仓库基本设置](#仓库基本设置)
7. [创建社交预览图](#创建社交预览图)
8. [创建首个 Release](#创建首个-release)
9. [发布后验证](#发布后验证)
10. [常见问题](#常见问题)

---

## 前置准备

### ✅ 检查清单

在开始之前，确认以下内容：

- [ ] 已安装 Git（在终端执行 `git --version` 检查）
- [ ] 已有 GitHub 账号
- [ ] 已配置 Git 用户信息
- [ ] DMG 文件已创建：`Usage4Claude-v1.0.0.dmg`
- [ ] 所有代码已编译通过，无警告
- [ ] 已阅读并理解项目文档

### 🔧 配置 Git（如果还没配置）

```bash
# 设置用户名（替换为你的 GitHub 用户名）
git config --global user.name "f-is-h"

# 设置邮箱（替换为你的 GitHub 邮箱）
git config --global user.email "your-email@example.com"

# 验证配置
git config --global --list
```

---

## 本地代码清理

### 步骤 1：处理调试代码

在项目目录打开终端：

```bash
cd /path/to/Usage4Claude
```

#### 1.1 修改 ClaudeAPIService.swift

**文件位置：** `Usage4Claude/Services/ClaudeAPIService.swift`

找到以下 4 处 `print` 语句，改为条件编译：

**修改前：**
```swift
print("API Response: \(jsonString)")
print("⚠️ 收到HTML响应，可能被Cloudflare拦截")
print("HTTP Status Code: \(httpResponse.statusCode)")
print("Decoding error: \(error)")
```

**修改后：**
```swift
#if DEBUG
print("API Response: \(jsonString)")
#endif

#if DEBUG
print("⚠️ 收到HTML响应，可能被Cloudflare拦截")
#endif

#if DEBUG
print("HTTP Status Code: \(httpResponse.statusCode)")
#endif

#if DEBUG
print("Decoding error: \(error)")
#endif
```

#### 1.2 在 Xcode 中编译测试

- 打开 Xcode
- 按 `Cmd + B` 编译
- 确保 0 个警告，0 个错误

### 步骤 2：添加免责声明到 README

**编辑文件：** `/path/to/Usage4Claude/README.md`

在文件最底部（`Contact` 部分之后）添加：

```markdown
---

## ⚖️ Disclaimer

This is an independent third-party tool with no official affiliation with Anthropic or Claude AI. "Claude" is a trademark of Anthropic. This project is created for personal use and is not endorsed by or associated with Anthropic.

Please comply with Claude AI's Terms of Service when using this software.

---
```

### 步骤 3：确认敏感文件被忽略

```bash
# 检查证书文件是否被忽略
git status --ignored | grep .p12

# 应该看到：
# Usage4Claude-CodeSigning.p12

# 如果看到它在 "Untracked files" 中，说明 .gitignore 工作正常
```

---

## Git 初始化

### 步骤 4：初始化 Git 仓库

```bash
# 确保在项目根目录
cd /path/to/Usage4Claude

# 初始化 Git 仓库
git init

# 查看状态
git status
```

**预期输出：**
```
Initialized empty Git repository in /path/to/Usage4Claude/.git/
```

### 步骤 5：添加文件到 Git

```bash
# 添加所有文件（.gitignore 会自动排除不需要的）
git add .

# 查看将要提交的文件
git status
```

**检查：** 确保 `.p12` 文件**不在**列表中

### 步骤 6：首次提交

```bash
# 创建首次提交
git commit -m "feat: initial commit - Usage4Claude v1.0.0

- Real-time Claude Pro usage monitoring
- Multi-language support (EN/JA/ZH-CN/ZH-TW)
- Keychain security for credentials
- Auto-update checking
- Native macOS menu bar app"

# 验证提交
git log --oneline
```

**预期输出：**
```
abc1234 (HEAD -> main) feat: initial commit - Usage4Claude v1.0.0
```

### 步骤 7：创建和推送标签

```bash
# 创建版本标签
git tag -a v1.0.0 -m "Release v1.0.0 - Initial release"

# 查看标签
git tag -l
```

---

## 创建 GitHub 仓库

### 步骤 8：在 GitHub 创建仓库

1. **访问 GitHub**
   - 打开浏览器，访问 https://github.com
   - 登录你的账号

2. **创建新仓库**
   - 点击右上角 `+` → `New repository`
   - 或直接访问：https://github.com/new

3. **填写仓库信息**

   **Repository name:** `Usage4Claude`
   
   **Description:**
   ```
   Monitor your Claude Pro 5-hour usage quota in real-time from your macOS menu bar
   ```
   
   **Public/Private:** 选择 `Public`（开源项目）
   
   **其他选项：**
   - ❌ 不要勾选 "Add a README file"（我们已有 README）
   - ❌ 不要勾选 "Add .gitignore"（我们已有 .gitignore）
   - ❌ 不要选择 "Choose a license"（我们已有 LICENSE）

4. **点击 `Create repository`**

---

## 推送代码

### 步骤 9：连接到远程仓库

**GitHub 会显示类似这样的命令，但我们要用自己的：**

```bash
# 添加远程仓库（替换为你的用户名）
git remote add origin https://github.com/f-is-h/Usage4Claude.git

# 验证远程仓库
git remote -v

# 应该看到：
# origin  https://github.com/f-is-h/Usage4Claude.git (fetch)
# origin  https://github.com/f-is-h/Usage4Claude.git (push)
```

### 步骤 10：推送代码和标签

```bash
# 将默认分支重命名为 main（如果还不是）
git branch -M main

# 推送代码到 GitHub
git push -u origin main

# 推送标签
git push origin v1.0.0
```

**首次推送时可能需要登录：**
- 如果提示输入密码，使用 GitHub Personal Access Token（不是账号密码）
- 创建 Token：https://github.com/settings/tokens/new
  - 勾选 `repo` 权限
  - 复制 Token 并保存（只显示一次！）

**预期输出：**
```
Enumerating objects: 123, done.
Counting objects: 100% (123/123), done.
...
To https://github.com/f-is-h/Usage4Claude.git
 * [new branch]      main -> main
```

### 步骤 11：验证代码已上传

在浏览器中访问：
```
https://github.com/f-is-h/Usage4Claude
```

**检查：**
- ✅ 能看到所有文件
- ✅ README.md 正确显示
- ✅ 目录结构完整
- ✅ .p12 文件**不在**仓库中

---

## 仓库基本设置

### 步骤 12：设置 About 部分

1. **在仓库页面**（https://github.com/f-is-h/Usage4Claude）

2. **点击右侧的 ⚙️ 图标**（在 About 框右上角）

3. **填写信息：**

   **Description:** （简短描述）
   ```
   Monitor your Claude Pro 5-hour usage quota in real-time from your macOS menu bar
   ```
   
   **Website:** （留空或填写）
   ```
   https://github.com/f-is-h/Usage4Claude
   ```
   
   **Topics:** （添加标签，用空格分隔）
   ```
   macos
   swift
   swiftui
   menubar-app
   status-bar
   claude
   claude-ai
   monitoring
   productivity
   utilities
   macos-app
   native-app
   ```
   
   **其他选项：**
   - ✅ 勾选 "Releases"
   - ❌ 不勾选 "Packages"
   - ❌ 不勾选 "Deployments"

4. **点击 `Save changes`**

### 步骤 13：配置仓库 Features

1. **点击仓库顶部的 `Settings` 标签**

2. **在左侧菜单，停留在 `General` 页面**

3. **向下滚动到 `Features` 部分**

   **勾选以下选项：**
   - ✅ **Issues** - 允许用户报告 Bug
   - ✅ **Preserve this repository** - 存档历史（可选）
   - ✅ **Discussions** - 社区讨论（可选）
   - ❌ **Sponsorships** - 暂时不需要
   - ❌ **Projects** - 暂时不需要
   - ❌ **Wiki** - 不需要（文档在仓库中）

4. **保存设置**（自动保存）

### 步骤 14：配置 Pull Requests 设置

**在同一个 Settings → General 页面：**

1. **向下滚动到 `Pull Requests` 部分**

2. **配置合并选项：**
   - ✅ **Allow squash merging** - 保持提交历史清晰
   - ❌ **Allow merge commits** - 可选
   - ❌ **Allow rebase merging** - 可选

3. **勾选：**
   - ✅ **Automatically delete head branches** - PR 合并后自动删除分支

---

## 创建社交预览图

### 步骤 15：制作预览图

#### 选项 A：使用在线工具（推荐，简单）

1. **访问 Canva**
   - 网址：https://www.canva.com
   - 注册/登录（免费账号即可）

2. **创建设计**
   - 搜索 "GitHub Social Preview" 模板
   - 或手动创建：1280x640 像素

3. **设计内容**
   ```
   左侧：Usage4Claude 图标（放大）
   右侧：
   - 标题："Usage4Claude"
   - 副标题："Monitor Claude Usage"
   - 标语："Native macOS Menu Bar App"
   ```

4. **下载**
   - 格式：PNG
   - 质量：最高
   - 命名：`social-preview.png`

#### 选项 B：使用 Figma（更专业）

1. **访问 Figma**
   - 网址：https://www.figma.com
   - 注册/登录（免费）

2. **新建文件**
   - Frame 尺寸：1280x640px

3. **设计内容**
   - 导入 `docs/images/icon@2x.png` 作为图标
   - 添加文字和装饰
   - 使用渐变背景（可选）

4. **导出**
   - File → Export → PNG
   - 2x 或 3x（高清）
   - 命名：`social-preview.png`

#### 选项 C：跳过此步骤（不推荐）

GitHub 会自动生成预览，但效果一般。

### 步骤 16：上传预览图

1. **回到 GitHub 仓库页面**
   - 访问：https://github.com/f-is-h/Usage4Claude

2. **进入 Settings**
   - 点击顶部 `Settings` 标签

3. **找到 Social preview**
   - 在 `General` 页面向下滚动
   - 找到 `Social preview` 部分

4. **上传图片**
   - 点击 `Upload an image...`
   - 选择 `social-preview.png`
   - 等待上传完成

5. **验证**
   - 图片应该显示在预览框中
   - 尺寸要求：至少 640x320px，推荐 1280x640px

---

## 创建首个 Release

### 步骤 17：准备 DMG 文件

**确认 DMG 位置：**
```bash
ls -lh /path/to/Usage4Claude/build/Usage4Claude1.0.0/Usage4Claude-v1.0.0.dmg
```

**检查文件大小：**（应该在 10-30MB 之间）

### 步骤 18：在 GitHub 创建 Release

1. **访问 Releases 页面**
   ```
   https://github.com/f-is-h/Usage4Claude/releases
   ```

2. **点击 `Draft a new release`** 或 `Create a new release`

3. **填写 Release 信息**

   **Choose a tag:**
   - 选择 `v1.0.0`（我们之前创建的标签）
   - 如果没有，输入 `v1.0.0` 并选择 "Create new tag: v1.0.0 on publish"

   **Target:**
   - 选择 `main` 分支

   **Release title:**
   ```
   Usage4Claude v1.0.0 - Initial Release
   ```

   **Description:** （复制以下内容）

   ```markdown
   ## 🎉 First Release!

   This is the first official release of Usage4Claude - a native macOS menu bar app for monitoring Claude Pro's 5-hour usage quota.

   ### ✨ Features

   **Core Functionality**
   - 📊 Real-time usage monitoring with live percentage display
   - 🎨 Smart color-coded alerts (green/orange/red)
   - ⏰ Precise countdown to quota reset
   - 🔄 Auto-refresh (configurable: 30s/1min/5min)

   **Personalization**
   - 🕓 Three display modes (percentage/icon/combined)
   - 🌍 Multi-language support (English, Japanese, Simplified Chinese, Traditional Chinese)
   - ⚙️ Visual settings interface
   - 👋 First-launch welcome wizard

   **Security & Convenience**
   - 🔒 Keychain encryption for sensitive data
   - 🆕 Automatic update checking
   - 📱 Detailed usage view window
   - 🎯 One-click access to Claude usage page

   ### 📦 Installation

   1. Download `Usage4Claude-v1.0.0.dmg` below
   2. Open the DMG file
   3. Drag app to Applications folder
   4. Right-click and select "Open" on first launch
   5. Follow the welcome wizard to configure

   ### ⚠️ Requirements

   - macOS 13.0 (Ventura) or later
   - Claude Pro subscription
   - Valid Claude API credentials

   ### 🐛 Known Issues

   - App is not notarized (requires manual authorization on first launch)
   - Authentication credentials must be obtained from browser dev tools

   ### 📝 Documentation

   - [Complete README](https://github.com/f-is-h/Usage4Claude#readme)
   - [User Guide](https://github.com/f-is-h/Usage4Claude#-user-guide)
   - [FAQ](https://github.com/f-is-h/Usage4Claude#-faq)
   - [Contributing](https://github.com/f-is-h/Usage4Claude/blob/main/CONTRIBUTING.md)

   ### 🙏 Acknowledgments

   Thanks to Claude AI for inspiration and assistance in development!

   ---

   **If you find this helpful, please give it a ⭐ Star!**
   ```

4. **上传 DMG 文件**
   - 找到页面底部的 "Attach binaries by dropping them here or selecting them."
   - 拖拽或点击选择 `Usage4Claude-v1.0.0.dmg`
   - 等待上传完成（进度条显示）

5. **设置 Release 选项**
   - ✅ **勾选 "Set as the latest release"**
   - ❌ **不勾选 "Set as a pre-release"**（除非这是测试版）
   - ❌ **不勾选 "Create a discussion for this release"**（可选）

6. **发布！**
   - 点击绿色按钮 **`Publish release`**

### 步骤 19：验证 Release

**发布成功后会自动跳转到 Release 页面。**

**检查清单：**
- ✅ Release 标题显示正确
- ✅ 版本标签显示 `v1.0.0`
- ✅ Release Notes 格式正确
- ✅ DMG 文件可以下载
- ✅ 文件大小显示正确（10-30MB）
- ✅ 显示为 "Latest" 标签

**测试下载：**
1. 点击 DMG 文件名下载
2. 等待下载完成
3. 尝试打开验证文件未损坏

---

## 发布后验证

### 步骤 20：完整功能测试

#### 20.1 检查仓库首页

访问：https://github.com/f-is-h/Usage4Claude

**确认：**
- ✅ README 正确渲染
- ✅ 徽章显示正常（版本、许可证等）
- ✅ 截图正常显示
- ✅ About 部分信息完整
- ✅ Topics 标签显示
- ✅ Release 徽章显示最新版本

#### 20.2 测试所有链接

**在 README 中点击测试：**
- [ ] 多语言版本链接（简中/繁中/日语）
- [ ] 截图图片链接
- [ ] 各个章节的内部锚点链接
- [ ] License 文件链接
- [ ] Issues 链接
- [ ] Discussions 链接
- [ ] Release 页面链接

#### 20.3 测试下载安装

**在另一台 Mac 上（或新用户账户）：**

1. 从 GitHub Release 下载 DMG
2. 打开 DMG
3. 拖拽安装
4. 首次打开（右键→打开）
5. 测试所有功能

**记录任何问题！**

### 步骤 21：检查应用内更新功能

1. 打开应用
2. 点击菜单 → "Check for Updates"
3. **应该提示：** "You're up to date! (1.0.0)"

**如果提示有新版本，说明：**
- UpdateChecker 中的版本比较有问题
- 或者 GitHub API 延迟（等待几分钟再试）

---

## 常见问题

### Q1: 推送时提示 "Permission denied"

**原因：** SSH 密钥未配置或 HTTPS 认证失败

**解决方案 A：使用 HTTPS + Personal Access Token**

1. 生成 Token：https://github.com/settings/tokens/new
   - 勾选 `repo` 权限
   - 点击 "Generate token"
   - **复制 Token 并保存**（只显示一次！）

2. 推送时输入：
   - Username: 你的 GitHub 用户名
   - Password: 粘贴刚才的 Token（不是账号密码！）

**解决方案 B：配置 SSH 密钥**

```bash
# 生成 SSH 密钥
ssh-keygen -t ed25519 -C "your-email@example.com"

# 添加到 GitHub
cat ~/.ssh/id_ed25519.pub
# 复制输出，粘贴到 GitHub Settings → SSH Keys

# 修改远程仓库为 SSH
git remote set-url origin git@github.com:f-is-h/Usage4Claude.git
```

### Q2: 推送后 README 图片不显示

**原因：** 图片路径错误

**检查：**
- README 中的图片路径是否正确
- 图片文件是否在 `docs/images/` 目录
- 图片文件是否已提交到 Git

**正确的路径格式：**
```markdown
<!-- 相对路径 -->
![icon](docs/images/icon@2x.png)

<!-- 或 GitHub 完整路径 -->
![icon](https://raw.githubusercontent.com/f-is-h/Usage4Claude/main/docs/images/icon@2x.png)
```

### Q3: Topics 标签添加后不显示

**原因：** 刷新延迟

**解决：**
1. 等待 1-2 分钟
2. 刷新页面（Cmd+R）
3. 清除浏览器缓存

### Q4: Release 创建后无法下载 DMG

**原因：** 文件上传失败或网络问题

**解决：**
1. 检查文件大小是否合理（不能太大，GitHub 限制 2GB）
2. 重新上传 DMG：
   - Edit release
   - 删除旧文件
   - 重新上传
   - Update release

### Q5: 社交预览图上传后不更新

**原因：** GitHub CDN 缓存

**解决：**
1. 等待 10-15 分钟
2. 在隐私浏览模式测试分享链接
3. 使用社交媒体调试工具：
   - Twitter: https://cards-dev.twitter.com/validator
   - Facebook: https://developers.facebook.com/tools/debug/

### Q6: 更新检查功能找不到 Release

**原因：** 
- Release 刚创建，GitHub API 延迟
- UpdateChecker 代码中的仓库信息错误

**检查：**
```swift
// 在 UpdateChecker.swift 中确认：
private let repoOwner = "f-is-h"  // 正确
private let repoName = "Usage4Claude"  // 正确
```

**测试 API：**
```bash
curl https://api.github.com/repos/f-is-h/Usage4Claude/releases/latest
```

应该返回 JSON，包含 `tag_name: "v1.0.0"`

### Q7: .gitignore 没有生效，敏感文件被提交了

**如果已经提交了 .p12 文件：**

```bash
# 从 Git 中移除但保留本地文件
git rm --cached Usage4Claude-CodeSigning.p12

# 提交移除操作
git commit -m "chore: remove certificate file from git"

# 推送
git push origin main
```

**如果已经推送到 GitHub（严重！）：**

需要清理 Git 历史：
```bash
# 使用 git-filter-repo（需要先安装）
brew install git-filter-repo

# 从历史中移除文件
git-filter-repo --invert-paths --path Usage4Claude-CodeSigning.p12

# 强制推送（危险操作！确认无误后执行）
git push origin main --force
```

---

## 🎉 完成！

恭喜！您的项目已经成功发布到 GitHub！

### 接下来做什么？

#### 立即（发布后 1 小时内）
- [ ] 自己测试下载和安装
- [ ] 在社交媒体分享
- [ ] 通知测试用户

#### 本周
- [ ] 监控 GitHub Issues
- [ ] 回复用户问题
- [ ] 收集反馈

#### 下周
- [ ] 制作演示 GIF/视频
- [ ] 写一篇介绍博客
- [ ] 提交到相关社区（Reddit r/MacApps 等）

#### 持续
- [ ] 定期检查 Issues 和 Discussions
- [ ] 收集功能建议
- [ ] 规划下一个版本

---

## 📚 相关资源

- **GitHub 官方文档：** https://docs.github.com
- **Git 教程：** https://git-scm.com/book/zh/v2
- **语义化版本：** https://semver.org/lang/zh-CN/
- **Keep a Changelog：** https://keepachangelog.com/zh-CN/

---

## 💡 小贴士

1. **不要害怕犯错**
   - Git 有版本控制，可以回退
   - GitHub 有编辑功能，可以修改
   - 社区很友好，会帮助新手

2. **保持更新**
   - 定期发布小版本
   - 及时修复 Bug
   - 倾听用户反馈

3. **享受过程**
   - 开源是学习的好机会
   - 社区贡献很有成就感
   - 不要给自己太大压力

---

**祝发布顺利！** 🚀

*如有问题，请查阅项目中的其他文档或在 GitHub Discussions 提问。*
