---
name: release
description: 发布 Usage4Claude 新版本时使用。当用户说“发布新版本 / 发版 / 出新版 / release / 打 tag 发布 / 准备发版材料”等，用本 skill 引导完成从收集变更、编写 CHANGELOG 与 RELEASE_NOTES、更新版本号、编译验证，到发版 commit、CI 自动发布的完整流程。
---

# 发布新版本（Release）

Usage4Claude 采用 **CI 自动发布**：向 `main` push 一个满足条件的 commit 后，
GitHub Actions（`.github/workflows/release.yml`）自动完成构建、签名、发 Release、
更新 Sparkle 更新源。你（Claude）的职责是准备好发版材料并引导用户完成触发，
**不代替用户执行发版 commit 与 push**。

> 若根目录存在 `NEXT_RELEASE.md`，说明本次发版有一次性特殊情况，**先读它**再按本流程走。

## 必须先记住的架构事实

- **两份发布材料，各司其职**（详见下一节分工表）：
  - `CHANGELOG.md` — 完整技术档案 + **版本号权威源**，不进 Sparkle。
  - `docs/RELEASE_NOTES.md` — 面向用户的发布说明，CI 提取当前版本段落后**同时**注入
    Sparkle 弹窗（`appcast.xml` 的 `<description>`）和 GitHub Release 正文。
- **触发条件**：commit message 含 `[release]`/`[RELEASE]`，push 到 `main`，且本次改动
  包含 `CHANGELOG.md` 或 `docs/RELEASE_NOTES.md`（发版通常两者都改）。
- **Sparkle 弹窗内容来自 docs/RELEASE_NOTES.md**（不是 CHANGELOG）。用户在应用内“检查更新”
  看到的就是 RELEASE_NOTES 当前版本段落。
- **docs/RELEASE_NOTES.md 必须有当前版本段落**：否则 Sparkle/Release 正文会为空。CI 的
  validate 阶段会 `grep "^## [X.Y.Z]"` fail-fast，但应发版前就写好。
- **Build 号自动跟随**：`CURRENT_PROJECT_VERSION = $(MARKETING_VERSION)`，Build 恒等于
  Version。**只改 Version，绝不手动固定 Build**，否则 Sparkle 认不出新版本。
- **appcast.xml 由 CI 维护**，绝不手改。
- 详细背景见 `docs/DAILY_RELEASE_WORKFLOW.md`、`docs/SPARKLE_SETUP.md`。

## 两份材料的分工（关键）

| | CHANGELOG.md | docs/RELEASE_NOTES.md |
|---|---|---|
| 定位 | 完整技术档案 + 版本号权威源 | 面向用户的发布说明 |
| 收录范围 | **所有改动**，含内部重构、CI、安全加固 | **只留用户可感知的现象** |
| 措辞 | 可保留技术细节（JWT、actor、base64url 等） | 口语化，去技术词 |
| 致谢 | 不加 | 在相关条目末尾加 `(thanks @author, #N)` |
| CI 喂给 | 无（纯档案；validate 从它提版本号） | Sparkle 弹窗 + GitHub Release 正文 |
| 何时写 | 发版前 | 发版前（不是发布后精修） |

> 规则细节见 `docs/CHANGELOG_AND_RELEASE_NOTES_GUIDELINES.md`。

## 流程

### 1. 收集自上个 tag 以来的变更

```bash
git fetch origin                                     # 先核对远程，避免发版已在别处完成
LAST_TAG=$(git describe --tags --abbrev=0)           # 上一个发布 tag，如 v3.3.0
git log "$LAST_TAG"..HEAD --oneline                  # 变更概览
git log "$LAST_TAG"..HEAD --format='=== %h ===%n%B'  # 完整 message（判断影响面必读）
git log "$LAST_TAG"..HEAD --merges --format='%h %s'  # 合并的 PR（用于致谢）
```

逐条阅读完整 message，区分：用户可感知的现象 vs 纯内部改动。两类都进 CHANGELOG，
但只有前者进 RELEASE_NOTES。

### 2. 决定版本号

读 CHANGELOG.md 顶部当前版本，按语义化递增：

| 改动类型 | 递增 | 例 |
|---|---|---|
| 仅 Bug 修复 | patch | 3.3.0 → 3.3.1 |
| 含新功能 | minor | 3.3.0 → 3.4.0 |
| 破坏性变更 | major | 3.3.0 → 4.0.0 |

版本号不确定时用 AskUserQuestion 让用户确认。

### 3. 编写两份发布材料

**3a. CHANGELOG.md（完整技术档案）**
- 在文件顶部（`# Changelog` 与首个 `## [` 之间）插入新版本段落，日期用当天。
- 收录**所有**改动，按 `Added` / `Changed` / `Fixed` / `Security` 分类。
- **新功能的后续修改/优化/bug 修复并入该功能条目**，不在 Fixed 里重复列出。
- 每个变更点一条，不同变更点只出现一次，简洁不赘述。
- **更新文件底部版本链接**：新增
  `[X.Y.Z]: https://github.com/f-is-h/Usage4Claude/releases/tag/vX.Y.Z`

**3b. docs/RELEASE_NOTES.md（面向用户 + 致谢）**
- 在文件顶部插入 `## [X.Y.Z] - 当天日期` 段落（结构同 CHANGELOG）。
- **只保留用户可感知的现象**，去技术词、口语化。
- 收集本版本对应的 **已合并 PR** 与 **已解决 Issue** 及作者，条目末尾致谢
  `(thanks @author, #N)`：
  ```bash
  gh pr view <n> --repo f-is-h/Usage4Claude --json number,title,author,state
  gh issue view <n> --repo f-is-h/Usage4Claude --json number,title,author,state
  ```
  **只对确已合并的 PR / 确已解决的 Issue 致谢**。未合并的 PR、仍 Open 且本次并未真正
  修复的 Issue **不致谢**，避免误导用户（硬规则）。

两份写入文件的都是**英文**；同时在对话里给用户中文对照（不写进文件）。写好后用
AskUserQuestion 让用户确认草稿再继续。

### 4. 更新 Xcode 版本号

两处 `MARKETING_VERSION`（Debug/Release）都要改：

```bash
sed -i '' 's/MARKETING_VERSION = <旧版本>;/MARKETING_VERSION = <新版本>;/g' \
  Usage4Claude.xcodeproj/project.pbxproj
grep -n "MARKETING_VERSION" Usage4Claude.xcodeproj/project.pbxproj  # 确认两处都改了
```

CHANGELOG 版本与 Xcode 版本**必须完全一致**，否则 CI 的 `verify_version.sh` 会失败。
RELEASE_NOTES 也必须有同一版本段落（CI validate 会 fail-fast）。

### 5. 编译验证

```bash
xcodebuild -project Usage4Claude.xcodeproj -scheme Usage4Claude -configuration Release build 2>&1 | tail -5
```

看到 `** BUILD SUCCEEDED **` 后，核对产物版本号：

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -name Usage4Claude.app -path '*/Release/*' | head -1)
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist"  # 应与 Version 相同
```

### 6. 发版 commit + push（**commit 由用户手写**）

发版 commit message 不走日常 `COMMIT_MESSAGE_GUIDELINES` 那套，由用户手工编写。
你只提供草稿供参考，**不擅自 commit/push**——`git add`/`commit`/`push` 需用户确认后执行。

- **只写一行标题，不要正文。** CI 只取第一行（去掉 `[release]` 前缀）作为 GitHub
  Release 标题；正文不被使用（Release 正文来自 RELEASE_NOTES），写了也是浪费。
- 格式：

```
[release] vX.Y.Z - 简短标题
```

- 触发前自检：commit 含 `[release]`、本次改动含 `CHANGELOG.md`/`docs/RELEASE_NOTES.md`、目标分支 `main`。

推送后 CI 触发。

### 7. 监控 CI

```bash
gh run list --workflow=release.yml --limit 3
gh run watch                     # 或看 https://github.com/f-is-h/Usage4Claude/actions
```

CI 三段：validate（版本校验 + RELEASE_NOTES 段落校验）→ build（构建签名，约 8 分钟）→
release（发 Release + 推 appcast.xml 回 main）。失败常见原因：版本号不一致、RELEASE_NOTES
缺当前版本段落、CHANGELOG 版本已发布过。

### 8.（可选）发布后装饰 GitHub Release 页面

CI 已用 RELEASE_NOTES 自动发布了面向用户的 Release，且 Sparkle 弹窗同源——**通常无需再做**。
若想让 GitHub Release 页面更精致（大标题、总览段落、emoji），可发布后手工编辑网页。

- 这属于 **GitHub 页面装饰**，**不回流 Sparkle**（Sparkle 已在发布时拿到 RELEASE_NOTES 段落）。
- 改的是对外公开页面，**先与用户确认再执行**。
- 页面正文结构 = 「RELEASE_NOTES 段落」+ `---` + Installation + `---` + Full Changelog，
  只改第一个 `---` 上方那段，下方模板不要动。用 `gh release edit` 会整体替换正文，需先
  `gh release view vX.Y.Z --json body -q .body` 取回完整正文改上半段后整体回填。

## 发版前的安全测试（不真正发布）

按影响面从小到大三档，用于在正式发版前验证：

**① 本地预览（零风险，什么都不发）**
```bash
swift test                                                          # 单元测试
xcodebuild -project Usage4Claude.xcodeproj -scheme Usage4Claude \
  -configuration Release build                                      # 能否编译
.github/scripts/verify_version.sh verify CHANGELOG.md Usage4Claude.xcodeproj  # 版本号一致性
.github/scripts/generate_release_notes.sh \
  .github/RELEASE_TEMPLATE.md <版本> /tmp/rn_preview.md docs/RELEASE_NOTES.md      # 预览 Release 正文
./scripts/build.sh --config Release                                # 本地打 DMG，验证打包脚本
```
`generate_release_notes.sh` 输出里第一个 `---` **上方**那段，同时也是 **Sparkle 更新弹窗**
会显示的内容（都来自 RELEASE_NOTES）——发版前务必看一眼措辞是否面向用户。

**② `test-release` 分支（CI 构建冒烟，不发布）**
- 把改动 push 到 `test-release` 分支（commit 仍含 `[release]`）。
- CI 跑 validate + build：在 CI 环境编译、导入证书、Sparkle 签名、打 DMG。
- **跳过 release job**（`is_test=true`）→ 不打 tag、不发 Release、不碰 appcast、不 push main。
- 用途：验证 CI 能否构建出签名 DMG（本地过 ≠ CI 过，证书/Sparkle 私钥只在 CI secrets）。
  DMG 作为 artifact 可下载。几乎无需清理。

**③ `workflow_dispatch` dry_run（端到端演练，产草稿）**
- 在 Actions 页面对 **main** 手动运行 workflow，勾选 `dry_run`。
- 跑完整三段，但：tag=`test-v<版本>`、Release 走 `--draft`（公众不可见）、appcast 只打印不 push。
- 用途：演练整条发布链路（含 release job 的 tag/release/appcast 逻辑）而不影响用户。
- **需清理**：`gh release delete test-v<版本> --yes` 且 `git push origin :refs/tags/test-v<版本>`。
- 注意：dry_run 必须在 main 触发才有端到端效果；在 test-release 触发会退化成 ②。

选择：只验发布材料 → ①；验 CI 构建 → ②；验整条链路 → ③。

## 红线清单

- 发版 commit 与 push **由用户执行**，你只准备材料 + 提供草稿。
- 发版前 `CHANGELOG.md` 与 `docs/RELEASE_NOTES.md` 都要有当前版本段落。
- CHANGELOG 版本号与 Xcode `MARKETING_VERSION` 必须一致。
- 只改 Version，**不碰 Build 号**（自动跟随 MARKETING_VERSION）。
- **不手改 appcast.xml**（CI 维护）。
- 致谢只给**确已合并/解决**的 PR/Issue。
- **已发布版本的 CHANGELOG / RELEASE_NOTES 段落不回改**（否则与已发内容、Sparkle 说明不一致）。
- 冒烟测试若需杀进程，用 `kill <PID>` 而非 `killall`（避免误伤用户在跑的正式版实例）。

## 相关文档

- `docs/DAILY_RELEASE_WORKFLOW.md` — 日常发版流程全文
- `docs/CHANGELOG_AND_RELEASE_NOTES_GUIDELINES.md` — CHANGELOG 与 RELEASE_NOTES 编写规范
- `docs/COMMIT_MESSAGE_GUIDELINES.md` — 日常 commit 规范（发版 commit 不适用）
- `docs/SPARKLE_SETUP.md` — Sparkle 自动更新机制
- `.github/workflows/release.yml` — CI 发布流水线
- `.github/RELEASE_TEMPLATE.md` — Release 正文固定模板（Installation 等）
