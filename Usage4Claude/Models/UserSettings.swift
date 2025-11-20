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
    
    // MARK: - 敏感信息（存储在Keychain中）
    
    /// Claude Organization ID
    /// 从浏览器开发者工具的网络请求中获取
    @Published var organizationId: String {
        didSet {
            // 将Keychain写入操作移到后台线程，避免阻塞主线程
            let value = organizationId
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.keychain.saveOrganizationId(value)
            }
        }
    }

    /// Claude Session Key
    /// 从浏览器 Cookie 中获取的 sessionKey 值
    @Published var sessionKey: String {
        didSet {
            // 将Keychain写入操作移到后台线程，避免阻塞主线程
            let value = sessionKey
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.keychain.saveSessionKey(value)
            }
        }
    }
    
    // MARK: - 非敏感设置（存储在UserDefaults中）
    
    /// 菜单栏图标显示模式
    @Published var iconDisplayMode: IconDisplayMode {
        didSet {
            defaults.set(iconDisplayMode.rawValue, forKey: "iconDisplayMode")
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
        } else {
            return .english  // 默认英语
        }
    }
    
    /// 私有初始化方法（单例模式）
    /// 从 Keychain 加载敏感信息，从 UserDefaults 加载其他设置
    private init() {
        // MARK: - 从Keychain加载敏感信息
        
        // 从Keychain加载认证信息
        self.organizationId = keychain.loadOrganizationId() ?? ""
        self.sessionKey = keychain.loadSessionKey() ?? ""
        
        // MARK: - 从UserDefaults加载非敏感设置
        
        if let modeString = defaults.string(forKey: "iconDisplayMode"),
           let mode = IconDisplayMode(rawValue: modeString) {
            self.iconDisplayMode = mode
        } else {
            self.iconDisplayMode = .percentageOnly
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
        
        // 检查是否首次启动（如果没有保存过认证信息，就是首次启动）
        if !defaults.bool(forKey: "hasLaunched") {
            self.isFirstLaunch = true
            defaults.set(true, forKey: "hasLaunched")
        } else {
            self.isFirstLaunch = false
        }
        
        // 初始化开机启动设置
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        
        // 同步系统实际状态
        syncLaunchAtLoginStatus()
    }
    
    // MARK: - Computed Properties
    
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
        refreshMode = .smart
        refreshInterval = 180  // 固定模式默认3分钟
        language = .chinese
        
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
}

// MARK: - Notification Names

/// 设置相关通知名称扩展
extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
    static let languageChanged = Notification.Name("languageChanged")
    static let launchAtLoginError = Notification.Name("launchAtLoginError")
}
