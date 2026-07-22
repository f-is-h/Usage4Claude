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
    private let metricIconSize: CGFloat = 18
    
    // MARK: - Initialization
    
    init(settings: UserSettings = .shared) {
        self.settings = settings
    }
    
    // MARK: - Public API

    /// 创建菜单栏图标
    /// - Parameters:
    ///   - usageData: Claude 用量数据
    ///   - codexUsageData: Codex 用量数据（nil 表示无 Codex 账号）
    ///   - button: 状态栏按钮（用于获取外观模式）
    /// - Returns: 生成的图标图像
    func createIcon(
        usageData: UsageData?,
        codexUsageData: CodexUsageData? = nil,
        multiAccountUsage: [UUID: UsageData] = [:],
        multiAccountCodexUsage: [UUID: CodexUsageData] = [:],
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

        // 多账户菜单栏模式：每个选中账户一组圆环
        if settings.isMultiAccountMenuBarActive {
            return createMultiAccountIcon(
                multiAccountUsage: multiAccountUsage,
                codexUsageData: codexUsageData,
                multiAccountCodexUsage: multiAccountCodexUsage,
                isMonochrome: isMonochrome,
                button: button
            )
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

        return icon
    }

    // MARK: - Multi-Account Icon Creation

    /// 多账户菜单栏图标：[App 图标?] + 每个账户 [5小时圆环 (+ 每周虚线圆环)]，账户之间用分隔线区隔
    /// Codex 数据存在时在末尾追加 Codex 指标（与多 Provider 模式一致）
    private func createMultiAccountIcon(
        multiAccountUsage: [UUID: UsageData],
        codexUsageData: CodexUsageData?,
        multiAccountCodexUsage: [UUID: CodexUsageData],
        isMonochrome: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        var icons: [NSImage] = []
        let removeBackground = settings.iconStyleMode == .colorTranslucent
        let circleSize = NSSize(width: metricIconSize, height: metricIconSize)

        if settings.iconDisplayMode == .iconOnly || settings.iconDisplayMode == .both {
            let iconName = isMonochrome ? "AppIconReverse" : "AppIcon"
            if let brand = ImageHelper.createSquareIcon(named: iconName, size: providerBrandIconSize, isTemplate: isMonochrome) {
                icons.append(brand)
            }
        }

        if settings.iconDisplayMode == .percentageOnly || settings.iconDisplayMode == .both {
            for account in settings.menuBarAccounts {
                // 数据未到达时显示 0% 占位，保持每个账户的位置稳定
                let data = multiAccountUsage[account.id]
                let fiveHour = data?.fiveHour?.percentage ?? 0
                if isMonochrome {
                    icons.append(createCircleTemplateImage(percentage: fiveHour, size: circleSize, button: button, removeBackground: true))
                } else {
                    icons.append(createCircleImage(percentage: fiveHour, size: circleSize, button: button, removeBackground: removeBackground))
                }

                if settings.multiAccountShowWeekly {
                    let weekly = data?.sevenDay?.percentage ?? 0
                    if isMonochrome {
                        icons.append(createCircleTemplateImage(percentage: weekly, size: circleSize, useSevenDayStyle: true, button: button, removeBackground: true))
                    } else {
                        icons.append(createCircleImage(percentage: weekly, size: circleSize, useSevenDayColor: true, button: button, removeBackground: removeBackground))
                    }
                }
            }
        }

        // 每个选中的 Codex 账户一组圆环（5小时 + 可选 7天）
        for account in settings.menuBarCodexAccounts {
            let data = multiAccountCodexUsage[account.id]
                ?? (account.id == settings.currentCodexAccountId ? codexUsageData : nil)
            let primary = data?.primary?.percentage ?? 0
            if isMonochrome {
                icons.append(createCircleTemplateImage(percentage: primary, size: circleSize, button: button, removeBackground: true))
            } else {
                let color = UsageColorScheme.codexPrimaryColorAdaptive(primary, for: button)
                icons.append(createCircleImage(percentage: primary, size: circleSize, colorOverride: color, button: button, removeBackground: removeBackground))
            }

            if settings.multiAccountShowWeekly {
                let secondary = data?.secondary?.percentage ?? 0
                if isMonochrome {
                    icons.append(createCircleTemplateImage(percentage: secondary, size: circleSize, useSevenDayStyle: true, button: button, removeBackground: true))
                } else {
                    let color = UsageColorScheme.codexSecondaryColorAdaptive(secondary, for: button)
                    icons.append(createCircleImage(percentage: secondary, size: circleSize, useSevenDayColor: true, colorOverride: color, button: button, removeBackground: removeBackground))
                }
            }
        }

        guard !icons.isEmpty else {
            return createMenuBarDividerIcon(isMonochrome: isMonochrome)
        }
        let combined = combineIcons(icons, spacing: 2.0, height: metricIconSize)
        combined.isTemplate = isMonochrome
        return combined
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

        // 为每个类型创建图标
        let icons = types.compactMap { type in
            createIconForType(type, data: data, isMonochrome: isMonochrome, button: button)
        }

        // 组合图标
        if icons.isEmpty {
            return createSimpleCircleIcon()
        } else if icons.count == 1 {
            return icons[0]
        } else {
            let combined = combineIcons(icons, spacing: 3.0, height: 18)
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

        // 创建百分比图标
        let percentageIcons = types.compactMap { type in
            createIconForType(type, data: data, isMonochrome: isMonochrome, button: button)
        }

        // 组合 App 图标 + 百分比图标
        var allIcons = [appIconCopy]
        allIcons.append(contentsOf: percentageIcons)

        let combined = combineIcons(allIcons, spacing: 3.0, height: metricIconSize)
        combined.isTemplate = isMonochrome
        return combined
    }
    
    // MARK: - Icon Drawing - Colored Mode (彩色模式)

    private func createCircleImage(percentage: Double, size: NSSize, useSevenDayColor: Bool = false, colorOverride: NSColor? = nil, useDashedStyle: Bool = false, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 2

        let backgroundCircle = NSBezierPath()
        backgroundCircle.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        menuBarCircleFillColor(for: button).setFill()
        backgroundCircle.fill()

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

        let fontSize: CGFloat = percentage >= 100 ? size.width * 0.275 : size.width * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: percentage >= 100 ? .bold : .semibold)
        let text = "\(Int(percentage))"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: menuBarCircleTextColor(for: button),
            .paragraphStyle: paragraphStyle
        ]
        let textSize = text.size(withAttributes: attrs)
        let textOrigin = NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2)
        text.draw(at: textOrigin, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    // MARK: - Icon Drawing - Template Mode (单色模式)

    private func createCircleTemplateImage(percentage: Double, size: NSSize, useSevenDayStyle: Bool = false, button: NSStatusBarButton? = nil, removeBackground: Bool = false) -> NSImage {
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

        let fontSize: CGFloat = percentage >= 100 ? size.width * 0.275 : size.width * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: percentage >= 100 ? .bold : .semibold)
        let text = "\(Int(percentage))"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func menuBarCircleFillColor(for button: NSStatusBarButton?) -> NSColor {
        if UsageColorScheme.isDarkMode(for: button) {
            return NSColor(calibratedWhite: 0.74, alpha: 0.82)
        }
        return NSColor(calibratedWhite: 0.88, alpha: 0.88)
    }

    private func menuBarCircleTextColor(for button: NSStatusBarButton?) -> NSColor {
        if UsageColorScheme.isDarkMode(for: button) {
            return NSColor(calibratedWhite: 0.08, alpha: 1.0)
        }
        return NSColor(calibratedWhite: 0.18, alpha: 1.0)
    }

    // MARK: - Utility Icons

    /// 创建简单圆形图标（备用）
    private func createSimpleCircleIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
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
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: 18, height: 18), button: button, removeBackground: true)
            } else {
                return createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18), button: button, removeBackground: removeBackground)
            }

        case .sevenDay:
            let percentage = data.sevenDay?.percentage ?? (showPlaceholder ? 0 : nil)
            guard let percentage = percentage else { return nil }
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: 18, height: 18), useSevenDayStyle: true, button: button, removeBackground: true)
            } else {
                return createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18), useSevenDayColor: true, button: button, removeBackground: removeBackground)
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
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: 18, height: 18), button: button, removeBackground: true)
            }
            let color = UsageColorScheme.codexPrimaryColorAdaptive(percentage, for: button)
            return createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18), colorOverride: color, button: button, removeBackground: removeBackground)

        case .codexSecondary:
            if isMonochrome {
                return createCircleTemplateImage(percentage: percentage, size: NSSize(width: 18, height: 18), useSevenDayStyle: true, button: button, removeBackground: true)
            }
            let color = UsageColorScheme.codexSecondaryColorAdaptive(percentage, for: button)
            return createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18), colorOverride: color, useDashedStyle: true, button: button, removeBackground: removeBackground)

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
