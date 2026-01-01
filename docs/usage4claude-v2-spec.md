# Usage4Claude 多限制显示功能实现文档

## 项目概述

为 Usage4Claude 应用添加对多种使用限制的支持，包括模型特定限制（Opus/Sonnet）和额外付费额度（Extra Usage）的监控与显示。

---

## 功能需求

### 1. 支持的限制类型

应用需要支持以下5种限制的显示：

| 限制类型 | API字段 | 图标形状 | 尺寸(W×H) | 说明 |
|---------|---------|----------|-----------|------|
| 5小时限制 | `five_hour` | ⭕ 圆形 | 18×18 | 已存在，保持不变 |
| 7天限制 | `seven_day` | ⭕ 圆形 | 18×18 | 已存在，保持不变 |
| Opus 7天限制 | `seven_day_opus` | ▯ 竖向圆角矩形 | 14×18 | 新增，旋转90度 |
| Sonnet 7天限制 | `seven_day_sonnet` | ▭ 横向圆角矩形 | 18×14 | 新增，平放 |
| Extra Usage | `extra_usage` | ⬡ 六边形 | 18×18 | 新增，平放（上下边平行）|

**图标显示顺序**（从左到右）：
1. five_hour
2. seven_day
3. extra_usage
4. seven_day_opus
5. seven_day_sonnet

### 2. 核心功能点

#### 2.1 智能显示模式（默认）
- 自动显示所有 API 返回数据非 null 的限制
- 强制使用单色主题
- 当选中此模式时，自定义显示选项不可用

#### 2.2 自定义显示模式
- 用户手动选择要显示的限制类型
- **限制规则**：
  - 必须至少选择一个圆形图标（five_hour 或 seven_day）
  - UI 禁止取消最后一个圆形图标
- **主题规则**：
  - 仅选择"five_hour"或"seven_day"或"both"：可选彩色主题或单色主题
  - 任何其他组合：强制单色主题，彩色主题选项显示但禁用

#### 2.3 菜单栏图标显示
- 根据显示模式和 API 数据，动态显示 1-5 个图标
- 图标间距：3pt（从原来的 4pt 减小）
- 最大总宽度：18×5 + 3×4 = 102pt

#### 2.4 详情窗口（Popover）
- 动态显示文字条，最少 2 条（five_hour + seven_day），最多 5 条
- 窗口高度根据显示的文字条数量自动扩展（无最大限制）
- 只有 five_hour 和 seven_day 的显示/隐藏会影响圆环图表
- 新增限制（opus/sonnet/extra_usage）只影响文字条的显示

**文字条布局**（2列）：
```
限制名称                 重置时间/状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5小时限制               今天 12:00
7天限制                 12月16日
额外用量                 $10/$25
7天Opus限制             12月16日
7天Sonnet限制           12月17日
```

**交互行为**：
- 默认显示：重置日期时间（今天显示"今天 HH:mm"，其他显示"MM月DD日"）
- 点击任意文字条：所有文字条切换为"剩余时间/剩余额度"模式
- 再次点击：切换回"重置日期时间"模式
- 状态保持到窗口关闭，下次打开恢复为"重置日期时间"模式

**剩余模式显示格式**：
```
限制名称                 剩余时间/额度
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5小时限制               还剩 2小时
7天限制                 还剩 1天3小时
额外用量                 还可使用 $15
7天Opus限制             还剩 3天4小时
7天Sonnet限制           还剩 5天6小时
```

**日期时间格式规则**：
- 今天的重置时间：`今天 HH:mm`（如"今天 12:00"）
- 非今天的重置时间：`MM月DD日`（如"12月16日"）
- Extra Usage：始终显示 `$已使用/$总额度`

#### 2.5 设置界面
在设置页面添加"显示选项"部分：

```
显示模式：
  ● 智能显示
    自动显示所有有数据的限制类型
  ○ 自定义显示
    [展开时显示以下选项]
    ☑️ 5小时限制
    ☑️ 7天限制
    ☐ Opus 7天限制
    ☐ Sonnet 7天限制
    ☐ 额外用量

主题选择：
  ○ 单色主题
  ○ 彩色主题（不可用：显示超过2个限制时仅支持单色）
    [根据显示选项动态启用/禁用]
```

#### 2.6 欢迎界面增强
在首次启动的欢迎界面添加"显示选项"配置步骤：

- 提供智能显示/自定义显示的单选
- 自定义显示时显示复选框列表
- **实时预览**：
  - 遵循用户当前选择
  - 智能模式：预览显示全部 5 个图标（使用假数据）
  - 自定义模式：仅预览勾选的图标
  - 假数据百分比：55%, 66%, 77%, 88%, 99%（按顺序）

---

## API 集成

### API 0: 获取 Organization 列表（新增）

**端点**：
```
GET https://claude.ai/api/organizations
```

**请求头**：
```http
Cookie: sessionKey={your_session_key}
Accept: application/json
```

**响应示例**：
```json
[
  {
    "id": 6305628,
    "uuid": "xxxx-xxx-xx-xx-xxx",
    "name": "XXX's Organization",
    "created_at": "2024-01-01T00:00:00.000000Z",
    "updated_at": "2024-12-15T00:00:00.000000Z",
    "capabilities": []
  }
]
```

**用途**：
- 自动获取用户的 Organization ID（uuid 字段）
- 简化配置流程，用户只需提供 sessionKey
- 在首次配置和重新配置时调用

**数据模型**：
```swift
struct Organization: Codable {
    let id: Int
    let uuid: String
    let name: String
    let created_at: String?
    let updated_at: String?
    let capabilities: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, name, capabilities
        case created_at
        case updated_at
    }
}
```

### API 1: 主要使用数据

**端点**：
```
GET https://claude.ai/api/organizations/{org_id}/usage
```

**请求头**：
```http
Cookie: sessionKey={your_session_key}
Accept: application/json
```

**响应示例**：
```json
{
  "five_hour": {
    "utilization": 58.0,
    "resets_at": "2025-12-15T12:59:59.878256+00:00"
  },
  "seven_day": null,
  "seven_day_oauth_apps": null,
  "seven_day_opus": null,
  "seven_day_sonnet": null,
  "iguana_necktie": null,
  "extra_usage": null
}
```

**字段说明**：
- `utilization`: 使用百分比（0-100 的浮点数）
- `resets_at`: ISO 8601 格式的重置时间字符串
- 值为 `null` 表示该限制不适用或未启用

### API 2: Extra Usage 额度信息

**端点**：
```
GET https://claude.ai/api/organizations/{org_id}/overage_spend_limit
```

**请求头**：
```http
Cookie: sessionKey={your_session_key}
Accept: application/json
```

**响应示例**：
```json
{
  "organization_uuid": "490a28-xxxxxx",
  "limit_type": "organization",
  "seat_tier": null,
  "account_uuid": null,
  "account_email": null,
  "account_name": null,
  "org_service_name": null,
  "is_enabled": true,
  "monthly_credit_limit": 2000,
  "currency": "USD",
  "used_credits": 0,
  "disabled_reason": null,
  "disabled_until": null,
  "out_of_credits": true,
  "discount_percent": null,
  "discount_ends_at": null,
  "created_at": "2025-12-15T10:01:35.060901Z",
  "updated_at": "2025-12-15T10:01:35.060901Z"
}
```

**关键字段**：
- `is_enabled`: 是否启用 Extra Usage 功能
- `monthly_credit_limit`: 月度额度上限（美元）
- `used_credits`: 已使用额度（美元）
- `currency`: 货币类型（通常为 "USD"）
- `out_of_credits`: 是否已用完额度

**注意**：只有当 `is_enabled: true` 且在智能模式下或用户勾选时才显示 Extra Usage

---

## 凭据管理与配置流程

### 1. 存储策略

**敏感度分级**：

```
Keychain 存储（高敏感）：
- sessionKey: String  // Claude session key (sk-ant-sid...)

UserDefaults 存储（低敏感/配置）：
- organizationId: String        // Organization UUID（v2.0.0 迁移）
- displayMode: DisplayMode      // 显示模式
- customDisplayTypes: [String]  // 自定义显示选项
- refreshInterval: Int          // 刷新间隔
- launchAtLogin: Bool          // 登录时启动
- preferredTheme: String       // 首选主题
- preferredLanguage: String    // 首选语言
```

**重要说明**：
- Organization ID 从 Keychain 迁移到 UserDefaults（v2.0.0 变更）
- Organization ID 只是标识符，没有 sessionKey 无法执行任何操作
- 减少 Keychain 弹窗次数：2次 → 1次
- 提升配置流程用户体验

### 2. 自动获取 Organization ID

**实现要点**：
- 调用 `GET /api/organizations` API
- 从返回的数组中取第一个组织的 uuid
- 保存到 UserDefaults 而非 Keychain
- 错误处理：sessionKey 无效或网络问题

### 3. 配置流程优化

**旧流程（v1.6.0）**：
1. 用户手动输入 sessionKey → Keychain 弹窗
2. 用户手动输入 organizationId → Keychain 弹窗  
3. 完成配置

**新流程（v2.0.0）**：
1. 用户输入 sessionKey → Keychain 弹窗
2. 自动获取 organizationId → 保存到 UserDefaults（无弹窗）
3. 完成配置

**优势**：
- ✅ 减少用户输入（不需要找 organization ID）
- ✅ 减少 Keychain 弹窗（2次 → 1次）
- ✅ 降低配置门槛（只需要 sessionKey）
- ✅ 提升配置成功率（自动获取更准确）

### 4. 数据迁移

**升级到 v2.0.0 时的迁移逻辑**：
- 应用启动时检查是否需要迁移
- 从 Keychain 读取旧的 organization ID
- 迁移到 UserDefaults
- 从 Keychain 删除旧数据
- 标记迁移完成，避免重复执行

---

## 数据模型设计

### 扩展 UsageData 模型

**现有字段（保持不变）**：
- `sessionPercentage: Double` - five_hour 百分比
- `sessionResetsAt: Date?` - five_hour 重置时间
- `weeklyPercentage: Double` - seven_day 百分比
- `weeklyResetsAt: Date?` - seven_day 重置时间
- `lastUpdated: Date` - 最后更新时间

**新增字段**：
- `opusPercentage: Double?` - Opus 7天限制百分比
- `opusResetsAt: Date?` - Opus 重置时间
- `sonnetPercentage: Double?` - Sonnet 7天限制百分比
- `sonnetResetsAt: Date?` - Sonnet 重置时间
- `extraUsageEnabled: Bool` - Extra Usage 是否启用
- `extraUsageUsed: Double?` - 已使用额度（美元）
- `extraUsageLimit: Double?` - 总额度（美元）
- `extraUsageCurrency: String` - 货币类型（默认 "USD"）

**计算属性**：
- `extraUsagePercentage: Double?` - Extra Usage 使用百分比
- `extraUsageRemaining: Double?` - Extra Usage 剩余额度

### 用户设置模型

**枚举定义**：

```swift
enum LimitType: String, Codable, CaseIterable {
    case fiveHour = "five_hour"
    case sevenDay = "seven_day"
    case opusWeekly = "seven_day_opus"
    case sonnetWeekly = "seven_day_sonnet"
    case extraUsage = "extra_usage"
    
    var isCircular: Bool {
        return self == .fiveHour || self == .sevenDay
    }
}

enum DisplayMode: String, Codable {
    case smart = "smart"        // 智能显示
    case custom = "custom"      // 自定义显示
}
```

**UserSettings 新增字段**：
- `displayMode: DisplayMode` - 显示模式（默认 smart）
- `customDisplayTypes: Set<LimitType>` - 自定义显示选择

**关键方法**：
- `getActiveDisplayTypes(usageData:)` - 获取当前应显示的限制类型
- `canUseColoredTheme()` - 判断是否可以使用彩色主题

**主题判断逻辑**：
- 智能模式：总是返回 false（强制单色）
- 自定义模式：只有选择 1-2 个圆形图标时返回 true

---

## UI 设计规范

### 1. 图标设计

#### 1.1 圆形图标（five_hour, seven_day）
**保持现有实现**，无需改动。

#### 1.2 横向圆角矩形（seven_day_sonnet）
- 尺寸：18×14
- 圆角半径：3
- 边框宽度：2.0
- 进度沿矩形边缘顺时针绘制

#### 1.3 竖向圆角矩形（seven_day_opus）
- 尺寸：14×18
- 圆角半径：3
- 边框宽度：2.0
- 进度沿矩形边缘顺时针绘制

#### 1.4 六边形图标（extra_usage）
- 尺寸：18×18
- 边框宽度：2.0
- 平放（上下边平行于地面）
- 从右侧中点开始顺时针绘制6个顶点
- 进度沿六边形边缘绘制

### 2. 颜色系统

#### 2.1 单色主题（强制用于多图标）
**使用系统自适应颜色**，根据百分比调整透明度：
- 0-50%：controlTextColor + 80% 透明度
- 51-75%：controlTextColor + 90% 透明度
- 76-100%：controlTextColor + 100% 透明度

#### 2.2 彩色主题（仅双圆形图标）
- 0-50%：systemGreen
- 51-75%：systemOrange
- 76-100%：systemRed

### 3. 菜单栏图标组合

**关键参数**：
- 图标间距：3pt
- 最大高度：18pt
- 垂直居中对齐
- 按顺序组合：five_hour → seven_day → extra_usage → opus → sonnet

**图标缓存策略**：
- 使用 NSCache 缓存渲染结果
- Key 格式：`"{type}_{percentage}_{theme}"`
- 避免频繁重绘

### 4. 详情窗口（Popover）

#### 4.1 布局结构
- 顶部：圆环图表（1-2个，根据设置动态显示）
- 中部：分割线
- 底部：文字条列表（2-5条，动态显示）
- 窗口宽度：320pt
- 窗口高度：根据内容自动调整

#### 4.2 文字条设计
**2列布局**：
- 左列：限制名称（左对齐）
- 右列：重置时间或剩余时间（右对齐，灰色）
- 行高：根据系统字体自动调整
- 可点击区域：整行

#### 4.3 日期时间格式
**默认模式（重置日期时间）**：
- 今天：`今天 HH:mm`
- 非今天：`MM月DD日`
- Extra Usage：`$已使用/$总额度`

**剩余模式（剩余时间/额度）**：
- 时间：`还剩 X天X小时` 或 `还剩 X小时X分钟`
- Extra Usage：`还可使用 $金额`

### 5. 设置界面

#### 5.1 窗口配置
- 尺寸：600×500
- 标题栏高度：38pt（优化后）
- 隐藏最小化和最大化按钮
- 监听语言变化，动态更新标题

#### 5.2 凭据设置
**布局要点**：
- Session Key：可编辑的 SecureField
- Organization ID：只读显示，带"重新获取"按钮
- 提示文本：说明自动获取机制
- 保存按钮：验证后自动获取 organization ID

#### 5.3 显示设置
**布局要点**：
- 单选组：智能显示 / 自定义显示
- 条件显示：自定义模式下显示复选框列表
- 圆形图标保护：禁用最后一个圆形图标的取消操作
- 主题选择：根据显示选项动态启用/禁用彩色主题

### 6. 欢迎界面

#### 6.1 凭据配置步骤
**关键元素**：
- Session Key 输入框（SecureField）
- 配置按钮（带加载状态）
- 成功提示（显示已获取的 organization ID）
- 错误提示（网络或认证失败）

#### 6.2 显示选项配置步骤
**关键元素**：
- 显示模式选择（单选：智能/自定义）
- 自定义选项（条件显示的复选框列表）
- 实时预览（显示菜单栏图标效果）
- 预览数据：55%, 66%, 77%, 88%, 99%

**预览逻辑**：
- 智能模式：预览全部5个图标
- 自定义模式：预览已选中的图标
- 使用单色主题渲染

---

## 实现关键点

### 1. API 调用策略
- 并行请求主 usage API 和 Extra Usage API
- Extra Usage 失败不影响主功能
- 使用 async/await 进行异步处理
- 统一错误处理和超时控制

### 2. 数据解析要点
- 使用 JSON 解析处理 API 响应
- 所有限制类型的数据都可能为 null，需要安全解包
- ISO 8601 日期格式解析（带小数秒）
- Extra Usage 的 is_enabled 判断

### 3. UserDefaults 存储
**关键 Keys**：
- `organizationId`: String
- `displayMode`: String
- `customDisplayTypes`: [String]
- `organizationIdMigrated`: Bool（迁移标记）

---

## 测试建议

### 1. 单元测试
**数据解析测试**：
- 完整响应解析
- 部分字段为 null 的响应
- Extra Usage 百分比计算
- 日期解析（ISO 8601 格式）

**显示逻辑测试**：
- 智能模式下各种数据组合
- 自定义模式下的圆形图标限制
- 主题可用性判断

### 2. UI 测试场景

**图标渲染测试**：
- 各类型图标在不同百分比下的渲染
- 单色/彩色主题切换
- 图标组合和间距

**详情窗口测试**：
- 不同数量的文字条显示（2-5条）
- 显示模式切换
- 日期时间格式正确性
- Extra Usage 格式显示

**设置界面测试**：
- 显示模式切换
- 圆形图标保护逻辑
- 主题选项动态启用/禁用
- 凭据自动获取流程

**欢迎界面测试**：
- 配置流程完整性
- 实时预览功能
- 假数据显示正确

### 3. 边界情况测试
- API 返回所有字段为 null
- API 请求失败
- Extra Usage 未启用
- 百分比为 0/100/超过100
- 日期解析失败
- 网络超时
- 数据迁移失败

---

## 本地化字符串

### 新增本地化 Key

```swift
enum LocalizationKey: String {
    // 限制类型名称
    case fiveHourLimit = "five_hour_limit"
    case sevenDayLimit = "seven_day_limit"
    case opusWeeklyLimit = "opus_weekly_limit"
    case sonnetWeeklyLimit = "sonnet_weekly_limit"
    case extraUsage = "extra_usage"
    
    // 显示选项
    case displayOptions = "display_options"
    case smartDisplay = "smart_display"
    case smartDisplayDescription = "smart_display_description"
    case customDisplay = "custom_display"
    
    // 主题选择
    case themeSelection = "theme_selection"
    case monochromeTheme = "monochrome_theme"
    case coloredTheme = "colored_theme"
    case coloredThemeUnavailableReason = "colored_theme_unavailable_reason"
    
    // 凭据配置
    case credentials = "credentials"
    case sessionKeyHint = "session_key_hint"
    case sessionKeyHelp = "session_key_help"
    case sessionKeyRequired = "session_key_required"
    case organizationIdAutoFetched = "organization_id_auto_fetched"
    case organizationIdHelp = "organization_id_help"
    case autoFetched = "auto_fetched"
    case fetching = "fetching"
    case refetch = "refetch"
    case configuring = "configuring"
    case credentialsSaved = "credentials_saved"
    case save = "save"
    case back = "back"
    case continue = "continue"
    
    // 欢迎界面
    case welcomeCredentialsTitle = "welcome_credentials_title"
    case welcomeCredentialsSubtitle = "welcome_credentials_subtitle"
    case welcomeDisplayTitle = "welcome_display_title"
    case welcomeDisplaySubtitle = "welcome_display_subtitle"
    case preview = "preview"
    
    // 详情窗口 - 日期时间格式
    case today = "today"                    // "今天"
    case todayTime = "today_time"          // "今天 %@" (用于格式化时间)
    case monthDay = "month_day"            // "%d月%d日"
    case extraUsageFormat = "extra_usage_format"  // "$%d/$%d"
    
    // 详情窗口 - 剩余时间
    case extraUsageRemaining = "extra_usage_remaining"  // "还可使用 %@"
    case remainingDaysHours = "remaining_days_hours"    // "还剩 %d天%d小时"
    case remainingHoursMinutes = "remaining_hours_minutes"  // "还剩 %d小时%d分钟"
    case remainingMinutes = "remaining_minutes"         // "还剩 %d分钟"
    
    // 设置窗口
    case settings = "settings"
    
    // 通用
    case unknown = "unknown"
}
```

### 各语言字符串文件

**en.lproj/Localizable.strings**：
```
/* 限制类型 */
"five_hour_limit" = "5-Hour Limit";
"seven_day_limit" = "7-Day Limit";
"opus_weekly_limit" = "7-Day Opus Limit";
"sonnet_weekly_limit" = "7-Day Sonnet Limit";
"extra_usage" = "Extra Usage";

/* 显示选项 */
"display_options" = "Display Options";
"smart_display" = "Smart Display";
"smart_display_description" = "Automatically display all limit types with data";
"custom_display" = "Custom Display";

/* 主题 */
"theme_selection" = "Theme";
"monochrome_theme" = "Monochrome Theme";
"colored_theme" = "Colored Theme";
"colored_theme_unavailable_reason" = "Unavailable: Only supported when displaying 2 or fewer circular indicators";

/* 凭据配置 */
"credentials" = "Credentials";
"session_key_hint" = "Find in browser DevTools → Application → Cookies → claude.ai";
"session_key_help" = "Your session key will be securely stored in macOS Keychain";
"session_key_required" = "Session Key is required";
"organization_id_auto_fetched" = "Organization ID automatically fetched";
"organization_id_help" = "Organization ID will be automatically fetched after saving Session Key";
"auto_fetched" = "Auto-fetched";
"fetching" = "Fetching...";
"refetch" = "Refetch";
"configuring" = "Configuring...";
"credentials_saved" = "Credentials saved successfully";
"save" = "Save";
"back" = "Back";
"continue" = "Continue";

/* 欢迎界面 */
"welcome_credentials_title" = "Configure Claude Access";
"welcome_credentials_subtitle" = "Enter your Session Key - we'll automatically fetch your Organization ID";
"welcome_display_title" = "Choose Display Options";
"welcome_display_subtitle" = "Select which usage limits to show in the menu bar";
"preview" = "Preview";

/* 详情窗口 - 日期时间 */
"today" = "Today";
"today_time" = "Today %@";  // "Today 12:00"
"month_day" = "%d/%d";      // "12/16" (month/day)
"extra_usage_format" = "$%d/$%d";

/* 详情窗口 - 剩余时间 */
"extra_usage_remaining" = "Remaining $%@";
"remaining_days_hours" = "%d days %d hours remaining";
"remaining_hours_minutes" = "%d hours %d minutes remaining";
"remaining_minutes" = "%d minutes remaining";

/* 设置窗口 */
"settings" = "Settings";

/* 通用 */
"unknown" = "Unknown";
```

**ja.lproj/Localizable.strings**：
```
/* 制限タイプ */
"five_hour_limit" = "5時間制限";
"seven_day_limit" = "7日制限";
"opus_weekly_limit" = "7日Opus制限";
"sonnet_weekly_limit" = "7日Sonnet制限";
"extra_usage" = "追加使用量";

/* 表示オプション */
"display_options" = "表示オプション";
"smart_display" = "スマート表示";
"smart_display_description" = "データのある制限タイプを自動的に表示";
"custom_display" = "カスタム表示";

/* テーマ */
"theme_selection" = "テーマ";
"monochrome_theme" = "モノクロテーマ";
"colored_theme" = "カラーテーマ";
"colored_theme_unavailable_reason" = "利用不可：2つ以下の円形インジケーターを表示する場合のみサポート";

/* 認証情報 */
"credentials" = "認証情報";
"session_key_hint" = "ブラウザのDevTools → Application → Cookies → claude.aiで確認";
"session_key_help" = "セッションキーはmacOSキーチェーンに安全に保存されます";
"session_key_required" = "セッションキーが必要です";
"organization_id_auto_fetched" = "組織IDが自動取得されました";
"organization_id_help" = "組織IDはセッションキー保存後に自動取得されます";
"auto_fetched" = "自動取得";
"fetching" = "取得中...";
"refetch" = "再取得";
"configuring" = "設定中...";
"credentials_saved" = "認証情報を保存しました";
"save" = "保存";
"back" = "戻る";
"continue" = "続ける";

/* ウェルカム画面 */
"welcome_credentials_title" = "Claudeアクセス設定";
"welcome_credentials_subtitle" = "セッションキーを入力してください。組織IDは自動的に取得されます";
"welcome_display_title" = "表示オプションを選択";
"welcome_display_subtitle" = "メニューバーに表示する使用量制限を選択してください";
"preview" = "プレビュー";

/* 詳細ウィンドウ - 日付時間 */
"today" = "今日";
"today_time" = "今日 %@";    // "今日 12:00"
"month_day" = "%d月%d日";    // "12月16日"
"extra_usage_format" = "$%d/$%d";

/* 詳細ウィンドウ - 残り時間 */
"extra_usage_remaining" = "残り$%@";
"remaining_days_hours" = "残り%d日%d時間";
"remaining_hours_minutes" = "残り%d時間%d分";
"remaining_minutes" = "残り%d分";

/* 設定ウィンドウ */
"settings" = "設定";

/* 一般 */
"unknown" = "不明";
```

**zh-Hans.lproj/Localizable.strings**：
```
/* 限制类型 */
"five_hour_limit" = "5小时限制";
"seven_day_limit" = "7天限制";
"opus_weekly_limit" = "7天Opus限制";
"sonnet_weekly_limit" = "7天Sonnet限制";
"extra_usage" = "额外用量";

/* 显示选项 */
"display_options" = "显示选项";
"smart_display" = "智能显示";
"smart_display_description" = "自动显示所有有数据的限制类型";
"custom_display" = "自定义显示";

/* 主题 */
"theme_selection" = "主题";
"monochrome_theme" = "单色主题";
"colored_theme" = "彩色主题";
"colored_theme_unavailable_reason" = "不可用：仅在显示2个或更少圆形指示器时支持";

/* 凭据配置 */
"credentials" = "凭据";
"session_key_hint" = "在浏览器开发者工具 → Application → Cookies → claude.ai 中查找";
"session_key_help" = "您的 Session Key 将被安全地存储在 macOS 钥匙串中";
"session_key_required" = "需要 Session Key";
"organization_id_auto_fetched" = "Organization ID 已自动获取";
"organization_id_help" = "Organization ID 将在保存 Session Key 后自动获取";
"auto_fetched" = "自动获取";
"fetching" = "获取中...";
"refetch" = "重新获取";
"configuring" = "配置中...";
"credentials_saved" = "凭据保存成功";
"save" = "保存";
"back" = "返回";
"continue" = "继续";

/* 欢迎界面 */
"welcome_credentials_title" = "配置 Claude 访问";
"welcome_credentials_subtitle" = "输入您的 Session Key，我们会自动获取您的 Organization ID";
"welcome_display_title" = "选择显示选项";
"welcome_display_subtitle" = "选择在菜单栏中显示哪些使用限制";
"preview" = "预览";

/* 详情窗口 - 日期时间 */
"today" = "今天";
"today_time" = "今天 %@";    // "今天 12:00"
"month_day" = "%d月%d日";    // "12月16日"
"extra_usage_format" = "$%d/$%d";

/* 详情窗口 - 剩余时间 */
"extra_usage_remaining" = "还可使用$%@";
"remaining_days_hours" = "还剩%d天%d小时";
"remaining_hours_minutes" = "还剩%d小时%d分钟";
"remaining_minutes" = "还剩%d分钟";

/* 设置窗口 */
"settings" = "设置";

/* 通用 */
"unknown" = "未知";
```

**zh-Hant.lproj/Localizable.strings**：
```
/* 限制類型 */
"five_hour_limit" = "5小時限制";
"seven_day_limit" = "7天限制";
"opus_weekly_limit" = "7天Opus限制";
"sonnet_weekly_limit" = "7天Sonnet限制";
"extra_usage" = "額外用量";

/* 顯示選項 */
"display_options" = "顯示選項";
"smart_display" = "智慧顯示";
"smart_display_description" = "自動顯示所有有資料的限制類型";
"custom_display" = "自訂顯示";

/* 主題 */
"theme_selection" = "主題";
"monochrome_theme" = "單色主題";
"colored_theme" = "彩色主題";
"colored_theme_unavailable_reason" = "不可用：僅在顯示2個或更少圓形指示器時支援";

/* 憑證配置 */
"credentials" = "憑證";
"session_key_hint" = "在瀏覽器開發者工具 → Application → Cookies → claude.ai 中尋找";
"session_key_help" = "您的 Session Key 將被安全地儲存在 macOS 鑰匙圈中";
"session_key_required" = "需要 Session Key";
"organization_id_auto_fetched" = "Organization ID 已自動取得";
"organization_id_help" = "Organization ID 將在儲存 Session Key 後自動取得";
"auto_fetched" = "自動取得";
"fetching" = "取得中...";
"refetch" = "重新取得";
"configuring" = "配置中...";
"credentials_saved" = "憑證儲存成功";
"save" = "儲存";
"back" = "返回";
"continue" = "繼續";

/* 歡迎介面 */
"welcome_credentials_title" = "配置 Claude 存取";
"welcome_credentials_subtitle" = "輸入您的 Session Key，我們會自動取得您的 Organization ID";
"welcome_display_title" = "選擇顯示選項";
"welcome_display_subtitle" = "選擇在選單列中顯示哪些使用限制";
"preview" = "預覽";

/* 詳情視窗 - 日期時間 */
"today" = "今天";
"today_time" = "今天 %@";    // "今天 12:00"
"month_day" = "%d月%d日";    // "12月16日"
"extra_usage_format" = "$%d/$%d";

/* 詳情視窗 - 剩餘時間 */
"extra_usage_remaining" = "還可使用$%@";
"remaining_days_hours" = "還剩%d天%d小時";
"remaining_hours_minutes" = "還剩%d小時%d分鐘";
"remaining_minutes" = "還剩%d分鐘";

/* 設定視窗 */
"settings" = "設定";

/* 通用 */
"unknown" = "未知";
```

---

## 开发指导（给 Claude Code）

本文档为 Usage4Claude v2.0.0 的完整技术规范。请按照以下功能模块逐步实现，每个功能模块可以独立开发和测试。

### 开发方式

**分阶段开发**：
- 不要一次性实现所有功能
- 每完成一个功能模块，进行测试验证
- 确保每个阶段的代码可以编译和运行
- 功能之间尽可能解耦，方便独立开发

### 核心功能模块

按推荐顺序实施：

#### 1. 凭据管理优化
**目标**：实现自动获取 Organization ID，优化配置流程

**包含**：
- 实现 `GET /api/organizations` API 调用
- 创建 `CredentialsManager` 类
- Organization ID 从 Keychain 迁移到 UserDefaults
- 实现数据迁移逻辑（v1.x → v2.0）
- 更新欢迎界面的凭据配置步骤
- 更新设置界面的凭据管理部分

**验证点**：
- 输入 sessionKey 后能自动获取 organizationId
- 只触发一次 Keychain 弹窗
- 旧版本用户升级后数据正常迁移

#### 2. Bug 修复
**目标**：修复已知问题

**包含**：
- 修复语言切换后设置窗口标题不更新（添加语言变化监听）
- 优化设置窗口标题栏高度和对齐

**验证点**：
- 切换语言后，打开的设置窗口标题立即更新
- 设置窗口标题栏高度合适，文字居中对齐

#### 3. 数据模型扩展
**目标**：支持新的限制类型数据

**包含**：
- 扩展 `UsageData` 模型（opus/sonnet/extra_usage）
- 创建 `LimitType` 枚举
- 创建 `DisplayMode` 枚举
- 扩展 `UserSettings` 模型

**验证点**：
- 数据模型可以正确存储所有限制类型
- 枚举定义完整且类型安全

#### 4. API 集成
**目标**：获取新的限制数据

**包含**：
- 实现主 usage API 的完整解析（包括 opus/sonnet）
- 实现 Extra Usage API 调用和解析
- 并行请求优化
- 错误处理和降级策略

**验证点**：
- 能正确解析所有限制类型的数据
- Extra Usage API 失败时不影响主功能
- 数据刷新正常工作

#### 5. 图标渲染系统
**目标**：实现新的图标类型

**包含**：
- 实现横向圆角矩形图标（sonnet）
- 实现竖向圆角矩形图标（opus）
- 实现六边形图标（extra_usage）
- 实现进度绘制逻辑
- 实现图标组合和缓存
- 实现单色/彩色主题切换

**验证点**：
- 各类型图标渲染正确
- 进度显示准确
- 图标组合间距合适
- 主题切换正常

#### 6. 显示逻辑系统
**目标**：实现智能显示和自定义显示

**包含**：
- 实现智能显示逻辑
- 实现自定义显示逻辑
- 实现主题可用性判断
- 实现菜单栏图标动态更新
- 实现 UserDefaults 存储

**验证点**：
- 智能模式正确识别有数据的限制
- 自定义模式不允许取消最后一个圆形图标
- 彩色主题仅在符合条件时可用
- 设置保存和加载正常

#### 7. 详情窗口重构
**目标**：支持多限制显示和模式切换

**包含**：
- 实现 2 列文字条布局
- 实现显示模式切换（重置时间 ↔ 剩余时间）
- 实现 Extra Usage 格式化
- 实现窗口高度动态调整
- 更新圆环显示逻辑

**验证点**：
- 文字条显示正确（2-5条）
- 点击切换显示模式正常
- Extra Usage 格式正确
- 窗口高度自适应

#### 8. 设置界面重构
**目标**：新的显示选项和凭据管理

**包含**：
- 实现显示模式选择（智能/自定义）
- 实现自定义显示选项
- 实现主题选择和禁用逻辑
- 集成新的凭据管理界面

**验证点**：
- 所有设置选项正常工作
- UI 交互逻辑正确
- 设置保存和应用正常

#### 9. 欢迎界面更新
**目标**：简化配置流程和添加预览

**包含**：
- 更新凭据配置步骤（只需 sessionKey）
- 实现显示选项配置
- 实现实时预览功能
- 使用假数据（55%, 66%, 77%, 88%, 99%）

**验证点**：
- 配置流程简洁流畅
- 预览实时响应用户选择
- 假数据显示正确

#### 10. 本地化
**目标**：完整的四语言支持

**包含**：
- 添加所有新的本地化 key
- 翻译四种语言（en/ja/zh-Hans/zh-Hant）
- 验证所有界面的本地化

**验证点**：
- 所有新功能都有本地化字符串
- 四种语言翻译准确
- 语言切换后所有文本正确显示

#### 11. 测试与优化
**目标**：全面测试和性能优化

**包含**：
- 单元测试（数据解析、显示逻辑）
- 集成测试（API 调用、数据流）
- UI 测试（各种显示组合）
- 边界情况测试
- 性能优化（图标缓存、内存管理）
- Bug 修复

**验证点**：
- 所有测试通过
- 无明显性能问题
- 边界情况处理正确

### 实施建议

1. **每次提交保持代码可运行**
   - 即使功能未完成，也要保证编译通过
   - 可以使用 feature flag 控制未完成功能

2. **优先处理依赖关系**
   - 数据模型 → API → UI
   - 先实现基础功能，再添加高级特性

3. **充分测试每个模块**
   - 完成一个功能立即测试
   - 不要积累太多未测试的代码

4. **参考现有代码风格**
   - 保持与项目现有代码一致
   - 遵循 Swift 和 SwiftUI 最佳实践

5. **文档和注释**
   - 复杂逻辑添加注释
   - 更新相关文档

---

## 注意事项

### 1. 向后兼容与数据迁移
- **v1.x → v2.0 升级**：自动迁移 organization ID 从 Keychain 到 UserDefaults
- 迁移逻辑在应用启动时自动执行
- 迁移成功后删除 Keychain 中的旧数据
- 使用迁移标记避免重复迁移
- 未配置新功能时，应用行为与 v1.6.0 完全一致
- 默认使用智能显示模式，自动适应用户账户
- 旧版本用户升级后无需重新配置（除非想自定义显示）

### 2. 配置流程优化
- **减少用户操作**：只需输入 sessionKey，organizationId 自动获取
- **减少 Keychain 弹窗**：从 2 次减少到 1 次
- **提升配置成功率**：自动获取比手动输入更准确
- **降低配置门槛**：普通用户不需要理解 organizationId

### 3. 性能考虑
- 图标渲染应该缓存，避免每次刷新都重绘
- 使用 `NSCache` 缓存图标
- Key 格式：`"{type}_{percentage}_{theme}"`
- 详情窗口文字条应使用 `LazyVStack` 优化

### 4. 错误处理
- Extra Usage API 可能不可用（403/404），需要优雅降级
- **Organization ID 获取失败**：提示用户检查 sessionKey 或网络连接
- 网络请求失败时显示缓存数据
- API 返回格式变化时不应崩溃
- 日志中不记录敏感信息（sessionKey、费用详情）
- **迁移失败不应影响应用启动**

### 5. 用户体验
- 至少保留一个显示选项（不允许全部取消）
- 彩色主题限制应有清晰提示
- 详情窗口切换应有动画
- 欢迎界面预览应实时响应

### 6. 隐私与安全
- Extra Usage 包含费用信息，确保日志中不暴露
- **sessionKey 严格保护**：仅存储在 Keychain
- **organizationId 合理保护**：存储在 UserDefaults（非敏感标识符）
- API 请求使用 HTTPS
- 不在日志中记录完整 API 响应
- **安全审查**：organizationId 无法单独用于账户操作

### 7. 代码质量
- 遵循现有代码风格
- 充分的注释和文档
- 单元测试覆盖率 > 80%
- SwiftLint 检查通过

### 8. 发布准备
- 更新 README（添加自动获取 organization ID 说明）
- 更新 CHANGELOG（v2.0.0 变更说明）
- 准备 release notes（中英日文）
  - 强调配置流程简化
  - 说明数据自动迁移
  - 新功能亮点介绍
- 更新应用截图（新的设置界面、欢迎界面）
- 准备 GitHub release
- **迁移指南**：v1.x 用户升级注意事项

---

## 版本规划

**版本号**：v2.0.0

**发布说明要点**：
- ✨ 新增 Opus/Sonnet 7天限制显示
- ✨ 新增 Extra Usage 额度监控
- ✨ 智能显示模式：自动显示有数据的限制
- ✨ 自定义显示：灵活选择显示项目
- ✨ 自动获取 Organization ID（无需手动输入）
- 🎨 单色/彩色主题智能切换
- 🔄 详情窗口文字条可切换显示模式
- 🌐 完整四语言支持
- 🐛 修复语言切换后设置窗口标题不更新
- 🐛 优化设置窗口标题栏高度和对齐
- 🐛 简化配置流程，减少 Keychain 弹窗

---

**文档版本**：2.0  
**最后更新**：2025-12-16  
**作者**：Claude (Anthropic)  
**适用项目**：Usage4Claude v2.0.0
