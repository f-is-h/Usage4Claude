# 如何编写 CHANGELOG 与 RELEASE_NOTES

本项目用**两份独立文件**承载发布信息，发版前都要写好：

- **`CHANGELOG.md`** — 完整技术档案 + 版本号权威源。**不进 Sparkle。**
- **`docs/RELEASE_NOTES.md`** — 面向用户的发布说明。CI 提取当前版本段落后**同时**喂给
  Sparkle 应用内更新弹窗和 GitHub Release 正文。

## 注意事项

以下适用于两份文件的生成：

- 如果一个功能是新增的（Added），那么对这个新功能的所有修改、调整、优化、bug 修复都应视为该新功能的一部分，不应单独在 Improved 或 Fixed 部分列出
- 生成英文内容的同时，请给出中文翻译（中文仅供对照，写入文件的正文用英文）
- 简洁不赘述
- 每个变更点使用一条说明文字
- 不同变更点只出现一次

## 两份材料的分工

| | CHANGELOG.md | docs/RELEASE_NOTES.md |
|---|---|---|
| 定位 | 完整技术档案 + 版本号权威源 | 面向用户的发布说明 |
| 收录范围 | **所有改动**，含内部重构、CI、安全加固 | **只留用户可感知的现象** |
| 措辞 | 可保留技术细节（JWT、actor、base64url 等） | 口语化，去技术词 |
| 致谢 | 不加 | 在相关条目末尾加 `(thanks @author, #N)` |
| CI 喂给 | 无（纯档案；validate 从它提版本号） | Sparkle 弹窗 + GitHub Release 正文 |
| 何时写 | 发版前 | 发版前（不是发布后精修） |

数据流：

```
docs/RELEASE_NOTES.md 的 ## [X.Y.Z] 段落
   ├─(update_appcast.py)────────────────────► appcast.xml <description> ─► Sparkle 更新弹窗
   └─(generate_release_notes.sh + 模板)─────► GitHub Release 正文

CHANGELOG.md ─► 版本号权威源 + 技术档案（不进 Sparkle）
```

## CHANGELOG.md

参照项目根目录下 `CHANGELOG.md`，在顶部编写最新版本段落。

- **收录本版本的所有改动**，包括对用户无直接感知的内部重构、CI/构建改动、安全加固等。
  按 `Added` / `Changed` / `Fixed` / `Security` 分类；内部工程改动放 `Changed`（或
  `Security`），措辞可保留必要技术细节。
- **版本号权威源**：CI 的 validate 从 CHANGELOG 顶部段落提取版本号，并与 Xcode
  `MARKETING_VERSION` 校验一致。
- 输出后提醒更新最下方链接，如
  `[1.2.0]: https://github.com/f-is-h/Usage4Claude/releases/tag/v1.2.0`

## docs/RELEASE_NOTES.md

面向用户的发布说明，按版本分段（`## [X.Y.Z] - 日期`，结构同 CHANGELOG）。

- **只留用户可感知的现象**：CHANGELOG 里的内部重构 / CI / 安全加固等**不进**这里。
- **去技术词、口语化**：例如把"JWT base64url 解码修复"改成"修复部分账户被过早判定登录过期"。
- **致谢已合并 PR / 已解决 Issue 的作者**：在相关条目末尾加 `(thanks @author, #N)`。
  - **只对确已合并的 PR、确已解决的 Issue 致谢。** 未合并的 PR、仍 Open 且本次并未真正
    修复的 Issue 不要致谢，避免误导用户。作者与状态用
    `gh pr view <n> --json author,state` / `gh issue view <n> --json author,state` 核实。
- **发版前必须写好当前版本段落**：CI validate 会 `grep "^## [X.Y.Z]"` fail-fast，缺了
  Sparkle 弹窗和 Release 正文都会为空。

### 段落示例

```markdown
## [3.3.0] - 2026-07-14

### Added
- **German localization**: Full German UI translation, README, and language
  switcher entry (thanks @schaitl, #66)
- **Per-model weekly usage rows**: Show weekly usage for any number of models
  (e.g. Opus, Sonnet, Fable), no longer limited to two fixed slots
  (thanks @Springs-Tea, #67)
- **Claude OAuth manual paste fallback**: When browser sign-in gets stuck,
  paste the callback link to complete sign-in (thanks @jessicalynn, #68)

### Fixed
- **Codex sign-in expiring unexpectedly**: Fixed an issue that could log some
  Codex accounts out too early
- **Menu bar icon not updating**: The icon now updates immediately when
  switching between light and dark mode
```

## GitHub Release 标题与页面

- **标题**：取自发版 commit 第一行去掉 `[release]` 前缀，例如 `v3.3.0 - German Localization`。
- **正文**：CI 用 RELEASE_NOTES 当前版本段落 + `.github/RELEASE_TEMPLATE.md` 的固定段落
  （📦 Installation、Full Changelog）自动生成。发版前 RELEASE_NOTES 写好即可，**无需发布后精修**。
- **可选装饰**：若想让页面更精致（大标题、总览段落、emoji），可发布后手工编辑网页。这是
  GitHub 页面装饰，**不回流 Sparkle**（Sparkle 已在发布时拿到 RELEASE_NOTES 段落）。固定
  段落由模板追加，装饰正文里不用重复写。

## 相关文档

- [发布 Skill](../.agents/skills/release/SKILL.md)
- [日常发版流程](./DAILY_RELEASE_WORKFLOW.md)
- [Commit Message 编写指南](./COMMIT_MESSAGE_GUIDELINES.md)
- [Sparkle 自动更新机制](./SPARKLE_SETUP.md)
