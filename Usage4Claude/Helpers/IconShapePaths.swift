//
//  IconShapePaths.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-18.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 图标形状路径工具类
/// 提供所有限制类型图标的形状路径生成方法
/// 支持 SwiftUI Path 和 NSBezierPath 两种格式
struct IconShapePaths {

    // MARK: - SwiftUI Path Methods

    /// 创建圆形路径
    /// - Parameter rect: 绘制区域
    /// - Returns: 圆形路径
    static func circlePath(in rect: CGRect) -> Path {
        Path { path in
            path.addEllipse(in: rect.insetBy(dx: 2, dy: 2))
        }
    }

    /// 创建圆角正方形路径（Opus）
    /// - Parameter rect: 绘制区域
    /// - Returns: 圆角正方形路径
    static func roundedSquarePath(in rect: CGRect) -> Path {
        Path { path in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let squareSize: CGFloat = 10
            let customRect = CGRect(
                x: center.x - squareSize / 2,
                y: center.y - squareSize / 2,
                width: squareSize,
                height: squareSize
            )
            path.addRoundedRect(in: customRect, cornerSize: CGSize(width: 2, height: 2))
        }
    }

    /// 创建右上角斜切的圆角正方形路径（Sonnet）
    /// - Parameter rect: 绘制区域
    /// - Returns: 斜切圆角正方形路径
    static func chamferedSquarePath(in rect: CGRect) -> Path {
        Path { path in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let squareSize: CGFloat = 10
            let customRect = CGRect(
                x: center.x - squareSize / 2,
                y: center.y - squareSize / 2,
                width: squareSize,
                height: squareSize
            )
            let cornerRadius: CGFloat = 2.0
            let cutSize: CGFloat = 2.5  // 右上角斜切大小

            // 从左下角开始
            path.move(to: CGPoint(x: customRect.minX, y: customRect.maxY - cornerRadius))

            // 左下圆角
            path.addArc(
                center: CGPoint(x: customRect.minX + cornerRadius, y: customRect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .init(degrees: 180),
                endAngle: .init(degrees: 90),
                clockwise: true
            )

            // 底边到右下角
            path.addLine(to: CGPoint(x: customRect.maxX - cornerRadius, y: customRect.maxY))

            // 右下圆角
            path.addArc(
                center: CGPoint(x: customRect.maxX - cornerRadius, y: customRect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .init(degrees: 90),
                endAngle: .init(degrees: 0),
                clockwise: true
            )

            // 右边到斜切位置（向上到右上角斜切点）
            path.addLine(to: CGPoint(x: customRect.maxX, y: customRect.minY + cutSize))

            // 斜切线（从右上斜切到左边）
            path.addLine(to: CGPoint(x: customRect.maxX - cutSize, y: customRect.minY))

            // 顶边到左上角
            path.addLine(to: CGPoint(x: customRect.minX + cornerRadius, y: customRect.minY))

            // 左上圆角
            path.addArc(
                center: CGPoint(x: customRect.minX + cornerRadius, y: customRect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .init(degrees: 270),
                endAngle: .init(degrees: 180),
                clockwise: true
            )

            // 回到起点
            path.closeSubpath()
        }
    }

    /// 创建平顶六边形路径（Extra Usage）
    /// - Parameters:
    ///   - center: 六边形中心点
    ///   - radius: 六边形半径
    /// - Returns: 六边形路径
    static func hexagonPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3.0
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
    }

    /// 根据限制类型获取对应的形状路径
    /// - Parameters:
    ///   - type: 限制类型
    ///   - rect: 绘制区域
    /// - Returns: 对应的形状路径
    static func pathForLimitType(_ type: LimitType, in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        switch type {
        case .fiveHour, .sevenDay:
            return circlePath(in: rect)

        case .opusWeekly:
            return roundedSquarePath(in: rect)

        case .sonnetWeekly:
            return chamferedSquarePath(in: rect)

        case .extraUsage:
            return hexagonPath(center: center, radius: 6)
        }
    }

    // MARK: - NSBezierPath Methods (for MenuBarIconRenderer)

    /// 创建圆角正方形 NSBezierPath（Opus）
    /// - Parameters:
    ///   - center: 中心点
    ///   - size: 正方形边长
    /// - Returns: NSBezierPath
    static func roundedSquareNSPath(center: CGPoint, size: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let rect = CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        path.appendRoundedRect(rect, xRadius: 2, yRadius: 2)
        return path
    }

    /// 创建右上角斜切的圆角正方形 NSBezierPath（Sonnet）
    /// - Parameters:
    ///   - center: 中心点
    ///   - size: 正方形边长
    /// - Returns: NSBezierPath
    static func chamferedSquareNSPath(center: CGPoint, size: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let rect = CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        let cornerRadius: CGFloat = 2.0
        let cutSize: CGFloat = 2.5

        // 从左下角开始
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

        // 左边到左下圆角
        path.appendArc(
            withCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 180,
            endAngle: 270,
            clockwise: false
        )

        // 底边到右下圆角
        path.line(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.appendArc(
            withCenter: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 270,
            endAngle: 0,
            clockwise: false
        )

        // 右边到斜切位置
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - cutSize))

        // 斜切线
        path.line(to: CGPoint(x: rect.maxX - cutSize, y: rect.maxY))

        // 顶边到左上圆角
        path.line(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.appendArc(
            withCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: 90,
            endAngle: 180,
            clockwise: false
        )

        path.close()
        return path
    }

    /// 创建平顶六边形 NSBezierPath（Extra Usage）
    /// - Parameters:
    ///   - center: 中心点
    ///   - radius: 半径
    /// - Returns: NSBezierPath
    static func hexagonNSPath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.line(to: CGPoint(x: x, y: y))
            }
        }

        path.close()
        return path
    }
}
