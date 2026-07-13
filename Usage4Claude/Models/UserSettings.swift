//
//  UserSettings.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import ServiceManagement
import OSLog

// MARK: - Display Modes

/// 菜单栏图标显示模式
enum IconDisplayMode: String, CaseIterable, Codable {
    /// 仅显示百分比圆环
    case percentageOnly = "percentage_only"
    /// 仅显示应用图标
    case iconOnly = "icon_only"
    /// 同时显示图标和百分比
    case both = "both"
    /// 不显示图标（双 Provider 时显示尖头分隔线）
    case none = "no_display"

    var localizedName: String {
        switch self {
        case .percentageOnly:
            return L.Display.percentageOnly
        case .iconOnly:
            return L.Display.iconOnly
        case .both:
            return L.Display.both
        case .none:
            return L.Display.none
        }
    }
}

/// 菜单栏图标样式模式
enum IconStyleMode: String, CaseIterable, Codable {
    /// 彩色通透（默认，彩色无背景）
    case colorTranslucent = "color_translucent"
    /// 彩色带背景
    case colorWithBackground = "color_with_background"
    /// 单色（Template模式，跟随系统主题）
    case monochrome = "monochrome"
    
    var localizedName: String {
        switch self {
        case .colorTranslucent:
            return L.IconStyle.colorTranslucent
        case .colorWithBackground:
            return L.IconStyle.colorWithBackground
        case .monochrome:
            return L.IconStyle.monochrome
        }
    }
    
    var description: String {
        switch self {
        case .colorTranslucent:
            return L.IconStyle.colorTranslucentDesc
        case .colorWithBackground:
            return L.IconStyle.colorWithBackgroundDesc
        case .monochrome:
            return L.IconStyle.monochromeDesc
        }
    }
}

// MARK: - Refresh Modes

/// 刷新模式
enum RefreshMode: String, CaseIterable, Codable {
    /// 智能频率（根据使用情况自动调整）
    case smart = "smart"
    /// 固定频率（用户手动设置）
    case fixed = "fixed"
    
    var localizedName: String {
        switch self {
        case .smart:
            return L.Refresh.smartMode
        case .fixed:
            return L.Refresh.fixedMode
        }
    }
}

/// 数据刷新频率
enum RefreshInterval: Int, CaseIterable, Codable {
    /// 1分钟刷新一次
    case oneMinute = 60
    /// 3分钟刷新一次
    case threeMinutes = 180
    /// 5分钟刷新一次
    case fiveMinutes = 300
    /// 10分钟刷新一次
    case tenMinutes = 600
    
    var localizedName: String {
        switch self {
        case .oneMinute:
            return L.Refresh.oneMinute
        case .threeMinutes:
            return L.Refresh.threeMinutes
        case .fiveMinutes:
            return L.Refresh.fiveMinutes
        case .tenMinutes:
            return L.Refresh.tenMinutes
        }
    }
}

// MARK: - Limit Types

/// 限制类型
enum LimitType: String, CaseIterable, Codable {
    /// 5小时限制
    case fiveHour = "five_hour"
    /// 7天限制
    case sevenDay = "seven_day"
    /// Extra Usage 额外付费额度
    case extraUsage = "extra_usage"
    /// Opus 每周限制
    case opusWeekly = "seven_day_opus"
    /// Sonnet 每周限制
    case sonnetWeekly = "seven_day_sonnet"
    /// Codex 5小时窗口（primary）
    case codexPrimary = "codex_primary"
    /// Codex 7天窗口（secondary）
    case codexSecondary = "codex_secondary"
    /// Codex Extra Usage / credits
    case codexExtraUsage = "codex_extra_usage"

    /// 所属 Provider
    var provider: ProviderType {
        switch self {
        case .fiveHour, .sevenDay, .extraUsage, .opusWeekly, .sonnetWeekly:
            return .claude
        case .codexPrimary, .codexSecondary, .codexExtraUsage:
            return .codex
        }
    }

    /// 是否为圆形图标（5小时、7天和 Codex 两项）
    var isCircular: Bool {
        return self == .fiveHour || self == .sevenDay || self == .codexPrimary || self == .codexSecondary
    }

    /// 是否为矩形图标（Opus和Sonnet）
    var isRectangular: Bool {
        return self == .opusWeekly || self == .sonnetWeekly
    }

    /// 是否为六边形图标（Extra Usage）
    var isHexagonal: Bool {
        return self == .extraUsage || self == .codexExtraUsage
    }

    /// 是否使用虚线样式（7天类型）
    var usesDashedStyle: Bool {
        return self == .sevenDay || self == .codexSecondary
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .fiveHour:
            return L.LimitTypes.fiveHour
        case .sevenDay:
            return L.LimitTypes.sevenDay
        case .opusWeekly:
            return L.LimitTypes.opusWeekly
        case .sonnetWeekly:
            return L.LimitTypes.sonnetWeekly
        case .extraUsage:
            return L.LimitTypes.extraUsage
        case .codexPrimary:
            return L.LimitTypes.codexPrimary
        case .codexSecondary:
            return L.LimitTypes.codexSecondary
        case .codexExtraUsage:
            return L.LimitTypes.codexExtraUsage
        }
    }
}

// MARK: - Display Mode

/// 显示模式（智能显示 vs 自定义显示）
enum DisplayMode: String, CaseIterable, Codable {
    /// 智能显示 - 自动显示有数据的限制类型
    case smart = "smart"
    /// 自定义显示 - 用户手动选择要显示的限制类型
    case custom = "custom"

    var localizedName: String {
        switch self {
        case .smart:
            return L.DisplayOptions.smartDisplay
        case .custom:
            return L.DisplayOptions.customDisplay
        }
    }
}

/// 时间格式偏好
enum TimeFormatPreference: String, CaseIterable, Codable {
    /// 跟随系统
    case system = "system"
    /// 12 小时制
    case twelveHour = "twelve_hour"
    /// 24 小时制
    case twentyFourHour = "twenty_four_hour"

    var localizedName: String {
        switch self {
        case .system:
            return L.TimeFormat.system
        case .twelveHour:
            return L.TimeFormat.twelveHour
        case .twentyFourHour:
            return L.TimeFormat.twentyFourHour
        }
    }
}

/// 应用外观模式
enum AppAppearance: String, CaseIterable, Codable {
    /// 跟随系统
    case system = "system"
    /// 浅色
    case light = "light"
    /// 深色
    case dark = "dark"

    var localizedName: String {
        switch self {
        case .system:
            return L.Appearance.system
        case .light:
            return L.Appearance.light
        case .dark:
            return L.Appearance.dark
        }
    }

    /// 对应的 SwiftUI ColorScheme（system 返回 nil，表示跟随系统）
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

/// 应用语言选项
enum AppLanguage: String, CaseIterable, Codable {
    /// 英语
    case english = "en"
    /// 日语
    case japanese = "ja"
    /// 简体中文
    case chinese = "zh-Hans"
    /// 繁体中文
    case chineseTraditional = "zh-Hant"
    /// 韩语
    case korean = "ko"
    /// 法语
    case french = "fr"

    var localizedName: String {
        switch self {
        case .english:
            return L.Language.english
        case .japanese:
            return L.Language.japanese
        case .chinese:
            return L.Language.chinese
        case .chineseTraditional:
            return L.Language.chineseTraditional
        case .korean:
            return L.Language.korean
        case .french:
            return L.Language.french
        }
    }
}

extension AppLanguage {
    /// 将应用语言转换为对应的 Locale
    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .japanese:
            return Locale(identifier: "ja_JP")
        case .chinese:
            return Locale(identifier: "zh_CN")
        case .chineseTraditional:
            return Locale(identifier: "zh_TW")
        case .korean:
            return Locale(identifier: "ko_KR")
        case .french:
            return Locale(identifier: "fr_FR")
        }
    }
}

// MARK: - User Settings

/// 用户设置管理类
/// 负责管理应用的所有用户配置，包括认证信息、显示设置、语言等
/// 敏感信息（Organization ID 和 Session Key）存储在 Keychain 中
/// 非敏感设置存储在 UserDefaults 中
class UserSettings: ObservableObject {
    // MARK: - Singleton

    /// 单例实例
    static let shared = UserSettings()

    /// customDisplayTypes 的默认值，init() 与 resetToDefaults() 共用，避免两处定义漂移不一致
    static let defaultCustomDisplayTypes: Set<LimitType> = [.fiveHour, .sevenDay]

    // MARK: - Properties

    private let defaults = UserDefaults.standard
    private let keychain = KeychainManager.shared

    /// Combine 订阅集合：转发 accountStore 的 objectWillChange，让绑定 UserSettings 的 SwiftUI 视图
    /// 在账户数据变化时也能收到更新（见 init() 中的订阅）
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 多账户支持（v2.1.0，拆分到 AccountStore，见审计报告 4.1）

    /// 账户 CRUD、持久化、当前账户 ID 均已迁移到 AccountStore，这里只做门面转发，
    /// 保持外部调用点（settings.accounts、settings.addAccount(...) 等）零改动。
    let accountStore = AccountStore()

    var accounts: [Account] { accountStore.accounts }
    var currentAccountId: UUID? { accountStore.currentAccountId }
    var currentAccount: Account? { accountStore.currentAccount }

    var sessionKey: String {
        get { accountStore.sessionKey }
        set { accountStore.sessionKey = newValue }
    }

    var organizationId: String {
        get { accountStore.organizationId }
        set { accountStore.organizationId = newValue }
    }

    /// Claude 账户列表的语义别名（等同于 accounts，用于 provider-aware 代码中保持对称）
    var claudeAccounts: [Account] { accountStore.claudeAccounts }

    // MARK: - Codex 账户支持

    var codexAccounts: [Account] { accountStore.codexAccounts }
    var currentCodexAccountId: UUID? { accountStore.currentCodexAccountId }
    var currentCodexAccount: Account? { accountStore.currentCodexAccount }
    var codexSessionToken: String { accountStore.codexSessionToken }
    var hasValidCodexCredentials: Bool { accountStore.hasValidCodexCredentials }

    /// 是否同时存在 Claude 和 Codex 账户（决定 UI 进入 multi-provider 形态）
    var isMultiProviderActive: Bool {
        #if DEBUG
        if debugModeEnabled {
            if displayMode == .custom {
                let hasClaudeDisplayTypes = customDisplayTypes.contains { $0.provider == .claude }
                let hasCodexDisplayTypes = customDisplayTypes.contains { $0.provider == .codex }
                return hasClaudeDisplayTypes && hasCodexDisplayTypes
            }
            return true
        }
        #endif
        return !accounts.isEmpty && !codexAccounts.isEmpty
    }

    // MARK: - 非敏感设置（存储在UserDefaults中）

    /// 菜单栏图标显示模式
    @Published var iconDisplayMode: IconDisplayMode {
        didSet {
            defaults.set(iconDisplayMode.rawValue, forKey: "iconDisplayMode")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    /// 菜单栏图标样式模式
    @Published var iconStyleMode: IconStyleMode {
        didSet {
            defaults.set(iconStyleMode.rawValue, forKey: "iconStyleMode")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    /// 刷新模式（智能/固定）
    @Published var refreshMode: RefreshMode {
        didSet {
            defaults.set(refreshMode.rawValue, forKey: "refreshMode")
            NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
        }
    }
    
    /// 数据刷新间隔（秒）- 仅在固定模式下使用
    @Published var refreshInterval: Int {
        didSet {
            defaults.set(refreshInterval, forKey: "refreshInterval")
            NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
        }
    }
    
    /// 应用界面语言
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "language")
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    /// 外观模式的持久化、应用到 NSApp、系统主题监听都在 AppearanceManager 里，这里只做门面转发。
    /// 计算属性也能形成 ReferenceWritableKeyPath，$settings.appearance 双向绑定不受影响。
    let appearanceManager = AppearanceManager()

    var appearance: AppAppearance {
        get { appearanceManager.appearance }
        set { appearanceManager.appearance = newValue }
    }

    /// 时间格式偏好
    @Published var timeFormatPreference: TimeFormatPreference {
        didSet {
            defaults.set(timeFormatPreference.rawValue, forKey: "timeFormatPreference")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 显示模式（智能显示/自定义显示）
    @Published var displayMode: DisplayMode {
        didSet {
            defaults.set(displayMode.rawValue, forKey: "displayMode")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 自定义显示的限制类型集合（仅在自定义模式下使用）
    @Published var customDisplayTypes: Set<LimitType> {
        didSet {
            let rawValues = customDisplayTypes.map { $0.rawValue }
            defaults.set(rawValues, forKey: "customDisplayTypes")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 自定义显示是否仅应用于菜单栏（开启时 Popover 走智能显示）
    @Published var customDisplayMenuBarOnly: Bool {
        didSet {
            defaults.set(customDisplayMenuBarOnly, forKey: "customDisplayMenuBarOnly")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// Popover 端是否应该显示自定义模式的占位符（0% 空壳）
    /// 仅当显示模式为 custom 且未开启"仅应用于菜单栏"时为 true
    var shouldShowCustomPlaceholderInPopover: Bool {
        displayMode == .custom && !customDisplayMenuBarOnly
    }

    /// 是否为首次启动标记
    @Published var isFirstLaunch: Bool {
        didSet {
            defaults.set(isFirstLaunch, forKey: "isFirstLaunch")
        }
    }
    
    /// 是否启用用量通知
    @Published var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    /// 开机启动的注册/注销/状态同步都在 LaunchAtLoginManager 里，这里只做门面转发。
    /// isEnabled 直接派生自 SMAppService.mainApp.status（唯一事实来源），
    /// 不再需要存储 Bool + 标志位防递归，失败时 Toggle 会随 status 不变而自动弹回。
    let launchAtLoginManager = LaunchAtLoginManager()

    var launchAtLogin: Bool {
        get { launchAtLoginManager.isEnabled }
        set { launchAtLoginManager.isEnabled = newValue }
    }

    /// 开机启动状态（用于UI显示）
    var launchAtLoginStatus: SMAppService.Status { launchAtLoginManager.status }

    // MARK: - Debug Mode (仅Debug编译时可用)

    #if DEBUG
    /// 是否启用调试模式（模拟不同数据场景）
    @Published var debugModeEnabled: Bool {
        didSet {
            defaults.set(debugModeEnabled, forKey: "debugModeEnabled")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试场景类型
    @Published var debugScenario: DebugScenario {
        didSet {
            defaults.set(debugScenario.rawValue, forKey: "debugScenario")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试用的5小时限制百分比（0-100）
    @Published var debugFiveHourPercentage: Double {
        didSet {
            defaults.set(debugFiveHourPercentage, forKey: "debugFiveHourPercentage")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试用的7天限制百分比（0-100）
    @Published var debugSevenDayPercentage: Double {
        didSet {
            defaults.set(debugSevenDayPercentage, forKey: "debugSevenDayPercentage")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试用的 Opus 限制百分比（0-100）
    @Published var debugOpusPercentage: Double {
        didSet {
            defaults.set(debugOpusPercentage, forKey: "debugOpusPercentage")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试用的 Sonnet 限制百分比（0-100）
    @Published var debugSonnetPercentage: Double {
        didSet {
            defaults.set(debugSonnetPercentage, forKey: "debugSonnetPercentage")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试用的 Codex 5小时窗口百分比（0-100）
    @Published var debugCodexPrimaryPercentage: Double {
        didSet {
            defaults.set(debugCodexPrimaryPercentage, forKey: "debugCodexPrimaryPercentage")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试用的 Codex 7天窗口百分比（0-100）
    @Published var debugCodexSecondaryPercentage: Double {
        didSet {
            defaults.set(debugCodexSecondaryPercentage, forKey: "debugCodexSecondaryPercentage")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试用的 Codex Extra Usage 百分比（0-100）
    @Published var debugCodexExtraUsagePercentage: Double {
        didSet {
            defaults.set(debugCodexExtraUsagePercentage, forKey: "debugCodexExtraUsagePercentage")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 调试用的 Extra Usage 是否启用
    @Published var debugExtraUsageEnabled: Bool {
        didSet {
            defaults.set(debugExtraUsageEnabled, forKey: "debugExtraUsageEnabled")
        }
    }

    /// 调试用的 Extra Usage 已使用金额（美分），与真实 API used_credits 单位一致
    @Published var debugExtraUsageUsed: Double {
        didSet {
            defaults.set(debugExtraUsageUsed, forKey: "debugExtraUsageUsed")
        }
    }

    /// 调试用的 Extra Usage 总限额（美分），与真实 API monthly_limit 单位一致，只能为整数
    @Published var debugExtraUsageLimit: Int {
        didSet {
            defaults.set(debugExtraUsageLimit, forKey: "debugExtraUsageLimit")
        }
    }

    /// 调试用的 Extra Usage 百分比（0-100），会同步更新 used 值
    @Published var debugExtraUsagePercentage: Double {
        didSet {
            defaults.set(debugExtraUsagePercentage, forKey: "debugExtraUsagePercentage")
            // 同步更新 used 值（美分）
            debugExtraUsageUsed = Double(debugExtraUsageLimit) * (debugExtraUsagePercentage / 100.0)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 是否模拟有可用更新（调试用）
    @Published var simulateUpdateAvailable: Bool {
        didSet {
            defaults.set(simulateUpdateAvailable, forKey: "simulateUpdateAvailable")
            // 发送通知让 MenuBarManager 重新检查更新状态
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 是否在菜单栏单独显示所有形状图标（调试用，方便截图）
    @Published var debugShowAllShapesIndividually: Bool {
        didSet {
            defaults.set(debugShowAllShapesIndividually, forKey: "debugShowAllShapesIndividually")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 是否保持详情窗口始终打开（调试用，方便录制动画）
    @Published var debugKeepDetailWindowOpen: Bool {
        didSet {
            defaults.set(debugKeepDetailWindowOpen, forKey: "debugKeepDetailWindowOpen")
        }
    }

    /// 调试场景枚举
    enum DebugScenario: String, CaseIterable {
        case realData = "real"              // 真实API数据
        case fiveHourOnly = "five_hour"     // 仅5小时限制
        case sevenDayOnly = "seven_day"     // 仅7天限制
        case both = "both"                  // 同时有两种限制
        case allFive = "all_five"           // 全部5种限制（v2.0测试）

        var displayName: String {
            switch self {
            case .realData:
                return "真实数据"
            case .fiveHourOnly:
                return "仅5小时限制"
            case .sevenDayOnly:
                return "仅7天限制"
            case .both:
                return "双限制"
            case .allFive:
                return "全部5种限制"
            }
        }
    }
    #endif

    // MARK: - 智能模式内部状态（不持久化，委托给 SmartRefreshPolicy 纯逻辑状态机）

    /// 智能刷新的 4 级监控模式状态机（纯逻辑，可独立单测，见 Helpers/SmartRefreshPolicy.swift）
    private let smartRefreshPolicy = SmartRefreshPolicy()

    /// 上次检测的百分比（用于检测变化）
    var lastUtilization: Double? {
        get { smartRefreshPolicy.lastUtilization }
        set { smartRefreshPolicy.lastUtilization = newValue }
    }

    /// 连续无变化次数
    var unchangedCount: Int {
        get { smartRefreshPolicy.unchangedCount }
        set { smartRefreshPolicy.unchangedCount = newValue }
    }

    /// 当前监控模式（智能模式下使用）
    var currentMonitoringMode: MonitoringMode {
        get { smartRefreshPolicy.currentMode }
        set { smartRefreshPolicy.currentMode = newValue }
    }

    // MARK: - Initialization
    
    /// 检测系统语言并映射到应用支持的语言
    /// - Returns: 与系统语言最匹配的 AppLanguage
    private static func detectSystemLanguage() -> AppLanguage {
        let systemLanguage = Locale.preferredLanguages.first ?? "en"

        // 根据系统语言前缀匹配应用支持的语言
        if systemLanguage.hasPrefix("zh-Hans") {
            return .chinese
        } else if systemLanguage.hasPrefix("zh-Hant") || systemLanguage.hasPrefix("zh-HK") || systemLanguage.hasPrefix("zh-TW") {
            return .chineseTraditional
        } else if systemLanguage.hasPrefix("ja") {
            return .japanese
        } else if systemLanguage.hasPrefix("ko") {
            return .korean
        } else if systemLanguage.hasPrefix("fr") {
            return .french
        } else {
            return .english  // 默认英语
        }
    }
    
    /// 私有初始化方法（单例模式）
    /// 从 Keychain 加载敏感信息，从 UserDefaults 加载其他设置
    private init() {
        // MARK: - 从UserDefaults加载非敏感设置

        if let modeString = defaults.string(forKey: "iconDisplayMode"),
           let mode = IconDisplayMode(rawValue: modeString) {
            self.iconDisplayMode = mode
        } else {
            self.iconDisplayMode = .percentageOnly
        }
        
        if let styleString = defaults.string(forKey: "iconStyleMode"),
           let style = IconStyleMode(rawValue: styleString) {
            self.iconStyleMode = style
        } else {
            self.iconStyleMode = .colorTranslucent  // 默认彩色通透
        }
        
        // 加载刷新模式，默认为智能模式
        if let modeString = defaults.string(forKey: "refreshMode"),
           let mode = RefreshMode(rawValue: modeString) {
            self.refreshMode = mode
        } else {
            self.refreshMode = .smart
        }
        
        let savedRefreshInterval = defaults.integer(forKey: "refreshInterval")
        self.refreshInterval = savedRefreshInterval > 0 ? savedRefreshInterval : 180 // 默认3分钟
        
        if let langString = defaults.string(forKey: "language"),
           let lang = AppLanguage(rawValue: langString) {
            self.language = lang
        } else {
            // 首次启动时使用系统语言
            self.language = Self.detectSystemLanguage()
        }

        // 外观模式的加载已搬进 AppearanceManager.init()

        // 加载时间格式偏好，默认跟随系统
        if let timeFormatString = defaults.string(forKey: "timeFormatPreference"),
           let timeFormat = TimeFormatPreference(rawValue: timeFormatString) {
            self.timeFormatPreference = timeFormat
        } else {
            self.timeFormatPreference = .system
        }

        // 加载显示模式，默认为智能模式
        if let modeString = defaults.string(forKey: "displayMode"),
           let mode = DisplayMode(rawValue: modeString) {
            self.displayMode = mode
        } else {
            self.displayMode = .smart
        }

        // 加载自定义显示类型，默认为 5 小时和 7 天限制
        if let rawValues = defaults.array(forKey: "customDisplayTypes") as? [String] {
            self.customDisplayTypes = Set(rawValues.compactMap { LimitType(rawValue: $0) })
        } else {
            self.customDisplayTypes = Self.defaultCustomDisplayTypes
        }

        // 加载"自定义显示仅应用于菜单栏"开关，默认关闭（保持向后兼容）
        self.customDisplayMenuBarOnly = defaults.bool(forKey: "customDisplayMenuBarOnly")

        // 检查是否首次启动（如果没有保存过认证信息，就是首次启动）
        if !defaults.bool(forKey: "hasLaunched") {
            self.isFirstLaunch = true
            defaults.set(true, forKey: "hasLaunched")
        } else {
            self.isFirstLaunch = false
        }
        
        // 加载通知设置，默认开启
        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true

        // 开机启动状态的加载已搬进 LaunchAtLoginManager.init()

        // MARK: - 初始化调试模式设置

        #if DEBUG
        self.debugModeEnabled = defaults.bool(forKey: "debugModeEnabled")
        self.debugScenario = DebugScenario(
            rawValue: defaults.string(forKey: "debugScenario") ?? "real"
        ) ?? .realData
        self.debugFiveHourPercentage = defaults.object(forKey: "debugFiveHourPercentage") as? Double ?? 55.0
        self.debugSevenDayPercentage = defaults.object(forKey: "debugSevenDayPercentage") as? Double ?? 66.0
        self.debugOpusPercentage = defaults.object(forKey: "debugOpusPercentage") as? Double ?? 77.0
        self.debugSonnetPercentage = defaults.object(forKey: "debugSonnetPercentage") as? Double ?? 88.0
        self.debugCodexPrimaryPercentage = defaults.object(forKey: "debugCodexPrimaryPercentage") as? Double ?? 42.0
        self.debugCodexSecondaryPercentage = defaults.object(forKey: "debugCodexSecondaryPercentage") as? Double ?? 58.0
        self.debugCodexExtraUsagePercentage = defaults.object(forKey: "debugCodexExtraUsagePercentage") as? Double ?? 35.0
        self.debugExtraUsageEnabled = defaults.object(forKey: "debugExtraUsageEnabled") as? Bool ?? true
        self.debugExtraUsageUsed = defaults.object(forKey: "debugExtraUsageUsed") as? Double ?? 3050.0
        self.debugExtraUsageLimit = defaults.object(forKey: "debugExtraUsageLimit") as? Int ?? 5000
        self.debugExtraUsagePercentage = defaults.object(forKey: "debugExtraUsagePercentage") as? Double ?? 61.0
        self.simulateUpdateAvailable = defaults.bool(forKey: "simulateUpdateAvailable")
        self.debugShowAllShapesIndividually = defaults.bool(forKey: "debugShowAllShapesIndividually")
        self.debugKeepDetailWindowOpen = defaults.bool(forKey: "debugKeepDetailWindowOpen")
        #endif

        // 账户加载/迁移、开机启动注册状态、外观应用与系统主题监听都已分别搬进
        // AccountStore / LaunchAtLoginManager / AppearanceManager 各自的 init()；
        // 这里只需转发它们的 objectWillChange，让 @ObservedObject var settings =
        // UserSettings.shared 的 SwiftUI 视图在这些子对象变化时也能收到刷新。
        for publisher in [accountStore.objectWillChange, launchAtLoginManager.objectWillChange, appearanceManager.objectWillChange] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // 同步系统实际的开机启动状态（LaunchAtLoginManager.init 只读了一次快照，
        // 这里主动刷新一次以防应用启动前用户在系统设置里手动改过）
        syncLaunchAtLoginStatus()
    }
    
    // MARK: - Computed Properties

    /// 当前应用使用的 Locale（基于用户选择的语言）
    var appLocale: Locale {
        return language.locale
    }

    /// 检查认证信息是否已配置
    /// OAuth 账户仅凭 refresh_token（sk-ant-ort01- 前缀）即可认为有效；
    /// session-cookie 账户仍需 organizationId + sessionKey 双非空。
    var hasValidCredentials: Bool {
        guard !sessionKey.isEmpty else { return false }
        if sessionKey.hasPrefix("sk-ant-ort01-") { return true }
        return !organizationId.isEmpty
    }

    /// 检查任一 Provider 的认证信息是否已配置
    var hasAnyValidCredentials: Bool {
        return hasValidCredentials || hasValidCodexCredentials
    }

    /// 验证 Organization ID 格式
    /// - Parameter id: 要验证的 Organization ID
    /// - Returns: 如果格式有效（UUID 格式）返回 true
    func isValidOrganizationId(_ id: String) -> Bool {
        // Organization ID 应该是 UUID 格式
        let uuidRegex = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", uuidRegex)
        return predicate.evaluate(with: id)
    }

    /// 验证 Session Key 格式
    /// - Parameter key: 要验证的 Session Key
    /// - Returns: 如果格式有效返回 true
    func isValidSessionKey(_ key: String) -> Bool {
        // Session Key 应该是非空的，并且有合理的长度
        // 典型的 session key 长度在 20-200 字符之间
        return !key.isEmpty && key.count >= 20 && key.count <= 500
    }
    
    /// 获取当前生效的刷新间隔（秒）
    /// - Returns: 智能模式返回当前监控模式的间隔，固定模式返回用户设置的间隔
    var effectiveRefreshInterval: Int {
        switch refreshMode {
        case .smart:
            return currentMonitoringMode.interval
        case .fixed:
            return refreshInterval
        }
    }
    
    // MARK: - Public Methods

    /// 重置为默认设置
    /// 只重置非敏感设置，不影响认证信息
    func resetToDefaults() {
        appearance = .system
        iconDisplayMode = .percentageOnly
        iconStyleMode = .colorTranslucent
        refreshMode = .smart
        refreshInterval = 180  // 固定模式默认3分钟
        language = Self.detectSystemLanguage()
        timeFormatPreference = .system
        displayMode = .smart
        customDisplayTypes = Self.defaultCustomDisplayTypes
        customDisplayMenuBarOnly = false
        notificationsEnabled = true

        // 重置智能模式状态
        lastUtilization = nil
        unchangedCount = 0
        currentMonitoringMode = .active
    }
    
    /// 清除所有认证信息
    /// 从 Keychain 中删除 Organization ID 和 Session Key
    func clearCredentials() {
        keychain.deleteCredentials()
        organizationId = ""
        sessionKey = ""
        Logger.settings.notice("已清除所有认证信息")
    }
    
    /// 更新智能监控模式
    /// 根据用量百分比变化智能调整刷新频率
    /// - Parameter currentUtilization: 当前用量百分比
    func updateSmartMonitoringMode(currentUtilization: Double) {
        updateSmartMonitoringMode(providerUtilizations: [.claude: currentUtilization])
    }

    /// 更新智能监控模式
    /// 任一 Provider 用量变化会切回活跃模式；全部无变化才累计静默次数。
    /// 状态机本身在 SmartRefreshPolicy 中（纯逻辑、可单测），这里只处理日志和通知这两个副作用。
    /// - Parameter providerUtilizations: 本轮成功获取的 Provider 用量百分比
    func updateSmartMonitoringMode(providerUtilizations: [ProviderType: Double]) {
        // 只在智能模式下工作
        guard refreshMode == .smart else { return }

        let previousMode = smartRefreshPolicy.currentMode
        let modeChanged = smartRefreshPolicy.update(providerUtilizations: providerUtilizations)

        if modeChanged {
            logModeTransition(from: previousMode, to: smartRefreshPolicy.currentMode)
            NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
        }
    }

    /// 记录模式切换日志
    /// - Parameters:
    ///   - from: 原模式
    ///   - to: 新模式
    private func logModeTransition(from: MonitoringMode, to: MonitoringMode) {
        let modeNames: [MonitoringMode: String] = [
            .active: "活跃 (1分钟)",
            .idleShort: "短期静默 (3分钟)",
            .idleMedium: "中期静默 (5分钟)",
            .idleLong: "长期静默 (10分钟)"
        ]
        Logger.settings.debug("监控模式切换: \(modeNames[from] ?? "") -> \(modeNames[to] ?? "")")
    }

    /// 重置智能监控模式状态
    /// 在切换到固定模式或用户手动刷新时调用
    func resetSmartMonitoringState() {
        smartRefreshPolicy.reset()
    }

    // MARK: - Account Management (v2.1.0)
    // 实际存取/持久化都在 AccountStore（Models/AccountStore.swift），这里只是门面转发，
    // 保持外部调用点不变。addCodexAccount 额外处理"首次接入 Codex"的展示类型初始化，
    // 因为那部分要读 displayMode/customDisplayTypes，属于 UserSettings 自己的地盘。

    /// 添加新账户
    /// - Parameter account: 要添加的账户
    func addAccount(_ account: Account) {
        accountStore.addAccount(account)
    }

    /// 删除账户
    /// - Parameter account: 要删除的账户
    func removeAccount(_ account: Account) {
        accountStore.removeAccount(account)
    }

    /// 切换到指定账户
    /// - Parameter account: 要切换到的账户
    func switchToAccount(_ account: Account) {
        accountStore.switchToAccount(account)
    }

    /// 更新账户信息
    /// - Parameters:
    ///   - account: 要更新的账户
    ///   - alias: 新的别名（可选）
    func updateAccount(_ account: Account, alias: String?) {
        accountStore.updateAccount(account, alias: alias)
    }

    /// 用于显示的账户列表
    var displayAccounts: [Account] { accountStore.displayAccounts }

    /// 当前账户的显示名称
    var currentAccountName: String? { accountStore.currentAccountName }

    // MARK: - Codex Account Management

    @discardableResult
    func addCodexAccount(_ account: Account) -> Account {
        let (stored, wasFirstCodexAccount) = accountStore.addCodexAccount(account)
        if wasFirstCodexAccount {
            ensureDefaultCodexDisplayTypesForCustomMode()
        }
        return stored
    }

    func removeCodexAccount(_ account: Account) {
        accountStore.removeCodexAccount(account)
    }

    func switchToCodexAccount(_ account: Account) {
        accountStore.switchToCodexAccount(account)
    }

    func updateCodexAccount(_ account: Account, alias: String?) {
        accountStore.updateCodexAccount(account, alias: alias)
    }

    /// 静默更新当前 Codex 账户的 session-token（不触发 accountChanged 通知）
    /// 用于自动续期场景——只更新持久化数据，不触发重新拉取循环
    func silentlyUpdateCurrentCodexSessionToken(_ token: String) {
        accountStore.silentlyUpdateCurrentCodexSessionToken(token)
    }

    /// 静默更新当前 Claude 账户的 session-token（不触发 accountChanged 通知）
    /// 用于 OAuth refresh_token 轮换场景——只更新持久化数据，不触发重新拉取循环
    func silentlyUpdateCurrentClaudeSessionToken(_ token: String) {
        accountStore.silentlyUpdateCurrentClaudeSessionToken(token)
    }

    private func ensureDefaultCodexDisplayTypesForCustomMode() {
        guard displayMode == .custom else { return }
        let codexTypes: Set<LimitType> = [.codexPrimary, .codexSecondary, .codexExtraUsage]
        guard customDisplayTypes.isDisjoint(with: codexTypes) else { return }
        customDisplayTypes.formUnion([.codexPrimary, .codexSecondary])
    }

    // MARK: - Launch at Login Management
    // 注册/注销/状态同步都在 LaunchAtLoginManager 里，这里只保留一个转发方法，
    // 供 ClaudeUsageMonitorApp（didBecomeActive）和设置页（onAppear）调用。

    /// 从系统读取实际的开机启动状态并更新UI
    func syncLaunchAtLoginStatus() {
        launchAtLoginManager.refreshStatus()
    }

    // MARK: - Display Logic Helper Methods (v2.0)

    /// 获取当前应该显示的限制类型列表
    /// - Parameters:
    ///   - usageData: Claude 用量数据
    ///   - codexUsageData: Codex 用量数据（可选，有 Codex 账号时传入）
    ///   - forMenuBar: 是否用于菜单栏渲染。当 customDisplayMenuBarOnly 开启时，
    ///                 仅菜单栏走 custom 分支，Popover 自动 fallback 到 smart 分支
    /// - Returns: 要显示的限制类型数组，按显示顺序排列
    func getActiveDisplayTypes(usageData: UsageData?, codexUsageData: CodexUsageData? = nil, forMenuBar: Bool = false) -> [LimitType] {
        // 当"仅应用于菜单栏"开启且当前是为 Popover 渲染时，强制走智能分支
        let effectiveMode: DisplayMode = {
            if displayMode == .custom && customDisplayMenuBarOnly && !forMenuBar {
                return .smart
            }
            return displayMode
        }()
        switch effectiveMode {
        case .smart:
            // 智能模式：显示所有有数据的类型
            var types: [LimitType] = []

            // Claude 类型：按规范顺序 fiveHour → sevenDay → extraUsage → opus → sonnet
            if let data = usageData {
                // 5小时和7天限制始终显示，因为所有账号均受这两项限制约束
                types.append(.fiveHour)
                types.append(.sevenDay)
                if data.extraUsage?.enabled == true {
                    types.append(.extraUsage)
                }
                if data.opus != nil {
                    types.append(.opusWeekly)
                }
                if data.sonnet != nil {
                    types.append(.sonnetWeekly)
                }
            }

            // Codex 类型：仅在对应窗口确有数据时追加
            // （Codex 曾临时取消5小时窗口，此时 API 只返回7天窗口，
            //  不能像 Claude 的 fiveHour/sevenDay 那样假定 primary 必然存在）
            if let codex = codexUsageData {
                if codex.primary != nil {
                    types.append(.codexPrimary)
                }
                if codex.secondary != nil {
                    types.append(.codexSecondary)
                }
                if codex.extraUsage?.enabled == true {
                    types.append(.codexExtraUsage)
                }
            }

            return types

        case .custom:
            // 自定义模式：按用户选择排序，无论数据是否存在都显示
            // Codex 类型仅在有 Codex 账号时纳入候选；Debug mock 模式例外
            var orderedTypes: [LimitType] = [.fiveHour, .sevenDay, .extraUsage, .opusWeekly, .sonnetWeekly]
            var shouldIncludeCodexTypes = !codexAccounts.isEmpty
            #if DEBUG
            if debugModeEnabled {
                shouldIncludeCodexTypes = true
            }
            #endif
            if shouldIncludeCodexTypes {
                orderedTypes.append(contentsOf: [.codexPrimary, .codexSecondary, .codexExtraUsage])
            }
            return orderedTypes.filter { customDisplayTypes.contains($0) }
        }
    }

    /// 判断当前配置是否可以使用彩色主题
    /// - Returns: true 表示可以使用彩色主题
    func canUseColoredTheme(usageData: UsageData?) -> Bool {
        let activeTypes = getActiveDisplayTypes(usageData: usageData)

        // 现在所有限制类型都支持彩色显示
        // 只要有图标就可以使用彩色主题
        return !activeTypes.isEmpty
    }
}

// MARK: - Notification Names

/// 设置相关通知名称扩展
// 注意：通知名称现已迁移到 NotificationNames.swift
// 保持向后兼容性的导入
