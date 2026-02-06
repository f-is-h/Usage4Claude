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
    
    var localizedName: String {
        switch self {
        case .percentageOnly:
            return L.Display.percentageOnly
        case .iconOnly:
            return L.Display.iconOnly
        case .both:
            return L.Display.both
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

/// 监控模式（内部使用，智能频率下的4级模式）
enum MonitoringMode: String, Codable {
    /// 活跃模式 - 1分钟刷新
    case active = "active"
    /// 短期静默 - 3分钟刷新
    case idleShort = "idle_short"
    /// 中期静默 - 5分钟刷新
    case idleMedium = "idle_medium"
    /// 长期静默 - 10分钟刷新
    case idleLong = "idle_long"
    
    /// 获取对应的刷新间隔（秒）
    var interval: Int {
        switch self {
        case .active:
            return 60      // 1分钟
        case .idleShort:
            return 180     // 3分钟
        case .idleMedium:
            return 300     // 5分钟
        case .idleLong:
            return 600     // 10分钟
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

    /// 是否为圆形图标（5小时和7天）
    var isCircular: Bool {
        return self == .fiveHour || self == .sevenDay
    }

    /// 是否为矩形图标（Opus和Sonnet）
    var isRectangular: Bool {
        return self == .opusWeekly || self == .sonnetWeekly
    }

    /// 是否为六边形图标（Extra Usage）
    var isHexagonal: Bool {
        return self == .extraUsage
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
    
    // MARK: - Properties
    
    private let defaults = UserDefaults.standard
    private let keychain = KeychainManager.shared
    
    // MARK: - 多账户支持（v2.1.0）

    /// 账户列表（存储在 Keychain 中）
    @Published var accounts: [Account] = [] {
        didSet {
            saveAccounts()
        }
    }

    /// 当前激活账户的 ID（存储在 UserDefaults 中）
    @Published var currentAccountId: UUID? {
        didSet {
            if let id = currentAccountId {
                defaults.set(id.uuidString, forKey: "currentAccountId")
            } else {
                defaults.removeObject(forKey: "currentAccountId")
            }
        }
    }

    /// 当前激活的账户
    var currentAccount: Account? {
        guard let id = currentAccountId else { return accounts.first }
        return accounts.first { $0.id == id }
    }

    /// Claude Session Key（计算属性，指向当前账户）
    var sessionKey: String {
        get { currentAccount?.sessionKey ?? "" }
        set {
            guard let id = currentAccountId,
                  let index = accounts.firstIndex(where: { $0.id == id }) else { return }
            accounts[index].sessionKey = newValue
        }
    }

    /// Claude Organization ID（计算属性，指向当前账户）
    var organizationId: String {
        get { currentAccount?.organizationId ?? "" }
        set {
            guard let id = currentAccountId,
                  let index = accounts.firstIndex(where: { $0.id == id }) else { return }
            accounts[index].organizationId = newValue
        }
    }

    // MARK: - 非敏感设置（存储在UserDefaults中）

    /// 组织列表（保留用于向后兼容，现已废弃）
    /// 从 v2.1.0 开始，组织信息包含在 Account 中
    @Published var organizations: [Organization] = [] {
        didSet {
            saveOrganizations()
        }
    }
    
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

    /// 是否为首次启动标记
    @Published var isFirstLaunch: Bool {
        didSet {
            defaults.set(isFirstLaunch, forKey: "isFirstLaunch")
        }
    }
    
    /// 开机启动设置
    @Published var launchAtLogin: Bool {
        didSet {
            // 在同步状态时不触发启用/禁用操作，避免无限循环
            guard !isSyncingLaunchStatus else { return }

            if launchAtLogin {
                enableLaunchAtLogin()
            } else {
                disableLaunchAtLogin()
            }
        }
    }
    
    /// 开机启动状态（用于UI显示）
    @Published var launchAtLoginStatus: SMAppService.Status = .notRegistered

    /// 防止同步状态时触发递归调用的标志
    private var isSyncingLaunchStatus: Bool = false

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

    /// 调试用的 Extra Usage 是否启用
    @Published var debugExtraUsageEnabled: Bool {
        didSet {
            defaults.set(debugExtraUsageEnabled, forKey: "debugExtraUsageEnabled")
        }
    }

    /// 调试用的 Extra Usage 已使用金额（美元）
    @Published var debugExtraUsageUsed: Double {
        didSet {
            defaults.set(debugExtraUsageUsed, forKey: "debugExtraUsageUsed")
        }
    }

    /// 调试用的 Extra Usage 总限额（美元）
    @Published var debugExtraUsageLimit: Double {
        didSet {
            defaults.set(debugExtraUsageLimit, forKey: "debugExtraUsageLimit")
        }
    }

    /// 调试用的 Extra Usage 百分比（0-100），会同步更新 used 值
    @Published var debugExtraUsagePercentage: Double {
        didSet {
            defaults.set(debugExtraUsagePercentage, forKey: "debugExtraUsagePercentage")
            // 同步更新 used 值
            debugExtraUsageUsed = debugExtraUsageLimit * (debugExtraUsagePercentage / 100.0)
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

    // MARK: - 智能模式内部状态（不持久化）
    
    /// 上次检测的百分比（用于检测变化）
    var lastUtilization: Double?
    
    /// 连续无变化次数
    var unchangedCount: Int = 0
    
    /// 当前监控模式（智能模式下使用）
    var currentMonitoringMode: MonitoringMode = .active
    
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
        } else {
            return .english  // 默认英语
        }
    }
    
    /// 私有初始化方法（单例模式）
    /// 从 Keychain 加载敏感信息，从 UserDefaults 加载其他设置
    private init() {
        // MARK: - 加载多账户数据（v2.1.0）

        // 从 Keychain 加载账户列表（使用局部变量避免初始化顺序问题）
        var loadedAccounts = keychain.loadAccounts() ?? []
        var loadedCurrentAccountId: UUID? = nil

        // 加载当前账户 ID
        if let idString = defaults.string(forKey: "currentAccountId"),
           let id = UUID(uuidString: idString) {
            loadedCurrentAccountId = id
        } else if let firstAccount = loadedAccounts.first {
            // 如果没有保存当前账户 ID，默认使用第一个账户
            loadedCurrentAccountId = firstAccount.id
        }

        // MARK: - 数据迁移（v2.0.x → v2.1.0 多账户）

        // 检查是否需要从单账户迁移到多账户
        if loadedAccounts.isEmpty && !defaults.bool(forKey: "multiAccountMigrated") {
            // 尝试从旧的单账户数据迁移
            let oldSessionKey = keychain.loadSessionKey() ?? ""
            let oldOrgId = defaults.string(forKey: "organizationId") ?? ""

            if !oldSessionKey.isEmpty && !oldOrgId.isEmpty {
                Logger.settings.notice("[Migration] Migrating single account to multi-account system")

                // 获取组织名称（如果有缓存）
                let cachedOrgs = Self.loadOrganizations(from: defaults)
                let orgName = cachedOrgs.first { $0.uuid == oldOrgId }?.name ?? "Account 1"

                // 创建第一个账户
                let migratedAccount = Account(
                    sessionKey: oldSessionKey,
                    organizationId: oldOrgId,
                    organizationName: orgName
                )
                loadedAccounts = [migratedAccount]
                loadedCurrentAccountId = migratedAccount.id

                // 清理旧的单账户数据
                keychain.deleteSessionKey()
                defaults.removeObject(forKey: "organizationId")

                Logger.settings.notice("[Migration] Multi-account migration completed")
            }

            defaults.set(true, forKey: "multiAccountMigrated")
        }

        // 设置 accounts 和 currentAccountId
        self.accounts = loadedAccounts
        self.currentAccountId = loadedCurrentAccountId

        // MARK: - 旧版迁移（v1.x → v2.0.0，保留向后兼容）

        // 迁移 Organization ID 从 Keychain 到 UserDefaults（旧版迁移，现已包含在上面的多账户迁移中）
        if !defaults.bool(forKey: "organizationIdMigrated") {
            if let oldOrgId = keychain.loadOrganizationId(), !oldOrgId.isEmpty {
                Logger.settings.notice("[Migration] Found Organization ID in old Keychain location")
                keychain.deleteOrganizationId()
            }
            defaults.set(true, forKey: "organizationIdMigrated")
        }

        // MARK: - 从UserDefaults加载非敏感设置

        // 加载缓存的组织列表（保留向后兼容）
        self.organizations = Self.loadOrganizations(from: defaults)
        
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
            self.customDisplayTypes = [.fiveHour, .sevenDay]
        }

        // 检查是否首次启动（如果没有保存过认证信息，就是首次启动）
        if !defaults.bool(forKey: "hasLaunched") {
            self.isFirstLaunch = true
            defaults.set(true, forKey: "hasLaunched")
        } else {
            self.isFirstLaunch = false
        }
        
        // 初始化开机启动设置
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")

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
        self.debugExtraUsageEnabled = defaults.object(forKey: "debugExtraUsageEnabled") as? Bool ?? true
        self.debugExtraUsageUsed = defaults.object(forKey: "debugExtraUsageUsed") as? Double ?? 30.50
        self.debugExtraUsageLimit = defaults.object(forKey: "debugExtraUsageLimit") as? Double ?? 50.0
        self.debugExtraUsagePercentage = defaults.object(forKey: "debugExtraUsagePercentage") as? Double ?? 61.0
        self.simulateUpdateAvailable = defaults.bool(forKey: "simulateUpdateAvailable")
        self.debugShowAllShapesIndividually = defaults.bool(forKey: "debugShowAllShapesIndividually")
        self.debugKeepDetailWindowOpen = defaults.bool(forKey: "debugKeepDetailWindowOpen")
        #endif

        // 同步系统实际状态
        syncLaunchAtLoginStatus()
    }
    
    // MARK: - Computed Properties

    /// 当前应用使用的 Locale（基于用户选择的语言）
    var appLocale: Locale {
        return language.locale
    }

    /// 检查认证信息是否已配置
    /// - Returns: 如果 Organization ID 和 Session Key 都不为空则返回 true
    var hasValidCredentials: Bool {
        return !organizationId.isEmpty && !sessionKey.isEmpty
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
        iconDisplayMode = .percentageOnly
        iconStyleMode = .colorTranslucent
        refreshMode = .smart
        refreshInterval = 180  // 固定模式默认3分钟
        language = Self.detectSystemLanguage()
        timeFormatPreference = .system
        displayMode = .smart
        customDisplayTypes = [.fiveHour, .sevenDay, .extraUsage]

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
        // 只在智能模式下工作
        guard refreshMode == .smart else { return }

        // 检查是否有变化
        if hasUtilizationChanged(currentUtilization) {
            switchToActiveMode()
        } else {
            handleNoChange()
        }

        // 更新上次的百分比
        lastUtilization = currentUtilization
    }

    /// 检查用量百分比是否有变化
    /// - Parameter current: 当前用量百分比
    /// - Returns: 如果变化超过 0.01 返回 true
    private func hasUtilizationChanged(_ current: Double) -> Bool {
        guard let last = lastUtilization else { return false }
        return abs(current - last) > 0.01
    }

    /// 切换到活跃模式
    private func switchToActiveMode() {
        guard currentMonitoringMode != .active else { return }

        Logger.settings.debug("检测到使用变化，切换到活跃模式 (1分钟)")
        currentMonitoringMode = .active
        unchangedCount = 0
        NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
    }

    /// 处理无变化情况
    private func handleNoChange() {
        unchangedCount += 1

        let previousMode = currentMonitoringMode
        let newMode = calculateNewMode()

        if let mode = newMode {
            currentMonitoringMode = mode
            unchangedCount = 0
            logModeTransition(from: previousMode, to: mode)
            NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
        }
    }

    /// 根据当前模式和无变化次数计算新模式
    /// - Returns: 如果需要切换，返回新模式；否则返回 nil
    private func calculateNewMode() -> MonitoringMode? {
        switch currentMonitoringMode {
        case .active:
            // 活跃模式：连续3次无变化（3分钟） -> 短期静默
            return unchangedCount >= 3 ? .idleShort : nil
        case .idleShort:
            // 短期静默：连续6次无变化（18分钟） -> 中期静默
            return unchangedCount >= 6 ? .idleMedium : nil
        case .idleMedium:
            // 中期静默：连续12次无变化（60分钟） -> 长期静默
            return unchangedCount >= 12 ? .idleLong : nil
        case .idleLong:
            // 长期静默：保持当前模式
            return nil
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
        lastUtilization = nil
        unchangedCount = 0
        currentMonitoringMode = .active
    }

    // MARK: - Account Management (v2.1.0)

    /// 保存账户列表到 Keychain
    private func saveAccounts() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.keychain.saveAccounts(self.accounts)
        }
    }

    /// 添加新账户
    /// - Parameter account: 要添加的账户
    func addAccount(_ account: Account) {
        accounts.append(account)
        // 如果是第一个账户，自动设为当前账户
        if accounts.count == 1 {
            currentAccountId = account.id
        }
        Logger.settings.notice("添加账户: \(account.displayName)")
    }

    /// 删除账户
    /// - Parameter account: 要删除的账户
    func removeAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }

        let wasCurrentAccount = (currentAccountId == account.id)
        accounts.remove(at: index)

        // 如果删除的是当前账户，切换到第一个账户
        if wasCurrentAccount {
            currentAccountId = accounts.first?.id
            // 发送账户变更通知
            NotificationCenter.default.post(name: .accountChanged, object: nil)
        }

        Logger.settings.notice("删除账户: \(account.displayName)")
    }

    /// 切换到指定账户
    /// - Parameter account: 要切换到的账户
    func switchToAccount(_ account: Account) {
        guard account.id != currentAccountId else { return }
        guard accounts.contains(where: { $0.id == account.id }) else { return }

        currentAccountId = account.id
        Logger.settings.notice("切换到账户: \(account.displayName)")

        // 发送账户变更通知
        NotificationCenter.default.post(name: .accountChanged, object: nil)
    }

    /// 更新账户信息
    /// - Parameters:
    ///   - account: 要更新的账户
    ///   - alias: 新的别名（可选）
    func updateAccount(_ account: Account, alias: String?) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].alias = alias
        let displayName = accounts[index].displayName
        Logger.settings.notice("更新账户别名: \(displayName)")
    }

    /// 用于显示的账户列表
    /// - Returns: 账户列表
    var displayAccounts: [Account] {
        return accounts
    }

    /// 当前账户的显示名称
    var currentAccountName: String? {
        return currentAccount?.displayName
    }

    // MARK: - Organization Management (保留向后兼容)

    /// 保存组织列表到 UserDefaults（保留向后兼容）
    private func saveOrganizations() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(organizations) {
            defaults.set(data, forKey: "cachedOrganizations")
        }
    }

    /// 从 UserDefaults 加载组织列表（保留向后兼容）
    /// - Parameter defaults: UserDefaults 实例
    /// - Returns: 组织列表，如果加载失败则返回空数组
    private static func loadOrganizations(from defaults: UserDefaults) -> [Organization] {
        guard let data = defaults.data(forKey: "cachedOrganizations") else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([Organization].self, from: data)) ?? []
    }

    // MARK: - Launch at Login Management
    
    /// 启用开机启动
    private func enableLaunchAtLogin() {
        do {
            try SMAppService.mainApp.register()
            defaults.set(true, forKey: "launchAtLogin")
            syncLaunchAtLoginStatus()
            Logger.settings.notice("开机启动已启用")
        } catch {
            Logger.settings.error("启用开机启动失败: \(error.localizedDescription)")
            // 注册失败，恢复状态（避免触发didSet）
            isSyncingLaunchStatus = true
            DispatchQueue.main.async {
                self.launchAtLogin = false
                // 在异步块内重置标志，避免 race condition
                self.isSyncingLaunchStatus = false
                self.syncLaunchAtLoginStatus()
            }

            // 发送错误通知
            NotificationCenter.default.post(
                name: .launchAtLoginError,
                object: nil,
                userInfo: ["error": error, "operation": "enable"]
            )
        }
    }
    
    /// 禁用开机启动
    private func disableLaunchAtLogin() {
        let currentStatus = SMAppService.mainApp.status

        // 如果服务未注册或未找到，直接更新设置，不执行unregister操作
        if currentStatus == .notRegistered || currentStatus == .notFound {
            defaults.set(false, forKey: "launchAtLogin")
            syncLaunchAtLoginStatus()
            Logger.settings.notice("开机启动服务未注册，已更新设置")
            return
        }

        do {
            try SMAppService.mainApp.unregister()
            defaults.set(false, forKey: "launchAtLogin")
            syncLaunchAtLoginStatus()
            Logger.settings.notice("开机启动已禁用")
        } catch {
            Logger.settings.error("禁用开机启动失败: \(error.localizedDescription)")
            // 取消注册失败，恢复状态（避免触发didSet）
            isSyncingLaunchStatus = true
            DispatchQueue.main.async {
                self.launchAtLogin = true
                // 在异步块内重置标志，避免 race condition
                self.isSyncingLaunchStatus = false
                self.syncLaunchAtLoginStatus()
            }

            // 发送错误通知
            NotificationCenter.default.post(
                name: .launchAtLoginError,
                object: nil,
                userInfo: ["error": error, "operation": "disable"]
            )
        }
    }
    
    /// 同步开机启动状态
    /// 从系统读取实际状态并更新UI
    func syncLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        DispatchQueue.main.async {
            self.launchAtLoginStatus = status

            // 同步实际状态到设置
            let isActuallyEnabled = (status == .enabled)
            if self.launchAtLogin != isActuallyEnabled {
                // 设置同步标志，避免触发 didSet 中的启用/禁用操作
                self.isSyncingLaunchStatus = true
                self.defaults.set(isActuallyEnabled, forKey: "launchAtLogin")
                self.launchAtLogin = isActuallyEnabled
                self.isSyncingLaunchStatus = false
            }
        }

        Logger.settings.debug("开机启动状态: \(String(describing: status))")
    }

    // MARK: - Display Logic Helper Methods (v2.0)

    /// 获取当前应该显示的限制类型列表
    /// - Parameter usageData: 用量数据
    /// - Returns: 要显示的限制类型数组，按显示顺序排列
    func getActiveDisplayTypes(usageData: UsageData?) -> [LimitType] {
        switch displayMode {
        case .smart:
            // 智能模式：显示所有有数据的类型
            guard let data = usageData else {
                return []
            }

            var types: [LimitType] = []

            // 按规范顺序: fiveHour → sevenDay → extraUsage → opus → sonnet
            if data.fiveHour != nil {
                types.append(.fiveHour)
            }
            if data.sevenDay != nil {
                types.append(.sevenDay)
            }
            if data.extraUsage?.enabled == true {
                types.append(.extraUsage)
            }
            if data.opus != nil {
                types.append(.opusWeekly)
            }
            if data.sonnet != nil {
                types.append(.sonnetWeekly)
            }

            return types

        case .custom:
            // 自定义模式：按用户选择排序，无论数据是否存在都显示
            let orderedTypes: [LimitType] = [.fiveHour, .sevenDay, .extraUsage, .opusWeekly, .sonnetWeekly]
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
