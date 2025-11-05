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
        static var generalSettings: String { localized("menu.general_settings") }
        static var authSettings: String { localized("menu.auth_settings") }
        static var checkUpdates: String { localized("menu.check_updates") }
        static var about: String { localized("menu.about") }
        static var webUsage: String { localized("menu.web_usage") }
        static var coffee: String { localized("menu.coffee") }
        static var quit: String { localized("menu.quit") }
    }
    
    // MARK: - Usage Detail View
    enum Usage {
        static var title: String { localized("usage.title") }
        static var notStarted: String { localized("usage.not_started") }
        static var resetIn: String { localized("usage.reset_in") }
        static var remaining: String { localized("usage.remaining") }
        static var loading: String { localized("usage.loading") }
        static var notConfigured: String { localized("usage.not_configured") }
        static var goToSettings: String { localized("usage.go_to_settings") }
        static var resetTime: String { localized("usage.reset_time") }
        static var used: String { localized("usage.used") }
        static var fiveHourLimit: String { localized("usage.five_hour_limit") }
    }
    
    // MARK: - Settings Tabs
    enum SettingsTab {
        static var general: String { localized("settings.tab.general") }
        static var auth: String { localized("settings.tab.auth") }
        static var about: String { localized("settings.tab.about") }
    }
    
    // MARK: - Settings General
    enum SettingsGeneral {
        static var displaySection: String { localized("settings.general.display_section") }
        static var menubarIcon: String { localized("settings.general.menubar_icon") }
        static var menubarHint: String { localized("settings.general.menubar_hint") }
        static var refreshSection: String { localized("settings.general.refresh_section") }
        static var refreshMode: String { localized("settings.general.refresh_mode") }
        static var refreshInterval: String { localized("settings.general.refresh_interval") }
        static var refreshHintSmart: String { localized("settings.general.refresh_hint_smart") }
        static var refreshHintFixed: String { localized("settings.general.refresh_hint_fixed") }
        static var languageSection: String { localized("settings.general.language_section") }
        static var interfaceLanguage: String { localized("settings.general.interface_language") }
        static var languageHint: String { localized("settings.general.language_hint") }
        static var resetButton: String { localized("settings.general.reset_button") }
    }
    
    // MARK: - Settings Authentication
    enum SettingsAuth {
        static var howToTitle: String { localized("settings.auth.how_to_title") }
        static var step1: String { localized("settings.auth.step1") }
        static var step2: String { localized("settings.auth.step2") }
        static var step3: String { localized("settings.auth.step3") }
        static var step4: String { localized("settings.auth.step4") }
        static var step5: String { localized("settings.auth.step5") }
        static var step6: String { localized("settings.auth.step6") }
        static var step7: String { localized("settings.auth.step7") }
        static var openBrowser: String { localized("settings.auth.open_browser") }
        static var orgIdLabel: String { localized("settings.auth.org_id_label") }
        static var orgIdPlaceholder: String { localized("settings.auth.org_id_placeholder") }
        static var orgIdHint: String { localized("settings.auth.org_id_hint") }
        static var sessionKeyLabel: String { localized("settings.auth.session_key_label") }
        static var sessionKeyPlaceholder: String { localized("settings.auth.session_key_placeholder") }
        static var sessionKeyHint: String { localized("settings.auth.session_key_hint") }
        static var configured: String { localized("settings.auth.configured") }
        static var notConfigured: String { localized("settings.auth.not_configured") }
        static var credentialsTitle: String { localized("settings.auth.credentials_title") }
        static var readyToUse: String { localized("settings.auth.ready_to_use") }
        static var needCredentials: String { localized("settings.auth.need_credentials") }
        static var showPassword: String { localized("settings.auth.show_password") }
        static var hidePassword: String { localized("settings.auth.hide_password") }
    }
    
    // MARK: - Settings About
    enum SettingsAbout {
        static func version(_ version: String) -> String {
            String(format: localized("settings.about.version"), version)
        }
        static var description: String { localized("settings.about.description") }
        static var developer: String { localized("settings.about.developer") }
        static var license: String { localized("settings.about.license") }
        static var licenseValue: String { localized("settings.about.license_value") }
        static var github: String { localized("settings.about.github") }
        static var coffee: String { localized("settings.about.coffee") }
        static var copyright: String { localized("settings.about.copyright") }
    }
    
    // MARK: - Welcome View
    enum Welcome {
        static var title: String { localized("welcome.title") }
        static var subtitle: String { localized("welcome.subtitle") }
        static var setupButton: String { localized("welcome.setup_button") }
        static var laterButton: String { localized("welcome.later_button") }
    }
    
    // MARK: - Update Checker
    enum Update {
        static var newVersionTitle: String { localized("update.new_version_title") }
        static var latestVersion: String { localized("update.latest_version") }
        static var currentVersion: String { localized("update.current_version") }
        static var viewDetailsHint: String { localized("update.view_details_hint") }
        static var viewReleasePage: String { localized("update.view_release_page") }
        static var downloadButton: String { localized("update.download_button") }
        static var remindLaterButton: String { localized("update.remind_later_button") }
        static var viewDetailsButton: String { localized("update.view_details_button") }
        static var upToDateTitle: String { localized("update.up_to_date_title") }
        static func upToDateMessage(_ version: String) -> String {
            String(format: localized("update.up_to_date_message"), version)
        }
        static var okButton: String { localized("update.ok_button") }
        static var checkFailedTitle: String { localized("update.check_failed_title") }
        static var confirmButton: String { localized("update.confirm_button") }
        
        enum Error {
            static var invalidUrl: String { localized("update.error.invalid_url") }
            static var network: String { localized("update.error.network") }
            static var noData: String { localized("update.error.no_data") }
            static var parseFailed: String { localized("update.error.parse_failed") }
        }
    }
    
    // MARK: - Icon Display Mode
    enum Display {
        static var percentageOnly: String { localized("display.percentage_only") }
        static var iconOnly: String { localized("display.icon_only") }
        static var both: String { localized("display.both") }
    }
    
    // MARK: - Refresh Interval
    enum Refresh {
        static var smartMode: String { localized("refresh.smart_mode") }
        static var fixedMode: String { localized("refresh.fixed_mode") }
        static var oneMinute: String { localized("refresh.1_minute") }
        static var threeMinutes: String { localized("refresh.3_minutes") }
        static var fiveMinutes: String { localized("refresh.5_minutes") }
        static var tenMinutes: String { localized("refresh.10_minutes") }
    }
    
    // MARK: - Language Names
    enum Language {
        static var english: String { localized("language.english") }
        static var japanese: String { localized("language.japanese") }
        static var chinese: String { localized("language.chinese") }
        static var chineseTraditional: String { localized("language.chinese_traditional") }
    }
    
    // MARK: - Window Titles
    enum Window {
        static var settingsTitle: String { localized("window.settings_title") }
        static var welcomeTitle: String { localized("window.welcome_title") }
    }
    
    // MARK: - Usage Data Formatting
    enum UsageData {
        static var notStartedReset: String { localized("usage_data.not_started_reset") }
        static var resettingSoon: String { localized("usage_data.resetting_soon") }
        static func resetsInHours(_ hours: Int, _ minutes: Int) -> String {
            String(format: localized("usage_data.resets_in_hours"), hours, minutes)
        }
        static func resetsInMinutes(_ minutes: Int) -> String {
            String(format: localized("usage_data.resets_in_minutes"), minutes)
        }
        static var unknown: String { localized("usage_data.unknown") }
        static var today: String { localized("usage_data.today") }
        static var tomorrow: String { localized("usage_data.tomorrow") }
    }
    
    // MARK: - Error Messages
    enum Error {
        static var invalidUrl: String { localized("error.invalid_url") }
        static var noData: String { localized("error.no_data") }
        static var sessionExpired: String { localized("error.session_expired") }
        static var cloudflareBlocked: String { localized("error.cloudflare_blocked") }
        static var noCredentials: String { localized("error.no_credentials") }
        static var networkFailed: String { localized("error.network_failed") }
        static var decodingFailed: String { localized("error.decoding_failed") }
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
