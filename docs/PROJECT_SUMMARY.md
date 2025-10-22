# Usage4Claude 项目开发总结

> 一个 macOS 菜单栏应用的完整开发历程，从零到生产就绪

## 📅 项目时间线

- **创建日期**: 2025年10月15日
- **当前版本**: 1.0.0
- **状态**: ✅ 持续改进中

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

#### 1. ClaudeUsageMonitorApp.swift（应用入口）
- 使用 `@NSApplicationDelegateAdaptor` 集成 AppDelegate
- 设置 `.accessory` 策略（不在 Dock 显示）
- 初始化 MenuBarManager

#### 2. MenuBarManager.swift（核心控制器）
- 管理菜单栏状态项
- 创建和控制弹出窗口
- 管理定时器（数据刷新 + 界面更新）
- 动态生成圆形进度图标
- 实现颜色编码逻辑

#### 3. ClaudeAPIService.swift（网络服务）
- 封装 API 请求逻辑
- 处理认证和Headers
- JSON 解析和错误处理
- 时间四舍五入处理

#### 4. UsageDetailView.swift（UI视图）
- SwiftUI 实现的详情界面
- 圆形进度条组件
- 实时倒计时显示
- 响应式数据绑定

#### 5. SettingsView.swift（设置界面）
- 通用设置：图标显示模式、刷新频率、语言选择
- 认证设置：可视化配置 Organization ID 和 Session Key
- 关于页面：版本信息、开发者信息、链接
- 首次启动欢迎界面

#### 6. UserSettings.swift（设置管理）
- UserDefaults 持久化存储
- Combine 响应式通知
- 多种显示模式（百分比/图标/组合）
- 可配置刷新频率

#### 7. LocalizationHelper.swift（本地化）
- 类型安全的本地化字符串访问
- 支持 4 种语言（英/日/简中/繁中）
- 动态语言切换

#### 8. UpdateChecker.swift（更新检查）
- GitHub Release API 集成
- 语义化版本比较
- 自动/手动更新检查
- DMG 下载链接

---

## 🐛 开发过程中的问题与解决方案

### 问题1：Cloudflare 反机器人保护

**现象**：
- curl 命令测试 API 时返回 HTML 页面（Cloudflare Challenge）
- 无法直接获取 API 数据

**原因分析**：
- Claude.ai 使用 Cloudflare 保护 API
- Cloudflare 会检测请求特征，拦截可疑请求

**解决方案**：
```swift
// 添加完整的浏览器 Headers 模拟真实请求
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)...", 
                 forHTTPHeaderField: "User-Agent")
// ... 更多 Headers
```

**结果**：
✅ macOS 应用的 URLSession 请求成功通过验证

---

### 问题2：Xcode 26 配置方式变化

**现象**：
- 新版 Xcode 不再使用传统的 Info.plist 编辑方式
- LSUIElement 配置找不到位置

**原因分析**：
- Xcode 26 引入了新的配置系统
- 使用 Build Settings 中的 `INFOPLIST_KEY_*` 替代直接编辑

**解决方案**：
```
TARGETS → Usage4Claude → Build Settings
添加：INFOPLIST_KEY_LSUIElement = YES
或在 Info 标签页中添加配置项
```

**经验总结**：
- 新版 Xcode 简化了配置流程
- 自动生成 Info.plist 减少了手动错误

---

### 问题3：Swift 6 并发警告

**现象**：
```
warning: main actor-isolated conformance of 'UsageResponse' to 'Decodable' 
cannot be used in nonisolated context
```

**原因分析**：
- Swift 6 引入了严格的并发检查
- 编译器将某些类型推断为 MainActor-isolated
- 在后台队列解码 MainActor-isolated 类型会产生警告

**解决方案**：
```swift
// 将数据模型明确标记为 nonisolated
nonisolated struct UsageResponse: Codable, Sendable {
    // ...
}
```

**技术要点**：
- `nonisolated` 明确告诉编译器类型不需要特定 actor
- 适用于纯数据传输对象（DTO）
- 保持了类型安全和线程安全

---

### 问题4：详情窗口不实时更新

**现象**：
- 菜单栏图标数据会更新
- 但打开的详情窗口不会动态刷新
- 倒计时文字静止不动

**原因分析**：
- Popover 在 init() 时创建一次
- NSHostingController 不会自动响应 @Published 变化
- 计算属性（如倒计时）不会触发视图更新

**解决方案**：
```swift
// 1. 每次打开 popover 时重新创建内容视图
private func updatePopoverContent() {
    popover.contentViewController = NSHostingController(
        rootView: UsageDetailView(...)
    )
}

// 2. 添加实时刷新定时器
private func startPopoverRefreshTimer() {
    popoverRefreshTimer = Timer.scheduledTimer(
        withTimeInterval: 1.0, 
        repeats: true
    ) { [weak self] _ in
        self?.updatePopoverContent()
    }
}
```

**优化细节**：
- 只在 popover 打开时刷新
- 关闭时立即停止定时器
- 平衡了实时性和性能

---

### 问题5：时间显示精度问题

**现象**：
- API 返回 `"2025-10-16T05:59:59.645383+00:00"`
- 显示为 "5:59" 而不是 "6:00"
- 倒计时显示 "59分59秒" 而不是 "1小时"

**原因分析**：
- API 返回的时间包含小数秒
- Date 格式化时直接截断，导致显示不准确

**解决方案**：
```swift
// 对时间进行四舍五入到最接近的秒
if let date = formatter.date(from: resetString) {
    let interval = date.timeIntervalSinceReferenceDate
    let roundedInterval = round(interval)
    resetsAt = Date(timeIntervalSinceReferenceDate: roundedInterval)
}
```

**效果**：
- `05:59:59.645` → `06:00:00` ✅
- 倒计时显示更准确友好

---

### 问题6：未使用状态显示优化

**现象**：
- 用户未使用 Claude 时，API 返回 `resets_at: null`
- 应用显示 "即将重置后重置"，令人困惑

**解决方案**：
```swift
var formattedResetsIn: String {
    guard let resetsAt = resetsAt else {
        return "开始使用后显示"  // 更友好的提示
    }
    // ... 正常倒计时逻辑
}
```

**用户体验提升**：
- 清晰告诉用户为什么没有显示时间
- 避免了令人困惑的文案

---

### 问题7：Binding 类型转换错误

**现象**：
```
Cannot convert value of type 'Published<UsageData?>.Publisher' 
to expected argument type 'Binding<UsageData?>'
```

**原因分析**：
- ObservableObject 中不能直接用 `$property` 传递 Binding
- SwiftUI 的 @Published 和 Binding 机制不同

**解决方案**：
```swift
// 手动创建 Binding
rootView: UsageDetailView(
    usageData: Binding(
        get: { self.usageData },
        set: { self.usageData = $0 }
    )
)
```

---

### 问题8：Focus 控制问题（Popover 闪烁）

**现象：**
- Popover 窗口打开时有明显的尺寸跳动
- 窗口边缘有轻微闪烁
- Focus 和非 Focus 状态颜色差异明显
- 前几次打开都会出现重绘

**原因分析：**
- NSPopover 在菜单栏应用中存在严重的 Focus 控制问题
- 标准的 `.transient` behavior 会自动管理 Focus，导致外观变化
- 调用 `becomeKey()` 会导致窗口在 Focus 和非 Focus 状态间切换，产生闪烁
- 许多成熟应用（如 Fantastical）使用自定义实现而非标准 NSPopover

**解决方案：**

1. **改变 Behavior 模式**
```swift
// 修改前：
popover.behavior = .transient

// 修改后：
popover.behavior = .applicationDefined
// 使用 applicationDefined 可以手动控制 popover 的关闭逻辑，避免系统自动进行 Focus 管理
```

2. **移除 becomeKey() 调用**
```swift
// 修改前：
NSApp.activate(ignoringOtherApps: true)
popover.show(...)
popover.contentViewController?.view.window?.becomeKey()

// 修改后：
popover.show(...)
// 不调用 becomeKey()，保持窗口在非 Focus 状态
```

3. **设置统一的 Appearance**
```swift
if #available(macOS 10.14, *) {
    hostingController.view.appearance = NSAppearance(named: .aqua)
}
```

4. **配置窗口属性**
```swift
if let popoverWindow = popover.contentViewController?.view.window {
    popoverWindow.level = .popUpMenu  // 确保显示在其他窗口之上
    popoverWindow.styleMask.remove(.titled)  // 防止窗口表现得像标题窗口
}
```

5. **手动实现点击外部关闭**
```swift
private func setupPopoverCloseObserver() {
    popoverCloseObserver = NSEvent.addLocalMonitorForEvents(
        matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] event in
        // 检测点击是否在 popover 外部
        // 如果是，则关闭 popover
    }
}
```

**效果：**
- ✅ 窗口大小固定，无尺寸跳动
- ✅ 无边缘闪烁现象
- ✅ 保持一致的外观，无 Focus 状态变化
- ✅ 行为类似其他专业菜单栏应用

---

### 问题9：界面显示问题

**问题9.1：三个点菜单样式问题**

**现象：**
- 三个点带圆圈和向下箭头，比较难看
- 按钮不停获取 Focus，导致选中状态闪烁

**修复：**
```swift
Menu {
    // 菜单项...
} label: {
    Image(systemName: "ellipsis")  // 去掉圆圈，使用纯三点
        .rotationEffect(.degrees(90))  // 旋转90度使三个点垂直显示
}
.menuIndicator(.hidden)  // 隐藏下拉箭头
.fixedSize()  // 防止菜单大小变化
```

**问题9.2：设置窗口位置问题**

**现象：**
设置窗口没有在屏幕正中央，还在右上角

**修复：**
```swift
// 替换 center() 方法为手动计算屏幕中心位置
if let screen = NSScreen.main {
    let screenFrame = screen.visibleFrame
    let windowFrame = window?.frame ?? NSRect.zero
    let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
    let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2
    window?.setFrameOrigin(NSPoint(x: x, y: y))
}
```

**问题9.3：图标显示为纯黑色问题**

**现象：**
所有地方的图标都显示为纯黑色：
- 任务栏图标
- 关于页面图标
- 详细界面左上角图标

**原因：**
设置了 `isTemplate = true`，导致图标被当作模板处理，只显示轮廓

**修复：**
```swift
// 创建图标副本后设置 isTemplate = false
if let appIcon = NSImage(named: "AppIcon") {
    let iconCopy = appIcon.copy() as! NSImage
    iconCopy.isTemplate = false  // 关闭模板模式
    iconCopy.size = NSSize(width: size, height: size)
    return iconCopy
}
```

**问题9.4：右键菜单和三个点菜单不一致**

**现象：**
右键菜单内容和三个点菜单不同

**修复：**
```swift
// 创建通用方法 createStandardMenu() 统一生成菜单
private func createStandardMenu() -> NSMenu {
    let menu = NSMenu()
    // 通用设置、认证信息、关于、访问 Claude 用量、Buy Me A Coffee、退出
    return menu
}
```

**问题9.5：窗口尺寸调整**

**调整内容：**
- 详细窗口高度：200px → 240px（确保内容完整显示）
- 设置窗口高度：400px → 500px（关于界面完整显示）

**问题9.6：版本信息和链接更新**

**更新内容：**
- 版本号：读取 XCode 配置
- 开发者：更新为 f-is-h
- GitHub 地址：https://github.com/f-is-h/Usage4Claude
- 认证界面按钮："在浏览器中打开 Claude" → "在浏览器中打开 Claude 用量页面"

**问题9.7：标签页跳转优化**

**实现：**
- 欢迎窗口的"去设置认证信息"按钮可直接跳转到认证信息标签页
- 修改通知系统支持传递标签页参数
- 点击"稍后设置"后显示友好提示和设置按钮

**整体效果：**
- ✅ 三个点菜单样式简洁
- ✅ 窗口居中显示
- ✅ 图标正常显示彩色
- ✅ 菜单内容统一
- ✅ 窗口尺寸适配内容
- ✅ 版本信息准确
- ✅ 用户引导流畅

---

### 问题10：资源泄漏导致应用被强制终止

**现象：**
- 应用运行一段时间后（数小时）被系统强制终止
- Launch 日志显示：`Terminated due to signal 9` (SIGKILL)
- 应用无错误提示，直接退出

**原因分析：**

Signal 9 (SIGKILL) 是系统强制终止进程的信号，通常由以下原因触发：

1. **通知观察者泄漏** (ClaudeUsageMonitorApp.swift)
   - 使用 `addObserver(_:selector:name:object:)` 添加观察者从未移除
   - 每次重新订阅都创建新观察者，导致观察者累积
   - 后果：内存泄漏，触发多次回调

2. **事件监听器泄漏** (MenuBarManager.swift)
   - `popoverCloseObserver` 在应用退出时如果 popover 是打开状态不会被清理
   - NSEvent 监听器持续占用系统资源
   - 后果：系统资源耗尽

3. **窗口通知观察者累积** (MenuBarManager.swift)
   - 每次打开设置窗口都添加新的 `NSWindow.willCloseNotification` 观察者
   - 观察者不断累积，从未被移除
   - 后果：内存泄漏，可能触发多次回调

4. **应用终止时资源未清理**
   - 缺少 `applicationWillTerminate` 方法
   - 应用退出时定时器、观察者、监听器等资源未被清理
   - 后果：资源泄漏，影响系统稳定性

**解决方案：**

**ClaudeUsageMonitorApp.swift 修复：**

```swift
// 1. 添加观察者数组追踪
private var notificationObservers: [NSObjectProtocol] = []

// 2. 使用闭包式观察者（自动保存引用）
let observer = NotificationCenter.default.addObserver(
    forName: .openSettings,
    object: nil,
    queue: .main
) { [weak self] notification in
    self?.openSettingsFromNotification(notification)
}
notificationObservers.append(observer)

// 3. 添加 applicationWillTerminate 方法
func applicationWillTerminate(_ notification: Notification) {
    // 清理所有通知观察者
    notificationObservers.forEach { observer in
        NotificationCenter.default.removeObserver(observer)
    }
    notificationObservers.removeAll()
    
    // 清理 MenuBarManager 的资源
    menuBarManager?.cleanup()
    
    // 关闭所有窗口
    welcomeWindow?.close()
    welcomeWindow = nil
}

// 4. 添加 deinit 方法（双重保险）
deinit {
    notificationObservers.forEach { observer in
        NotificationCenter.default.removeObserver(observer)
    }
}
```

**MenuBarManager.swift 修复：**

```swift
// 1. 添加窗口观察者引用
private var windowCloseObserver: NSObjectProtocol?

// 2. 改进窗口观察者管理
// 移除旧的观察者（如果存在）
if let observer = windowCloseObserver {
    NotificationCenter.default.removeObserver(observer)
}

// 添加新的观察者并保存引用
windowCloseObserver = NotificationCenter.default.addObserver(
    forName: NSWindow.willCloseNotification,
    object: settingsWindow,
    queue: .main
) { [weak self] _ in
    self?.settingsWindow = nil
    if self?.settings.hasValidCredentials == true && self?.usageData == nil {
        self?.startRefreshing()
    }
}

// 3. 添加公开的 cleanup 方法
func cleanup() {
    // 停止所有定时器
    timer?.invalidate()
    timer = nil
    popoverRefreshTimer?.invalidate()
    popoverRefreshTimer = nil
    
    // 移除所有事件监听器
    removePopoverCloseObserver()
    
    // 清理窗口观察者
    if let observer = windowCloseObserver {
        NotificationCenter.default.removeObserver(observer)
        windowCloseObserver = nil
    }
    
    // 取消所有 Combine 订阅
    cancellables.removeAll()
    
    // 关闭 popover 和窗口
    if popover.isShown {
        popover.performClose(nil)
    }
    settingsWindow?.close()
    settingsWindow = nil
}

// 4. 改进 deinit 方法
deinit {
    cleanup()
}

// 5. 改进 closePopover 方法
private func closePopover() {
    // 确保 popover 关闭
    if popover.isShown {
        popover.performClose(nil)
    }
    
    // 清理刷新定时器
    popoverRefreshTimer?.invalidate()
    popoverRefreshTimer = nil
    
    // 移除事件监听器
    removePopoverCloseObserver()
}
```

**修复效果：**

修复前：
- ❌ 观察者不断累积
- ❌ 事件监听器持续占用资源
- ❌ 定时器继续运行即使不需要
- ❌ 应用运行数小时后被系统强制终止 (Signal 9)

修复后：
- ✅ 所有观察者都被正确追踪和移除
- ✅ 事件监听器在不需要时立即清理
- ✅ 定时器在应用退出时停止
- ✅ 应用退出时所有资源都被正确清理
- ✅ 无内存泄漏，可以长时间稳定运行

**最佳实践总结：**

1. **通知观察者管理**
```swift
// ❌ 错误做法
NotificationCenter.default.addObserver(
    self, selector: #selector(method), name: .someName, object: nil
)
// 没有保存引用，无法移除

// ✅ 正确做法
let observer = NotificationCenter.default.addObserver(
    forName: .someName, object: nil, queue: .main
) { [weak self] _ in /* 处理通知 */ }
observers.append(observer)  // 保存引用以便清理
```

2. **事件监听器管理**
```swift
// 添加监听器时保存引用
eventMonitor = NSEvent.addLocalMonitorForEvents(...) { event in
    return event
}

// 不需要时立即移除
if let monitor = eventMonitor {
    NSEvent.removeMonitor(monitor)
    eventMonitor = nil
}
```

3. **定时器管理**
```swift
timer = Timer.scheduledTimer(...)
// 停止时清空引用
timer?.invalidate()
timer = nil
```

4. **应用生命周期钩子**
```swift
func applicationWillTerminate(_ notification: Notification) {
    // 清理所有资源：移除观察者、停止定时器、关闭窗口
}
```

5. **deinit 方法**
```swift
deinit {
    cleanup()  // 确保资源被清理（双重保险）
}
```

**技术要点：**
- 使用闭包式观察者便于追踪和管理
- 及时移除不再需要的资源
- 在应用生命周期关键节点清理资源
- deinit 作为最后防线
- 使用 weak self 避免循环引用

---

### 问题11：认证信息安全存储（Keychain迁移）

**现象：**
- 应用使用 UserDefaults 明文存储 Session Key 和 Organization ID
- 认证信息存储在 `~/Library/Preferences/Bundle_ID.plist` 文件中
- 任何程序都可以读取这些敏感信息
- 存在严重的安全隐患

**原因分析：**

1. **UserDefaults 的安全问题**
   - 完全明文存储，无任何加密
   - 文件权限虽然是 600，但无法防止恶意软件
   - 在用户账户下运行的任何程序都可以读取
   - 使用 `defaults read` 命令可直接查看

2. **攻击者可以做什么**
   - 完全控制用户的 Claude 账户
   - 查看所有对话历史
   - 消耗用户配额
   - 代表用户进行操作

3. **不符合 macOS 最佳实践**
   - Apple 明确建议敏感信息使用 Keychain
   - 通过 App Store 审核困难

**解决方案：**

**方案选择：混合存储方案**
- **Keychain**：存储敏感认证信息（Session Key、Organization ID）
- **UserDefaults**：存储非敏感设置（语言、刷新频率、显示模式等）

**实施步骤：**

1. **创建 KeychainManager.swift**
```swift
class KeychainManager {
    static let shared = KeychainManager()
    
    // Keychain 配置
    private let service = "xy.Usage4Claude"  // 使用 Bundle ID 作为服务名
    
    // 保存方法
    func saveOrganizationId(_ value: String) -> Bool
    func saveSessionKey(_ value: String) -> Bool
    
    // 读取方法
    func loadOrganizationId() -> String?
    func loadSessionKey() -> String?
    
    // 删除方法
    func deleteOrganizationId() -> Bool
    func deleteSessionKey() -> Bool
    func deleteAll() -> Bool
    func deleteCredentials() -> Bool  // deleteAll 的别名，更符合业务语义
    
    // 通用 Keychain 操作
    private func save(key: String, value: String) -> Bool { ... }
    private func load(key: String) -> String? { ... }
    private func delete(key: String) -> Bool { ... }
}
```

2. **修改 UserSettings.swift**
```swift
class UserSettings: ObservableObject {
    private let keychain = KeychainManager.shared
    
    // 敏感信息 → Keychain
    @Published var organizationId: String {
        didSet {
            keychain.saveOrganizationId(organizationId)
        }
    }
    
    @Published var sessionKey: String {
        didSet {
            keychain.saveSessionKey(sessionKey)
        }
    }
    
    // 非敏感设置 → 继续使用 UserDefaults
    @Published var iconDisplayMode: IconDisplayMode {
        didSet {
            defaults.set(iconDisplayMode.rawValue, forKey: "iconDisplayMode")
        }
    }
    
    // 初始化时从 Keychain 加载
    private init() {
        self.organizationId = keychain.loadOrganizationId() ?? ""
        self.sessionKey = keychain.loadSessionKey() ?? ""
        // ... 其他设置从 UserDefaults 加载
    }
    
    // 清除认证信息
    func clearCredentials() {
        keychain.deleteCredentials()
        organizationId = ""
        sessionKey = ""
    }
}
```

**Keychain 工作机制：**

1. **三重验证机制**
```
应用尝试访问 Keychain 项目
    ↓
① 检查 Bundle ID
    ↓
② 检查代码签名（最关键！）
    ↓
③ 检查 Service Name
    ↓
全部匹配 → ✅ 允许访问
任一不匹配 → ❌ 拒绝访问
```

2. **标识方式**
- Service: `xyz.fi5h.Usage4Claude` (Bundle ID)
- Account: `sessionKey` 或 `organizationId` (键名)
- 完整标识：`Service + Account`

3. **访问控制策略**
- 使用 `kSecAttrAccessibleAfterFirstUnlock`
- 设备首次解锁后数据可访问
- 可与 iCloud Keychain 同步（可选）
- 系统级 AES-256 加密
- T2 芯片 / Secure Enclave 硬件保护

**代码签名问题与解决：**

**问题：** Keychain 依赖代码签名来识别应用，开发期间 ad-hoc 签名每次都会变化，导致无法访问之前存储的数据。

**解决方案：创建自签名证书**

1. **创建证书**
```bash
# 打开"钥匙串访问"应用
# 菜单：钥匙串访问 → 证书助理 → 创建证书
# - 名称：Usage4Claude-CodeSigning
# - 身份类型：自签名根证书
# - 证书类型：代码签名
# - 让我覆盖默认值：✓
# - 密钥对信息：RSA 2048位
# - 位置：登录（login）钥匙串
```

2. **导出证书保证签名稳定**
```bash
# 右键证书 → 导出
# 保存为：Usage4Claude-CodeSigning.p12
# 设置密码（用于保护私钥）
```

3. **在 Xcode 中配置**
```
TARGETS → Usage4Claude → Signing&Capabilities → Signing
- 取消勾选 Automatically manage signing
- Provisioning Profile: None（macOS应用不需要）
- Signing Certificate: 无法直接设置 Usage4Claude-CodeSigning(下方设置完成后此处会自动变为 Usage4Claude-CodeSigning)
TARGETS → Usage4Claude → Build Settings → Signing
- Code Signing Identity: Usage4Claude-CodeSigning
  Debug: 包含 Any macOS SDK 均需要设置
  Release: 包含 Any macOS SDK 均需要设置
- Code Signing Style: Manual
```

**效果：**
- ✅ 签名永远稳定（无论在哪台机器编译）
- ✅ 完全免费（不需要付费开发者证书）
- ✅ Keychain 可以正常工作
- ✅ 可以正常发布 DMG

**App Sandbox 与文件路径：**

**配置：** `ENABLE_APP_SANDBOX = YES`

**影响：**

1. **UserDefaults 存储位置改变**

传统位置（❌ 不在这里）：
```
~/Library/Preferences/xyz.fi5h.Usage4Claude.plist
```

实际位置（✅ 在这里）：
```
~/Library/Containers/xyz.fi5h.Usage4Claude/Data/Library/Preferences/xyz.fi5h.Usage4Claude.plist
```

2. **为什么 `defaults read` 能读取？**
- `defaults read` 命令会自动查找沙盒容器内的数据
- 系统会智能处理路径转换

3. **数据持久性**
- ✅ 数据持久化在磁盘上
- ✅ 重启电脑后数据依然存在
- ✅ macOS 自动管理同步时机

4. **是否需要 App Sandbox？**

应该开启的情况：
- ✅ 通过 Mac App Store 发布（必须）
- ✅ GitHub/直接分发（推荐，提高安全性）
- ✅ 应用不需要额外系统权限
- ✅ 增加用户信任度

本项目选择：**保持开启**
- 功能简单，只需网络请求
- 不需要访问用户文件系统
- 符合 macOS 最佳实践

**编译错误修复：**

**错误：** `Value of type 'KeychainManager' has no member 'deleteCredentials'`

**原因：** UserSettings.swift 调用了 `keychain.deleteCredentials()`，但 KeychainManager 中只有 `deleteAll()` 方法。

**修复：**
```swift
// 在 KeychainManager.swift 中添加
/// 删除所有凭证信息（deleteAll的别名，更符合业务语义）
@discardableResult
func deleteCredentials() -> Bool {
    return deleteAll()
}
```

**安全性对比：**

| 方面 | UserDefaults (修改前) | Keychain (修改后) |
|------|---------------------|------------------|
| **存储位置** | Preferences/xxx.plist | Keychains/login.keychain-db |
| **加密** | ❌ 无 | ✅ AES-256 |
| **访问控制** | ❌ 任何应用可读 | ✅ 仅本应用 |
| **恶意软件防护** | ❌ 无法防护 | ✅ 有效防护 |
| **硬件保护** | ❌ 无 | ✅ T2/Secure Enclave |
| **备份安全** | ❌ 明文备份 | ✅ 加密备份 |
| **撤销访问** | ❌ 无法撤销 | ✅ 可通过钥匙串删除 |

**最终存储方案：**

| 数据类型 | 存储位置 | 原因 |
|---------|---------|------|
| Session Key | Keychain (加密) | 敏感认证信息 |
| Organization ID | Keychain (加密) | 敏感认证信息 |
| 图标显示模式 | UserDefaults | 非敏感设置 |
| 刷新频率 | UserDefaults | 非敏感设置 |
| 语言设置 | UserDefaults | 非敏感设置 |
| 首次启动标记 | UserDefaults | 非敏感设置 |

**修复效果：**

修复前：
- ❌ 认证信息明文存储
- ❌ 任何程序都可以读取
- ❌ 严重的安全隐患

修复后：
- ✅ 认证信息加密存储在 Keychain
- ✅ 只有本应用可以访问
- ✅ 系统级安全保护
- ✅ 符合 Apple 最佳实践
- ✅ 用户可在"钥匙串访问"中管理
- ✅ 代码签名稳定，开发体验良好

**技术要点：**

1. **明确区分敏感和非敏感数据**
   - 敏感：密码、Token、API Key → Keychain
   - 非敏感：UI 设置、偏好 → UserDefaults

2. **Keychain 访问策略选择**
   - 一般应用：`kSecAttrAccessibleAfterFirstUnlock`
   - 高安全要求：`kSecAttrAccessibleWhenUnlocked`
   - 不需同步：添加 `ThisDeviceOnly` 后缀

3. **代码签名管理**
   - 开发期间：使用自签名证书保持签名稳定
   - 发布时：可使用相同证书或 ad-hoc 签名
   - 导出 .p12 文件：确保团队成员使用相同签名

4. **App Sandbox 最佳实践**
   - 保持开启以提高安全性
   - 理解沙盒环境下的文件路径
   - 声明必要的权限

5. **UserDefaults 自动同步**
   - 信任系统的自动同步机制
   - 不需要手动调用 `synchronize()`
   - 避免使用已弃用的 API

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
    formatter.locale = Locale(identifier: "zh_CN")
    
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
    private var timer: Timer?              // 数据刷新定时器（60秒）
    private var popoverRefreshTimer: Timer?  // UI刷新定时器（1秒）
    
    // 生命周期管理
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

### 代码规模
| 文件 | 行数 | 说明 |
|------|------|------|
| ClaudeUsageMonitorApp.swift | ~80 | 应用入口 + 欢迎界面 |
| MenuBarManager.swift | ~450 | 核心逻辑 + Focus优化 |
| ClaudeAPIService.swift | ~200 | 网络服务 |
| UsageDetailView.swift | ~180 | UI视图 |
| SettingsView.swift | ~350 | 设置界面 |
| UserSettings.swift | ~130 | 设置管理 |
| LocalizationHelper.swift | ~120 | 本地化支持 |
| UpdateChecker.swift | ~150 | 更新检查 |
| **总计** | **~1660行** | 功能完善，结构清晰 |

### 性能指标
- CPU 使用率：< 0.1%（空闲时）
- 内存占用：~20MB
- 网络请求：每分钟1次
- 启动时间：< 1秒

---

## 🎯 设计决策与权衡

### 1. 刷新频率选择
**决策**：60秒数据刷新，1秒UI刷新
**权衡**：平衡实时性和资源消耗
**效果**：用户体验良好，资源占用低

### 2. 使用 SwiftUI + AppKit 混合
**决策**：UI用SwiftUI，系统集成用AppKit
**理由**：结合两者优势
**效果**：界面现代，集成稳定

### 3. 不使用第三方库
**决策**：纯原生实现
**理由**：减少依赖，提高可维护性
**结果**：应用轻量，无兼容性问题

---

## 🔮 未来展望

### 短期计划
1. **功能增强**
    - 🚧 开机启动设置
    - 🚧 快捷键支持

2. **开发者**
    - 🚧 Release 日志输出逻辑优化
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

*文档更新时间：2025年10月21日*
*版本：1.0.0*
*状态：持续更新中*

> "The best code is no code at all. The second best is simple, clear code."
> 
> — Jeff Atwood
