# UsagePaceCC 日常版本发布流程

> 使用 GitHub Workflow 自动化发布的快速指南

**预计时间**: 10-15 分钟  
**前提条件**: 已完成 Workflow 初始配置和测试

---

## 📋 快速流程图

```
①开发代码 → ②准备发布材料 → ③提交推送 → ④等待CI → ⑤编辑发布 → ⑥完成
```

---

## 🚀 发布步骤

### 步骤 1：开发代码 + 更新版本号

**在 Xcode 中：**
1. 完成所有代码改动
2. 更新版本号：
   - Target → General → Identity
   - **Version**: `X.Y.Z`（新版本号）
   - **Build**: `1`（新版本从1开始）

**验证：**
```bash
# 编译测试
Cmd + B

# 运行测试  
Cmd + R
```

---

### 步骤 2：准备发布材料

**使用 Claude 创建三份文档：**

**提示词示例：**
```
请参照 CHANGELOG_RELEASE_NOTES_COMMIT_MESSAGE_GUIDELINES.md，
为 v1.X.X 版本创建：
1. CHANGELOG 条目
2. Release Notes
3. Commit Message

改动内容：
- [列出主要改动]
```

**输出结果：**
- ✅ CHANGELOG.md 的新版本条目
- ✅ Release Notes（完整版）
- ✅ Commit Message（含body）

---

### 步骤 3：更新 CHANGELOG.md

**编辑 CHANGELOG.md：**

使用任意工具编译 CHANGELOG.md

1. 在文件顶部添加 Claude 生成的新版本条目
2. **重要**: 更新底部的版本链接
   ```markdown
   [1.X.X]: https://github.com/quangyendn/UsagePaceCC/releases/tag/v1.X.X
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

[1.2.0]: https://github.com/quangyendn/UsagePaceCC/releases/tag/v1.2.0
[1.1.0]: https://github.com/quangyendn/UsagePaceCC/releases/tag/v1.1.0
```

---

### 步骤 4：提交并推送（触发 Workflow）

**使用 Claude 生成的 Commit Message：**

```bash
cd /Users/iMac/Coding/Projects/UsagePaceCC

# 添加所有改动
git add .

# 提交（复制 Claude 生成的 commit message）
git commit -m "[release] feat: 改动描述

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
https://github.com/quangyendn/UsagePaceCC/actions
```

**Workflow 流程（约10分钟）：**

```
✅ validate (ubuntu, ~30秒)
   └─ 提取版本号、验证格式
   
✅ build (macos, ~8分钟)  
   └─ 验证版本一致性
   └─ 编译构建、签名
   └─ 生成 DMG 和 SHA256
   
✅ release (ubuntu, ~1分钟)
   └─ 创建 Git Tag
   └─ 创建 Draft Release
   └─ 上传 DMG 和 SHA256
```

**收到邮件通知：**
- ✉️ Workflow started
- ✉️ Workflow completed (成功/失败)

**如果失败：**
- 查看失败的 Job 日志
- 常见问题：版本号不一致、证书问题
- 修复后重新推送

---

### 步骤 6：编辑 Draft Release

**Workflow 完成后：**

1. **访问 Releases 页面：**
   ```
   https://github.com/quangyendn/UsagePaceCC/releases
   ```

2. **找到 Draft Release（未发布）：**
   ```
   vX.Y.Z - ❗️❗️❗️请在这里输入你的简短描述❗️❗️❗️
   ```

3. **点击 "Edit" 编辑：**

   **修改标题：**
   ```
   从: v1.2.0 - ❗️❗️❗️请在这里输入你的简短描述❗️❗️❗️
   改为: v1.2.0 - Settings UI Redesign
   ```

   **替换描述：**
   - 删除模板注释（`<!-- ... -->`）
   - 粘贴 Claude 生成的 Release Notes
   - 或手动完善自动生成的内容

4. **预览效果：**
   - 切换到 "Preview" 标签查看渲染效果
   - 检查格式、链接、emoji

5. **验证附件：**
   - ✅ `UsagePaceCC-vX.Y.Z.dmg` 已上传
   - ✅ `UsagePaceCC-vX.Y.Z.dmg.sha256` 已上传

6. **发布：**
   - ✅ 勾选 "Set as the latest release"
   - ❌ 不勾选 "Set as a pre-release"
   - 点击 **"Publish release"**

---

### 步骤 7：验证发布

**检查清单：**

1. **访问 Release 页面：**
   ```
   https://github.com/quangyendn/UsagePaceCC/releases/tag/vX.Y.Z
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
   open ~/Downloads/UsagePaceCC-vX.Y.Z.dmg
   
   # 安装测试
   # 验证版本号
   ```

4. **测试更新检查：**
   - 打开旧版本应用
   - 菜单 → Check for Updates
   - 应提示新版本可用

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
2. ✅ Commit message 包含 `[release]` 关键字
3. ✅ CHANGELOG.md 底部链接已更新
4. ✅ 所有代码已编译测试通过

**常见错误：**
- ❌ 版本号不一致 → CI 构建失败
- ❌ 忘记 `[release]` → Workflow 不触发
- ❌ 忘记更新链接 → CHANGELOG 链接失效

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

- [CHANGELOG/Release Notes 编写指南](./CHANGELOG_RELEASE_NOTES_COMMIT_MESSAGE_GUIDELINES.md)
- [GitHub Workflow 完整文档](./GITHUB_WORKFLOW_SUMMARY.md)
- [详细发布指南](./GITHUB_UPDATE_RELEASE_GUIDE.md)

---

**最后更新**: 2025-11-20  
**版本**: 1.0
