//
//  AntigravityUsageData+Display.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//
//  依赖 LimitType / L.* / AppKit 的展示层辅助，与纯数据的 AntigravityUsageData.swift 分开，
//  后者才能进 SwiftPM 测试目标。
//

import AppKit
import SwiftUI

// MARK: - LimitType 映射

extension AntigravityUsageData {

    /// Antigravity 的全部限制类型，按展示顺序排列
    static let limitTypes: [LimitType] = [
        .antigravityGeminiFiveHour,
        .antigravityGeminiWeekly,
        .antigravityThirdPartyFiveHour,
        .antigravityThirdPartyWeekly
    ]

    /// 指定限制类型对应的数据；非 Antigravity 类型返回 nil
    func limit(for type: LimitType) -> UsageData.LimitData? {
        switch type {
        case .antigravityGeminiFiveHour: return gemini.fiveHour
        case .antigravityGeminiWeekly: return gemini.weekly
        case .antigravityThirdPartyFiveHour: return thirdParty.fiveHour
        case .antigravityThirdPartyWeekly: return thirdParty.weekly
        default: return nil
        }
    }

    /// 有数据的限制类型
    var availableLimitTypes: [LimitType] {
        Self.limitTypes.filter { limit(for: $0) != nil }
    }
}

extension LimitType {
    /// 是否为 Antigravity 的 5 小时窗口
    var isAntigravityFiveHour: Bool {
        self == .antigravityGeminiFiveHour || self == .antigravityThirdPartyFiveHour
    }

    /// 详情行使用的短标签（列标题已经写明 Antigravity）
    var antigravityRowLabel: String {
        switch self {
        case .antigravityGeminiFiveHour: return L.Antigravity.geminiFiveHourShort
        case .antigravityGeminiWeekly: return L.Antigravity.geminiWeeklyShort
        case .antigravityThirdPartyFiveHour: return L.Antigravity.thirdPartyFiveHourShort
        default: return L.Antigravity.thirdPartyWeeklyShort
        }
    }
}

// MARK: - 配色

/// 与 Claude（绿/紫/橙/蓝/粉）、Codex（松石/天空蓝）错开的四个色系：
/// Gemini 5h 靛蓝、Gemini 每周 琥珀、Claude/GPT 5h 玫红、Claude/GPT 每周 青柠。
/// 每个色系与 Codex 一样分安全(<70%)/警告(<90%)/危险三档
extension UsageColorScheme {

    private typealias RGB = (r: Double, g: Double, b: Double)

    private static func antigravityPalette(_ type: LimitType) -> [RGB] {
        switch type {
        case .antigravityGeminiFiveHour:
            return [(129, 140, 248), (79, 70, 229), (49, 46, 129)]     // #818CF8 #4F46E5 #312E81
        case .antigravityGeminiWeekly:
            return [(251, 191, 36), (217, 119, 6), (146, 64, 14)]      // #FBBF24 #D97706 #92400E
        case .antigravityThirdPartyFiveHour:
            return [(251, 113, 133), (225, 29, 72), (136, 19, 55)]     // #FB7185 #E11D48 #881337
        default:
            return [(163, 230, 53), (101, 163, 13), (63, 98, 18)]      // #A3E635 #65A30D #3F6212
        }
    }

    private static func antigravityRGB(_ type: LimitType, _ percentage: Double) -> RGB {
        let palette = antigravityPalette(type)
        if percentage < 70 { return palette[0] }
        if percentage < 90 { return palette[1] }
        return palette[2]
    }

    /// 根据 Antigravity 限制类型和使用百分比返回 NSColor
    static func antigravityColor(_ type: LimitType, _ percentage: Double) -> NSColor {
        let c = antigravityRGB(type, percentage)
        return NSColor(red: c.r / 255.0, green: c.g / 255.0, blue: c.b / 255.0, alpha: 1.0)
    }

    /// 根据 Antigravity 限制类型和使用百分比返回 SwiftUI Color
    static func antigravityColorSwiftUI(_ type: LimitType, _ percentage: Double, opacity: Double = 0.9) -> Color {
        let c = antigravityRGB(type, percentage)
        return Color(red: c.r / 255.0, green: c.g / 255.0, blue: c.b / 255.0).opacity(opacity)
    }

    /// 根据 Antigravity 限制类型和使用百分比返回自适应 NSColor
    static func antigravityColorAdaptive(_ type: LimitType, _ percentage: Double, for statusButton: NSStatusBarButton? = nil) -> NSColor {
        let baseColor = antigravityColor(type, percentage)
        return isDarkMode(for: statusButton) ? baseColor.adjustedForDarkMode() : baseColor
    }

    /// 详情行图标使用的固定基色（安全档），与 Codex 行图标的做法一致
    static func antigravityBaseColorSwiftUI(_ type: LimitType) -> Color {
        antigravityColorSwiftUI(type, 0, opacity: 1)
    }
}
