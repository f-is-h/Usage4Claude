//
//  LocalizationHelper.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 本地化字符串访问器
/// 提供类型安全的本地化字符串访问方式
/// 支持动态语言切换，根据用户设置返回对应语言的字符串
enum L {
    
    // MARK: - Menu Items
    enum Menu {
        static let generalSettings = localized("menu.general_settings")
        static let authSettings = localized("menu.auth_settings")
        static let checkUpdates = localized("menu.check_updates")
        static let about = localized("menu.about")
        static let webUsage = localized("menu.web_usage")
        static let coffee = localized("menu.coffee")
        static let quit = localized("menu.quit")
    }
    
    // MARK: - Usage Detail View
    enum Usage {
        static let title = localized("usage.title")
        static let notStarted = localized("usage.not_started")
        static let resetIn = localized("usage.reset_in")
        static let remaining = localized("usage.remaining")
        static let loading = localized("usage.loading")
        static let notConfigured = localized("usage.not_configured")
        static let goToSettings = localized("usage.go_to_settings")
        static let resetTime = localized("usage.reset_time")
        static let used = localized("usage.used")
        static let fiveHourLimit = localized("usage.five_hour_limit")
    }
    
    // MARK: - Settings Tabs
    enum SettingsTab {
        static let general = localized("settings.tab.general")
        static let auth = localized("settings.tab.auth")
        static let about = localized("settings.tab.about")
    }
    
    // MARK: - Settings General
    enum SettingsGeneral {
        static let displaySection = localized("settings.general.display_section")
        static let menubarIcon = localized("settings.general.menubar_icon")
        static let menubarHint = localized("settings.general.menubar_hint")
        static let refreshSection = localized("settings.general.refresh_section")
        static let refreshInterval = localized("settings.general.refresh_interval")
        static let refreshHint = localized("settings.general.refresh_hint")
        static let languageSection = localized("settings.general.language_section")
        static let interfaceLanguage = localized("settings.general.interface_language")
        static let languageHint = localized("settings.general.language_hint")
        static let resetButton = localized("settings.general.reset_button")
    }
    
    // MARK: - Settings Authentication
    enum SettingsAuth {
        static let howToTitle = localized("settings.auth.how_to_title")
        static let step1 = localized("settings.auth.step1")
        static let step2 = localized("settings.auth.step2")
        static let step3 = localized("settings.auth.step3")
        static let step4 = localized("settings.auth.step4")
        static let step5 = localized("settings.auth.step5")
        static let step6 = localized("settings.auth.step6")
        static let step7 = localized("settings.auth.step7")
        static let openBrowser = localized("settings.auth.open_browser")
        static let orgIdLabel = localized("settings.auth.org_id_label")
        static let orgIdPlaceholder = localized("settings.auth.org_id_placeholder")
        static let orgIdHint = localized("settings.auth.org_id_hint")
        static let sessionKeyLabel = localized("settings.auth.session_key_label")
        static let sessionKeyPlaceholder = localized("settings.auth.session_key_placeholder")
        static let sessionKeyHint = localized("settings.auth.session_key_hint")
        static let configured = localized("settings.auth.configured")
        static let notConfigured = localized("settings.auth.not_configured")
    }
    
    // MARK: - Settings About
    enum SettingsAbout {
        static func version(_ version: String) -> String {
            String(format: localized("settings.about.version"), version)
        }
        static let description = localized("settings.about.description")
        static let developer = localized("settings.about.developer")
        static let license = localized("settings.about.license")
        static let licenseValue = localized("settings.about.license_value")
        static let github = localized("settings.about.github")
        static let coffee = localized("settings.about.coffee")
        static let copyright = localized("settings.about.copyright")
    }
    
    // MARK: - Welcome View
    enum Welcome {
        static let title = localized("welcome.title")
        static let subtitle = localized("welcome.subtitle")
        static let setupButton = localized("welcome.setup_button")
        static let laterButton = localized("welcome.later_button")
    }
    
    // MARK: - Update Checker
    enum Update {
        static let newVersionTitle = localized("update.new_version_title")
        static let latestVersion = localized("update.latest_version")
        static let currentVersion = localized("update.current_version")
        static let viewDetailsHint = localized("update.view_details_hint")
        static let viewReleasePage = localized("update.view_release_page")
        static let downloadButton = localized("update.download_button")
        static let remindLaterButton = localized("update.remind_later_button")
        static let viewDetailsButton = localized("update.view_details_button")
        static let upToDateTitle = localized("update.up_to_date_title")
        static func upToDateMessage(_ version: String) -> String {
            String(format: localized("update.up_to_date_message"), version)
        }
        static let okButton = localized("update.ok_button")
        static let checkFailedTitle = localized("update.check_failed_title")
        static let confirmButton = localized("update.confirm_button")
        
        enum Error {
            static let invalidUrl = localized("update.error.invalid_url")
            static let network = localized("update.error.network")
            static let noData = localized("update.error.no_data")
            static let parseFailed = localized("update.error.parse_failed")
        }
    }
    
    // MARK: - Icon Display Mode
    enum Display {
        static let percentageOnly = localized("display.percentage_only")
        static let iconOnly = localized("display.icon_only")
        static let both = localized("display.both")
    }
    
    // MARK: - Refresh Interval
    enum Refresh {
        static let thirtySeconds = localized("refresh.30_seconds")
        static let oneMinute = localized("refresh.1_minute")
        static let fiveMinutes = localized("refresh.5_minutes")
    }
    
    // MARK: - Language Names
    enum Language {
        static let english = localized("language.english")
        static let japanese = localized("language.japanese")
        static let chinese = localized("language.chinese")
        static let chineseTraditional = localized("language.chinese_traditional")
    }
    
    // MARK: - Window Titles
    enum Window {
        static let settingsTitle = localized("window.settings_title")
        static let welcomeTitle = localized("window.welcome_title")
    }
    
    // MARK: - Usage Data Formatting
    enum UsageData {
        static let notStartedReset = localized("usage_data.not_started_reset")
        static let resettingSoon = localized("usage_data.resetting_soon")
        static func resetsInHours(_ hours: Int, _ minutes: Int) -> String {
            String(format: localized("usage_data.resets_in_hours"), hours, minutes)
        }
        static func resetsInMinutes(_ minutes: Int) -> String {
            String(format: localized("usage_data.resets_in_minutes"), minutes)
        }
        static let unknown = localized("usage_data.unknown")
        static let today = localized("usage_data.today")
        static let tomorrow = localized("usage_data.tomorrow")
    }
    
    // MARK: - Error Messages
    enum Error {
        static let invalidUrl = localized("error.invalid_url")
        static let noData = localized("error.no_data")
        static let sessionExpired = localized("error.session_expired")
        static let cloudflareBlocked = localized("error.cloudflare_blocked")
        static let noCredentials = localized("error.no_credentials")
    }
    
    // MARK: - Helper Methods
    
    /// 本地化字符串辅助方法
    /// 根据用户设置的语言返回对应的本地化字符串
    /// - Parameter key: 本地化字符串的键名
    /// - Returns: 对应语言的本地化字符串
    private static func localized(_ key: String) -> String {
        // 从UserSettings获取用户选择的语言
        let language = UserSettings.shared.language.rawValue
        
        // 获取对应语言的bundle
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // 如果找不到对应语言，使用系统默认
            return NSLocalizedString(key, comment: "")
        }
        
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
