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
        let size = NSSize(width: 22, height: 22)

        // 根据显示模式选择图标样式
        let isTemplateMode = settings.iconStyleMode == .monochrome
        let removeBackground = settings.iconStyleMode == .colorTranslucent

        // 无数据时显示默认图标
        guard let data = usageData else {
            return isTemplateMode ?
                createCircleTemplateImage(percentage: 0, size: size, button: button, removeBackground: true) :
                createCircleImage(percentage: 0, size: size, button: button, removeBackground: true)
        }

        var icon: NSImage

        // 根据显示模式创建图标
        switch settings.iconDisplayMode {
        case .percentageOnly:
            if data.hasBothLimits, let fiveHour = data.fiveHour, let sevenDay = data.sevenDay {
                icon = isTemplateMode ?
                    createDualCircleTemplateImage(fiveHourPercentage: fiveHour.percentage, sevenDayPercentage: sevenDay.percentage, size: size, button: button, removeBackground: removeBackground) :
                    createDualCircleImage(fiveHourPercentage: fiveHour.percentage, sevenDayPercentage: sevenDay.percentage, size: size, button: button, removeBackground: removeBackground)
            } else if let fiveHour = data.fiveHour {
                icon = isTemplateMode ?
                    createCircleTemplateImage(percentage: fiveHour.percentage, size: size, button: button, removeBackground: removeBackground) :
                    createCircleImage(percentage: fiveHour.percentage, size: size, button: button, removeBackground: removeBackground)
            } else if let sevenDay = data.sevenDay {
                icon = isTemplateMode ?
                    createCircleTemplateImage(percentage: sevenDay.percentage, size: size, button: button, removeBackground: removeBackground) :
                    createCircleImage(percentage: sevenDay.percentage, size: size, useSevenDayColor: true, button: button, removeBackground: removeBackground)
            } else {
                // Fallback
                icon = createSimpleCircleIcon()
            }

        case .iconOnly:
            if let appIcon = NSImage(named: "AppIcon"), let iconCopy = appIcon.copy() as? NSImage {
                iconCopy.size = NSSize(width: 18, height: 18)
                iconCopy.isTemplate = isTemplateMode
                icon = iconCopy
            } else {
                icon = createSimpleCircleIcon()
            }

        case .both:
            if data.hasBothLimits, let fiveHour = data.fiveHour, let sevenDay = data.sevenDay {
                icon = isTemplateMode ?
                    createCombinedDualTemplateImage(fiveHourPercentage: fiveHour.percentage, sevenDayPercentage: sevenDay.percentage, button: button, removeBackground: removeBackground) :
                    createCombinedDualImage(fiveHourPercentage: fiveHour.percentage, sevenDayPercentage: sevenDay.percentage, button: button, removeBackground: removeBackground)
            } else if let fiveHour = data.fiveHour {
                icon = isTemplateMode ?
                    createCombinedTemplateImage(percentage: fiveHour.percentage, button: button, removeBackground: removeBackground) :
                    createCombinedImage(percentage: fiveHour.percentage, button: button, removeBackground: removeBackground)
            } else if let sevenDay = data.sevenDay {
                icon = isTemplateMode ?
                    createCombinedTemplateImage(percentage: sevenDay.percentage, button: button, removeBackground: removeBackground) :
                    createCombinedImage(percentage: sevenDay.percentage, useSevenDayColor: true, button: button, removeBackground: removeBackground)
            } else {
                icon = createSimpleCircleIcon()
            }
        }

        // 如果需要徽章，添加徽章
        if hasUpdate {
            icon = addBadgeToImage(icon)
        }

        return icon
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

        NSColor.gray.withAlphaComponent(0.7).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        backgroundPath.lineWidth = 2.0
        backgroundPath.stroke()

        let color = useSevenDayColor ? UsageColorScheme.sevenDayColorAdaptive(percentage, for: button) : UsageColorScheme.fiveHourColorAdaptive(percentage, for: button)
        color.setStroke()

        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (CGFloat(percentage) / 100.0 * 360)

        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = 2.5
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

    private func createDualCircleImage(fiveHourPercentage: Double, sevenDayPercentage: Double, size: NSSize, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let circleSize = min(size.width, size.height)
        let spacing: CGFloat = 2
        let totalWidth = circleSize + spacing + circleSize
        let image = NSImage(size: NSSize(width: totalWidth, height: size.height))
        image.lockFocus()

        let radius = circleSize / 2 - 2
        let leftCenter = NSPoint(x: circleSize / 2, y: size.height / 2)
        let rightCenter = NSPoint(x: circleSize + spacing + circleSize / 2, y: size.height / 2)

        // 左圆环（5小时）
        if !removeBackground {
            let leftBackgroundCircle = NSBezierPath()
            leftBackgroundCircle.appendArc(withCenter: leftCenter, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
            NSColor(white: 1, alpha: 0.5).setFill()
            leftBackgroundCircle.fill()
        }

        NSColor.gray.withAlphaComponent(0.7).setStroke()
        let leftBackgroundPath = NSBezierPath()
        leftBackgroundPath.appendArc(withCenter: leftCenter, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        leftBackgroundPath.lineWidth = 2.0
        leftBackgroundPath.stroke()

        UsageColorScheme.fiveHourColorAdaptive(fiveHourPercentage, for: button).setStroke()
        let leftProgressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let leftEndAngle = startAngle - (CGFloat(fiveHourPercentage) / 100.0 * 360)
        leftProgressPath.appendArc(withCenter: leftCenter, radius: radius, startAngle: startAngle, endAngle: leftEndAngle, clockwise: true)
        leftProgressPath.lineWidth = 2.5
        leftProgressPath.stroke()

        // 右圆环（7天）
        if !removeBackground {
            let rightBackgroundCircle = NSBezierPath()
            rightBackgroundCircle.appendArc(withCenter: rightCenter, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
            NSColor(white: 1, alpha: 0.5).setFill()
            rightBackgroundCircle.fill()
        }

        NSColor.gray.withAlphaComponent(0.7).setStroke()
        let rightBackgroundPath = NSBezierPath()
        rightBackgroundPath.appendArc(withCenter: rightCenter, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        rightBackgroundPath.lineWidth = 2.0
        rightBackgroundPath.stroke()

        UsageColorScheme.sevenDayColorAdaptive(sevenDayPercentage, for: button).setStroke()
        let rightProgressPath = NSBezierPath()
        let rightEndAngle = startAngle - (CGFloat(sevenDayPercentage) / 100.0 * 360)
        rightProgressPath.appendArc(withCenter: rightCenter, radius: radius, startAngle: startAngle, endAngle: rightEndAngle, clockwise: true)
        rightProgressPath.lineWidth = 2.5
        rightProgressPath.stroke()

        let fontSize: CGFloat = circleSize * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraphStyle]

        let leftText = "\(Int(fiveHourPercentage))"
        let leftTextSize = leftText.size(withAttributes: attrs)
        leftText.draw(at: NSPoint(x: leftCenter.x - leftTextSize.width / 2, y: leftCenter.y - leftTextSize.height / 2), withAttributes: attrs)

        let rightText = "\(Int(sevenDayPercentage))"
        let rightTextSize = rightText.size(withAttributes: attrs)
        rightText.draw(at: NSPoint(x: rightCenter.x - rightTextSize.width / 2, y: rightCenter.y - rightTextSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    private func createCombinedImage(percentage: Double, useSevenDayColor: Bool = false, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 42, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()

        if let appIcon = NSImage(named: "AppIcon"), let iconCopy = appIcon.copy() as? NSImage {
            iconCopy.isTemplate = false
            iconCopy.size = NSSize(width: 16, height: 16)
            iconCopy.draw(in: NSRect(x: 1, y: 2, width: 16, height: 16))
        }

        let circleX: CGFloat = 20
        let center = NSPoint(x: circleX + 10, y: 10)
        let radius: CGFloat = 8

        if !removeBackground {
            let backgroundCircle = NSBezierPath()
            backgroundCircle.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
            NSColor.white.withAlphaComponent(0.5).setFill()
            backgroundCircle.fill()
        }

        NSColor.gray.withAlphaComponent(0.7).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        backgroundPath.lineWidth = 2.0
        backgroundPath.stroke()

        let color = useSevenDayColor ? UsageColorScheme.sevenDayColorAdaptive(percentage, for: button) : UsageColorScheme.fiveHourColorAdaptive(percentage, for: button)
        color.setStroke()

        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (CGFloat(percentage) / 100.0 * 360)
        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = 2.5
        progressPath.stroke()

        let font = NSFont.systemFont(ofSize: 8, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraphStyle]

        let text = "\(Int(percentage))"
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    private func createCombinedDualImage(fiveHourPercentage: Double, sevenDayPercentage: Double, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 60, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()

        if let appIcon = NSImage(named: "AppIcon"), let iconCopy = appIcon.copy() as? NSImage {
            iconCopy.isTemplate = false
            iconCopy.size = NSSize(width: 16, height: 16)
            iconCopy.draw(in: NSRect(x: 1, y: 2, width: 16, height: 16))
        }

        let circlesStartX: CGFloat = 20
        let circleRadius: CGFloat = 8
        let circleSpacing: CGFloat = 4
        let leftCenter = NSPoint(x: circlesStartX + circleRadius, y: 10)
        let rightCenter = NSPoint(x: circlesStartX + circleRadius * 2 + circleSpacing + circleRadius, y: 10)

        // 左圆环
        if !removeBackground {
            let leftBackgroundCircle = NSBezierPath()
            leftBackgroundCircle.appendArc(withCenter: leftCenter, radius: circleRadius, startAngle: 0, endAngle: 360, clockwise: false)
            NSColor.white.withAlphaComponent(0.5).setFill()
            leftBackgroundCircle.fill()
        }

        NSColor.gray.withAlphaComponent(0.7).setStroke()
        let leftBackgroundPath = NSBezierPath()
        leftBackgroundPath.appendArc(withCenter: leftCenter, radius: circleRadius, startAngle: 0, endAngle: 360, clockwise: false)
        leftBackgroundPath.lineWidth = 2.0
        leftBackgroundPath.stroke()

        UsageColorScheme.fiveHourColorAdaptive(fiveHourPercentage, for: button).setStroke()
        let leftProgressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let leftEndAngle = startAngle - (CGFloat(fiveHourPercentage) / 100.0 * 360)
        leftProgressPath.appendArc(withCenter: leftCenter, radius: circleRadius, startAngle: startAngle, endAngle: leftEndAngle, clockwise: true)
        leftProgressPath.lineWidth = 2.5
        leftProgressPath.stroke()

        // 右圆环
        if !removeBackground {
            let rightBackgroundCircle = NSBezierPath()
            rightBackgroundCircle.appendArc(withCenter: rightCenter, radius: circleRadius, startAngle: 0, endAngle: 360, clockwise: false)
            NSColor.white.withAlphaComponent(0.5).setFill()
            rightBackgroundCircle.fill()
        }

        NSColor.gray.withAlphaComponent(0.7).setStroke()
        let rightBackgroundPath = NSBezierPath()
        rightBackgroundPath.appendArc(withCenter: rightCenter, radius: circleRadius, startAngle: 0, endAngle: 360, clockwise: false)
        rightBackgroundPath.lineWidth = 2.0
        rightBackgroundPath.stroke()

        UsageColorScheme.sevenDayColorAdaptive(sevenDayPercentage, for: button).setStroke()
        let rightProgressPath = NSBezierPath()
        let rightEndAngle = startAngle - (CGFloat(sevenDayPercentage) / 100.0 * 360)
        rightProgressPath.appendArc(withCenter: rightCenter, radius: circleRadius, startAngle: startAngle, endAngle: rightEndAngle, clockwise: true)
        rightProgressPath.lineWidth = 2.5
        rightProgressPath.stroke()

        let font = NSFont.systemFont(ofSize: 8, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraphStyle]

        let leftText = "\(Int(fiveHourPercentage))"
        let leftTextSize = leftText.size(withAttributes: attrs)
        leftText.draw(at: NSPoint(x: leftCenter.x - leftTextSize.width / 2, y: leftCenter.y - leftTextSize.height / 2), withAttributes: attrs)

        let rightText = "\(Int(sevenDayPercentage))"
        let rightTextSize = rightText.size(withAttributes: attrs)
        rightText.draw(at: NSPoint(x: rightCenter.x - rightTextSize.width / 2, y: rightCenter.y - rightTextSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    // MARK: - Icon Drawing - Template Mode (单色模式)

    private func createCircleTemplateImage(percentage: Double, size: NSSize, button: NSStatusBarButton? = nil, removeBackground: Bool = false) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 2

        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        backgroundPath.lineWidth = 1.5
        backgroundPath.stroke()

        NSColor.labelColor.setStroke()
        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (CGFloat(percentage) / 100.0 * 360)
        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = 2.5
        progressPath.lineCapStyle = .round
        progressPath.stroke()

        let fontSize: CGFloat = size.width * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = "\(Int(percentage))"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraphStyle]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func createDualCircleTemplateImage(fiveHourPercentage: Double, sevenDayPercentage: Double, size: NSSize, button: NSStatusBarButton? = nil, removeBackground: Bool = false) -> NSImage {
        let circleSize = min(size.width, size.height)
        let spacing: CGFloat = 2
        let totalWidth = circleSize + spacing + circleSize
        let image = NSImage(size: NSSize(width: totalWidth, height: size.height))
        image.lockFocus()

        let radius = circleSize / 2 - 2
        let leftCenter = NSPoint(x: circleSize / 2, y: size.height / 2)
        let rightCenter = NSPoint(x: circleSize + spacing + circleSize / 2, y: size.height / 2)

        // 左圆环
        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        let leftBackgroundPath = NSBezierPath()
        leftBackgroundPath.appendArc(withCenter: leftCenter, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        leftBackgroundPath.lineWidth = 1.5
        leftBackgroundPath.stroke()

        NSColor.labelColor.setStroke()
        let leftProgressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let leftEndAngle = startAngle - (CGFloat(fiveHourPercentage) / 100.0 * 360)
        leftProgressPath.appendArc(withCenter: leftCenter, radius: radius, startAngle: startAngle, endAngle: leftEndAngle, clockwise: true)
        leftProgressPath.lineWidth = 2.5
        leftProgressPath.lineCapStyle = .round
        leftProgressPath.stroke()

        // 右圆环
        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        let rightBackgroundPath = NSBezierPath()
        rightBackgroundPath.appendArc(withCenter: rightCenter, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        rightBackgroundPath.lineWidth = 1.5
        rightBackgroundPath.stroke()

        NSColor.labelColor.setStroke()
        let rightProgressPath = NSBezierPath()
        let rightEndAngle = startAngle - (CGFloat(sevenDayPercentage) / 100.0 * 360)
        rightProgressPath.appendArc(withCenter: rightCenter, radius: radius, startAngle: startAngle, endAngle: rightEndAngle, clockwise: true)
        rightProgressPath.lineWidth = 2.5
        rightProgressPath.lineCapStyle = .round
        rightProgressPath.stroke()

        let fontSize: CGFloat = circleSize * 0.4
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraphStyle]

        let leftText = "\(Int(fiveHourPercentage))"
        let leftTextSize = leftText.size(withAttributes: attrs)
        leftText.draw(at: NSPoint(x: leftCenter.x - leftTextSize.width / 2, y: leftCenter.y - leftTextSize.height / 2), withAttributes: attrs)

        let rightText = "\(Int(sevenDayPercentage))"
        let rightTextSize = rightText.size(withAttributes: attrs)
        rightText.draw(at: NSPoint(x: rightCenter.x - rightTextSize.width / 2, y: rightCenter.y - rightTextSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func createCombinedTemplateImage(percentage: Double, button: NSStatusBarButton? = nil, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 42, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()

        if let appIcon = NSImage(named: "AppIcon"), let iconCopy = appIcon.copy() as? NSImage {
            iconCopy.isTemplate = true
            iconCopy.size = NSSize(width: 16, height: 16)
            iconCopy.draw(in: NSRect(x: 1, y: 2, width: 16, height: 16))
        }

        let circleX: CGFloat = 20
        let center = NSPoint(x: circleX + 10, y: 10)
        let radius: CGFloat = 8

        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        backgroundPath.lineWidth = 1.5
        backgroundPath.stroke()

        NSColor.labelColor.setStroke()
        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (CGFloat(percentage) / 100.0 * 360)
        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = 2.5
        progressPath.lineCapStyle = .round
        progressPath.stroke()

        let font = NSFont.systemFont(ofSize: 8, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraphStyle]

        let text = "\(Int(percentage))"
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2), withAttributes: attrs)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func createCombinedDualTemplateImage(fiveHourPercentage: Double, sevenDayPercentage: Double, button: NSStatusBarButton? = nil, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 60, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()

        if let appIcon = NSImage(named: "AppIcon"), let iconCopy = appIcon.copy() as? NSImage {
            iconCopy.isTemplate = true
            iconCopy.size = NSSize(width: 16, height: 16)
            iconCopy.draw(in: NSRect(x: 1, y: 2, width: 16, height: 16))
        }

        let circlesStartX: CGFloat = 20
        let circleRadius: CGFloat = 8
        let circleSpacing: CGFloat = 4
        let leftCenter = NSPoint(x: circlesStartX + circleRadius, y: 10)
        let rightCenter = NSPoint(x: circlesStartX + circleRadius * 2 + circleSpacing + circleRadius, y: 10)

        // 左圆环
        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        let leftBackgroundPath = NSBezierPath()
        leftBackgroundPath.appendArc(withCenter: leftCenter, radius: circleRadius, startAngle: 0, endAngle: 360, clockwise: false)
        leftBackgroundPath.lineWidth = 1.5
        leftBackgroundPath.stroke()

        NSColor.labelColor.setStroke()
        let leftProgressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let leftEndAngle = startAngle - (CGFloat(fiveHourPercentage) / 100.0 * 360)
        leftProgressPath.appendArc(withCenter: leftCenter, radius: circleRadius, startAngle: startAngle, endAngle: leftEndAngle, clockwise: true)
        leftProgressPath.lineWidth = 2.5
        leftProgressPath.lineCapStyle = .round
        leftProgressPath.stroke()

        // 右圆环
        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        let rightBackgroundPath = NSBezierPath()
        rightBackgroundPath.appendArc(withCenter: rightCenter, radius: circleRadius, startAngle: 0, endAngle: 360, clockwise: false)
        rightBackgroundPath.lineWidth = 1.5
        rightBackgroundPath.stroke()

        NSColor.labelColor.setStroke()
        let rightProgressPath = NSBezierPath()
        let rightEndAngle = startAngle - (CGFloat(sevenDayPercentage) / 100.0 * 360)
        rightProgressPath.appendArc(withCenter: rightCenter, radius: circleRadius, startAngle: startAngle, endAngle: rightEndAngle, clockwise: true)
        rightProgressPath.lineWidth = 2.5
        rightProgressPath.lineCapStyle = .round
        rightProgressPath.stroke()

        let font = NSFont.systemFont(ofSize: 8, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraphStyle]

        let leftText = "\(Int(fiveHourPercentage))"
        let leftTextSize = leftText.size(withAttributes: attrs)
        leftText.draw(at: NSPoint(x: leftCenter.x - leftTextSize.width / 2, y: leftCenter.y - leftTextSize.height / 2), withAttributes: attrs)

        let rightText = "\(Int(sevenDayPercentage))"
        let rightTextSize = rightText.size(withAttributes: attrs)
        rightText.draw(at: NSPoint(x: rightCenter.x - rightTextSize.width / 2, y: rightCenter.y - rightTextSize.height / 2), withAttributes: attrs)

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

}
