# Usage4Claude 日常版本发布流程

> 使用 GitHub Workflow 自动化发布的快速指南

**预计时间**: 10-15 分钟  
**前提条件**: 已完成 Workflow 初始配置和测试

---

## 📋 快速流程图

```
①开发代码 → ②准备材料 → ③提交推送 → ④CI自动构建并发布 → ⑤（可选）精修 → ⑥完成
```

---

## 🚀 发布步骤

### 步骤 1：开发代码 + 更新版本号

**在 Xcode 中：**
1. 完成所有代码改动
2. 更新版本号：
   - Target → General → Identity
   - **Version**: `X.Y.Z`（新版本号，唯一需要手动改的版本字段）
   - **Build**: **不要手动改**，保持自动跟随（见下方警告）

> ⚠️ **Build 号必须随版本递增，绝不能固定为 `1`**
>
> Sparkle 判断"有没有新版本"，比较的是 **Build 号（`CFBundleVersion`）**，
> 而不是 Version 字符串。如果每个版本的 Build 都填 `1`，Sparkle 会认为所有
> 版本都一样，结果要么老用户收不到更新，要么用户被反复提示更新（死循环）。
>
> 项目已配置 `CURRENT_PROJECT_VERSION = $(MARKETING_VERSION)`，Build 号会
> **自动等于 Version**。因此只需修改 Version 即可，**不要在 Xcode 里把 Build
> 改回具体数字**。

**验证：**
```bash
# 编译测试
Cmd + B

# 运行测试  
Cmd + R
```

---

### 步骤 2：准备发布材料

**使用 Claude 创建 CHANGELOG 条目：**

**提示词示例：**
```
请参照 CHANGELOG_AND_RELEASE_NOTES_GUIDELINES.md，
为 vX.Y.Z 版本创建 CHANGELOG 条目。

改动内容：
- [列出主要改动]
```

**输出结果：**
- ✅ CHANGELOG.md 的新版本条目

> 💡 **发版 commit message 需手工编写**（格式见步骤 4）。**Release Notes 也不用手写**：
> GitHub Release 标题取自 commit 第一行，正文由 CI 自动用 CHANGELOG 段落兜底生成；
> 需要更精致的文案时，可在发布后到 GitHub 手工精修（见步骤 6）。

---

### 步骤 3：更新 CHANGELOG.md

**编辑 CHANGELOG.md：**

使用任意工具编译 CHANGELOG.md

1. 在文件顶部添加 Claude 生成的新版本条目
2. **重要**: 更新底部的版本链接
   ```markdown
   [1.X.X]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.X.X
   ```

**示例：**
```markdown
# Changelog

## [1.2.0] - 2025-11-20

### Added
- 新功能描述

### Fixed
- Bug修复描述

## [1.1.0] - 2025-11-15
...

[1.2.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.2.0
[1.1.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.1.0
```

---

### 步骤 4：提交并推送（触发 Workflow）

**手工编写发版 Commit Message：**

```bash
cd /Users/iMac/Coding/Projects/Usage4Claude

# 添加所有改动
git add .

# 提交（发版 commit message 手工编写，不走 COMMIT_MESSAGE_GUIDELINES 那套）
# 第一行去掉 [release] 后会成为 GitHub Release 标题
git commit -m "[release] v1.X.X - 简短标题

- 详细改动1
- 详细改动2
..."

# 推送到 GitHub（触发 Workflow）
git push origin main
```

**触发条件验证：**
- ✅ Commit message 包含 `[release]` 或 `[RELEASE]`
- ✅ 修改了 `CHANGELOG.md`
- ✅ 推送到 `main` 分支

---

### 步骤 5：等待 CI 完成

**访问 Actions 页面监控：**
```
https://github.com/f-is-h/Usage4Claude/actions
```

**Workflow 流程（约10分钟）：**

```
✅ validate (ubuntu, ~30秒)
   └─ 提取版本号、验证格式、确认版本号高于已发布版本
   
✅ build (macos, ~8分钟)  
   └─ 验证版本一致性
   └─ 编译构建、签名
   └─ 生成 DMG 和 SHA256
   └─ 用 Sparkle EdDSA 私钥签名 DMG（生成 appcast enclosure）
   
✅ release (ubuntu, ~1分钟)
   └─ 创建 Git Tag
   └─ 生成 Release Notes（标题取自 commit、正文默认用 CHANGELOG 段落）
   └─ 直接发布 Release（非草稿）+ 上传 DMG 和 SHA256
   └─ 更新 appcast.xml 并推送到 main（Sparkle 更新源）
```

**收到邮件通知：**
- ✉️ Workflow started
- ✉️ Workflow completed (成功/失败)

**如果失败：**
- 查看失败的 Job 日志
- 常见问题：版本号不一致、证书问题
- 修复后重新推送

---

### 步骤 6：（可选）精修 Release Notes

CI 已经**自动发布**了 release——标题来自 commit 第一行，正文默认用 CHANGELOG
段落。**这一步不是必须的**，只在想让 Release 页面有更精致文案时才做。

1. **访问 Releases 页面：**
   ```
   https://github.com/f-is-h/Usage4Claude/releases
   ```

2. **找到已发布的 release（vX.Y.Z），点击 "Edit"**

3. **润色正文：**
   - 在自动生成的 CHANGELOG 内容基础上，补充总览段落、emoji 标题等
   - 更新后点 "Update release"

> 💡 **不影响 Sparkle**：应用内更新弹窗的说明取自 CHANGELOG，与 GitHub Release
> Notes 无关。即使不精修、甚至留着默认内容，也不影响用户的更新体验。

---

### 步骤 7：验证发布

**检查清单：**

1. **访问 Release 页面：**
   ```
   https://github.com/f-is-h/Usage4Claude/releases/tag/vX.Y.Z
   ```

2. **验证内容：**
   - [ ] 标题正确
   - [ ] 标记为 "Latest"
   - [ ] Release Notes 格式正确
   - [ ] DMG 可下载
   - [ ] SHA256 可下载

3. **测试下载：**
   ```bash
   # 下载 DMG
   open ~/Downloads/Usage4Claude-vX.Y.Z.dmg
   
   # 安装测试
   # 验证版本号
   ```

4. **测试 Sparkle 更新检查：**
   - 打开旧版本应用
   - 菜单 → Check for Updates
   - 应弹出 Sparkle 更新窗口，提示新版本并可一键安装
   - 前提：appcast.xml 已更新（CI 自动）且 release 已 Publish（DMG 可下载）

---

## ✅ 完成！

发布成功后可以：
- 🎉 在社交媒体分享
- 📝 记录用户反馈
- 🐛 关注 GitHub Issues
- 📅 规划下个版本

---

## 📝 快速参考

### Commit Message 格式

```bash
[release] <type>: <subject>

<body>
```

**Type 类型：**
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `refactor`: 重构
- `perf`: 性能优化

### 版本号规则

| 改动类型 | 版本号变化 | 示例 |
|---------|-----------|------|
| Bug 修复 | +0.0.1 | 1.0.0 → 1.0.1 |
| 新功能 | +0.1.0 | 1.0.0 → 1.1.0 |
| 重大更新 | +1.0.0 | 1.0.0 → 2.0.0 |

### 常用命令

```bash
# 查看状态
git status
git log --oneline -3

# 提交推送
git add .
git commit -m "[release] your message"
git push origin main

# 查看 Tags
git tag -l
git show vX.Y.Z
```

---

## ⚠️ 注意事项

**必须确保：**
1. ✅ Xcode 版本号与 CHANGELOG 版本号**完全一致**
2. ✅ Commit message 用发版格式 `[release] vX.Y.Z - 标题`
3. ✅ CHANGELOG.md 底部链接已更新
4. ✅ 所有代码已编译测试通过
5. ✅ Build 号保持 `$(MARKETING_VERSION)` 自动跟随，未被手动固定

**常见错误：**
- ❌ 版本号不一致 → CI 构建失败
- ❌ 忘记 `[release]` → Workflow 不触发
- ❌ 忘记更新链接 → CHANGELOG 链接失效
- ❌ 把 Build 号固定成 `1` → Sparkle 无法识别新版本（更新失效或死循环）
- ❌ 手动编辑 appcast.xml → 该文件由 CI 自动维护，手动改易出错

---

## 🆘 遇到问题？

**如果 Workflow 失败：**
1. 查看 Actions 页面的错误日志
2. 检查版本号是否一致
3. 检查 GitHub Secrets 配置
4. 参考 [GITHUB_WORKFLOW_SUMMARY.md](./GITHUB_WORKFLOW_SUMMARY.md) 故障排除部分

**如果更新检测失败：**
1. 等待 5-10 分钟（GitHub API 延迟）
2. 验证 Release 已正确发布
3. 检查 Release 标记为 "Latest"

---

## 📚 相关文档

- [Commit Message 编写指南](./COMMIT_MESSAGE_GUIDELINES.md)
- [CHANGELOG 与 Release Notes 编写指南](./CHANGELOG_AND_RELEASE_NOTES_GUIDELINES.md)
- [Sparkle 更新机制设置与原理](./SPARKLE_SETUP.md)
- [GitHub Workflow 完整文档（归档）](./archive/GITHUB_WORKFLOW_SUMMARY.md)
- [详细发布指南（归档）](./archive/GITHUB_UPDATE_RELEASE_GUIDE.md)

---

**最后更新**: 2026-06-20  
**版本**: 2.0（接入 Sparkle 自动更新）
