# Plan: 为 Usage4Claude 增加 Codex 额度支持

## Context

作者本人同时使用 Claude 和 Codex 进行多 AI 并行工作，希望在同一个软件中查看两家额度。本次变更并非来自用户 Issue 需求，而是作者个人需要 + 架构上能做到"对原 Claude 用户无侵入"的双重前提下推进。

ChatGPT 网页侧已有可用的额度查询接口（`/api/auth/session` 取 accessToken，`/backend-api/wham/usage` 查用量），认证方式与 Claude 类似（cookie + 模拟浏览器请求头），意味着现有基础设施大部分可平移。

本变更的核心约束：**Claude-only 用户的体验、视觉、数据存储必须零变化**——他们甚至不需要知道软件能支持 Codex。Codex 仅在用户主动添加 Codex 账号后，作为**平等的另一种 Provider** 出现在软件中。

---

# Part A: 产品设计哲学（实现时复制为 docs/PRODUCT_DESIGN_PHILOSOPHY.md）

## 1. 项目定位

Usage4Claude 是作者为自己和有相同需求的用户做的菜单栏小工具。它有以下不可妥协的属性：

- **小而美**：不追求功能全、用户多、市场大
- **克制**：不是所有合理的需求都会被采纳；以作者的审美为基础
- **开源不商业**：欢迎更多人使用，但不为商业化损耗产品灵魂
- **作品感优先**：每一个新功能都需要先通过"是否符合产品灵魂"的检验

## 2. 核心设计原则

### 2.1 State-driven Progressive Disclosure（基于状态的渐进披露）

UI 形态由用户的真实账号状态决定，而不是由"功能开关"决定。

- 普通的 feature flag 思路：用户在设置里勾选"启用 Codex 支持" → UI 出现 Codex 元素。这种思路会污染设置面板，让 Claude-only 用户感知到 Codex 的存在。
- 本项目采用 state-driven 思路：用户在账号管理里登录了 Codex 账号 → UI 自动适应有 Codex 的形态；只登 Claude 时连 Codex 这个词都不会出现。

**Codex 不是一个功能，而是一种存在状态。**

### 2.2 Provider 平等共存

一旦用户进入 multi-provider 状态，Claude 和 Codex 就是**平等的两个 Provider**，没有主次。不刻意弱化 Codex 也不刻意强调 Claude。

- 视觉权重对等
- 命名、配色、图形识别度对等
- 设置面板中账号管理入口对等
- 数据刷新优先级对等

### 2.3 不为扩展性预留扩展性

主动选择"停在 Claude + Codex 两家"作为产品硬约束。

- 这个工具是为"同时用 Claude 和 Codex"这一类用户做的
- 加入 Gemini / Cursor / Copilot 等会破坏产品形态（三栏 popover、三组菜单栏图标都不再优雅）
- 当有人请求加第三家时，诚实回复"这是有意识的设计取舍"
- 边界感比无限承诺更值钱

## 3. 设计决策的边界

### 3.1 何时说"是"
- 新功能符合产品灵魂（小而美、克制）
- 实现路径不污染既有用户体验
- 代码层面能形成对称、清晰的抽象

### 3.2 何时说"不"
- 新功能需要在设置里开 toggle 才能让既有用户不被打扰 → 通常是错的方向
- 新功能需要为了某类用户而妥协既有视觉语言
- 新功能"看起来酷但用得少"
- 新功能为扩大 TAM 而非解决真实需求

## 4. 对外定位的诚实

README 第一句话不能假装这是个"多 AI 通用工具"，但也不能装作没有 Codex 支持。

参考措辞：
> Track your Claude (and optional Codex) subscription quota — beautifully, in your menu bar.

Codex 的位置应该在副标题/Features 区段而非头图，符合"作者本人需要 + 锦上添花"的真实产品状态。

## 5. 技术决策由哲学推导

以下技术选择不是工程偏好，是哲学的延伸：

| 哲学原则 | 推导出的技术决策 |
|---|---|
| Claude-only 用户零感知 | 不改 Bundle ID、不改仓库名、不改产品名、不动用户数据 |
| 状态驱动 UI | Popover 宽度、菜单栏图标分组都由 `accounts.contains(where: provider == .codex)` 推导 |
| Provider 平等 | 抽 `UsageProvider` 协议；Account 模型加 `provider` 字段；不让 Claude 在代码层面"占主位" |
| 停在两家 | 不引入泛型 `[String: ProviderConfig]`；用 enum 明确表达"只有这两家" |

---

# Part B: 实现计划

## B.1 总体架构

引入三层抽象：

1. **Provider 维度**：`enum ProviderType { case claude, codex }`
2. **数据维度**：每个 Provider 有自己的 UsageData 类型（不强行合并），通过 `UsageDataProtocol` 让 UI 统一访问
3. **账号维度**：`Account` 加 `provider` 字段；Keychain/UserDefaults 按 provider 分桶存储；同时刻可有一个当前 Claude 账号 + 一个当前 Codex 账号

## B.2 文件级改动清单

### 新建文件

| 文件 | 用途 |
|---|---|
| `Usage4Claude/Models/ProviderType.swift` | `enum ProviderType: String, Codable, CaseIterable { case claude, codex }`，附带 `displayName`、`brandColor` |
| `Usage4Claude/Services/UsageProvider.swift` | 协议：`fetchUsage / cancelAllRequests / providerType / sessionValid` |
| `Usage4Claude/Services/CodexAPIService.swift` | 实现 `UsageProvider`。两步请求：先 `GET /api/auth/session` 取 accessToken，再 `GET /backend-api/wham/usage`。配 30/60s 超时、关 HTTP/3、no-cache，跟 `ClaudeAPIService.init` 一致 |
| `Usage4Claude/Services/CodexAPIHeaderBuilder.swift` | Cookie 名 `__Secure-next-auth.session-token`，UA/Origin/Referer 走 `chatgpt.com` |
| `Usage4Claude/Models/CodexUsageData.swift` | Codex 侧的内部模型 + `toCodexUsageData()` 解析 |
| `Usage4Claude/Views/WebLogin/CodexWebLoginCoordinator.swift` | 仿 `WebLoginCoordinator`，加载 `https://chatgpt.com/auth/login`，轮询 `__Secure-next-auth.session-token` cookie，调 `/api/auth/session` 验证 |
| `docs/PRODUCT_DESIGN_PHILOSOPHY.md` | 复制本文档 Part A 全部内容 |
| `docs/IMPLEMENTATION_PLAN_CODEX.md` | 复制本 plan 文件全文（包含 Part A 与 Part B），作为本次实现的归档文档；后续若实现过程中产生方案偏离，需同步更新此文档 |

### 抽象层改造

| 文件 | 改动 |
|---|---|
| `Models/Account.swift` | 加 `provider: ProviderType` 字段，使用自定义 `init(from:)` 让旧 JSON（无 provider 字段）解码时默认为 `.claude`，旧数据零迁移；新增便利构造器 `Account.claude(...)` 和 `Account.codex(...)`；Codex 账号无 `organizationId` 概念，让 `organizationId` 改为 `Optional<String>` |
| `Services/ClaudeAPIService.swift` | 实现 `UsageProvider` 协议；不改外部行为 |
| `Services/KeychainManager.swift` | **保持 Claude 数据现状不动**——`"accounts"` / `"DEBUG_accounts"` 继续承载 Claude 账号 JSON。**仅新增** `"accounts_codex"` / `"DEBUG_accounts_codex"` 用于 Codex。新增 helper `keychainKey(for: ProviderType)`：`.claude → "accounts"`、`.codex → "accounts_codex"`，把不对称隐藏在内部。**不写任何迁移代码**——零数据风险，回滚只需删 Codex 新 key |
| `Models/UserSettings.swift` | `currentAccountId` 保留语义（继续表示当前 Claude 账号 UUID）；新增 `currentCodexAccountId`（DEBUG 前缀同步保持，参考 bd019d7）；`accounts: [Account]` 拆解为按 provider 维度访问的属性 `claudeAccounts: [Account]` / `codexAccounts: [Account]`，但底层存储仍按 provider 分桶（互不影响）；既有 `sessionKey` / `organizationId` 计算属性语义不变（指向当前 Claude 账号）；新增 `codexSessionToken` 计算属性指向当前 Codex 账号。**新增 `isMultiProviderActive: Bool`** = `!claudeAccounts.isEmpty && !codexAccounts.isEmpty` |
| `Helpers/DataRefreshManager.swift` | `@Published var usageData` 拆为 `claudeUsageData` 和 `codexUsageData`；`fetchUsage` 内部根据当前激活的 provider 集并发拉取（仍走 `DispatchGroup`）；`scheduleResetVerification` 按 provider 各自调度；智能模式触发条件改为"两家任意一家发生变化都重置 active 模式"；TimerManager 的 id 加 provider 后缀避免冲突 |

### LimitType 与图形扩展

| 文件 | 改动 |
|---|---|
| `Models/UserSettings.swift:143` (`LimitType`) | 新增 case：根据探针实际返回的 Codex 数据结构决定，**先做最小集**：`codexPrimary`（必有）+ `codexSecondary`（如有）。`displayName` 同步加；新增 `provider: ProviderType` 计算属性方便分组。**形状复用现有定义**：`codexPrimary` 复用圆形（与 `fiveHour` 同形），`codexSecondary`（如有）复用六边形（与 `extraUsage` 同形），因此 `isCircular` / `isHexagonal` 等谓词只需把 Codex case 加入对应分支 |
| `Models/UserSettings.swift:1223` (`getActiveDisplayTypes`) | 加入 Codex case 排序：`fiveHour → sevenDay → extraUsage → opus → sonnet → codexPrimary → codexSecondary`；smart 模式下 Codex 类型仅在对应 `codexUsageData` 字段非 nil 时加入 |
| `Helpers/ColorScheme.swift` | 新增 `codexPrimaryColor` / `codexPrimaryColorAdaptive` / `codexPrimaryColorSwiftUI`（如 Codex Secondary 存在则同步加），三档配色（<70% / <90% / ≥90%）。Codex 品牌色建议：deep teal 或 graphite，与 Claude 的橙色系明显错开。**形状复用但配色独立**——这是确保两家视觉可区分的关键，因为形状不再承担区分职责 |
| `Helpers/IconShapePaths.swift` | `pathForLimitType` 中 Codex case 直接复用已有路径（Codex Primary → 圆形路径；Codex Secondary → 六边形路径） |
| `Helpers/ShapeIconRenderer.swift` | **不新增渲染函数**。直接复用 `MenuBarIconRenderer.createCircleImage` 和 `ShapeIconRenderer.drawHexagonWithPercentage`，仅传入 Codex 的颜色函数 |
| `App/MenuBarIconRenderer.swift:378` (`createIconForType`) | switch 加 Codex case，分发到既有的 circle / hexagon 渲染函数，传 Codex 颜色 |

### 菜单栏 Provider 分组逻辑

| 文件 | 改动 |
|---|---|
| `App/MenuBarUI.swift:combineIcons` | 增加 `multiProvider: Bool` 参数。当 true 时：拼接顺序为 `[Claude provider 标识图标] + [Claude 指标们] + [Codex provider 标识图标] + [Codex 指标们]`；当 false 时维持现有逻辑 |
| `App/MenuBarUI.swift:generateCacheKey` (:530) | cache key 加入 `mp_<bool>_codex_<percentages>` 片段；缓存上限 50 暂保留，必要时观察后调 |
| 新增小函数 `createProviderBrandIcon(_ provider: ProviderType)` | 在 `MenuBarIconRenderer` 中。Claude 用现有 AppIcon 资源；Codex 用新增的 monochrome 标识（建议用 SF Symbols 风格一个 16x16 的简笔标识，避免直接拷贝 OpenAI 商标） |

### Popover 自适应宽度

| 文件 | 改动 |
|---|---|
| `Views/UsageDetailView.swift` | 引入 `@EnvironmentObject` 获取 `UserSettings.isMultiProviderActive`；`.frame` 的 `width` 改为计算值：单 provider 时 290pt，multi 时 580pt；高度计算逻辑：单 provider 时维持现状，multi 时 `max(claudeColumnHeight, codexColumnHeight)`；用 `.animation(.easeInOut(duration: 0.25), value: isMultiProviderActive)` 平滑过渡 |
| `Views/UsageDetailView.swift` | multi 模式时 body 改为 `HStack` 双列，左列复用现有 Claude 渲染逻辑（包括大圆环 + UnifiedLimitRow），右列是 Codex 平行渲染。**关键**：通过抽出 `ProviderColumn(provider:)` 子视图实现两列复用，避免硬编码两份 |
| `Views/Components/UsageRowComponents.swift` (`UnifiedLimitRow.iconColor` :93 等四处 switch) | 加 Codex case |
| `Views/Extensions/UsageDetailView+Helpers.swift` | `getPrimaryLimitData` 改为 provider-aware；新增 `getCodexPrimaryLimitData` |

### 设置面板

| 文件 | 改动 |
|---|---|
| `Views/Settings/Tabs/AuthSettingsView.swift` | 顶部"添加账号"按钮保留为单一入口；点击后弹出小型 Provider 选择器（"Claude / Codex"），再走对应的 WebLogin 流程；账号列表分两组显示（"Claude Accounts" + "Codex Accounts" sectionHeader），仅在两家都有账号时才显示 sectionHeader，否则隐藏（state-driven 原则） |
| `Views/Settings/Tabs/GeneralSettingsView.swift` | "显示选项"卡片中 LimitType 复选框列表自动包含 Codex 类型（因为 `LimitType.allCases` 已经扩展） |
| Welcome / 引导流程（`Views/Settings/Welcome/`） | 新用户首次启动时仍只引导 Claude 登录（保持现状）；不增加 Codex 引导步骤——Codex 完全由"老用户在设置里主动添加"触发 |

### 本地化

| 文件 | 改动 |
|---|---|
| `Resources/{en,ja,ko,zh-Hans,zh-Hant}.lproj/Localizable.strings` | 新增 key：`provider.claude` / `provider.codex` / `account.add.claude` / `account.add.codex` / `limit.codex_primary` / `limit.codex_secondary` / `webview.codex.title` 等；不动既有 key（保持向后兼容） |

### 不改的东西（明确清单）

- 仓库名 `f-is-h/Usage4Claude` — 不改
- Bundle ID `xyz.fi5h.Usage4Claude` — 不改
- 产品 Display Name `Usage4Claude` — 不改
- `UpdateChecker.swift` 的 `repoOwner` / `repoName` — 不改（因此不需要发"过渡版"）
- `MenuBarManager.swift:405` 的 `setFrameAutosaveName` — 不改
- `DiagnosticLogger.swift` 的 `Application Support/Usage4Claude/logs` 路径 — 不改
- README 主标题"Usage4Claude" — 不改，但在 Features 列表加一行 Codex 支持说明（Part A.4）
- 网站 `usage4claude.pages.dev` 域名、HTML title、SEO meta — 不改

## B.3 实现顺序（单一 feature 分支，本地完整开发后一次性 PR）

所有改动在本地一个 feature 分支（建议命名 `feature/codex-support`）上完成，作者本人使用一段时间确认稳定后，再以单个 PR 合并回 main。下面的阶段划分仅为本地开发的逻辑顺序、便于切换上下文，不对应多次 PR：

1. **阶段 1：Provider 抽象层重构** — 加 `ProviderType` / `UsageProvider` / `Account.provider`（带 Codable 默认值），`ClaudeAPIService` 实现协议；KeychainManager helper 落地。**完成后自测**：删旧版安装新版本地 build，确认 Claude 行为零变化。
2. **阶段 2：Codex API 服务 + WebLogin** — 新增 `CodexAPIService` / `CodexAPIHeaderBuilder` / `CodexWebLoginCoordinator` / `CodexUsageData`；UI 暂不接入，通过 Debug menu 触发 fetch 看日志验证 API 探针正确。
3. **阶段 3：UI 层 LimitType 扩展** — 加 Codex 配色与缓存键；形状直接复用既有圆形/六边形不新增；菜单栏单 provider 状态下视觉不变（codexAccounts 为空时不会渲染）。
4. **阶段 4：菜单栏 + Popover multi-provider 自适应** — 激活双 provider 视觉：Provider 标识图标分组、Popover 290↔580pt 自适应动画、`ProviderColumn` 子视图抽离。
5. **阶段 5：设置面板与文档** — AuthSettingsView 改造、Welcome 流程检查、本地化补全、`docs/PRODUCT_DESIGN_PHILOSOPHY.md` 与 `docs/IMPLEMENTATION_PLAN_CODEX.md`（本 plan 文件全文复制版）落地、README Features 增补。
6. **阶段 6：本人长期试用** — 完整功能在 feature 分支上自用至少 1-2 周，覆盖系统休眠/唤醒、网络切换、代理开关、各种边界场景；期间发现的问题直接在分支上修复。
7. **阶段 7：单次 PR 合并** — 试用稳定后，整理 commits（必要时 squash）、撰写详细 PR description（按 `docs/COMMIT_MESSAGE_GUIDELINES.md` 规范，英文、无 emoji、无 Co-Authored-By），合并到 main 并发布新版本。

## B.4 验证计划

### 自动化验证（编译期 + 单元测试）
- `swift build` 通过
- 现有单元测试全部通过（重点：`UserSettingsTests` 中关于账号切换的测试可能需要补 provider 维度）

### 手动验证矩阵

| 场景 | 期望行为 |
|---|---|
| Claude-only 用户启动新版 | 视觉、行为 100% 与旧版一致；Keychain Access 中 `accounts` key 内容与旧版完全相同（无任何写入），`accounts_codex` key 不存在 |
| 卸载新版回退到旧版 | 旧版正常读取 `accounts` 数据，Claude 账号无丢失（验证回滚安全性）|
| Claude-only 用户在设置里点"添加账号" | 弹出 Provider 选择器（这是唯一的可感知变化）|
| 添加第一个 Codex 账号 | Popover 平滑从 290pt 扩展到 580pt；菜单栏出现 Provider 分组；动画无闪烁 |
| 删除最后一个 Codex 账号回到 Claude-only | Popover 平滑收回到 290pt；视觉回到旧版状态 |
| 同时有 Claude 和 Codex 账号，切换某一家的当前账号 | 只重新拉对应 provider 的数据；另一家不受影响 |
| 系统休眠 5 分钟唤醒 | 两家数据都自动刷新（沿用现有 wake observer）|
| 关掉 Wi-Fi 再开启 | 两家都正常回归刷新 |
| 启用代理 | 两家请求都通过代理（HTTP/3 已禁用）|
| Codex session 过期 | 只有 Codex 列显示"会话过期"提示，Claude 列正常 |
| Codex Cloudflare 拦截 | 错误处理与 Claude 等同 |
| Debug build 与 Release build 同时安装 | 各自的账号数据完全隔离（旧 bd019d7 隔离原则在 Codex 数据上同样成立）|
| 仅登 Codex 不登 Claude（极端） | 应可用；UI 仅显示 Codex 列（580pt 单列略宽，可接受，或 fallback 到 290pt 单列布局）|

### Codex API 探针前置任务
在 PR-2 开工前，作者本人需要用浏览器 DevTools 抓一次完整的 `/backend-api/wham/usage` 返回，确认：
- `rate_limit` 下到底有几个 window（primary / secondary / weekly?）
- 每个 window 是否有 `resets_at` 字段
- 是否有类似 Claude Extra Usage 的"额外配额"概念
- accessToken 的实际 TTL（决定是每次请求都刷还是缓存几分钟）

探针结果会反过来微调 `LimitType` 新增的 case 数量和 `CodexUsageData` 字段。

---

## B.5 风险与开放问题

1. **Codex API 可能变**：ChatGPT 后端不是公开 API，随时可能调整。所有 Codex 相关代码要做好"接口失败时优雅降级"——拉不到数据时，UI 自动回退到 Claude-only 形态（state-driven 原则在错误情况下也成立）。
2. **WebLogin 风控**：chatgpt.com 对自动化登录可能比 claude.ai 严格。如果 `nonPersistent` WKWebView + 标准 UA 不够，可能要考虑用 `WKWebsiteDataStore.default()`（共享 Safari cookie）作为 fallback，但这会引入隐私问题，需要权衡。
3. **形状复用的视觉清晰度依赖配色**：因为 Codex 与 Claude 共享形状（圆 / 六边形），区分两家的唯一视觉线索是配色 + Provider 标识图标分组。这要求 Codex 配色必须与同形状的 Claude 配色（5h 绿色系、Extra 粉色系）有明显色相错开。建议 Codex Primary 用 deep teal，Codex Secondary 用 graphite/dark slate，避免落入绿/粉/紫的既有色域。
4. **图标知识产权**：Codex 的 Provider 标识图标不能直接拿 OpenAI 商标，建议用一个 SF Symbol（如 `sparkles` 或 `cpu`）做风格化处理，与 Claude 的 AppIcon 视觉语言匹配。

---

## B.6 后续讨论

- Plan 通过后，先创建一个跟踪 issue/discussion，把 Part A 哲学公开发出去，欢迎用户讨论（这本身也是产品理念的一种诚实输出）
- PR-1 落地后冷藏一周，作者本人主用确认稳定，再开 PR-2
- 如果 Codex API 探针发现数据结构与预期差异巨大（比如根本没有 reset 时间），整个计划需要回到 Phase 2 重新设计
