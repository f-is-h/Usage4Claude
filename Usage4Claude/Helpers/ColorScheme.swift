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
        // 方法1: 使用状态栏按钮的外观
        if let button = statusButton,
           let appearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return appearance == .darkAqua
        }

        // 方法2: 使用应用的 effectiveAppearance
        if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return appearance == .darkAqua
        }

        // 最终降级
        return true
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
