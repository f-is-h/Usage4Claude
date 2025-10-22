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

/// 数据刷新频率
enum RefreshInterval: Int, CaseIterable, Codable {
    /// 30秒刷新一次
    case thirtySeconds = 30
    /// 1分钟刷新一次
    case oneMinute = 60
    /// 5分钟刷新一次
    case fiveMinutes = 300
    
    var localizedName: String {
        switch self {
        case .thirtySeconds:
            return L.Refresh.thirtySeconds
        case .oneMinute:
            return L.Refresh.oneMinute
        case .fiveMinutes:
            return L.Refresh.fiveMinutes
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
    
    /// 数据刷新间隔（秒）
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
        
        let savedRefreshInterval = defaults.integer(forKey: "refreshInterval")
        self.refreshInterval = savedRefreshInterval > 0 ? savedRefreshInterval : 60 // 默认1分钟
        
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
    
    // MARK: - Public Methods
    
    /// 重置为默认设置
    /// 只重置非敏感设置，不影响认证信息
    func resetToDefaults() {
        iconDisplayMode = .percentageOnly
        refreshInterval = 60
        language = .chinese
    }
    
    /// 清除所有认证信息
    /// 从 Keychain 中删除 Organization ID 和 Session Key
    func clearCredentials() {
        keychain.deleteCredentials()
        organizationId = ""
        sessionKey = ""
        print("🗑️ 已清除所有认证信息")
    }
}

// MARK: - Notification Names

/// 设置相关通知名称扩展
extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
    static let languageChanged = Notification.Name("languageChanged")
}
