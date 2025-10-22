# Usage4Claude 手动打包发布指南

> 详细步骤：从编译到发布 GitHub Release

## 📋 目录

1. [准备工作](#准备工作)
2. [步骤1：在 Xcode 中编译打包](#步骤1在xcode中编译打包)
3. [步骤2：安装 create-dmg 工具](#步骤2安装create-dmg工具)
4. [步骤3：创建 DMG 安装包](#步骤3创建dmg安装包)
5. [步骤4：测试 DMG](#步骤4测试dmg)
6. [步骤5：发布到 GitHub](#步骤5发布到github)
7. [常见问题](#常见问题)

---

## 准备工作

### 环境要求
- ✅ macOS 13.0 或更高版本
- ✅ Xcode 15.0 或更高版本
- ✅ 已安装Homebrew（用于安装create-dmg）

### 版本号规划
在发布前，建议先规划好版本号，遵循语义化版本规范：
- **主版本号(Major)**: 不兼容的API修改 → `2.0.0`
- **次版本号(Minor)**: 向下兼容的功能新增 → `1.1.0`
- **修订号(Patch)**: 向下兼容的问题修复 → `1.0.1`

示例：
- 第一个正式版本：`v1.0.0`
- 修复bug后：`v1.0.1`
- 添加新功能：`v1.1.0`

---

## 步骤1：在Xcode中编译打包

### 1.1 清理之前的构建

在Xcode中执行清理操作：
- 菜单栏：`Product` → `Clean Build Folder`
- 或快捷键：`⇧⌘K`

### 1.2 设置构建配置

确保使用Release配置：
1. 点击顶部工具栏的设备选择器（Usage4Claude旁边）
2. 选择 `Any Mac (Apple Silicon)` 或 `Any Mac (Intel)`
3. 菜单栏：`Product` → `Scheme` → `Edit Scheme...`
4. 左侧选择 `Run`，确保 `Build Configuration` 设置为 `Release`

### 1.3 Archive（归档）

**重要提示：** Archive前确保已经关闭了之前打开的Usage4Claude应用实例。

1. 菜单栏：`Product` → `Archive`
2. 等待编译完成（通常1-2分钟）
3. 编译成功后会自动打开 `Organizer` 窗口

### 1.4 Export（导出）

在Organizer窗口中：

1. 选择刚才创建的Archive（最新的那个）
2. 点击右侧的 `Distribute App` 按钮
3. 选择 `Custom`
4. 点击 `Next`
5. 选择 `Copy App`
6. 点击 `Next`
7. 选择保存位置，建议保存到：
   ```
   <项目根目录>/build/Usage4Claude-Export/
   ```
9. 点击 `Export`

完成后，得到一个 `Usage4Claude.app` 文件。

### 1.5 验证导出的 App

在终端中验证app能正常运行：

```bash
cd <项目根目录>/build/Usage4Claude-Export/
open Usage4Claude.app
```

应该能看到 Usage4Claude 在菜单栏正常运行。

---

## 步骤2：安装 create-dmg 工具

### 2.1 通过 Homebrew 安装

打开终端，执行：

```bash
brew install create-dmg
```

等待安装完成（通常30秒-1分钟）。

### 2.2 验证安装

```bash
create-dmg --version
```

应该能看到版本信息，如：`create-dmg 1.2.1`

---

## 步骤3：创建 DMG 安装包

### 3.1 进入工作目录

```bash
cd <项目根目录>/build/Usage4Claude-Export
```

### 3.2 创建DMG

使用 create-dmg 创建一个漂亮的 DMG 安装包：

```bash
create-dmg \
  --volname "Usage4Claude" \
  --volicon "../../docs/images/icon@2x.png" \
  --window-pos 200 120 \
  --window-size 600 500 \
  --icon-size 128 \
  --icon "Usage4Claude.app" 175 190 \
  --hide-extension "Usage4Claude.app" \
  --app-drop-link 425 190 \
  "Usage4Claude-v1.0.0.dmg" \
  "Usage4Claude.app"
```

**参数说明：**
- `--volname`: DMG挂载后显示的卷名
- `--volicon`: DMG的图标（可选）
- `--window-pos`: DMG打开后窗口的位置
- `--window-size`: DMG窗口的大小
- `--icon-size`: 图标的大小
- `--icon`: 指定app在窗口中的位置
- `--app-drop-link`: 创建Applications文件夹的快捷方式，并设置位置
- 输出文件名: `Usage4Claude-v1.0.0.dmg`（根据版本号修改）

### 3.4 简化版命令（快速创建）

如果不需要复杂的自定义，可以用最简单的命令：

```bash
create-dmg \
  --volname "Usage4Claude" \
  --window-size 600 500 \
  --app-drop-link 425 190 \
  "Usage4Claude-v1.0.0.dmg" \
  "Usage4Claude.app"
```

完成后，会在当前目录看到 `Usage4Claude-v1.0.0.dmg` 文件。

---

## 步骤4：测试DMG

### 4.1 挂载DMG测试

双击打开DMG文件，验证：

✅ 检查项：
- [ ] DMG能正常打开
- [ ] 看到Usage4Claude.app图标
- [ ] 看到Applications文件夹的快捷方式
- [ ] 界面布局美观

### 4.2 安装测试

1. 从DMG中拖动Usage4Claude.app到Applications快捷方式
2. 打开访达，进入Applications文件夹
3. 找到Usage4Claude.app，双击运行

**首次运行提示：**

由于我们的应用没有签名，首次运行时macOS会显示警告：

```
"Usage4Claude.app" cannot be opened because the developer cannot be verified.
```

**解决方法：**
1. 右键点击 `Usage4Claude.app`
2. 选择 `Open`（打开）
3. 在弹出的对话框中点击 `Open`

之后就可以正常使用了。

### 4.3 功能测试

确保以下功能正常：
- [ ] 应用出现在菜单栏
- [ ] 点击图标能打开详情窗口
- [ ] API能正常获取数据
- [ ] 设置功能正常
- [ ] 定时刷新工作正常

---

## 步骤5：发布到GitHub

### 5.1 准备Release Notes

在发布前，准备好本次更新的说明。建议包含：

**模板示例：**

```markdown
## ✨ 新功能
- 添加了XXX功能
- 支持XXX操作

## 🐛 Bug修复
- 修复了XXX问题
- 解决了XXX崩溃

## 🔧 优化改进
- 优化了XXX性能
- 改进了XXX体验

## 📝 其他
- 更新了依赖
- 文档完善
```

**实际例子（v1.0.0首次发布）：**

```markdown
## 🎉 首次发布

Usage4Claude是一个macOS菜单栏应用，用于实时监控 Claude AI 的5小时使用限制。

### ✨ 主要功能
- 📊 实时显示 Claude AI 的使用百分比
- ⏰ 倒计时显示重置时间
- 🎨 颜色编码提示（绿色、橙色、红色）
- 🔄 自动刷新（可自定义间隔）
- ⚙️ 完整的设置界面
- 🌓 支持系统深色/浅色模式

### 📦 安装说明
1. 下载 `Usage4Claude-v1.0.0.dmg`
2. 打开DMG文件
3. 拖动应用到 Applications 文件夹
4. 首次打开需要右键 → 打开
5. 在设置中配置 Claude API 认证信息

### ⚠️ 注意事项
- 需要macOS 13.0或更高版本
- 应用未签名，首次运行需要手动授权
- 需要有效的Claude 账号

### 🙏 致谢
感谢所有测试者和贡献者！
```

### 5.2 在GitHub创建Release

#### 方式一：通过网页界面（推荐新手）

1. **访问仓库Release页面**
   ```
   https://github.com/f-is-h/Usage4Claude/releases
   ```

2. **创建新Release**
   - 点击 `Draft a new release` 按钮

3. **填写Release信息**
   - **Choose a tag**: 输入 `v1.0.0`（如果不存在会自动创建）
   - **Target**: 选择 `main` 分支
   - **Release title**: 输入 `Version 1.0.0` 或 `Usage4Claude v1.0.0`
   - **Description**: 粘贴准备好的Release Notes

4. **上传DMG文件**
   - 拖动 `Usage4Claude-v1.0.0.dmg` 到 `Attach binaries` 区域
   - 等待上传完成

5. **发布选项**
   - 勾选 `Set as the latest release`
   - 如果是测试版，可以勾选 `Set as a pre-release`

6. **发布**
   - 点击 `Publish release` 按钮

#### 方式二：通过GitHub CLI（推荐熟手）

```bash
# 安装GitHub CLI（如果还没有）
brew install gh

# 登录
gh auth login

# 创建tag
git tag v1.0.0
git push origin v1.0.0

# 创建Release并上传DMG
gh release create v1.0.0 \
  ~/Desktop/Usage4Claude-Release/Usage4Claude-v1.0.0.dmg \
  --title "Version 1.0.0" \
  --notes "Release notes here..."
```

### 5.3 验证发布

发布完成后，验证：

1. **访问Release页面**
   ```
   https://github.com/f-is-h/Usage4Claude/releases
   ```

2. **检查内容**
   - [ ] Tag正确显示
   - [ ] Release Notes格式正确
   - [ ] DMG文件可以下载
   - [ ] 文件大小合理（通常10-20MB）

3. **测试下载**
   - 点击下载DMG
   - 在另一台Mac上测试安装
   - 或者清除缓存后重新下载测试

---

## 常见问题

### Q1: Archive后找不到Organizer窗口

**解决方法：**
- 菜单栏：`Window` → `Organizer`
- 或快捷键：`⌥⌘⇧O`

### Q2: 导出的App无法运行

**可能原因：**
1. 选错了构建目标（应该是Any Mac）
2. 使用了Debug配置而非Release
3. 依赖的资源文件未正确包含

**解决方法：**
- 重新Archive，确保使用Release配置
- 检查Build Settings中的设置

### Q3: create-dmg命令找不到

**解决方法：**
```bash
# 重新安装
brew reinstall create-dmg

# 检查PATH
echo $PATH

# 手动指定路径
/opt/homebrew/bin/create-dmg --version
```

### Q4: DMG创建失败

**常见错误：**
```
hdiutil: create failed - Resource busy
```

**解决方法：**
- 确保没有其他DMG已经挂载
- 关闭访达中所有Usage4Claude相关的窗口
- 重启终端后重试

### Q5: 用户无法打开App提示"损坏"

这是macOS Gatekeeper的安全检查。

**用户解决方法：**
```bash
# 移除隔离属性
xattr -cr /Applications/Usage4Claude.app
```

**或者：**
1. 右键 → 打开
2. 点击"打开"按钮

**根本解决（需要付费开发者账号）：**
- 代码签名 + 公证
- 见进阶指南

### Q6: 如何修改已发布的Release

在GitHub Release页面：
1. 找到对应的Release
2. 点击右上角的 `Edit` 按钮
3. 修改Release Notes或重新上传文件
4. 点击 `Update release`

**注意：** 无法修改Tag名称，如果Tag错了需要删除重建。

### Q7: 如何删除Release

```bash
# 使用GitHub CLI
gh release delete v1.0.0

# 同时删除tag
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
```

或在网页上：
1. 进入Release页面
2. 点击右上角的删除按钮

---

## 🎯 快速参考清单

发布新版本的快速步骤：

```bash
# 1. 在Xcode中Archive和Export

# 2. 进入工作目录
cd <项目根目录>/build/Usage4Claude-Export

# 4. 创建DMG
create-dmg \
  --volname "Usage4Claude" \
  --window-size 600 500 \
  --app-drop-link 425 190 \
  "Usage4Claude-v1.0.1.dmg" \
  "Usage4Claude.app"

# 5. 测试DMG
open Usage4Claude-v1.0.1.dmg

# 6. 发布到GitHub
# (在网页上操作或使用gh CLI)
```

---

## 📚 相关文档

- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - 项目开发总结
- [README.md](README.zh-CN.md) - 项目说明

---

## 🔮 进阶话题

### 自动化发布

当项目更加成熟后，可以考虑使用GitHub Actions自动化整个流程：
- 自动编译
- 自动创建DMG
- 自动生成Changelog
- 自动发布Release

详见未来的自动化指南。

### 代码签名与公证

如果有Apple开发者账号（$99/年），可以：
- 代码签名：用户打开不会看到警告
- 公证（Notarization）：macOS自动验证安全性
- 分发更专业：用户体验更好

这需要额外的配置和步骤，可以参考Apple官方文档。

---

**最后更新：** 2025年10月22日  
**适用版本：** v1.0.0+  
**维护者：** [f-is-h](https://github.com/f-is-h)

---
