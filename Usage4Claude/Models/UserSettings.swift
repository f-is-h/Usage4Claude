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
            // 保存到Keychain而不是UserDefaults
            keychain.saveOrganizationId(organizationId)
        }
    }
    
    /// Claude Session Key
    /// 从浏览器 Cookie 中获取的 sessionKey 值
    @Published var sessionKey: String {
        didSet {
            // 保存到Keychain而不是UserDefaults
            keychain.saveSessionKey(sessionKey)
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
    
    // MARK: - 智能模式内部状态（不持久化）
    
    /// 上次检测的百分比（用于检测变化）
    var lastUtilization: Double?
    
    /// 连续无变化次数
    var unchangedCount: Int = 0
    
    /// 当前监控模式（智能模式下使用）
    var currentMonitoringMode: MonitoringMode = .active
    
    // MARK: - Initialization
    
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
            self.language = .chinese
        }
        
        // 检查是否首次启动（如果没有保存过认证信息，就是首次启动）
        if !defaults.bool(forKey: "hasLaunched") {
            self.isFirstLaunch = true
            defaults.set(true, forKey: "hasLaunched")
        } else {
            self.isFirstLaunch = false
        }
    }
    
    // MARK: - Computed Properties
    
    /// 检查认证信息是否已配置
    /// - Returns: 如果 Organization ID 和 Session Key 都不为空则返回 true
    var hasValidCredentials: Bool {
        return !organizationId.isEmpty && !sessionKey.isEmpty
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
        print("🗑️ 已清除所有认证信息")
    }
    
    /// 更新智能监控模式
    /// 根据用量百分比变化智能调整刷新频率
    /// - Parameter currentUtilization: 当前用量百分比
    func updateSmartMonitoringMode(currentUtilization: Double) {
        // 只在智能模式下工作
        guard refreshMode == .smart else { return }
        
        // 检测百分比是否有变化
        if let last = lastUtilization, abs(currentUtilization - last) > 0.01 {
            // 检测到使用，立即切换到活跃模式
            if currentMonitoringMode != .active {
                print("🟢 检测到使用变化，切换到活跃模式 (1分钟)")
                currentMonitoringMode = .active
                unchangedCount = 0
                NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
            }
        } else {
            // 没有变化，增加计数
            unchangedCount += 1
            
            // 根据连续无变化次数逐步降低频率
            let previousMode = currentMonitoringMode
            
            switch currentMonitoringMode {
            case .active:
                // 活跃模式：连续3次无变化（3分钟） -> 短期静默
                if unchangedCount >= 3 {
                    currentMonitoringMode = .idleShort
                    unchangedCount = 0
                }
            case .idleShort:
                // 短期静默：连续6次无变化（18分钟） -> 中期静默
                if unchangedCount >= 6 {
                    currentMonitoringMode = .idleMedium
                    unchangedCount = 0
                }
            case .idleMedium:
                // 中期静默：连续12次无变化（60分钟） -> 长期静默
                if unchangedCount >= 12 {
                    currentMonitoringMode = .idleLong
                    unchangedCount = 0
                }
            case .idleLong:
                // 长期静默：保持当前模式
                break
            }
            
            // 如果模式发生变化，发送通知
            if previousMode != currentMonitoringMode {
                let modeNames: [MonitoringMode: String] = [
                    .active: "活跃 (1分钟)",
                    .idleShort: "短期静默 (3分钟)",
                    .idleMedium: "中期静默 (5分钟)",
                    .idleLong: "长期静默 (10分钟)"
                ]
                print("🔄 监控模式切换: \(modeNames[previousMode] ?? "") -> \(modeNames[currentMonitoringMode] ?? "")")
                NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
            }
        }
        
        // 更新上次的百分比
        lastUtilization = currentUtilization
    }
    
    /// 重置智能监控模式状态
    /// 在切换到固定模式或用户手动刷新时调用
    func resetSmartMonitoringState() {
        lastUtilization = nil
        unchangedCount = 0
        currentMonitoringMode = .active
    }
}

// MARK: - Notification Names

/// 设置相关通知名称扩展
extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
    static let languageChanged = Notification.Name("languageChanged")
}
