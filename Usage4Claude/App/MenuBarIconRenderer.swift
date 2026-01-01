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
    
    // MARK: - Initialization
    
    init(settings: UserSettings = .shared) {
        self.settings = settings
    }
    
    // MARK: - Public API
    
    /// 创建菜单栏图标
    /// - Parameters:
    ///   - usageData: 用量数据
    ///   - hasUpdate: 是否有可用更新
    ///   - button: 状态栏按钮（用于获取外观模式）
    /// - Returns: 生成的图标图像
    func createIcon(
        usageData: UsageData?,
        hasUpdate: Bool,
        button: NSStatusBarButton?
    ) -> NSImage {
        // 无数据时显示默认图标
        guard let data = usageData else {
            let size = NSSize(width: 22, height: 22)
            return settings.iconStyleMode == .monochrome ?
                createCircleTemplateImage(percentage: 0, size: size, button: button, removeBackground: true) :
                createCircleImage(percentage: 0, size: size, button: button, removeBackground: true)
        }

        // 获取要显示的限制类型
        let activeTypes = settings.getActiveDisplayTypes(usageData: data)

        // 判断是否可以使用彩色主题
        let canUseColor = settings.canUseColoredTheme(usageData: data)
        let forceMonochrome = !canUseColor && settings.iconStyleMode != .monochrome
        let isMonochrome = settings.iconStyleMode == .monochrome || forceMonochrome

        var icon: NSImage

        // 根据显示模式创建图标
        switch settings.iconDisplayMode {
        case .percentageOnly:
            // 仅显示百分比（圆形/矩形/六边形组合）
            icon = createCombinedPercentageIcon(data: data, types: activeTypes, isMonochrome: isMonochrome, button: button)

        case .iconOnly:
            // 仅显示 App 图标
            let iconName = isMonochrome ? "AppIconReverse" : "AppIcon"
            if let appIcon = NSImage(named: iconName), let iconCopy = appIcon.copy() as? NSImage {
                iconCopy.size = NSSize(width: 18, height: 18)
                iconCopy.isTemplate = isMonochrome
                icon = iconCopy
            } else {
                icon = createSimpleCircleIcon()
            }

        case .both:
            // App 图标 + 百分比组合
            icon = createCombinedIconWithAppIcon(data: data, types: activeTypes, isMonochrome: isMonochrome, button: button)
        }

        // 如果需要徽章，添加徽章
        if hasUpdate {
            icon = addBadgeToImage(icon)
        }

        return icon
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
        guard let appIcon = NSImage(named: iconName), let appIconCopy = appIcon.copy() as? NSImage else {
            return createCombinedPercentageIcon(data: data, types: types, isMonochrome: isMonochrome, button: button)
        }

        appIconCopy.size = NSSize(width: 18, height: 18)
        appIconCopy.isTemplate = isMonochrome

        // 创建百分比图标
        let percentageIcons = types.compactMap { type in
            createIconForType(type, data: data, isMonochrome: isMonochrome, button: button)
        }

        // 组合 App 图标 + 百分比图标
        var allIcons = [appIconCopy]
        allIcons.append(contentsOf: percentageIcons)

        let combined = combineIcons(allIcons, spacing: 3.0, height: 18)
        combined.isTemplate = isMonochrome
        return combined
    }
    
    // MARK: - Icon Drawing - Colored Mode (彩色模式)

    private func createCircleImage(percentage: Double, size: NSSize, useSevenDayColor: Bool = false, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
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

        // 7天限制使用虚线以区分5小时限制
        if useSevenDayColor {
            let dashPattern: [CGFloat] = [3, 1]
            backgroundPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        }

        backgroundPath.stroke()

        let color = useSevenDayColor ? UsageColorScheme.sevenDayColorAdaptive(percentage, for: button) : UsageColorScheme.fiveHourColorAdaptive(percentage, for: button)
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

        let fontSize: CGFloat = size.width * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = "\(Int(percentage))"
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

        let fontSize: CGFloat = size.width * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = "\(Int(percentage))"
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
        }
    }

}
