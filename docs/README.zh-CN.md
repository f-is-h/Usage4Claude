# Usage4Claude

[English](../README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md)

<div align="center">

<img src="images/icon@2x.png" width="256" alt="icon">

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange?style=flat-square)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/f-is-h/Usage4Claude?style=flat-square)](https://github.com/f-is-h/Usage4Claude/releases)

**一个优雅的 macOS 菜单栏应用，实时监控您的 Claude AI 使用情况。**

[功能特性](#-功能特性) • [下载安装](#-下载安装) • [使用指南](#-使用指南) • [常见问题](#-常见问题) • [支持项目](#-支持项目)

</div>

---

## ✨ 功能特性

### 🎯 核心功能

- **📊 实时监控** - 在菜单栏实时显示 Claude 订阅的5小时使用配额
- **🎨 智能色彩** - 根据使用率自动变色提醒（绿色/橙色/红色）
- **⏰ 精确计时** - 精确到分的配额重置时间显示
- **🔄 智能/固定刷新** - 智能4级自适应刷新或固定间隔（1/3/5/10分钟）
- **💻 原生体验** - 纯原生 macOS 应用，轻量且优雅

### 🎨 个性化

- **🕓 多种显示模式**
  - 仅显示百分比 - 简洁直观，无须点击即可查看
  - 仅显示图标 - 低调优雅，点击后显示详细信息
  - 图标 + 百分比 - 信息完整，视觉定位快速易识别

- **🌍 多语言支持**
  - English
  - 日本語
  - 简体中文
  - 繁体中文
  - 更多语言适配中…

### 🔧 便捷功能

- **⚙️ 可视化设置** - 无需修改代码，图形化配置所有选项
- **🆕 自动更新检查** - 及时获取最新版本和功能
- **👋 友好引导** - 首次启动提供详细的配置向导
- **… 菜单显示** - 多种菜单打开方式，详情页与右键

### 🔒 安全与隐私

- 🏠 **仅本地存储** - 所有数据仅存储在本地，绝不收集和上传任何个人信息
- 🔐 **Keychain保护** - 敏感信息使用 Keychain 存储，无明文密钥
- 📖 **开源透明** - 代码完全公开，任何人都可审计
- 🛡️ **沙盒防护** - 启用 App Sandbox，增强安全性

---

## 📸 截图预览

### 菜单栏显示效果

| 百分比模式 | 图标模式 | 组合模式 |
|:---:|:---:|:---:|
| <img src="images/taskbar.ring@2x.png" width="20" alt="ring"> | <img src="images/taskbar.icon@2x.png" width="20" alt="icon"> | <img src="images/taskbar@2x.png" width="50" alt="icon and ring"> |

**圆环颜色指示**：

🟢 **绿色**（0-69%）- 安全使用中

🟠 **橙色**（70-89%）- 注意用量

🔴 **红色**（90-100%）- 接近限制

### 详情窗口

<img src="images/detail.zh-CN@2x.png" width="290" alt="Detail Window">

### 设置界面

**通用设置** - 自定义显示，刷新和语言选项  
**认证信息** - 配置 Claude 账户认证信息  
**关于** - 版本信息和相关链接

### 欢迎界面

**设置认证信息** - 立即前往认证信息设置界面完成配置  
**稍后设置** - 关闭欢迎窗口，稍后可在设置界面中进行配置

---

## 💾 下载安装

### 方式一：下载预编译版本（推荐）

1. 前往 [Releases 页面](https://github.com/f-is-h/Usage4Claude/releases)
2. 下载最新版本的 `.dmg` 文件
3. 双击打开，将应用拖入「应用程序」文件夹
4. 首次运行时，右键点击应用选择「打开」（需要允许运行未签名应用）
5. 需要允许使用 Keychain 存储认证信息（版本更新后需要再次允许。授权窗口显示两次: 组织 ID, Session Key ）

### 方式二：从源码构建

#### 前置要求
- macOS 13.0 或更高版本
- Xcode 15.0 或更高版本
- Git

#### 构建步骤

```bash
# 克隆仓库
git clone https://github.com/f-is-h/Usage4Claude.git
cd Usage4Claude

# 在 Xcode 中打开
open Usage4Claude.xcodeproj

# 在 Xcode 中按 Cmd + R 运行
```

---

## 📖 使用指南

### 首次配置

1. **启动应用**  
   首次运行会显示欢迎界面

2. **配置认证信息**  
   点击「去设置认证信息」按钮

3. **获取必要信息**  
   - 点击「在浏览器中打开 Claude 用量页面」
   - 打开浏览器开发者工具（按 F12 或 Cmd + Option + I）
   - 切换到「网络」(Network) 标签
   - 刷新页面
   - 找到名为 `usage` 的请求
   - 查看请求头 (Headers)，找到：
     - `Cookie` 中的 `sessionKey=sk-ant-...` 值
     - URL 中的组织 ID（格式为 `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`）

4. **填写信息**  
   - 将组织 ID 粘贴到「Organization ID」输入框
   - 将 Session Key 粘贴到「Session Key」输入框
   - 配置完成后会自动开始监控

### 日常使用

- **默认显示** - 任务栏图标显示使用量百分比
- **查看详情** - 点击任务栏图标或百分比图标
- **显示菜单** - 在详情窗口点击「…」图标或者右键点击任务栏图标
- **检查更新** - 菜单 → 检查更新
- **退出应用** - 菜单 → 退出

### 刷新模式

**智能频率（推荐）**
- 根据使用情况自动调整刷新间隔
- 活跃模式（1分钟）- 正在使用 Claude 时快速刷新
- 静默模式（3/5/10分钟）- 静默时逐步减慢刷新
- 静默期间显著减少 API 调用（最多10倍）
- 检测到使用变化后立即恢复到1分钟刷新

**固定频率**
- **1分钟** - 推荐的持续监控
- **3分钟** - 平衡监控
- **5分钟** - 低频监控
- **10分钟** - 最少 API 调用

---

## ❓ 常见问题

<details>
<summary><b>Q: 应用显示"会话已过期"怎么办？</b></summary>

A: Session Key 会定期过期（通常几周到几个月），需要重新获取：
1. 打开设置 → 认证信息
2. 按照配置指南重新获取 Session Key
3. 粘贴新的 Session Key 即可

</details>

<details>
<summary><b>Q: 如何让应用开机自动启动？</b></summary>

A: 
1. 打开「系统设置」→「通用」→「登录项」
2. 点击「+」添加 Usage4Claude

</details>

<details>
<summary><b>Q: 应用占用多少系统资源？</b></summary>

A: 非常轻量：
- CPU 使用率：< 0.1%（空闲时）
- 内存占用：约 20MB
- 网络请求：每分钟仅 1 次

</details>

<details>
<summary><b>Q: 支持哪些 macOS 版本？</b></summary>

A: 需要 macOS 13.0 (Ventura) 或更高版本。支持 Intel 和 Apple Silicon (M1/M2/M3) 芯片。

</details>

<details>
<summary><b>Q: 为什么需要 Keychain 权限？</b></summary>

A: 
- Keychain 是 macOS 的系统级密码管理器
- 您的 Session Key 和 Organization ID 会被加密存储在 Keychain 中
- 这是 Apple 推荐的最安全的敏感信息存储方式
- 只有本应用可以访问这些信息，其它应用无权查看

</details>

<details>
<summary><b>Q: 我的数据安全吗？隐私如何保护？</b></summary>

**完全安全！** 

**数据存储：**
- 所有数据**仅**存储在您本地 Mac 上
- 不收集、不追踪、不统计任何信息
- 除了调用 Claude API 外无其他网络请求
- 不使用任何第三方服务

**认证信息安全：**
- Session Key 通过 macOS Keychain 加密（系统级加密）
- Keychain 使用 AES-256 加密 + 硬件保护（T2 / Secure Enclave）
- 仅本应用可访问您的凭证，其他应用无法读取
- 您可随时通过"钥匙串访问"应用撤销权限

**代码透明性：**
- 100% 开源
- 无混淆或隐藏功能
- 社区可审计和验证

**额外保护：**
- 启用 App Sandbox（限制系统访问）
- 无权访问您的文件、通讯录或其他应用
- 最小化权限（仅网络 + Keychain）

您可以通过GitHub查看源代码来验证这一切！

</details>

---

## 🛠 技术栈

本项目采用现代 macOS 原生技术栈构建：

- **语言**: Swift 5.0+
- **UI 框架**: SwiftUI + AppKit 混合
- **架构**: MVVM
- **网络**: URLSession
- **响应式**: Combine Framework
- **本地化**: 内置 i18n 支持
- **平台**: macOS 13.0+

---

## 🗺 路线图

### ✅ 已完成
- [x] 基础监控功能
- [x] 菜单栏实时显示
- [x] 圆形进度指示器
- [x] 智能颜色提醒
- [x] 实时倒计时
- [x] 菜单栏多种显示模式
- [x] 可视化设置界面
- [x] 多语言支持
- [x] 首次启动引导
- [x] 更新检查
- [x] 认证信息 Keychain 存储

### 短期计划
1. **功能增强**
    - 🚧 开机启动设置
    - 🚧 快捷键支持

2. **开发者**
    - 🚧 Shell 自动打包 DMG 
    - 🚧 GitHub Actions自动发布

### 中期计划
3. **显示优化**
    - 设置界面
    - 暗黑模式
    - 详情窗口 Focus 状态

5. **功能增加**
    - 7天使用量监控支持（OAuth・Opus）
    - 用量通知提醒
    - 更多语言本地化

### 长期愿景
5. **自动设置**
   - 浏览器插件自动获取认证信息
   - 认证信息自动设置

6. **更多显示方式**
   - 桌面小组件
   - 浏览器插件图标用量显示

7. **数据分析**
   - 历史使用记录
   - 趋势图表展示

8. **多平台支持**
   - iOS / iPadOS 版本
   - Apple Watch 版本
   - Windows 版本

---

## 🤝 贡献

欢迎所有形式的贡献！无论是新功能、Bug 修复还是文档改进。

详细的贡献指南，请参阅 [CONTRIBUTING.md](../CONTRIBUTING.md)。

### 如何贡献

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

### 贡献者

感谢所有为这个项目做出贡献的人！

<!-- ALL-CONTRIBUTORS-LIST:START -->
<!-- 这里将自动生成贡献者列表 -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## 📝 更新日志

详细的版本历史和更新内容，请参阅 [CHANGELOG.md](../CHANGELOG.md)。

---

## 💖 支持项目

如果这个项目对您有帮助，欢迎通过以下方式支持：

### ⭐ Star 项目
给项目一个 Star 是对我最大的鼓励！

### ☕ 请我喝杯咖啡

<!-- GitHub Sponsors -->
<!-- <a href="https://github.com/sponsors/f-is-h">
  <img src="https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?style=for-the-badge&logo=github" alt="GitHub Sponsor">
</a> -->

<!-- Ko-fi -->
<a href="https://ko-fi.com/1attle">
  <img src="https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=for-the-badge&logo=ko-fi" alt="Ko-fi">
</a>

<!-- Buy Me A Coffee -->
<!-- <a href="https://buymeacoffee.com/fish_">
  <img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee">
</a> -->

### 📢 分享项目
如果您喜欢这个项目，请分享给更多可能需要的人！

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

```
MIT License

Copyright (c) 2025 f-is-h

您可以自由地使用、复制、修改、合并、发布、分发、再许可和/或销售本软件的副本。
```

---

## 🙏 致谢

- 感谢 [Claude AI](https://claude.ai) 大部分代码均由 AI 编写
- 感谢所有贡献者和用户的支持
- 图标设计灵感来自 Claude AI 官方品牌

---

## 📞 联系方式

- **Issues**: [提交问题或建议](https://github.com/f-is-h/Usage4Claude/issues)
- **Discussions**: [参与讨论](https://github.com/f-is-h/Usage4Claude/discussions)
- **GitHub**: [@f-is-h](https://github.com/f-is-h)

---

## ⚖️ 免责声明

本项目是一个独立的第三方工具，与 Anthropic 或 Claude AI 没有官方关联。使用本软件时请遵守 Claude AI 的服务条款。

---

<div align="center">

**如果这个项目对您有帮助，请给一个 ⭐ Star！**

Made with ❤️ by [f-is-h](https://github.com/f-is-h)

[⬆ 回到顶部](#usage4claude)

</div>
