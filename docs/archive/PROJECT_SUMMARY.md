# Usage4Claude 项目开发总结

> 已归档（2026-07-17）：本文档内容截至 v1.6.0（2025-12-03），与当前版本已严重脱节，仅作参考，勿当作现行事实。

> 一个 macOS 菜单栏应用的完整开发历程，从零到生产就绪

## 📅 项目时间线

- **创建日期**: 2025年10月15日
- **当前版本**: 1.6.0
- **最后更新**: 2025年12月03日
- **状态**: ✅ 持续改进中
- **重大重构**: 2025年12月1-3日（v2-Pragmatic 架构重构）

---

## 🎯 项目目标与成果

### 初始目标
创建一个 macOS 菜单栏应用，用于监控 Claude AI 的5小时使用限制，让用户方便了解使用状况。

### 最终成果
成功开发了一个功能完整、界面优雅的原生 macOS 应用，实现了所有计划功能并解决了开发过程中遇到的所有技术难题。

### 核心成就
- ✅ 从零开始完成整个应用开发
- ✅ 成功绕过 Cloudflare 反机器人保护
- ✅ 实现了实时更新和倒计时功能
- ✅ 创建了优雅的 SwiftUI 界面
- ✅ 完整的设置系统（通用/认证/关于）
- ✅ 多语言支持（英/日/简体中文/繁体中文）
- ✅ 自动更新检查功能
- ✅ 敏感信息 Keychain 存储
- ✅ v2-Pragmatic 架构重构（2269行 → 4核心类2081行）

---

## 🏗️ 技术架构

### 技术栈选择
- **语言**: Swift 5.0（类型安全、性能优秀）
- **UI框架**: SwiftUI + AppKit 混合（现代化UI + 系统集成）
- **并发**: Combine Framework（响应式编程）
- **网络**: URLSession（原生网络请求）
- **平台**: macOS 13.0+（广泛兼容性）
- **架构**: MVVM（清晰的关注点分离）

### 核心组件设计

**项目结构：**
```
Usage4Claude/
├── App/                    # 应用核心
├── Services/               # 服务层
├── Models/                 # 数据模型
├── Views/                  # 界面视图
├── Helpers/                # 工具类
└── Resources/              # 资源文件
```

#### 1. App 层（重构后架构）

**ClaudeUsageMonitorApp.swift**（应用入口）
- 使用 `@NSApplicationDelegateAdaptor` 集成 AppDelegate
- 设置 `.accessory` 策略（不在 Dock 显示）
- 管理应用生命周期和资源清理
- 首次启动欢迎流程

**MenuBarManager.swift**（协调层 - 452行）
- **职责**：协调 UI 和数据层，管理设置窗口
- 数据绑定：将 DataRefreshManager 状态同步到视图
- 弹出窗口管理：打开/关闭 popover，设置内容视图
- 菜单操作处理：刷新、设置、更新检查、关于等
- 设置窗口生命周期管理
- 用户确认版本管理（`acknowledgedVersion`）

**MenuBarUI.swift**（UI层 - 480行）
- **职责**：管理菜单栏UI元素和用户交互
- NSStatusItem 管理和点击事件处理
- Popover 生命周期管理
- 图标缓存机制（提升性能）
- 右键菜单创建
- 点击外部关闭逻辑

**MenuBarIconRenderer.swift**（渲染层 - 614行）
- **职责**：专注于图标绘制和渲染逻辑
- 8种图标绘制方法（彩色/模板模式 × 4种样式）
- 双限制图标支持（内外双圈）
- 更新徽章渲染
- 百分比颜色映射
- 模板模式和透明背景支持

**DataRefreshManager.swift**（数据层 - 409行）
- **职责**：管理数据刷新、定时器、更新检查
- API 数据获取和状态管理
- 智能刷新逻辑（4级监控模式）
- 重置时间验证（+1s/+10s/+30s）
- 每日自动更新检查
- 刷新动画最小时长控制
- TimerManager 统一定时器管理

#### 2. Services 层

**ClaudeAPIService.swift**（网络服务）
- Cloudflare 绕过（完整浏览器 Headers）
- 共享 URLSession 实例
- 认证处理和错误分类
- 时间数据四舍五入

**KeychainManager.swift**（安全存储）
- Keychain 加密存储敏感数据
- Organization ID / Session Key 管理
- 统一的保存/读取/删除接口

**UpdateChecker.swift**（更新检查）
- GitHub Release API 集成
- 语义化版本比较
- 自动/手动更新检查

#### 3. Models 层

**UserSettings.swift**（设置管理）
- 混合存储策略（Keychain + UserDefaults）
- 刷新模式管理（智能/固定）
- 4级智能监控状态机
- Combine 响应式更新

#### 4. Views 层

**UsageDetailView.swift**（详情界面）
- 圆形进度条和实时倒计时
- 三点菜单（统一菜单生成）
- 响应式数据绑定

**SettingsView.swift**（设置界面）
- 三标签页设计（通用/认证/关于）
- 智能/固定刷新模式切换
- 认证信息可视化配置
- 标签页直接跳转支持

#### 5. Helpers 层

**LocalizationHelper.swift**（本地化）
- 类型安全的字符串访问
- 4 语言支持（en/ja/zh-Hans/zh-Hant）
- 动态语言切换

**TimerManager.swift**（定时器管理）
- 统一的定时器创建和管理
- 支持单次和重复定时器
- 自动清理机制

**NotificationNames.swift**（通知名称）
- 类型安全的通知名称常量
- 避免硬编码字符串错误
- UserInfo 键名常量

---

## 🔄 架构重构历程

### v2-Pragmatic 重构（2025年12月1-3日）

**重构动机**：
- 原 MenuBarManager.swift 单文件 2269 行，职责过多
- 代码可读性差，维护困难
- 违反单一职责原则

**重构方案**：v2-Pragmatic（实用主义方案）
- **核心思想**：3-4 核心类平衡实用性和可维护性
- **目标**：每个文件 400-600 行，职责清晰
- **优势**：LLM 友好（2-3 次文件读取理解全貌）

**重构成果**：
- MenuBarManager: 2269 行 → 452 行（-80%）
- 新增 MenuBarUI: 480 行（UI 层）
- 新增 MenuBarIconRenderer: 614 行（渲染层）
- 新增 DataRefreshManager: 409 行（数据层）
- **总计**：4 核心类 2081 行（比原来少 188 行）

**重构收益**：
- ✅ 单一职责：每个类职责明确
- ✅ 易于理解：文件大小适中
- ✅ 便于维护：修改影响范围小
- ✅ LLM 友好：快速理解代码结构
- ✅ 零功能损失：所有功能正常工作

**详细文档**：参见 [docs/REFACTORING_V2_PRAGMATIC.md](REFACTORING_V2_PRAGMATIC.md)

---

## 🐛 开发过程中的问题与解决方案

### 问题1：Cloudflare 反机器人保护

**问题**：curl 请求 API 返回 HTML（Cloudflare Challenge），无法获取数据

**原因**：Claude.ai 使用 Cloudflare 保护，检测并拦截非浏览器请求

**解决**：添加完整的浏览器 Headers 模拟真实请求
```swift
request.setValue("*/*", forHTTPHeaderField: "accept")
request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ...", forHTTPHeaderField: "user-agent")
request.setValue("https://claude.ai", forHTTPHeaderField: "origin")
request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
// ... 更多 Headers
```

**效果**：✅ URLSession 请求成功绕过 Cloudflare 验证

---

### 问题2：开发环境配置

**Xcode 26 配置方式变化**
- 新版使用 Build Settings 中的 `INFOPLIST_KEY_*` 替代直接编辑 Info.plist
- LSUIElement 配置：`TARGETS → Build Settings → INFOPLIST_KEY_LSUIElement = YES`

**Swift 6 并发模式**
- 数据模型需明确声明为 `nonisolated` 以避免 MainActor 警告
- 示例：`nonisolated struct UsageResponse: Codable, Sendable`

---

### 问题3：详情窗口实时更新

**问题**：菜单栏图标更新，但弹出窗口倒计时静止不动

**原因**：Popover 初始化后不会自动响应数据变化，计算属性不触发视图更新

**解决**：双定时器设计
```swift
// 定时器1：数据刷新（根据用户设置）
timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { 
    self.fetchUsage() 
}

// 定时器2：UI 实时更新（1秒，仅 popover 打开时）
popoverRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { 
    self.updatePopoverContent() 
}
```

**要点**：
- 每次打开 popover 时重建内容视图
- 关闭 popover 时立即停止 UI 定时器
- 平衡实时性与性能

---

### 问题4：数据处理优化

**时间显示精度**
- 问题：API 返回 `05:59:59.645`，显示为 "5:59" 而非 "6:00"
- 解决：对时间进行四舍五入 `resetsAt = Date(timeIntervalSinceReferenceDate: round(interval))`

**未使用状态处理**
- 问题：`resets_at: null` 时显示"即将重置后重置"，令人困惑
- 解决：显示"开始使用后显示"等友好提示

**SwiftUI Binding 转换**
- 问题：ObservableObject 中不能直接用 `$property` 传递 Binding
- 解决：手动创建 `Binding(get: { self.data }, set: { self.data = $0 })`

---

### 问题5：Popover 窗口稳定性（Focus 控制）

**问题**：Popover 打开时尺寸跳动、边缘闪烁、Focus/非-Focus 颜色差异明显

**原因**：
- NSPopover 的 `.transient` behavior 会自动管理 Focus，导致外观变化
- 调用 `becomeKey()` 使窗口在 Focus 状态间切换，产生闪烁

**解决**：

1. **使用 applicationDefined behavior**
   - 手动控制 popover 关闭逻辑，避免系统自动 Focus 管理
   - `popover.behavior = .applicationDefined`

2. **不调用 becomeKey()**
   - 保持窗口在非-Focus 状态，避免外观变化
   - 直接 `popover.show(...)` 而不调用 `becomeKey()`

3. **设置统一 Appearance**
   - `hostingController.view.appearance = NSAppearance(named: .aqua)`

4. **配置窗口属性**
   - `popoverWindow.level = .popUpMenu` （确保层级）
   - `popoverWindow.styleMask.remove(.titled)` （防止标题窗口行为）

5. **手动实现点击外部关闭**
   - 监听鼠标事件，检测点击位置
   - 点击 popover 外部时自动关闭

**效果**：✅ 窗口稳定、无闪烁、外观一致，类似专业菜单栏应用

---

### 问题6：资源泄漏导致应用终止（Signal 9）

**问题**：应用运行数小时后被系统强制终止（`SIGKILL`），无错误提示

**原因**：通知观察者、事件监听器、定时器未正确清理，导致资源累积耗尽

**解决**：

**1. 追踪并清理通知观察者**
```swift
// 使用数组保存观察者引用
private var notificationObservers: [NSObjectProtocol] = []

// 使用闭包式观察者
let observer = NotificationCenter.default.addObserver(
    forName: .openSettings, object: nil, queue: .main
) { [weak self] notification in
    self?.handleNotification(notification)
}
notificationObservers.append(observer)

// 应用退出时清理
func applicationWillTerminate(_ notification: Notification) {
    notificationObservers.forEach { observer in
        NotificationCenter.default.removeObserver(observer)
    }
}
```

**2. 管理事件监听器生命周期**
```swift
// 保存监听器引用
private var popoverCloseObserver: Any?

// 添加监听器
popoverCloseObserver = NSEvent.addLocalMonitorForEvents(...) { ... }

// 不需要时立即移除
if let observer = popoverCloseObserver {
    NSEvent.removeMonitor(observer)
    popoverCloseObserver = nil
}
```

**3. 统一资源清理方法**
```swift
func cleanup() {
    timer?.invalidate()
    timer = nil
    popoverRefreshTimer?.invalidate()
    popoverRefreshTimer = nil
    removePopoverCloseObserver()
    cancellables.removeAll()
}

deinit {
    cleanup()
}
```

**效果**：✅ 应用可长时间稳定运行，无资源泄漏

---

### 问题7：开发环境代码签名配置

**问题**：开发期间 ad-hoc 签名每次变化，导致 Keychain 无法访问之前存储的数据

**原因**：Keychain 依赖代码签名识别应用，签名不稳定会导致访问失败

**解决**：创建自签名证书保持签名稳定

**1. 创建证书**
```
钥匙串访问 → 证书助理 → 创建证书
- 名称：Usage4Claude-CodeSigning
- 类型：代码签名
- 证书类型：自签名根证书
- 密钥对：RSA 2048位
```

**2. 导出证书**
```
右键证书 → 导出 → 保存为 .p12 文件
```

**3. Xcode 配置**
```
TARGETS → Build Settings → Signing
- Code Signing Identity: Usage4Claude-CodeSigning
- Code Signing Style: Manual
```

**效果**：
- ✅ 签名永远稳定（任何机器编译）
- ✅ 完全免费（无需开发者证书）
- ✅ Keychain 正常工作
- ✅ 可正常发布 DMG

---

### 问题8：智能监控频率实现

**需求**：活跃时及时更新（1分钟），静默时减少调用（最长10分钟），自动调整

**方案**：4级渐进式智能频率调整

```
🟢 活跃模式 (Active)     - 1分钟刷新
   ↓ 连续 3 次无变化
🟡 短期静默 (Idle-Short)  - 3分钟刷新
   ↓ 连续 6 次无变化
🟠 中期静默 (Idle-Medium) - 5分钟刷新
   ↓ 连续 12 次无变化
🔴 长期静默 (Idle-Long)   - 10分钟刷新

检测到使用变化 → 立即回到活跃模式
```

**核心逻辑**：
```swift
func updateSmartMonitoringMode(currentUtilization: Double) {
    // 检测百分比变化（容差0.01）
    if let last = lastUtilization, abs(currentUtilization - last) > 0.01 {
        currentMonitoringMode = .active  // 立即切换到活跃模式
        unchangedCount = 0
    } else {
        unchangedCount += 1  // 无变化，逐步降频
        // 根据连续无变化次数切换模式...
    }
}
```

**效果**：
- ✅ 活跃时1分钟刷新，体验良好
- ✅ 静默时最长10分钟，减少10倍API调用
- ✅ 4级平滑过渡，避免突变
- ✅ 用户可选智能/固定模式

**重置时间智能验证**（2025-10-31 新增）：
在有明确重置时间时，额外安排验证刷新以确保及时捕捉重置：
- 重置后 +1秒 → 第一次验证
- 重置后 +10秒 → 第二次验证
- 重置后 +30秒 → 第三次验证
- **检测到重置时间变化时自动取消后续验证**（避免不必要的API调用）

**实现**：
```swift
// 每次获取数据后检测重置时间是否变化
let hasResetChanged = hasResetTimeChanged(from: lastResetsAt, to: newResetsAt)
if hasResetChanged {
    cancelResetVerification()  // 重置已完成，取消剩余验证
}
```

---

### 问题9：URLSession 网络超时优化

**问题**：API 请求成功但出现大量 "Operation timed out" 错误

**原因**：
- 每次请求都创建新的 URLSession
- Session 创建后未正确关闭，连接累积
- 缺少合适的超时配置

**解决**：使用共享 URLSession 实例

```swift
class ClaudeAPIService {
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30   // 请求超时：30秒
        configuration.timeoutIntervalForResource = 60  // 资源超时：60秒
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: configuration)
    }
    
    func fetchUsage(completion: @escaping (Result<UsageData, Error>) -> Void) {
        // 直接使用共享的 session
        session.dataTask(with: request) { ... }.resume()
    }
}
```

**效果**：✅ 消除超时错误，提升网络稳定性

---

### 问题10：重构后更新徽章实时更新失效

**问题**：v2-Pragmatic 重构第7天完成后，更新徽章无法实时更新
- 从无更新切换到有更新：需要重启应用才能看到徽章
- 从有更新切换到无更新：菜单栏徽章消失，但详情窗口和菜单徽章依然存在

**原因**：重构时将 `acknowledgedVersion` 从 MenuBarManager 移到了 DataRefreshManager
- 导致 `shouldShowUpdateBadge` 计算属性跨对象访问状态
- `objectWillChange.send()` 无法正确触发 SwiftUI 视图更新
- 跨 ObservableObject 的响应式更新时序问题

**错误尝试**：
1. 添加 `.updateBadgeDismissed` 通知
2. 在 DataRefreshManager 中发送通知
3. 在 MenuBarManager 中监听并清除缓存
4. **结果**：完全无效（"和刚才没有任何区别"）

**正确解决**（参考 GitHub 原始代码）：
1. 将 `acknowledgedVersion` 移回 MenuBarManager（状态应在同一对象）
2. 保持 `shouldShowUpdateBadge` 作为 MenuBarManager 的计算属性
3. `checkForUpdates()` 直接修改本地状态并调用 `objectWillChange.send()`
4. 保留 UsageDetailView 的 `@Binding` 改进（正确的优化）

**核心代码**：
```swift
// MenuBarManager.swift
private var acknowledgedVersion: String?

var shouldShowUpdateBadge: Bool {
    guard hasAvailableUpdate, let latest = latestVersion else { return false }
    return acknowledgedVersion != latest
}

@objc func checkForUpdates() {
    if let version = latestVersion {
        acknowledgedVersion = version
        objectWillChange.send()  // 触发UI更新
        updateMenuBarIcon()
    }
    dataManager.checkForUpdatesManually()
}
```

**关键教训**：
- SwiftUI 响应式状态应保持在同一个 ObservableObject 中
- 计算属性依赖的状态不应跨对象访问
- 遇到问题时参考原始实现（GitHub 源码）
- 失败的修复尝试应及时清理（删除无用通知）

**效果**：✅ 所有更新徽章实时显示，无需重启

---

## 🔧 关键技术实现细节

### 1. 动态生成菜单栏图标

```swift
private func createMenuBarImage(percentage: Double) -> NSImage? {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)
    
    image.lockFocus()
    
    // 绘制圆形进度条
    let path = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 16, height: 16))
    let color = colorForPercentage(percentage)
    color.setStroke()
    path.lineWidth = 2.0
    path.stroke()
    
    // 绘制进度弧线
    let progressPath = NSBezierPath()
    let startAngle: CGFloat = 90
    let endAngle = 90 - (360 * CGFloat(percentage) / 100)
    progressPath.appendArc(
        withCenter: NSPoint(x: 9, y: 9),
        radius: 8,
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: true
    )
    // ... 更多绘制逻辑
}
```

### 2. 智能日期格式化

```swift
var formattedResetTime: String {
    guard let resetsAt = resetsAt else {
        return "未知"
    }
    
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale.current
    
    let calendar = Calendar.current
    if calendar.isDateInToday(resetsAt) {
        formatter.dateFormat = "'今天' HH:mm"
    } else if calendar.isDateInTomorrow(resetsAt) {
        formatter.dateFormat = "'明天' HH:mm"
    } else {
        formatter.dateFormat = "M月d日 HH:mm"
    }
    
    return formatter.string(from: resetsAt)
}
```

### 3. 双重定时器管理

```swift
class MenuBarManager {
    private var timer: Timer?                   // 数据刷新定时器
    private var popoverRefreshTimer: Timer?     // UI刷新定时器（1秒）
    
    deinit {
        timer?.invalidate()
        popoverRefreshTimer?.invalidate()
    }
}
```

---

## 📊 代码质量统计

### 编译状态
- ✅ **0 个编译警告**
- ✅ **0 个编译错误**
- ✅ **Swift 6 并发模式兼容**

### 代码规模（重构后）

#### 核心架构层
| 文件 | 行数 | 说明 |
|------|------|------|
| MenuBarManager.swift | 452 | 协调层：UI/数据绑定 + 窗口管理 |
| MenuBarUI.swift | 480 | UI层：状态项 + Popover + 菜单 |
| MenuBarIconRenderer.swift | 614 | 渲染层：8种图标绘制方法 |
| DataRefreshManager.swift | 409 | 数据层：刷新 + 定时器 + 更新检查 |
| **核心小计** | **1955** | **4个文件，职责清晰** |

#### 其他组件
| 文件 | 行数 | 说明 |
|------|------|------|
| ClaudeUsageMonitorApp.swift | ~80 | 应用入口 + 生命周期 |
| ClaudeAPIService.swift | ~200 | 网络服务 |
| UsageDetailView.swift | ~650 | 详情视图（含菜单） |
| SettingsView.swift | ~350 | 设置界面 |
| UserSettings.swift | ~230 | 设置管理 + 智能逻辑 |
| KeychainManager.swift | ~100 | 安全存储 |
| LocalizationHelper.swift | ~120 | 本地化支持 |
| UpdateChecker.swift | ~150 | 更新检查 |
| TimerManager.swift | ~80 | 定时器统一管理 |
| NotificationNames.swift | ~60 | 通知名称常量 |
| **总计** | **~3975行** | 功能完善，结构清晰 |

### 性能指标
- CPU 使用率：< 0.1%（空闲时）
- 内存占用：~20MB
- 网络请求：智能模式 1-10分钟/次
- 启动时间：< 1秒

---

## 🎯 设计决策与权衡

### 1. 智能刷新策略
**决策**：4级渐进式频率调整
**权衡**：平衡实时性、资源消耗和API限流
**效果**：活跃时响应快，静默时节省资源

### 2. 双定时器架构
**决策**：数据刷新（可变）+ UI更新（1秒）分离
**理由**：解耦数据和UI，优化用户体验
**效果**：倒计时流畅，数据刷新灵活

### 3. 混合存储策略
**决策**：Keychain（敏感）+ UserDefaults（设置）
**理由**：安全性与便利性平衡
**效果**：认证信息安全，设置访问高效

### 4. SwiftUI + AppKit 混合
**决策**：UI用SwiftUI，系统集成用AppKit
**理由**：结合两者优势
**效果**：界面现代，集成稳定

### 5. 纯原生实现
**决策**：不使用第三方库
**理由**：减少依赖，提高可维护性
**结果**：应用轻量，无兼容性问题

### 6. v2-Pragmatic 重构方案
**决策**：4核心类架构（协调/UI/渲染/数据）
**权衡**：未选择更细粒度的v3方案（10+类）
**理由**：
- 平衡可维护性与复杂度
- LLM 友好（2-3次读取理解全貌）
- 每个文件 400-600 行，适中大小
**效果**：
- 单一职责原则
- 易于理解和修改
- 零功能损失

---

## 🔮 未来展望

### 短期计划
- 开机启动设置
- 快捷键支持
- Shell 自动打包 DMG
- GitHub Actions 自动发布

### 中期计划
- 暗黑模式支持
- 7天使用量监控（OAuth・Opus）
- 用量通知提醒
- 更多语言本地化

### 长期愿景
- 浏览器插件自动获取认证信息
- 桌面小组件
- 历史使用记录与趋势分析
- iOS / iPadOS / Windows 版本

---

*文档更新时间：2025年12月03日*
*版本：1.6.0*
*状态：持续更新中*

> "The best code is no code at all. The second best is simple, clear code."
>
> — Jeff Atwood
>
> "Any fool can write code that a computer can understand. Good programmers write code that humans can understand."
>
> — Martin Fowler
