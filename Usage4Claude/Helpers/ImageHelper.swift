//
//  ImageHelper.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import AppKit

/// 图像处理辅助工具
/// 提供应用图标创建、缓存等功能
enum ImageHelper {
    // MARK: - Cache

    /// SwiftUI 按对象身份比较 `Image(nsImage:)`：每次 body 重算都新建 NSImage 会被当成换图，
    /// 处在动画事务里（切换剩余显示、刷新按钮旋转）就会做一次交叉淡入，看起来是图标闪一下。
    /// 同尺寸复用同一个实例即可避免；返回的图像由调用方只读使用，不要修改。
    private static let iconCache = NSCache<NSString, NSImage>()

    private static func cachedIcon(key: String, make: () -> NSImage?) -> NSImage? {
        let cacheKey = key as NSString
        if let cached = iconCache.object(forKey: cacheKey) { return cached }
        guard let image = make() else { return nil }
        iconCache.setObject(image, forKey: cacheKey)
        return image
    }

    // MARK: - App Icon

    /// 创建应用图标（非模板模式），同尺寸返回缓存的同一实例
    /// - Parameter size: 图标大小
    /// - Returns: 指定大小的应用图标，如果无法加载则返回 nil
    static func createAppIcon(size: CGFloat) -> NSImage? {
        cachedIcon(key: "AppIcon-\(size)") {
            guard let appIcon = NSImage(named: "AppIcon") else { return nil }
            guard let iconCopy = appIcon.copy() as? NSImage else { return nil }
            iconCopy.isTemplate = false
            iconCopy.size = NSSize(width: size, height: size)
            return iconCopy
        }
    }

    /// 创建应用图标（非模板模式，指定宽高）
    /// - Parameters:
    ///   - width: 图标宽度
    ///   - height: 图标高度
    /// - Returns: 指定尺寸的应用图标，如果无法加载则返回 nil
    static func createAppIcon(width: CGFloat, height: CGFloat) -> NSImage? {
        guard let appIcon = NSImage(named: "AppIcon") else { return nil }
        guard let iconCopy = appIcon.copy() as? NSImage else { return nil }
        iconCopy.isTemplate = false
        iconCopy.size = NSSize(width: width, height: height)
        return iconCopy
    }

    // MARK: - Codex Icon

    /// 同尺寸返回缓存的同一实例，原因见 `iconCache`。
    /// lockFocus 按当时主屏倍率出位图，倍率也进 key，1x/Retina 屏之间切换时重新生成
    static func createCodexIcon(size: CGFloat) -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return cachedIcon(key: "CodexIcon-\(size)@\(scale)x") {
            createSquareIcon(named: "CodexIcon", size: size, isTemplate: false, sourceInset: 2)
        }
    }

    /// 从资源中创建正方形图标。部分透明 PNG 的边缘 RGB 不是透明白，
    /// 直接缩放时会被 AppKit 采样成细暗线，因此这里先居中裁方并略微内收。
    static func createSquareIcon(named name: String, size: CGFloat, isTemplate: Bool, sourceInset: CGFloat = 0) -> NSImage? {
        guard let source = NSImage(named: name) else { return nil }
        let targetSize = NSSize(width: size, height: size)
        let image = NSImage(size: targetSize)

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: targetSize).fill()

        let sourceSize = source.size
        let side = min(sourceSize.width, sourceSize.height) - sourceInset * 2
        let cropRect = NSRect(
            x: (sourceSize.width - side) / 2,
            y: (sourceSize.height - side) / 2,
            width: side,
            height: side
        )

        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: cropRect,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
        )
        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }

    // MARK: - System Images

    /// 创建系统符号图像
    /// - Parameters:
    ///   - systemName: SF Symbols 名称
    ///   - size: 图像大小
    ///   - weight: 符号粗细
    /// - Returns: 创建的系统图像，如果无法加载则返回 nil
    static func createSystemImage(
        systemName: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        return NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}
