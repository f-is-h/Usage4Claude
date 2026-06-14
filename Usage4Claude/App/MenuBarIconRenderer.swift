//
//  MenuBarIconRenderer.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import AppKit

/// 菜单栏图标渲染器
/// 负责所有图标的绘制逻辑，支持彩色和单色两种模式
/// 从 MenuBarUI 中提取以实现职责分离
class MenuBarIconRenderer {
    
    // MARK: - Settings Reference
    
    /// 用户设置实例
    private let settings: UserSettings
    /// 菜单栏品牌图标尺寸
    private let providerBrandIconSize: CGFloat = 16
    /// 菜单栏指标图标尺寸
    private let metricIconSize: CGFloat = 22
    
    // MARK: - Initialization
    
    init(settings: UserSettings = .shared) {
        self.settings = settings
    }
    
    // MARK: - Public API

    /// 创建菜单栏图标
    /// - Parameters:
    ///   - usageData: Claude 用量数据
    ///   - codexUsageData: Codex 用量数据（nil 表示无 Codex 账号）
    ///   - hasUpdate: 是否有可用更新
    ///   - button: 状态栏按钮（用于获取外观模式）
    /// - Returns: 生成的图标图像
    func createIcon(
        usageData: UsageData?,
        codexUsageData: CodexUsageData? = nil,
        hasUpdate: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        // 确定单色/彩色模式
        let isMonochrome: Bool
        if let data = usageData {
            let canUseColor = settings.canUseColoredTheme(usageData: data)
            let forceMonochrome = !canUseColor && settings.iconStyleMode != .monochrome
            isMonochrome = settings.iconStyleMode == .monochrome || forceMonochrome
        } else {
            isMonochrome = settings.iconStyleMode == .monochrome
        }

        var icon: NSImage

        if let codex = codexUsageData {
            // 有 Codex 数据路径
            let allTypes = settings.getActiveDisplayTypes(usageData: usageData, codexUsageData: codex, forMenuBar: true)
            let codexTypes = allTypes.filter { $0.provider == .codex }

            if settings.isMultiProviderActive, let data = usageData {
                // 双 Provider 模式
                let claudeTypes = allTypes.filter { $0.provider == .claude }
                icon = createMultiProviderIcon(data: data, codex: codex, claudeTypes: claudeTypes, codexTypes: codexTypes, isMonochrome: isMonochrome, button: button)
            } else {
                // Codex-only（无 Claude 账号）或降级路径
                icon = createCodexOnlyIcon(codex: codex, codexTypes: codexTypes, isMonochrome: isMonochrome, button: button)
            }
        } else {
            // Claude-only 路径（原有逻辑）
            guard let data = usageData else {
                let size = NSSize(width: 22, height: 22)
                let defaultIcon: NSImage
                if settings.iconDisplayMode == .none {
                    defaultIcon = createMenuBarDividerIcon(isMonochrome: isMonochrome)
                } else {
                    defaultIcon = isMonochrome ?
                        createCircleTemplateImage(percentage: 0, size: size, button: button, removeBackground: true) :
                        createCircleImage(percentage: 0, size: size, button: button, removeBackground: true)
                }
                if hasUpdate { return addBadgeToImage(defaultIcon) }
                return defaultIcon
            }

            let activeTypes = settings.getActiveDisplayTypes(usageData: data, forMenuBar: true)

            switch settings.iconDisplayMode {
            case .percentageOnly:
                icon = createCombinedPercentageIcon(data: data, types: activeTypes, isMonochrome: isMonochrome, button: button)
            case .iconOnly:
                let iconName = isMonochrome ? "AppIconReverse" : "AppIcon"
                if let iconCopy = ImageHelper.createSquareIcon(named: iconName, size: providerBrandIconSize, isTemplate: isMonochrome) {
                    icon = iconCopy
                } else {
                    icon = createSimpleCircleIcon()
                }
            case .both:
                icon = createCombinedIconWithAppIcon(data: data, types: activeTypes, isMonochrome: isMonochrome, button: button)
            case .none:
                icon = createMenuBarDividerIcon(isMonochrome: isMonochrome)
            }
        }

        if hasUpdate { icon = addBadgeToImage(icon) }
        return icon
    }

    // MARK: - Multi-Provider Icon Creation

    /// 双 Provider 模式图标：[Claude 品牌] + [Claude 指标] + [Codex 品牌] + [Codex 指标]
    private func createMultiProviderIcon(
        data: UsageData,
        codex: CodexUsageData,
        claudeTypes: [LimitType],
        codexTypes: [LimitType],
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        var icons: [NSImage] = []

        switch settings.iconDisplayMode {
        case .iconOnly:
            let iconName = isMonochrome ? "AppIconReverse" : "AppIcon"
            if let copy = ImageHelper.createSquareIcon(named: iconName, size: providerBrandIconSize, isTemplate: isMonochrome) {
                icons.append(copy)
            }

        case .percentageOnly, .both:
            // Claude 部分
            let claudeIcons = claudeTypes.compactMap { createIconForType($0, data: data, isMonochrome: isMonochrome, button: button) }
            if !claudeIcons.isEmpty {
                if settings.iconDisplayMode == .both {
                    let iconName = isMonochrome ? "AppIconReverse" : "AppIcon"
                    if let copy = ImageHelper.createSquareIcon(named: iconName, size: providerBrandIconSize, isTemplate: isMonochrome) {
                        icons.append(copy)
                    }
                }
                icons.append(contentsOf: claudeIcons)
            }

            // Codex 部分
            let codexIcons = buildCodexIcons(codex: codex, types: codexTypes, isMonochrome: isMonochrome, button: button)
            if !codexIcons.isEmpty {
                if settings.iconDisplayMode == .percentageOnly, !claudeIcons.isEmpty {
                    icons.append(createMenuBarDividerIcon(isMonochrome: isMonochrome))
                } else if settings.iconDisplayMode == .both,
                   let brand = createProviderBrandIcon(.codex, isMonochrome: isMonochrome, size: providerBrandIconSize) {
                    icons.append(brand)
                }
                icons.append(contentsOf: codexIcons)
            }

        case .none:
            // 不显示图标：仅显示轻量分隔线，保留可点击的状态栏锚点
            icons.append(createMenuBarDividerIcon(isMonochrome: isMonochrome))
        }

        let combined = icons.isEmpty ? createSimpleCircleIcon() : combineIcons(icons, spacing: 2.0, height: metricIconSize)
        combined.isTemplate = isMonochrome
        return combined
    }

    /// Codex-only 模式图标（无 Claude 账号时）
    private func createCodexOnlyIcon(
        codex: CodexUsageData,
        codexTypes: [LimitType],
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        switch settings.iconDisplayMode {
        case .none:
            return createMenuBarDividerIcon(isMonochrome: isMonochrome)

        case .iconOnly:
            return createProviderBrandIcon(.codex, isMonochrome: isMonochrome, size: providerBrandIconSize) ?? createSimpleCircleIcon()

        case .percentageOnly, .both:
            var icons: [NSImage] = []
            if settings.iconDisplayMode == .both,
               let brand = createProviderBrandIcon(.codex, isMonochrome: isMonochrome, size: providerBrandIconSize) {
                icons.append(brand)
            }
            icons.append(contentsOf: buildCodexIcons(codex: codex, types: codexTypes, isMonochrome: isMonochrome, button: button))
            if icons.isEmpty { return createSimpleCircleIcon() }
            let combined = icons.count == 1 ? icons[0] : combineIcons(icons, spacing: 3.0, height: metricIconSize)
            combined.isTemplate = isMonochrome
            return combined
        }
    }

    /// 构建 Codex 指标图标列表
    private func buildCodexIcons(codex: CodexUsageData, types: [LimitType], isMonochrome: Bool, button: NSStatusBarButton?) -> [NSImage] {
        let showPlaceholder = settings.displayMode == .custom
        return types.compactMap { type -> NSImage? in
            switch type {
            case .codexPrimary:
                let percentage = codex.primary?.percentage ?? (showPlaceholder ? 0 : nil)
                return percentage.flatMap { createCodexIcon(type: type, percentage: $0, isMonochrome: isMonochrome, button: button) }
            case .codexSecondary:
                let percentage = codex.secondary?.percentage ?? (showPlaceholder ? 0 : nil)
                return percentage.flatMap { createCodexIcon(type: type, percentage: $0, isMonochrome: isMonochrome, button: button) }
            case .codexExtraUsage:
                let percentage: Double?
                if let extra = codex.extraUsage, extra.enabled {
                    percentage = extra.percentage
                } else if showPlaceholder {
                    percentage = 0
                } else {
                    percentage = nil
                }
                return percentage.flatMap { createCodexIcon(type: type, percentage: $0, isMonochrome: isMonochrome, button: button) }
            default:
                return nil
            }
        }
    }

    /// 创建 Provider 品牌图标（用于多 Provider 模式下的视觉分组）
    private func createProviderBrandIcon(_ provider: ProviderType, isMonochrome: Bool, size: CGFloat = 14) -> NSImage? {
        switch provider {
        case .claude:
            let iconName = isMonochrome ? "AppIconReverse" : "AppIcon"
            return ImageHelper.createSquareIcon(named: iconName, size: size, isTemplate: isMonochrome)
        case .codex:
            let iconName = isMonochrome ? "CodexIconReverse" : "CodexIcon"
            return ImageHelper.createSquareIcon(named: iconName, size: size, isTemplate: isMonochrome, sourceInset: isMonochrome ? 0 : 2)
        }
    }

    /// 创建仅百分比的组合图标
    private func createCombinedPercentageIcon(
        data: UsageData,
        types: [LimitType],
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        guard !types.isEmpty else {
            return createSimpleCircleIcon()
        }

        // 按类型顺序：每个用量圆环后紧跟其对应的时间圆环
        // 例如 [5H用量][5H时间][7天用量][7天时间]
        var icons: [NSImage] = []
        for type in types {
            guard let usageIcon = createIconForType(type, data: data, isMonochrome: isMonochrome, button: button) else { continue }
            icons.append(usageIcon)
            if let timeIcon = timeCircleFor(type: type, data: data, isMonochrome: isMonochrome, button: button) {
                icons.append(timeIcon)
            }
        }

        // 组合图标
        if icons.isEmpty {
            return createSimpleCircleIcon()
        } else if icons.count == 1 {
            return icons[0]
        } else {
            let combined = combineIcons(icons, spacing: 3.0, height: metricIconSize)
            combined.isTemplate = isMonochrome
            return combined
        }
    }

    /// 创建 App 图标 + 百分比的组合图标
    private func createCombinedIconWithAppIcon(
        data: UsageData,
        types: [LimitType],
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        // 获取 App 图标（单色模式使用反转图标）
        let iconName = isMonochrome ? "AppIconReverse" : "AppIcon"
        guard let appIconCopy = ImageHelper.createSquareIcon(named: iconName, size: providerBrandIconSize, isTemplate: isMonochrome) else {
            return createCombinedPercentageIcon(data: data, types: types, isMonochrome: isMonochrome, button: button)
        }

        // 组合 App 图标 + （每个用量圆环后紧跟其时间圆环）
        var allIcons = [appIconCopy]
        for type in types {
            guard let usageIcon = createIconForType(type, data: data, isMonochrome: isMonochrome, button: button) else { continue }
            allIcons.append(usageIcon)
            if let timeIcon = timeCircleFor(type: type, data: data, isMonochrome: isMonochrome, button: button) {
                allIcons.append(timeIcon)
            }
        }

        let combined = combineIcons(allIcons, spacing: 3.0, height: metricIconSize)
        combined.isTemplate = isMonochrome
        return combined
    }
    
    // MARK: - Icon Drawing - Colored Mode (彩色模式)

    private func createCircleImage(percentage: Double, size: NSSize, useSevenDayColor: Bool = false, colorOverride: NSColor? = nil, useDashedStyle: Bool = false, button: NSStatusBarButton?, removeBackground: Bool = false, centerText: String? = nil) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 2

        if !removeBackground {
            let backgroundCircle = NSBezierPath()
            backgroundCircle.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
            NSColor.white.withAlphaComponent(0.5).setFill()
            backgroundCircle.fill()
        }

        NSColor.gray.withAlphaComponent(0.5).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        backgroundPath.lineWidth = 1.5

        // 7天/Codex secondary 限制使用虚线以区分实线圆
        if useSevenDayColor || useDashedStyle {
            let dashPattern: [CGFloat] = [3, 1]
            backgroundPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        }

        backgroundPath.stroke()

        let color: NSColor
        if let override = colorOverride {
            color = override
        } else {
            color = useSevenDayColor ? UsageColorScheme.sevenDayColorAdaptive(percentage, for: button) : UsageColorScheme.fiveHourColorAdaptive(percentage, for: button)
        }
        color.setStroke()

        let progressPath = NSBezierPath()
        let lineWidth: CGFloat = 2.5

        // 计算进度角度
        let baseAngle = CGFloat(percentage) / 100.0 * 360
        let circumference = 2 * CGFloat.pi * radius  // 圆周长
        let capAngle = (lineWidth / circumference) * 360  // 圆头延伸对应的角度

        let progressAngle: CGFloat
        let startAngle: CGFloat

        if percentage >= 100 {
            // 100%: 使用完整角度和固定起点，因为 .butt 端点无延伸
            progressAngle = baseAngle
            startAngle = 90
        } else {
            // 5小时/7天限制：使用渐进式减法，保持起点固定，实现平滑增长
            // 减去的角度随百分比线性增加，在50%时完成完整减法，50%-100%显示完全精确
            progressAngle = baseAngle - capAngle * min(1.0, CGFloat(percentage / 50.0))
            startAngle = 90 - capAngle / 2 + 0.5
        }

        let endAngle = startAngle - progressAngle

        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = lineWidth
        // 100%时使用平头让圆环完美闭合，其他进度使用圆头
        progressPath.lineCapStyle = percentage >= 100 ? .butt : .round
        progressPath.stroke()

        let text = centerText ?? "\(Int(percentage))"
        let fontSize: CGFloat
        let fontWeight: NSFont.Weight
        if centerText != nil {
            // 时间圆环：按文本长度自适应字号（如 "45m"/"2h"/"5d"）
            fontSize = text.count >= 3 ? size.width * 0.30 : size.width * 0.40
            fontWeight = .semibold
        } else {
            fontSize = percentage >= 100 ? size.width * 0.275 : size.width * 0.4
            fontWeight = percentage >= 100 ? .bold : .semibold
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraphStyle]
        let textSize = text.size(withAttributes: attrs)
        let textOrigin = NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2)
        text.draw(at: textOrigin, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    // MARK: - Icon Drawing - Template Mode (单色模式)

    private func createCircleTemplateImage(percentage: Double, size: NSSize, useSevenDayStyle: Bool = false, button: NSStatusBarButton? = nil, removeBackground: Bool = false, centerText: String? = nil) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 2

        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        backgroundPath.lineWidth = 1.5

        // 7天限制使用虚线以区分5小时限制
        if useSevenDayStyle {
            let dashPattern: [CGFloat] = [3, 1]
            backgroundPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        }

        backgroundPath.stroke()

        NSColor.labelColor.setStroke()
        let progressPath = NSBezierPath()
        let lineWidth: CGFloat = 2.5

        // 计算进度角度
        let baseAngle = CGFloat(percentage) / 100.0 * 360
        let circumference = 2 * CGFloat.pi * radius  // 圆周长
        let capAngle = (lineWidth / circumference) * 360  // 圆头延伸对应的角度

        let progressAngle: CGFloat
        let startAngle: CGFloat

        if percentage >= 100 {
            // 100%: 使用完整角度和固定起点，因为 .butt 端点无延伸
            progressAngle = baseAngle
            startAngle = 90
        } else {
            // 单色模式：使用渐进式减法，保持起点固定，实现平滑增长
            // 减去的角度随百分比线性增加，在50%时完成完整减法，50%-100%显示完全精确
            progressAngle = baseAngle - capAngle * min(1.0, CGFloat(percentage / 50.0))
            startAngle = 90 - capAngle / 2 + 0.5
        }

        let endAngle = startAngle - progressAngle

        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = lineWidth
        // 100%时使用平头让圆环完美闭合，其他进度使用圆头
        progressPath.lineCapStyle = percentage >= 100 ? .butt : .round
        progressPath.stroke()

        let text = centerText ?? "\(Int(percentage))"
        let fontSize: CGFloat
        let fontWeight: NSFont.Weight
        if centerText != nil {
            // 时间圆环：按文本长度自适应字号（如 "45m"/"2h"/"5d"）
            fontSize = text.count >= 3 ? size.width * 0.30 : size.width * 0.40
            fontWeight = .semibold
        } else {
            fontSize = percentage >= 100 ? size.width * 0.275 : size.width * 0.4
            fontWeight = percentage >= 100 ? .bold : .semibold
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraphStyle]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - Utility Icons

    /// 创建简单圆形图标（备用）
    private func createSimpleCircleIcon() -> NSImage {
        let size = NSSize(width: metricIconSize, height: metricIconSize)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 3, y: 3, width: 12, height: 12)
        let path = NSBezierPath(ovalIn: rect)

        NSColor.labelColor.setStroke()
        path.lineWidth = 2.0
        path.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// 在图标上添加徽章（小红点）
    private func addBadgeToImage(_ baseImage: NSImage) -> NSImage {
        let size = baseImage.size
        let expandedSize = NSSize(width: size.width + 2.5, height: size.height + 2.5)
        let badgedImage = NSImage(size: expandedSize)

        badgedImage.lockFocus()
        baseImage.draw(in: NSRect(origin: .zero, size: size))

        let badgeRadius: CGFloat = 2.0
        let badgeDiameter = badgeRadius * 2
        let badgeX = expandedSize.width - badgeDiameter - 1.5
        let badgeY = expandedSize.height - badgeDiameter - 1.5
        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeDiameter, height: badgeDiameter)

        NSGraphicsContext.saveGraphicsState()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        NSGraphicsContext.restoreGraphicsState()

        badgedImage.unlockFocus()
        badgedImage.isTemplate = baseImage.isTemplate

        return badgedImage
    }

    // MARK: - Countdown Circle Rendering

    /// 窗口总时长，用于计算"已过去比例"，使时间圆环可与相邻用量圆环直接对比
    private let fiveHourWindowSeconds: TimeInterval = 5 * 60 * 60
    private let sevenDayWindowSeconds: TimeInterval = 7 * 24 * 60 * 60

    /// 为指定限制类型构建对应的时间圆环（紧跟在该类型的用量圆环之后显示）
    /// - 环填充 = 当前窗口"已过去"的比例（与相邻用量环同向，便于判断用量是否超前于时间）
    /// - 中心文本 = 剩余时间（紧凑自适应单位）
    /// - 5小时 = 红色，7天 = 橙色；其它类型无时间圆环（返回 nil）
    private func timeCircleFor(
        type: LimitType,
        data: UsageData,
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage? {
        // 用户可在设置中关闭菜单栏倒计时（关闭时不绘制时间圆环）
        guard settings.menuBarCountdownEnabled else { return nil }
        switch type {
        case .fiveHour:
            // 窗口重置后尚未使用 token 时 API 无 resets_at；此时显示满窗占位（空环 + 整窗时间），
            // 让时钟始终与用量圆环成对出现，首次用量产生后平滑切换为真实倒计时。
            let remaining = placeholderRemaining(data.fiveHour?.resetsIn, window: fiveHourWindowSeconds)
            return makeTimeCircle(
                remaining: remaining,
                windowSeconds: fiveHourWindowSeconds,
                text: timeCircleText(remaining: remaining, isShortWindow: true),
                color: .systemRed,
                isMonochrome: isMonochrome,
                button: button
            )
        case .sevenDay:
            let remaining = placeholderRemaining(data.sevenDay?.resetsIn, window: sevenDayWindowSeconds)
            return makeTimeCircle(
                remaining: remaining,
                windowSeconds: sevenDayWindowSeconds,
                text: timeCircleText(remaining: remaining, isShortWindow: false),
                color: .systemOrange,
                isMonochrome: isMonochrome,
                button: button
            )
        default:
            return nil
        }
    }

    /// 计算时间圆环使用的"剩余秒数"：
    /// - 有有效 resets_at（resetsIn > 0）时返回真实剩余（并夹在整窗内）
    /// - 窗口刚重置、尚无 resets_at，或剩余 <= 0 时，回退为整个窗口 → 空环 + 满窗占位
    private func placeholderRemaining(_ resetsIn: TimeInterval?, window: TimeInterval) -> TimeInterval {
        guard let resetsIn = resetsIn, resetsIn > 0 else { return window }
        return min(resetsIn, window)
    }

    /// 绘制单个时间圆环，复用用量圆环的绘制逻辑（环=已过去比例，中心=剩余时间文本）
    private func makeTimeCircle(
        remaining: TimeInterval,
        windowSeconds: TimeInterval,
        text: String,
        color: NSColor,
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        // 已过去比例（0-100），与用量百分比同尺度
        let elapsed = max(0, min(100, (1 - remaining / windowSeconds) * 100))
        let size = NSSize(width: metricIconSize, height: metricIconSize)
        let removeBackground = settings.iconStyleMode == .colorTranslucent

        if isMonochrome {
            return createCircleTemplateImage(percentage: elapsed, size: size, button: button, removeBackground: true, centerText: text)
        }
        return createCircleImage(percentage: elapsed, size: size, colorOverride: color, button: button, removeBackground: removeBackground, centerText: text)
    }

    /// 紧凑的时间圆环中心文本（≤3字符，自适应单位）
    /// - 短窗口（5小时）: <60分钟显示 "Nm"，否则 "Nh"
    /// - 长窗口（7天）: <24小时显示 "Nh"，否则 "Nd"
    private func timeCircleText(remaining: TimeInterval, isShortWindow: Bool) -> String {
        if isShortWindow {
            let totalMinutes = remaining / 60.0
            if totalMinutes < 60 {
                let m = max(1, Int(totalMinutes.rounded()))
                if m < 60 { return "\(m)m" }
                // 四舍五入恰好到 60 分钟时，按 1 小时显示
            }
            // ≥1 小时：四舍五入到最近的整点（剩余分钟 >30 进位，<30 舍去）
            let hours = max(1, Int((remaining / 3600).rounded()))
            return "\(hours)h"
        } else {
            let hours = Int(ceil(remaining / 3600))
            if hours < 24 { return "\(hours)h" }
            return "\(hours / 24)d"
        }
    }

    // MARK: - Icon Combination Methods (v2.0)

    /// 组合多个图标到单个图像
    /// - Parameters:
    ///   - icons: 要组合的图标数组
    ///   - spacing: 图标间距
    ///   - height: 统一高度（默认18）
    /// - Returns: 组合后的图标
    private func combineIcons(_ icons: [NSImage], spacing: CGFloat = 3.0, height: CGFloat = 18) -> NSImage {
        guard !icons.isEmpty else {
            return createSimpleCircleIcon()
        }

        // 计算总宽度
        let totalWidth = icons.reduce(0) { $0 + $1.size.width } + CGFloat(icons.count - 1) * spacing
        let size = NSSize(width: totalWidth, height: height)

        let image = NSImage(size: size)
        image.lockFocus()

        var currentX: CGFloat = 0
        for icon in icons {
            let y = (height - icon.size.height) / 2  // 垂直居中
            icon.draw(at: NSPoint(x: currentX, y: y),
                     from: NSRect(origin: .zero, size: icon.size),
                     operation: .sourceOver,
                     fraction: 1.0)
            currentX += icon.size.width + spacing
        }

        image.unlockFocus()
        return image
    }

    /// 根据限制类型和数据创建单个图标
    /// - Parameters:
    ///   - type: 限制类型
    ///   - data: 用量数据
    ///   - isMonochrome: 是否为单色模式
    ///   - button: 状态栏按钮
    /// - Returns: 图标图像
    func createIconForType(
        _ type: LimitType,
        data: UsageData,
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage? {
        // 根据主题模式决定是否移除背景
        // colorTranslucent: 移除背景（通透）
        // colorWithBackground: 保留背景（半透明白色）
        let removeBackground = settings.iconStyleMode == .colorTranslucent

        // 在自定义模式下，即使数据为 nil 也显示占位图标（0%）
        // 在智能模式下，数据为 nil 时返回 nil
        let showPlaceholder = settings.displayMode == .custom

        switch type {
        case .fiveHour:
            let percentage = data.fiveHour?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage = percentage else { return nil }
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: metricIconSize, height: metricIconSize), button: button, removeBackground: true)
            } else {
                return createCircleImage(percentage: percentage, size: NSSize(width: metricIconSize, height: metricIconSize), button: button, removeBackground: removeBackground)
            }

        case .sevenDay:
            let percentage = data.sevenDay?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage = percentage else { return nil }
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: metricIconSize, height: metricIconSize), useSevenDayStyle: true, button: button, removeBackground: true)
            } else {
                return createCircleImage(percentage: percentage, size: NSSize(width: metricIconSize, height: metricIconSize), useSevenDayColor: true, button: button, removeBackground: removeBackground)
            }

        case .opusWeekly:
            let percentage = data.opus?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage = percentage else { return nil }
            return ShapeIconRenderer.createVerticalRectangleIcon(percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)

        case .sonnetWeekly:
            let percentage = data.sonnet?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage = percentage else { return nil }
            return ShapeIconRenderer.createHorizontalRectangleIcon(percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)

        case .extraUsage:
            let percentage: Double?
            if let extraUsage = data.extraUsage, extraUsage.enabled {
                percentage = extraUsage.percentage
            } else if showPlaceholder {
                percentage = 0
            } else {
                percentage = nil
            }
            guard let percentage = percentage else { return nil }
            return ShapeIconRenderer.createHexagonIcon(percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)

        case .codexPrimary, .codexSecondary, .codexExtraUsage:
            // Codex 数据在 Phase 4 通过 createCodexIcon 独立渲染
            // createIconForType 仅处理 Claude UsageData，此处返回 nil
            return nil
        }
    }

    /// 根据 Codex 用量数据创建单个图标（Codex 专用，Phase 4 接入 UI）
    func createCodexIcon(
        type: LimitType,
        percentage: Double,
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage? {
        let removeBackground = settings.iconStyleMode == .colorTranslucent

        switch type {
        case .codexPrimary:
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: metricIconSize, height: metricIconSize), button: button, removeBackground: true)
            }
            let color = UsageColorScheme.codexPrimaryColorAdaptive(percentage, for: button)
            return createCircleImage(percentage: percentage, size: NSSize(width: metricIconSize, height: metricIconSize), colorOverride: color, button: button, removeBackground: removeBackground)

        case .codexSecondary:
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: metricIconSize, height: metricIconSize), useSevenDayStyle: true, button: button, removeBackground: true)
            }
            let color = UsageColorScheme.codexSecondaryColorAdaptive(percentage, for: button)
            return createCircleImage(percentage: percentage, size: NSSize(width: metricIconSize, height: metricIconSize), colorOverride: color, useDashedStyle: true, button: button, removeBackground: removeBackground)

        case .codexExtraUsage:
            let color = UsageColorScheme.codexExtraUsageColorAdaptive(percentage, for: button)
            return ShapeIconRenderer.createHexagonIcon(percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground, colorOverride: color)

        default:
            return nil
        }
    }

    /// 创建轻量分隔线图标（用于"不显示图标"模式）
    private func createMenuBarDividerIcon(isMonochrome: Bool) -> NSImage {
        let width: CGFloat = 5
        let height: CGFloat = metricIconSize
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        let lineRect = NSRect(x: (width - 1) / 2, y: 1, width: 1, height: height - 2)
        let linePath = NSBezierPath(rect: lineRect)
        let lineColor = isMonochrome ? NSColor.labelColor : NSColor.secondaryLabelColor
        let gradient = NSGradient(colors: [
            lineColor.withAlphaComponent(0.0),
            lineColor.withAlphaComponent(0.55),
            lineColor.withAlphaComponent(0.55),
            lineColor.withAlphaComponent(0.0)
        ])
        gradient?.draw(in: linePath, angle: 90)

        image.unlockFocus()
        if isMonochrome { image.isTemplate = true }
        return image
    }

}
