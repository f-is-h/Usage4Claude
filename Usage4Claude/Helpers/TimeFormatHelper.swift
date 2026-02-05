//
//  TimeFormatHelper.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-02-05.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 统一时间格式化帮助器
/// 根据用户的时间格式偏好提供一致的时间格式化方法
enum TimeFormatHelper {

    // MARK: - Format Strings

    /// 获取时间格式字符串（小时:分钟）
    /// - Returns: "HH:mm" 或 "h:mm a" 格式字符串
    static var timeOnlyFormat: String {
        return uses24HourFormat ? "HH:mm" : "h:mm a"
    }

    /// 获取小时格式字符串（仅小时）
    /// - Returns: "HH" 或 "h a" 格式字符串
    static var hourOnlyFormat: String {
        return uses24HourFormat ? "HH" : "h a"
    }

    /// 获取日期+时间模板
    /// - Parameter dateTemplate: 日期部分的模板（如 "MMMd"）
    /// - Returns: 完整的日期时间模板
    static func dateTimeTemplate(dateTemplate: String) -> String {
        if uses24HourFormat {
            return "\(dateTemplate) HH:mm"
        } else {
            return "\(dateTemplate) h:mm a"
        }
    }

    /// 获取日期+小时模板
    /// - Parameter dateTemplate: 日期部分的模板（如 "MMMd"）
    /// - Returns: 完整的日期+小时模板
    static func dateHourTemplate(dateTemplate: String) -> String {
        if uses24HourFormat {
            return "\(dateTemplate) HH"
        } else {
            return "\(dateTemplate) h a"
        }
    }

    // MARK: - Formatting Methods

    /// 格式化时间（小时:分钟）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的时间字符串
    static func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = UserSettings.shared.appLocale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = timeOnlyFormat
        return formatter.string(from: date)
    }

    /// 格式化小时
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的小时字符串
    static func formatHourOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = UserSettings.shared.appLocale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = hourOnlyFormat
        return formatter.string(from: date)
    }

    /// 格式化日期和时间
    /// - Parameters:
    ///   - date: 要格式化的日期
    ///   - dateTemplate: 日期部分的模板
    /// - Returns: 格式化后的日期时间字符串
    static func formatDateTime(_ date: Date, dateTemplate: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = UserSettings.shared.appLocale
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate(dateTimeTemplate(dateTemplate: dateTemplate))
        return formatter.string(from: date)
    }

    /// 格式化日期和小时
    /// - Parameters:
    ///   - date: 要格式化的日期
    ///   - dateTemplate: 日期部分的模板
    /// - Returns: 格式化后的日期+小时字符串
    static func formatDateHour(_ date: Date, dateTemplate: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = UserSettings.shared.appLocale
        formatter.timeZone = TimeZone.current

        // 根据语言和时间格式构建格式字符串
        let langCode = UserSettings.shared.appLocale.identifier
        let dateString: String
        let timeString: String

        // 日期格式
        let dateFormatter = DateFormatter()
        dateFormatter.locale = UserSettings.shared.appLocale
        dateFormatter.timeZone = TimeZone.current
        if langCode.hasPrefix("zh") || langCode.hasPrefix("ja") {
            dateFormatter.dateFormat = "M月d日"
        } else if langCode.hasPrefix("ko") {
            dateFormatter.dateFormat = "M월d일"
        } else {
            dateFormatter.dateFormat = "MMM d"
        }
        dateString = dateFormatter.string(from: date)

        // 时间格式（仅小时）
        let timeFormatter = DateFormatter()
        timeFormatter.locale = UserSettings.shared.appLocale
        timeFormatter.timeZone = TimeZone.current
        if uses24HourFormat {
            // 24小时制：显示"15时"或"15"
            if langCode.hasPrefix("zh") || langCode.hasPrefix("ja") {
                timeFormatter.dateFormat = "H时"
            } else if langCode.hasPrefix("ko") {
                timeFormatter.dateFormat = "H시"
            } else {
                timeFormatter.dateFormat = "HH':00'"
            }
        } else {
            // 12小时制：使用本地化模板
            timeFormatter.setLocalizedDateFormatFromTemplate("j")
        }
        timeString = timeFormatter.string(from: date)

        return "\(dateString) \(timeString)"
    }

    // MARK: - Detection

    /// 检测当前是否应该使用 24 小时格式
    /// - Returns: true 表示使用 24 小时制，false 表示使用 12 小时制
    static var uses24HourFormat: Bool {
        let preference = UserSettings.shared.timeFormatPreference

        switch preference {
        case .system:
            return detectSystem24HourFormat()
        case .twelveHour:
            return false
        case .twentyFourHour:
            return true
        }
    }

    /// 检测系统是否使用 24 小时制
    /// - Returns: true 表示系统使用 24 小时制
    static func detectSystem24HourFormat() -> Bool {
        let formatter = DateFormatter()
        formatter.locale = UserSettings.shared.appLocale
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let timeString = formatter.string(from: Date())

        // 如果包含 AM/PM 标记，则是 12 小时制
        // 检查常见的 AM/PM 变体
        let ampmIndicators = ["AM", "PM", "am", "pm", "上午", "下午", "午前", "午後", "오전", "오후"]
        for indicator in ampmIndicators {
            if timeString.contains(indicator) {
                return false
            }
        }

        return true
    }
}
