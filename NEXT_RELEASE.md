# 下次发版备忘（一次性）

> **这是一次性文件，不是长期手册。** 本项目刚把 Sparkle 更新弹窗和 GitHub Release 正文的
> 内容源从 `CHANGELOG.md` 改成了 `RELEASE_NOTES.md`（详见 release skill /
> `docs/CHANGELOG_AND_RELEASE_NOTES_GUIDELINES.md`）。**下次发版是这套新机制的第一次实战。**
> 本文件只记录“因为是第一次”而存在的特殊注意点。**新机制跑通一次后，删掉本文件即可。**
> 常规、完整的发版流程见 release skill（`.agents/skills/release/SKILL.md`）。

---

## 为什么这次特殊

发版链路刚改过，改动只做了本地验证，**没在真实的 CI 发版里跑过**：

- `release.yml`：触发 paths 加了 `RELEASE_NOTES.md`；validate 阶段新增
  “RELEASE_NOTES 是否有当前版本段落”的 fail-fast 校验；Generate release notes 和
  Update appcast 两步的数据源从 `CHANGELOG.md` 改成 `RELEASE_NOTES.md`。
- `update_appcast.py` / `generate_release_notes.sh`：提取源改成 `RELEASE_NOTES.md`。

所以第一次实战前，务必比平时多做一步 **CI 冒烟验证**。

---

## 下次发版必须注意的 4 个特殊点

1. **先做一次 CI 冒烟，别直接正式发**（因为上面的 CI 改动没在真实发版跑过）。二选一：
   - **`test-release` 分支**：把发版改动 push 到 `test-release`（commit 含 `[release]`）。
     CI 只跑 validate + build（编译/签名/打 DMG），**跳过发布**，不打 tag、不碰 appcast。
     确认绿了再正式发 `main`。
   - 或 **Actions → workflow_dispatch → 勾 `dry_run`**（对 main）：跑完整链路但产 draft，
     tag 用 `test-v<版本>`、appcast 只打印不推。事后清理：
     `gh release delete test-v<版本> --yes` 且 `git push origin :refs/tags/test-v<版本>`。

2. **两份文件顶部都要新增新版本段落**。当前 `CHANGELOG.md` 和 `RELEASE_NOTES.md` 顶部
   都是 `## [3.3.0]`（已发布）。下次发新版（如 3.3.1 / 3.4.0）时，在**两份文件顶部各加**
   该新版本段落；v3.3.0 段落留作历史，不要动。

3. **版本号三处一致**：`CHANGELOG.md`、`RELEASE_NOTES.md`、Xcode `MARKETING_VERSION`（两处）
   必须是同一个新版本号。不一致 CI 会失败。

4. **RELEASE_NOTES 漏写会被拦**：validate 阶段 `grep "^## [X.Y.Z]" RELEASE_NOTES.md`，
   缺当前版本段落直接 fail-fast（这就是防“忘了写用户版说明导致 Sparkle 弹窗为空”）。

---

## 简版动作清单

细节按 release skill 走，顺序：

1. `git fetch origin` 核对远程 → `git log v3.3.0..HEAD` 收集变更
2. 定版本号（patch/minor/major）
3. 写 `CHANGELOG.md`（技术全量）+ `RELEASE_NOTES.md`（面向用户 + 致谢，只对已合并 PR /
   已解决 Issue 致谢）
4. 改 Xcode 两处 `MARKETING_VERSION`
5. 本地验证：
   ```bash
   xcodebuild -project Usage4Claude.xcodeproj -scheme Usage4Claude -configuration Release build 2>&1 | tail -3
   .github/scripts/verify_version.sh verify CHANGELOG.md Usage4Claude.xcodeproj
   .github/scripts/generate_release_notes.sh .github/RELEASE_TEMPLATE.md <版本> /tmp/rn.md RELEASE_NOTES.md
   # 看 /tmp/rn.md 第一个 --- 之上那段 = Sparkle 弹窗会显示的内容
   ```
6. **CI 冒烟验证一次**（见上面第 1 点）——这是本次唯一比常规多出来的步骤
7. 用户手写单行发版 commit：`[release] vX.Y.Z - 标题` → push `main`
8. 监控 CI；发布后确认 Sparkle 弹窗显示的是 RELEASE_NOTES 的用户版内容

---

## 发完之后

新机制首发验证 OK（Sparkle 弹窗内容正确、Release 正文正确）后：**删除本文件**。
之后常规发版直接用 release skill 即可。
