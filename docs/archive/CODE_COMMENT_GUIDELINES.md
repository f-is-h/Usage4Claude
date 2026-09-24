# Swift 代码注释规范指南

> 本文档定义了 Usage4Claude 项目的代码注释标准。作为 AI 助手，你必须严格遵守这些规范。

## 📋 总体原则

### 核心理念
1. **分层注释策略** - 根据代码层级采用不同详细程度的注释
2. **类型安全文档** - 使用标准的 Swift 文档注释格式
3. **避免冗余** - 不注释显而易见的代码
4. **中文优先** - 所有注释使用中文
5. **实用性** - 注释应该帮助理解代码意图，而非重复代码内容

### 标准格式
- 使用 `///` 进行文档注释
- 使用 `//` 进行行内注释
- 使用 `// MARK: -` 组织代码结构
- 使用 `- Parameter`、`- Returns`、`- Note`、`- Important` 等标记

---

## 🎯 分层注释策略

### Level 1: Services 层（详细注释）

**适用文件：**
- `*Service.swift`
- `*Manager.swift`（核心服务类）
- `*Checker.swift`

**注释要求：**
1. ✅ 类必须有完整的职责描述
2. ✅ 所有公开方法必须有文档注释
3. ✅ 参数和返回值必须说明
4. ✅ 数据模型的属性必须注释
5. ✅ 使用 Note 和 Important 标记关键信息

**示例：**

```swift
/// Claude API 服务类
/// 负责与 Claude.ai API 通信，获取用户的使用情况数据
/// 包含请求构建、认证处理、Cloudflare 绕过和数据解析功能
class ClaudeAPIService {
    // MARK: - Properties
    
    /// API 基础 URL
    private let baseURL = "https://claude.ai/api/organizations"
    
    /// 用户设置实例，用于获取认证信息
    private let settings = UserSettings.shared
    
    // MARK: - Public Methods
    
    /// 获取用户的 Claude 使用情况
    /// - Parameter completion: 完成回调，包含成功的 UsageData 或失败的 Error
    /// - Note: 请求会自动添加必要的 Headers 以绕过 Cloudflare 防护
    /// - Important: 调用前确保用户已配置有效的认证信息
    func fetchUsage(completion: @escaping (Result<UsageData, Error>) -> Void) {
        // 实现...
    }
}

/// 用量数据模型
/// 应用内部使用的标准化用量数据结构
struct UsageData: Sendable {
    /// 当前使用百分比 (0-100)
    let percentage: Double
    
    /// 用量重置时间，nil 表示尚未开始使用
    let resetsAt: Date?
    
    /// 距离重置的剩余时间（秒）
    /// - Returns: 剩余秒数，如果 resetsAt 为 nil 则返回 nil
    var resetsIn: TimeInterval? {
        guard let resetsAt = resetsAt else { return nil }
        return resetsAt.timeIntervalSinceNow
    }
}
```

---

### Level 2: App/Models 层（中等注释）

**适用文件：**
- `*App.swift`
- `AppDelegate.swift`
- `*Settings.swift`
- `MenuBarManager.swift`

**注释要求：**
1. ✅ 类必须有职责说明
2. ✅ 关键属性必须注释
3. ✅ 重要方法必须有功能说明
4. ✅ 复杂逻辑必须解释
5. ⚠️ 简单的 getter/setter 可以不注释

**示例：**

```swift
/// 应用代理类
/// 负责应用生命周期管理、资源初始化和清理
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    /// 菜单栏管理器，负责所有菜单栏相关功能
    private var menuBarManager: MenuBarManager!
    
    /// 欢迎窗口，在首次启动时显示
    private var welcomeWindow: NSWindow?
    
    /// 通知观察者数组，用于在应用退出时清理
    private var notificationObservers: [NSObjectProtocol] = []
    
    // MARK: - Application Lifecycle
    
    /// 应用启动完成时调用
    /// 初始化菜单栏管理器，根据是否首次启动显示欢迎窗口或开始刷新数据
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 初始化 MenuBar 管理器
        menuBarManager = MenuBarManager()
        
        // 检查是否首次启动
        if settings.isFirstLaunch {
            showWelcomeWindow()
        } else {
            menuBarManager.startRefreshing()
        }
    }
}

/// 菜单栏图标显示模式
enum IconDisplayMode: String, CaseIterable, Codable {
    /// 仅显示百分比圆环
    case percentageOnly = "percentage_only"
    /// 仅显示应用图标
    case iconOnly = "icon_only"
    /// 同时显示图标和百分比
    case both = "both"
    
    var localizedName: String {
        // 不需要注释显而易见的 switch
        switch self {
        case .percentageOnly: return L.Display.percentageOnly
        case .iconOnly: return L.Display.iconOnly
        case .both: return L.Display.both
        }
    }
}
```

---

### Level 3: Views 层（简洁注释）

**适用文件：**
- `*View.swift`

**注释要求：**
1. ✅ 视图组件必须有用途说明
2. ✅ 复杂的计算逻辑必须注释
3. ✅ 辅助方法有简短说明
4. ❌ 不注释 SwiftUI 的布局代码
5. ❌ 不注释简单的 @State 和 @Binding

**示例：**

```swift
/// 用量详情视图
/// 显示 Claude 的当前使用情况，包括百分比进度条、倒计时和重置时间
struct UsageDetailView: View {
    @Binding var usageData: UsageData?
    @Binding var errorMessage: String?
    
    /// 菜单操作回调
    var onMenuAction: ((MenuAction) -> Void)? = nil
    
    /// 菜单操作类型
    enum MenuAction {
        case generalSettings
        case authSettings
        case checkForUpdates
        // 枚举值通常不需要注释（self-explanatory）
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // SwiftUI 布局代码不需要注释
            Text("Usage")
            ProgressView()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 根据使用百分比返回对应的颜色
    /// - 0-70%: 绿色（安全）
    /// - 70-90%: 橙色（警告）
    /// - 90-100%: 红色（危险）
    private func colorForPercentage(_ percentage: Double) -> Color {
        if percentage < 70 {
            return .green
        } else if percentage < 90 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Supporting Views

/// 信息行组件
/// 显示一行信息，包含图标、标题和值
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        // 简单布局不需要注释
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Text(value)
        }
    }
}
```

---

### Level 4: Helpers 层（简洁注释）

**适用文件：**
- `*Helper.swift`
- `Extensions.swift`
- `Utilities.swift`

**注释要求：**
1. ✅ 工具类必须有功能描述
2. ✅ 辅助方法有简要说明
3. ❌ 不注释简单的扩展方法

**示例：**

```swift
/// 本地化字符串访问器
/// 提供类型安全的本地化字符串访问方式
/// 支持动态语言切换，根据用户设置返回对应语言的字符串
enum L {
    // MARK: - Menu Items
    
    enum Menu {
        static let settings = localized("menu.settings")
        static let quit = localized("menu.quit")
    }
    
    // MARK: - Helper Methods
    
    /// 本地化字符串辅助方法
    /// 根据用户设置的语言返回对应的本地化字符串
    /// - Parameter key: 本地化字符串的键名
    /// - Returns: 对应语言的本地化字符串
    private static func localized(_ key: String) -> String {
        let language = UserSettings.shared.language.rawValue
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
```

---

## ✅ DO（推荐做法）

### 1. 使用标准文档注释格式

```swift
/// 获取用户数据
/// - Parameter userId: 用户ID
/// - Returns: 用户数据，失败返回 nil
/// - Note: 此方法会进行网络请求
/// - Important: 需要先调用 authenticate() 方法
func fetchUser(userId: String) -> User? {
    // ...
}
```

### 2. 为复杂逻辑添加解释性注释

```swift
/// 计算剩余时间的格式化字符串
var formattedTime: String {
    // 向上取整到分钟，避免显示 "0分钟" 的困惑
    let totalMinutes = Int(ceil(resetsIn / 60))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    
    if hours > 0 {
        return "\(hours)小时\(minutes)分钟"
    } else {
        return "\(minutes)分钟"
    }
}
```

### 3. 使用 MARK 组织代码结构

```swift
class MyClass {
    // MARK: - Properties
    
    private var name: String
    
    // MARK: - Initialization
    
    init(name: String) {
        self.name = name
    }
    
    // MARK: - Public Methods
    
    func doSomething() {
        // ...
    }
    
    // MARK: - Private Methods
    
    private func helper() {
        // ...
    }
}
```

### 4. 为枚举案例添加说明（非显而易见时）

```swift
enum NetworkError: Error {
    /// 网络连接超时
    case timeout
    /// 服务器返回 5xx 错误
    case serverError
    /// 响应数据格式错误
    case invalidResponse
}
```

### 5. 为关键属性添加用途说明

```swift
/// 数据刷新定时器
/// 根据用户设置的刷新频率定期获取数据
private var timer: Timer?

/// 弹出窗口实时刷新定时器（1秒间隔）
/// 用于更新倒计时显示
private var popoverRefreshTimer: Timer?
```

---

## ❌ DON'T（避免做法）

### 1. 不要重复方法名

```swift
// ❌ 错误示例
/// 保存用户
func saveUser() {
    // ...
}

// ✅ 正确示例
/// 将用户数据持久化到数据库
func saveUser() {
    // ...
}
```

### 2. 不要注释显而易见的代码

```swift
// ❌ 错误示例
// 设置标题为 "Hello"
label.text = "Hello"

// 创建一个字符串
let name = "John"

// ✅ 正确示例（不需要注释）
label.text = "Hello"
let name = "John"
```

### 3. 不要为每个私有辅助方法都写文档

```swift
// ❌ 错误示例（过度注释）
/// 返回红色
/// - Returns: UIColor.red
private func getRedColor() -> UIColor {
    return .red
}

// ✅ 正确示例（简单方法不需要注释）
private func getRedColor() -> UIColor {
    return .red
}
```

### 4. 不要注释简单的 SwiftUI 布局

```swift
// ❌ 错误示例
var body: some View {
    VStack {
        // 显示标题
        Text("Title")
        // 显示副标题
        Text("Subtitle")
    }
}

// ✅ 正确示例
var body: some View {
    VStack {
        Text("Title")
        Text("Subtitle")
    }
}
```

### 5. 不要为简单的计算属性添加注释

```swift
// ❌ 错误示例
/// 返回全名
var fullName: String {
    return firstName + " " + lastName
}

// ✅ 正确示例（self-explanatory）
var fullName: String {
    return firstName + " " + lastName
}
```

---

## 📝 特殊场景注释指南

### 1. 复杂算法

```swift
/// 使用语义化版本比较规则判断版本号大小
/// - Parameters:
///   - latest: 最新版本号（如 "1.2.3"）
///   - current: 当前版本号（如 "1.2.0"）
/// - Returns: 如果 latest 比 current 新则返回 true
/// - Note: 使用主版本.次版本.修订号的比较规则
private func isNewerVersion(latest: String, current: String) -> Bool {
    let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
    let currentComponents = current.split(separator: ".").compactMap { Int($0) }
    
    // 确保至少有3个版本号组件，不足的补0
    let latestPadded = (latestComponents + [0, 0, 0]).prefix(3)
    let currentPadded = (currentComponents + [0, 0, 0]).prefix(3)
    
    // 逐位比较主版本、次版本、修订号
    for (l, c) in zip(latestPadded, currentPadded) {
        if l > c { return true }
        if l < c { return false }
    }
    
    return false
}
```

### 2. 性能优化相关

```swift
/// 更新弹出窗口内容
/// - Note: 不要每次都重新创建 controller，只更新 rootView 以提高性能
private func updatePopoverContent() {
    if let hostingController = popover.contentViewController as? NSHostingController<UsageDetailView> {
        hostingController.rootView = UsageDetailView(...)
    }
}
```

### 3. 安全性相关

```swift
/// 保存敏感数据到 Keychain
/// - Parameter value: 要保存的敏感值
/// - Returns: 是否保存成功
/// - Important: 数据使用 AES-256 加密，只有本应用可以访问
@discardableResult
func saveSessionKey(_ value: String) -> Bool {
    return save(key: "sessionKey", value: value)
}
```

### 4. 已知问题或临时方案

```swift
/// 创建组合图标
/// - Note: 不要设置 isTemplate，否则图标会变成纯白色（已知 macOS bug）
private func createCombinedImage() -> NSImage {
    let image = NSImage(size: size)
    // ...
    // image.isTemplate = true  // 不要取消这个注释！
    return image
}
```

### 5. 平台兼容性

```swift
/// 设置窗口外观
/// - Note: 仅 macOS 10.14+ 支持 NSAppearance
if #available(macOS 10.14, *) {
    hostingController.view.appearance = NSAppearance(named: .aqua)
}
```

---

## 🔧 实践检查清单

在编写代码时，请确认：

- [ ] Services 层的所有公开方法都有完整文档注释
- [ ] 数据模型的属性都有用途说明
- [ ] 关键业务逻辑有解释性注释
- [ ] 使用了 MARK 组织代码结构
- [ ] 没有为显而易见的代码添加冗余注释
- [ ] 复杂算法有详细的实现说明
- [ ] 所有注释使用中文
- [ ] 使用了标准的文档注释格式（`///`）

---

## 📚 参考资源

### 标准标记说明

| 标记 | 用途 | 示例 |
|------|------|------|
| `- Parameter` | 说明参数 | `- Parameter name: 用户名` |
| `- Returns` | 说明返回值 | `- Returns: 用户对象` |
| `- Throws` | 说明抛出的错误 | `- Throws: NetworkError` |
| `- Note` | 补充说明 | `- Note: 需要网络权限` |
| `- Important` | 重要提示 | `- Important: 必须先认证` |
| `- Warning` | 警告信息 | `- Warning: 此方法已弃用` |

### MARK 使用规范

```swift
// MARK: - Properties          （属性）
// MARK: - Initialization       （初始化）
// MARK: - Lifecycle            （生命周期）
// MARK: - Public Methods       （公开方法）
// MARK: - Private Methods      （私有方法）
// MARK: - Actions              （动作/事件处理）
// MARK: - Delegates            （代理方法）
// MARK: - Helper Methods       （辅助方法）
// MARK: - Computed Properties  （计算属性）
// MARK: - Data Models          （数据模型）
// MARK: - Extensions           （扩展）
```

---

## 🎯 最终目标

通过遵循这套注释规范，我们的代码应该达到：

1. **可读性** - 任何开发者都能快速理解代码意图
2. **可维护性** - 修改代码时不会因为缺少上下文而困惑
3. **专业性** - 展现高质量的代码标准
4. **一致性** - 整个项目使用统一的注释风格
5. **实用性** - 注释提供有价值的信息，而非冗余内容

---

*本文档基于 Usage4Claude 项目的实际代码总结而成，作为 Project Knowledge 的一部分供 AI 助手参考。*

*最后更新：2025年10月21日*
