//
//  ImageHelper+Antigravity.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//

import AppKit

extension ImageHelper {

    /// Antigravity 品牌图标：代码绘制的拱形「A」，不依赖资源文件
    /// - Parameters:
    ///   - size: 边长
    ///   - isMonochrome: 单色模式返回 template 图像，由系统按菜单栏外观着色
    static func createAntigravityIcon(size: CGFloat, isMonochrome: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let path = archPath(in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.1))
            if isMonochrome {
                NSColor.black.setFill()
                path.fill()
            } else {
                NSGraphicsContext.saveGraphicsState()
                path.addClip()
                let gradient = NSGradient(colors: [
                    NSColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1),  // 蓝
                    NSColor(red: 0.58, green: 0.40, blue: 0.95, alpha: 1),  // 紫
                    NSColor(red: 0.92, green: 0.35, blue: 0.45, alpha: 1)   // 红
                ])
                gradient?.draw(in: rect, angle: -45)
                NSGraphicsContext.restoreGraphicsState()
            }
            return true
        }
        image.isTemplate = isMonochrome
        return image
    }

    /// 拱形路径：外弧从左下经顶部到右下，内弧反向收回，底部两条腿
    private static func archPath(in rect: NSRect) -> NSBezierPath {
        let thickness = rect.width * 0.26
        let center = NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.42)
        let outerRadius = rect.width / 2
        let innerRadius = outerRadius - thickness

        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.minX, y: center.y))
        path.appendArc(withCenter: center, radius: outerRadius, startAngle: 180, endAngle: 0, clockwise: true)
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - thickness, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - thickness, y: center.y))
        path.appendArc(withCenter: center, radius: innerRadius, startAngle: 0, endAngle: 180, clockwise: false)
        path.line(to: NSPoint(x: rect.minX + thickness, y: rect.minY))
        path.close()
        return path
    }
}
