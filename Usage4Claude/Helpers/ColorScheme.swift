//
//  ColorScheme.swift
//  Usage4Claude
//
//  Created by Claude on 2025-11-26.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import AppKit
import OSLog

/// 统一配色方案管理
/// 提供5小时和7天限制的颜色配置，支持 AppKit 和 SwiftUI
enum UsageColorScheme {

    // MARK: - 外观检测

    /// 检测当前是否为深色模式
    /// - Parameter statusButton: 可选的状态栏按钮，用于获取外观信息
    /// - Returns: true 表示深色模式，false 表示浅色模式
    static func isDarkMode(for statusButton: NSStatusBarButton? = nil) -> Bool {
        // 方法1: 使用状态栏按钮的外观（最准确，反映系统菜单栏的真实外观）
        if let button = statusButton,
           let appearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return appearance == .darkAqua
        }

        // 方法2: 直接读取系统外观设置（不受 NSApp.appearance 影响）
        // 当用户设置了应用外观偏好时，NSApp.effectiveAppearance 会反映应用设置而非系统设置
        // 菜单栏图标渲染需要始终跟随系统外观，所以这里检测系统真实状态
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    /// 检测当前是否为深色模式（便捷属性）
    static var isDarkMode: Bool {
        return isDarkMode(for: nil)
    }

    // MARK: - 5小时限制配色（绿→橙→红）

    /// 根据5小时限制使用百分比返回 NSColor
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 0-70% 绿色(安全), 70-90% 橙色(警告), 90-100% 红色(危险)
    static func fiveHourColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 40/255.0, green: 180/255.0, blue: 70/255.0, alpha: 1.0)  // 稍暗的绿色 #28B446
        } else if percentage < 90 {
            return NSColor.systemOrange
        } else {
            return NSColor.systemRed
        }
    }

    /// 根据5小时限制使用百分比返回 SwiftUI Color
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 0-70% 绿色(安全), 70-90% 橙色(警告), 90-100% 红色(危险)
    ///         详细界面使用时会添加透明度，使颜色更柔和
    static func fiveHourColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return .green.opacity(opacity)  // 系统绿色
        } else if percentage < 90 {
            return .orange.opacity(opacity)
        } else {
            return .red.opacity(opacity)
        }
    }

    /// 根据5小时限制使用百分比返回自适应 NSColor（根据系统外观调整亮度）
    /// - Parameters:
    ///   - percentage: 使用百分比 (0-100)
    ///   - statusButton: 状态栏按钮，用于获取准确的外观
    /// - Returns: 适配当前外观的状态颜色
    /// - Note: 深色模式下会自动提高亮度，确保在深色背景下清晰可见
    static func fiveHourColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = fiveHourColor(percentage)

        if isDarkMode(for: statusButton) {
            // 深色模式：提高亮度，让颜色更明亮
            return baseColor.adjustedForDarkMode()
        } else {
            // 浅色模式：使用原色或稍微加深
            return baseColor
        }
    }

    // MARK: - 7天限制配色

    /// 根据7天限制使用百分比返回 NSColor
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 当前方案 - 淡紫→浓紫→深紫红
    ///         0-70% 淡紫色(安全), 70-90% 浓紫色(警告), 90-100% 深紫红色(危险)
    static func sevenDayColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 192/255.0, green: 132/255.0, blue: 252/255.0, alpha: 1.0)  // 淡紫色 #C084FC
        } else if percentage < 90 {
            return NSColor(red: 180/255.0, green: 80/255.0, blue: 240/255.0, alpha: 1.0)  // 浓紫色 #B450F0
        } else {
            return NSColor(red: 180/255.0, green: 30/255.0, blue: 160/255.0, alpha: 1.0)   // 深紫红色 #B41EA0（浓郁警示）
        }
    }

    /// 根据7天限制使用百分比返回 SwiftUI Color
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 当前方案 - 淡紫→浓紫→深紫红
    ///         0-70% 淡紫色(安全), 70-90% 浓紫色(警告), 90-100% 深紫红色(危险)
    ///         详细界面使用时会添加透明度，使颜色更柔和
    static func sevenDayColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return Color(red: 192/255.0, green: 132/255.0, blue: 252/255.0).opacity(opacity)  // 淡紫色 #C084FC
        } else if percentage < 90 {
            return Color(red: 180/255.0, green: 80/255.0, blue: 240/255.0).opacity(opacity)  // 浓紫色 #B450F0
        } else {
            return Color(red: 180/255.0, green: 30/255.0, blue: 160/255.0).opacity(opacity)   // 深紫红色 #B41EA0（浓郁警示）
        }
    }

    /// 根据7天限制使用百分比返回自适应 NSColor（根据系统外观调整亮度）
    /// - Parameters:
    ///   - percentage: 使用百分比 (0-100)
    ///   - statusButton: 状态栏按钮，用于获取准确的外观
    /// - Returns: 适配当前外观的状态颜色
    /// - Note: 深色模式下会自动提高亮度和饱和度，确保在深色背景下清晰可见
    static func sevenDayColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = sevenDayColor(percentage)

        if isDarkMode(for: statusButton) {
            // 深色模式：提高亮度和饱和度
            return baseColor.adjustedForDarkMode()
        } else {
            // 浅色模式：使用原色
            return baseColor
        }
    }

    // MARK: - Extra Usage 配色（粉→红→紫红）

    /// 根据Extra Usage使用百分比返回 NSColor
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 0-70% 粉色(安全), 70-90% 玫红色(警告), 90-100% 紫红色(危险)
    static func extraUsageColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 255/255.0, green: 158/255.0, blue: 205/255.0, alpha: 1.0)  // 粉色 #FF9ECD
        } else if percentage < 90 {
            return NSColor(red: 236/255.0, green: 72/255.0, blue: 153/255.0, alpha: 1.0)   // 玫红色 #EC4899
        } else {
            return NSColor(red: 217/255.0, green: 70/255.0, blue: 239/255.0, alpha: 1.0)   // 紫红色 #D946EF
        }
    }

    /// 根据Extra Usage使用百分比返回自适应 NSColor
    static func extraUsageColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = extraUsageColor(percentage)
        if isDarkMode(for: statusButton) {
            return baseColor.adjustedForDarkMode()
        } else {
            return baseColor
        }
    }

    // MARK: - Opus Weekly 配色（浅橙→橙→橙红）

    /// 根据Opus Weekly使用百分比返回 NSColor
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 0-70% 琥珀色(安全), 70-90% 橙色(警告), 90-100% 橙红色(危险)
    static func opusWeeklyColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 251/255.0, green: 191/255.0, blue: 36/255.0, alpha: 1.0)  // 琥珀色 #FBBF24
        } else if percentage < 90 {
            return NSColor.systemOrange
        } else {
            return NSColor(red: 255/255.0, green: 100/255.0, blue: 50/255.0, alpha: 1.0)   // 橙红色 #FF6432
        }
    }

    /// 根据Opus Weekly使用百分比返回自适应 NSColor
    static func opusWeeklyColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = opusWeeklyColor(percentage)
        if isDarkMode(for: statusButton) {
            return baseColor.adjustedForDarkMode()
        } else {
            return baseColor
        }
    }

    // MARK: - Sonnet Weekly 配色（浅蓝→蓝→蓝紫）

    /// 根据Sonnet Weekly使用百分比返回 NSColor
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 0-70% 浅蓝色(安全), 70-90% 蓝色(警告), 90-100% 深靛蓝色(危险)
    static func sonnetWeeklyColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 100/255.0, green: 200/255.0, blue: 255/255.0, alpha: 1.0)  // 浅蓝色 #64C8FF
        } else if percentage < 90 {
            return NSColor.systemBlue
        } else {
            return NSColor(red: 79/255.0, green: 70/255.0, blue: 229/255.0, alpha: 1.0)   // 深靛蓝色 #4F46E5
        }
    }

    /// 根据Sonnet Weekly使用百分比返回自适应 NSColor
    static func sonnetWeeklyColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = sonnetWeeklyColor(percentage)
        if isDarkMode(for: statusButton) {
            return baseColor.adjustedForDarkMode()
        } else {
            return baseColor
        }
    }

    // MARK: - Codex Primary 配色（亮松石 → 深松石 → 最深松石，圆形）

    /// 根据 Codex primary 使用百分比返回 NSColor
    /// - Note: 0-70% 亮松石(安全), 70-90% 深松石(警告), 90-100% 最深松石(危险)
    static func codexPrimaryColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 45/255.0, green: 212/255.0, blue: 191/255.0, alpha: 1.0)  // #2DD4BF 亮松石
        } else if percentage < 90 {
            return NSColor(red: 13/255.0, green: 148/255.0, blue: 136/255.0, alpha: 1.0)  // #0D9488 深松石
        } else {
            return NSColor(red: 19/255.0, green: 78/255.0, blue: 74/255.0, alpha: 1.0)    // #134E4A 最深松石
        }
    }

    /// 根据 Codex primary 使用百分比返回 SwiftUI Color
    static func codexPrimaryColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0).opacity(opacity)   // #2DD4BF
        } else if percentage < 90 {
            return Color(red: 13/255.0, green: 148/255.0, blue: 136/255.0).opacity(opacity)   // #0D9488
        } else {
            return Color(red: 19/255.0, green: 78/255.0, blue: 74/255.0).opacity(opacity)     // #134E4A
        }
    }

    /// 根据 Codex primary 使用百分比返回自适应 NSColor
    static func codexPrimaryColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = codexPrimaryColor(percentage)
        if isDarkMode(for: statusButton) {
            return baseColor.adjustedForDarkMode()
        } else {
            return baseColor
        }
    }

    // MARK: - Codex Secondary 配色（天空蓝 → 蓝 → 深蓝，虚线圆形）

    /// 根据 Codex secondary 使用百分比返回 NSColor
    /// - Note: 0-70% 天空蓝(安全), 70-90% 蓝色(警告), 90-100% 深蓝(危险)
    ///         与 primary 的松石色系区分，避免两个圆环过于接近
    static func codexSecondaryColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 96/255.0, green: 165/255.0, blue: 250/255.0, alpha: 1.0)   // #60A5FA 天空蓝
        } else if percentage < 90 {
            return NSColor(red: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0)    // #2563EB 蓝色
        } else {
            return NSColor(red: 30/255.0, green: 58/255.0, blue: 138/255.0, alpha: 1.0)    // #1E3A8A 深蓝
        }
    }

    /// 根据 Codex secondary 使用百分比返回 SwiftUI Color
    static func codexSecondaryColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return Color(red: 96/255.0, green: 165/255.0, blue: 250/255.0).opacity(opacity)  // #60A5FA
        } else if percentage < 90 {
            return Color(red: 37/255.0, green: 99/255.0, blue: 235/255.0).opacity(opacity)   // #2563EB
        } else {
            return Color(red: 30/255.0, green: 58/255.0, blue: 138/255.0).opacity(opacity)   // #1E3A8A
        }
    }

    /// 根据 Codex secondary 使用百分比返回自适应 NSColor
    static func codexSecondaryColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = codexSecondaryColor(percentage)
        if isDarkMode(for: statusButton) {
            return baseColor.adjustedForDarkMode()
        } else {
            return baseColor
        }
    }

    // MARK: - Codex Extra Usage 配色（金色 credits → 深金色 → 最深琥珀，六边形）

    /// 根据 Codex Extra Usage 使用百分比返回 NSColor
    /// - Note: Codex credits 的真实 API 只有余额/触顶状态；调试模式会使用百分比驱动视觉预览。
    static func codexExtraUsageColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 245/255.0, green: 158/255.0, blue: 11/255.0, alpha: 1.0)  // #F59E0B
        } else if percentage < 90 {
            return NSColor(red: 217/255.0, green: 119/255.0, blue: 6/255.0, alpha: 1.0)   // #D97706
        } else {
            return NSColor(red: 120/255.0, green: 53/255.0, blue: 15/255.0, alpha: 1.0)   // #78350F 最深琥珀
        }
    }

    /// 根据 Codex Extra Usage 使用百分比返回 SwiftUI Color
    static func codexExtraUsageColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0).opacity(opacity)
        } else if percentage < 90 {
            return Color(red: 217/255.0, green: 119/255.0, blue: 6/255.0).opacity(opacity)
        } else {
            return Color(red: 120/255.0, green: 53/255.0, blue: 15/255.0).opacity(opacity)
        }
    }

    /// 根据 Codex Extra Usage 使用百分比返回自适应 NSColor
    static func codexExtraUsageColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = codexExtraUsageColor(percentage)
        if isDarkMode(for: statusButton) {
            return baseColor.adjustedForDarkMode()
        } else {
            return baseColor
        }
    }

    // MARK: - Grok Weekly 配色（黑/灰 → 深灰，圆形）

    /// Grok brand-adjacent grays with warm warning ramp
    static func grokWeeklyColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 100/255.0, green: 116/255.0, blue: 139/255.0, alpha: 1.0)  // #64748B slate
        } else if percentage < 90 {
            return NSColor(red: 71/255.0, green: 85/255.0, blue: 105/255.0, alpha: 1.0)    // #475569
        } else {
            return NSColor(red: 30/255.0, green: 41/255.0, blue: 59/255.0, alpha: 1.0)     // #1E293B
        }
    }

    static func grokWeeklyColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return Color(red: 100/255.0, green: 116/255.0, blue: 139/255.0).opacity(opacity)
        } else if percentage < 90 {
            return Color(red: 71/255.0, green: 85/255.0, blue: 105/255.0).opacity(opacity)
        } else {
            return Color(red: 30/255.0, green: 41/255.0, blue: 59/255.0).opacity(opacity)
        }
    }

    static func grokWeeklyColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = grokWeeklyColor(percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    // MARK: - Grok Monthly 配色（品红/玫红，虚线圆）

    static func grokMonthlyColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 244/255.0, green: 114/255.0, blue: 182/255.0, alpha: 1.0)  // #F472B6
        } else if percentage < 90 {
            return NSColor(red: 219/255.0, green: 39/255.0, blue: 119/255.0, alpha: 1.0)   // #DB2777
        } else {
            return NSColor(red: 131/255.0, green: 24/255.0, blue: 67/255.0, alpha: 1.0)    // #831843
        }
    }

    static func grokMonthlyColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return Color(red: 244/255.0, green: 114/255.0, blue: 182/255.0).opacity(opacity)
        } else if percentage < 90 {
            return Color(red: 219/255.0, green: 39/255.0, blue: 119/255.0).opacity(opacity)
        } else {
            return Color(red: 131/255.0, green: 24/255.0, blue: 67/255.0).opacity(opacity)
        }
    }

    static func grokMonthlyColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = grokMonthlyColor(percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    // MARK: - Grok Credits 配色（冷金/柠檬，六边形）

    static func grokCreditsColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 250/255.0, green: 204/255.0, blue: 21/255.0, alpha: 1.0)   // #FACC15
        } else if percentage < 90 {
            return NSColor(red: 202/255.0, green: 138/255.0, blue: 4/255.0, alpha: 1.0)    // #CA8A04
        } else {
            return NSColor(red: 113/255.0, green: 63/255.0, blue: 18/255.0, alpha: 1.0)    // #713F12
        }
    }

    static func grokCreditsColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return Color(red: 250/255.0, green: 204/255.0, blue: 21/255.0).opacity(opacity)
        } else if percentage < 90 {
            return Color(red: 202/255.0, green: 138/255.0, blue: 4/255.0).opacity(opacity)
        } else {
            return Color(red: 113/255.0, green: 63/255.0, blue: 18/255.0).opacity(opacity)
        }
    }

    static func grokCreditsColorAdaptive(_ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = grokCreditsColor(percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    // MARK: - 备选配色方案（注释保留，方便切换测试）

    /*
    // 方案2: 粉红→紫红→深紫红
    static func sevenDayColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 255/255.0, green: 158/255.0, blue: 205/255.0, alpha: 1.0)  // 粉红色 #FF9ECD
        } else if percentage < 90 {
            return NSColor(red: 217/255.0, green: 70/255.0, blue: 239/255.0, alpha: 1.0)  // 紫红色 #D946EF
        } else {
            return NSColor(red: 168/255.0, green: 85/255.0, blue: 247/255.0, alpha: 1.0)   // 深紫红 #A855F7
        }
    }

    static func sevenDayColorSwiftUI(_ percentage: Double, opacity: Double = 0.7) -> Color {
        if percentage < 70 {
            return Color(red: 255/255.0, green: 158/255.0, blue: 205/255.0).opacity(opacity)  // 粉红色 #FF9ECD
        } else if percentage < 90 {
            return Color(red: 217/255.0, green: 70/255.0, blue: 239/255.0).opacity(opacity)  // 紫红色 #D946EF
        } else {
            return Color(red: 168/255.0, green: 85/255.0, blue: 247/255.0).opacity(opacity)   // 深紫红 #A855F7
        }
    }
    */

    /*
    // 方案3: 薄荷绿→青紫→靛蓝
    static func sevenDayColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 107/255.0, green: 237/255.0, blue: 227/255.0, alpha: 1.0)  // 薄荷绿 #6BEDE3
        } else if percentage < 90 {
            return NSColor(red: 129/255.0, green: 140/255.0, blue: 248/255.0, alpha: 1.0)  // 青紫色 #818CF8
        } else {
            return NSColor(red: 76/255.0, green: 81/255.0, blue: 191/255.0, alpha: 1.0)   // 靛蓝色 #4C51BF
        }
    }

    static func sevenDayColorSwiftUI(_ percentage: Double, opacity: Double = 0.7) -> Color {
        if percentage < 70 {
            return Color(red: 107/255.0, green: 237/255.0, blue: 227/255.0).opacity(opacity)  // 薄荷绿 #6BEDE3
        } else if percentage < 90 {
            return Color(red: 129/255.0, green: 140/255.0, blue: 248/255.0).opacity(opacity)  // 青紫色 #818CF8
        } else {
            return Color(red: 76/255.0, green: 81/255.0, blue: 191/255.0).opacity(opacity)   // 靛蓝色 #4C51BF
        }
    }
    */

    /*
    // 方案4: 琥珀→橙紫→深紫
    static func sevenDayColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 251/255.0, green: 191/255.0, blue: 36/255.0, alpha: 1.0)  // 琥珀色 #FBBF24
        } else if percentage < 90 {
            return NSColor(red: 192/255.0, green: 132/255.0, blue: 252/255.0, alpha: 1.0)  // 橙紫色 #C084FC
        } else {
            return NSColor(red: 124/255.0, green: 58/255.0, blue: 237/255.0, alpha: 1.0)   // 深紫色 #7C3AED
        }
    }

    static func sevenDayColorSwiftUI(_ percentage: Double, opacity: Double = 0.7) -> Color {
        if percentage < 70 {
            return Color(red: 251/255.0, green: 191/255.0, blue: 36/255.0).opacity(opacity)  // 琥珀色 #FBBF24
        } else if percentage < 90 {
            return Color(red: 192/255.0, green: 132/255.0, blue: 252/255.0).opacity(opacity)  // 橙紫色 #C084FC
        } else {
            return Color(red: 124/255.0, green: 58/255.0, blue: 237/255.0).opacity(opacity)   // 深紫色 #7C3AED
        }
    }
    */
}

// MARK: - NSColor 扩展

extension NSColor {
    /// 为深色模式调整颜色（提高亮度和饱和度）
    /// - Returns: 适合深色背景显示的更亮版本
    func adjustedForDarkMode() -> NSColor {
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else {
            return self
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // 提高亮度：确保亮度至少为 0.75，最多提升 40%（从 0.7/1.3 提升到 0.75/1.4）
        let adjustedBrightness = min(1.0, max(0.75, brightness * 1.4))

        // 保持饱和度不变，让颜色更鲜艳（从 0.9 改为 1.0）
        let adjustedSaturation = min(1.0, saturation * 1.0)

        return NSColor(hue: hue, saturation: adjustedSaturation, brightness: adjustedBrightness, alpha: alpha)
    }
}
