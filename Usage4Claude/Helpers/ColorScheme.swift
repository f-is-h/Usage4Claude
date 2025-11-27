//
//  ColorScheme.swift
//  Usage4Claude
//
//  Created by Claude on 2025-11-26.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import AppKit

/// 统一配色方案管理
/// 提供5小时和7天限制的颜色配置，支持 AppKit 和 SwiftUI
enum UsageColorScheme {

    // MARK: - 5小时限制配色（绿→橙→红）

    /// 根据5小时限制使用百分比返回 NSColor
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 0-70% 绿色(安全), 70-90% 橙色(警告), 90-100% 红色(危险)
    static func fiveHourColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor.systemGreen
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
            return .green.opacity(opacity)
        } else if percentage < 90 {
            return .orange.opacity(opacity)
        } else {
            return .red.opacity(opacity)
        }
    }

    // MARK: - 7天限制配色

    /// 根据7天限制使用百分比返回 NSColor
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 当前方案 - 青蓝→蓝紫→深紫
    ///         0-70% 青蓝色(安全), 70-90% 蓝紫色(警告), 90-100% 深紫色(危险)
    static func sevenDayColor(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor(red: 90/255.0, green: 200/255.0, blue: 250/255.0, alpha: 1.0)  // 青蓝色 #5AC8FA
        } else if percentage < 90 {
            return NSColor(red: 123/255.0, green: 104/255.0, blue: 238/255.0, alpha: 1.0)  // 蓝紫色 #7B68EE
        } else {
            return NSColor(red: 100/255.0, green: 50/255.0, blue: 180/255.0, alpha: 1.0)   // 深紫色 #6432B4
        }
    }

    /// 根据7天限制使用百分比返回 SwiftUI Color
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 对应的状态颜色
    /// - Note: 当前方案 - 青蓝→蓝紫→深紫
    ///         0-70% 青蓝色(安全), 70-90% 蓝紫色(警告), 90-100% 深紫色(危险)
    ///         详细界面使用时会添加透明度，使颜色更柔和
    static func sevenDayColorSwiftUI(_ percentage: Double, opacity: Double = 0.9) -> Color {
        if percentage < 70 {
            return Color(red: 90/255.0, green: 200/255.0, blue: 250/255.0).opacity(opacity)  // 青蓝色 #5AC8FA
        } else if percentage < 90 {
            return Color(red: 123/255.0, green: 104/255.0, blue: 238/255.0).opacity(opacity)  // 蓝紫色 #7B68EE
        } else {
            return Color(red: 100/255.0, green: 50/255.0, blue: 180/255.0).opacity(opacity)   // 深紫色 #6432B4
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
