//
//  UsageData+Formatting.swift
//  Usage4Claude
//
//  Locale-aware display formatting for `UsageData` / `ExtraUsageData`. Lives
//  outside `ClaudeAPIResponseModels.swift` because it depends on `L.*` and
//  `UserSettings.shared` — both main-app-only — and the response-models file
//  is shared with a SwiftPM test target.
//

import Foundation

// MARK: - UsageData.LimitData formatting

extension UsageData.LimitData {
    /// 格式化的剩余时间字符串（用于5小时限制，显示X小时Y分）
    /// - Returns: 本地化的剩余时间描述（如 "2小时30分"）
    var formattedResetsInHours: String {
        guard let resetsAt = resetsAt else {
            return L.UsageData.notStartedReset
        }

        let resetsIn = resetsAt.timeIntervalSinceNow

        guard resetsIn > 0 else {
            return L.UsageData.resettingSoon
        }

        // 向上取整到分钟（使用 ceil 函数）
        let totalMinutes = Int(ceil(resetsIn / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return L.UsageData.resetsInHours(hours, minutes)
        } else {
            return L.UsageData.resetsInMinutes(minutes)
        }
    }

    /// 格式化的剩余时间字符串（用于7天限制，显示X天Y小时）
    /// - Returns: 本地化的剩余时间描述（如 "剩余约3天12小时"）
    var formattedResetsInDays: String {
        guard let resetsAt = resetsAt else {
            return L.UsageData.notStartedReset
        }

        let resetsIn = resetsAt.timeIntervalSinceNow

        guard resetsIn > 0 else {
            return L.UsageData.resettingSoon
        }

        // 向上取整到小时
        let totalHours = Int(ceil(resetsIn / 3600))
        let days = totalHours / 24
        let hours = totalHours % 24

        if days > 0 {
            return L.UsageData.resetsInDays(days, hours)
        } else {
            // 不足1天时，显示"约X小时"
            return L.UsageData.resetsInHours(hours, 0)
        }
    }

    /// 格式化的重置时间字符串（短格式，用于5小时限制）
    /// - Returns: 本地化的重置时间描述（如 "今天 14:30" 或 "明天 09:00"）
    var formattedResetTimeShort: String {
        guard let resetsAt = resetsAt else {
            return L.UsageData.unknown
        }

        var calendar = Calendar.current
        calendar.locale = UserSettings.shared.appLocale
        let timeString = TimeFormatHelper.formatTimeOnly(resetsAt)

        if calendar.isDateInToday(resetsAt) {
            return "\(L.UsageData.today) \(timeString)"
        } else if calendar.isDateInTomorrow(resetsAt) {
            return "\(L.UsageData.tomorrow) \(timeString)"
        } else {
            return TimeFormatHelper.formatDateTime(resetsAt, dateTemplate: "Md")
        }
    }

    /// 格式化的重置时间字符串（长格式，用于7天限制）
    /// - Returns: 本地化的重置日期描述（如 "11月29日 14时" 或 "Nov 29 2 PM"）
    var formattedResetDateLong: String {
        guard let resetsAt = resetsAt else {
            return L.UsageData.unknown
        }

        return TimeFormatHelper.formatDateHour(resetsAt, dateTemplate: "MMMd")
    }

    // MARK: - 极简格式化方法（用于双模式两行显示）

    /// 极简格式化的剩余时间（省略零值单位）
    /// - 示例: "45m", "1h30m", "3d12h"
    var formattedCompactRemaining: String {
        guard let resetsAt = resetsAt else {
            return "-"
        }

        let resetsIn = resetsAt.timeIntervalSinceNow
        guard resetsIn > 0 else {
            return L.UsageData.compactResettingSoon
        }

        let totalMinutes = Int(ceil(resetsIn / 60))

        // 如果不足1小时，只显示分钟
        if totalMinutes < 60 {
            return L.UsageData.compactRemainingMinutes(totalMinutes)
        }

        let totalHours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60

        // 如果不足1天，显示小时+分钟
        if totalHours < 24 {
            return L.UsageData.compactRemainingHours(totalHours, remainingMinutes)
        }

        // 超过1天，显示天+小时
        let days = totalHours / 24
        let hours = totalHours % 24

        return L.UsageData.compactRemainingDays(days, hours)
    }

    /// 菜单栏倒计时文本（紧凑、无后缀、语言无关）
    /// - 用于菜单栏常驻显示距离重置的剩余时间
    /// - 示例: "45m", "1h32m", "2d7h"；无重置时间或已重置时返回 nil
    var menuBarCountdown: String? {
        guard let resetsAt = resetsAt else { return nil }

        let resetsIn = resetsAt.timeIntervalSinceNow
        guard resetsIn > 0 else { return nil }

        // 向上取整到分钟，与其它倒计时格式保持一致
        let totalMinutes = Int(ceil(resetsIn / 60))

        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }

        let totalHours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if totalHours < 24 {
            return "\(totalHours)h\(minutes)m"
        }

        let days = totalHours / 24
        let hours = totalHours % 24

        return "\(days)d\(hours)h"
    }

    /// 格式化的重置时间（用于5小时限制）
    /// - 示例: "Today 15:07" / "Today 3:07 PM", "Tomorrow 09:30" / "Tomorrow 9:30 AM"
    var formattedCompactResetTime: String {
        guard let resetsAt = resetsAt else {
            return "-"
        }

        let calendar = Calendar.current

        // 判断是今天还是明天
        let prefix: String
        if calendar.isDateInToday(resetsAt) {
            prefix = L.UsageData.today
        } else if calendar.isDateInTomorrow(resetsAt) {
            prefix = L.UsageData.tomorrow
        } else {
            // 其他日期显示月日
            let formatter = DateFormatter()
            formatter.locale = UserSettings.shared.appLocale
            formatter.timeZone = TimeZone.current
            // 根据语言使用不同的日期格式
            let langCode = UserSettings.shared.appLocale.identifier
            if langCode.hasPrefix("zh") || langCode.hasPrefix("ja") {
                formatter.dateFormat = "M月d日"  // 中文/日语：12月25日
            } else if langCode.hasPrefix("ko") {
                formatter.dateFormat = "M월d일"  // 韩语：12월25일
            } else {
                formatter.dateFormat = "MMM d"   // 英文：Dec 25
            }
            prefix = formatter.string(from: resetsAt)
        }

        let timeString = TimeFormatHelper.formatTimeOnly(resetsAt)

        return "\(prefix) \(timeString)"
    }

    /// 格式化的重置日期（用于7天限制，精确到小时）
    /// - 示例: "Dec 16 15:00" / "Dec 16 3 PM" (英文), "12月16日 15时" (中文)
    var formattedCompactResetDate: String {
        guard let resetsAt = resetsAt else {
            return "-"
        }

        return TimeFormatHelper.formatDateHour(resetsAt, dateTemplate: "MMMd")
    }

    /// 格式化的重置日期（精确到分钟，仅用于 Codex secondary_window）
    /// - 示例: "Dec 16 15:42" / "Dec 16 3:42 PM", "12月16日 15:42"
    var formattedCompactResetDateWithMinutes: String {
        guard let resetsAt = resetsAt else {
            return "-"
        }

        return TimeFormatHelper.formatDateMinute(resetsAt, dateTemplate: "MMMd")
    }

    /// 极简格式化的剩余时间（精确到分钟，仅用于 Codex secondary_window）
    /// - 示例: "45m", "1h30m", "3d12h35m"
    var formattedCompactRemainingWithMinutes: String {
        guard let resetsAt = resetsAt else {
            return "-"
        }

        let resetsIn = resetsAt.timeIntervalSinceNow
        guard resetsIn > 0 else {
            return L.UsageData.compactResettingSoon
        }

        let totalMinutes = Int(ceil(resetsIn / 60))

        if totalMinutes < 60 {
            return L.UsageData.compactRemainingMinutes(totalMinutes)
        }

        let totalHours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60

        if totalHours < 24 {
            return L.UsageData.compactRemainingHours(totalHours, remainingMinutes)
        }

        let days = totalHours / 24
        let hours = totalHours % 24

        return L.UsageData.compactRemainingDaysWithMinutes(days, hours, remainingMinutes)
    }
}

// MARK: - UsageData formatting (backward-compat shims)

extension UsageData {
    /// 格式化的剩余时间字符串
    /// - Note: 向后兼容属性
    var formattedResetsIn: String {
        return primaryLimit?.formattedResetsInHours ?? L.UsageData.notStartedReset
    }

    /// 格式化的重置时间字符串
    /// - Note: 向后兼容属性
    var formattedResetTime: String {
        return primaryLimit?.formattedResetTimeShort ?? L.UsageData.unknown
    }

    /// 根据使用百分比返回对应的状态颜色
    /// - Note: 向后兼容属性
    var statusColor: String {
        let percentage = self.percentage
        if percentage < 50 {
            return "green"
        } else if percentage < 70 {
            return "yellow"
        } else if percentage < 90 {
            return "orange"
        } else {
            return "red"
        }
    }
}

// MARK: - ExtraUsageData formatting

extension ExtraUsageData {
    /// 格式化的使用金额/总额度字符串（默认模式）
    /// - Returns: 如 "$12.50 / $50.00"
    var formattedUsageAmount: String {
        guard enabled, let used = used, let limit = limit else {
            return L.ExtraUsage.notEnabled
        }
        return L.ExtraUsage.usageAmount(used, limit, symbol: currencySymbol)
    }

    /// 格式化的剩余金额字符串（剩余模式）
    /// - Returns: 如 "还可使用 $37"
    var formattedRemainingAmount: String {
        guard enabled, let used = used, let limit = limit else {
            return L.ExtraUsage.notEnabled
        }
        let remaining = max(0, limit - used)
        return L.ExtraUsage.remainingAmount(remaining, symbol: currencySymbol)
    }

    /// 极简格式化的使用金额（用于列表显示）
    /// - Returns: 如 "$10.47/$25"
    var formattedCompactAmount: String {
        guard enabled, let used = used, let limit = limit else {
            return "-"
        }
        let sym = currencySymbol
        return String(format: "%@%.2f/%@%.0f", sym, used, sym, limit)
    }
}
