//
//  TimerManager.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-01.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import OSLog

/// 定时器统一管理器
/// 负责应用内所有定时器的创建、调度和清理，防止内存泄漏
/// 提供类型安全的定时器标识符管理
class TimerManager {
    // MARK: - Properties

    /// 定时器存储字典，键为标识符，值为 Timer 实例
    private var timers: [String: Timer] = [:]

    /// 线程安全队列
    private let queue = DispatchQueue(label: "com.usage4claude.timer", attributes: .concurrent)

    // MARK: - Public Methods

    /// 调度定时器
    /// - Parameters:
    ///   - identifier: 定时器唯一标识符
    ///   - interval: 时间间隔（秒）
    ///   - repeats: 是否重复执行
    ///   - block: 定时器触发时执行的闭包
    /// - Note: 如果相同标识符的定时器已存在，会先取消旧定时器
    func schedule(
        _ identifier: String,
        interval: TimeInterval,
        repeats: Bool = true,
        block: @escaping () -> Void
    ) {
        // 先取消同标识符的旧定时器
        invalidate(identifier)

        // 创建新定时器
        let timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: repeats
        ) { _ in
            block()
        }

        // 线程安全地保存定时器
        queue.async(flags: .barrier) {
            self.timers[identifier] = timer
        }

        Logger.menuBar.info("⏰ Timer scheduled: \(identifier) (interval: \(interval)s, repeats: \(repeats))")
    }

    /// 取消指定定时器
    /// - Parameter identifier: 定时器标识符
    func invalidate(_ identifier: String) {
        queue.async(flags: .barrier) {
            if let timer = self.timers[identifier] {
                timer.invalidate()
                self.timers.removeValue(forKey: identifier)
                Logger.menuBar.info("⏹️ Timer invalidated: \(identifier)")
            }
        }
    }

    /// 取消所有定时器
    /// - Note: 通常在应用退出或重大状态变更时调用
    func invalidateAll() {
        queue.async(flags: .barrier) {
            let count = self.timers.count
            self.timers.values.forEach { $0.invalidate() }
            self.timers.removeAll()
            Logger.menuBar.info("🛑 All timers invalidated (count: \(count))")
        }
    }

    /// 检查指定定时器是否活跃
    /// - Parameter identifier: 定时器标识符
    /// - Returns: 如果定时器存在且有效返回 true
    func isActive(_ identifier: String) -> Bool {
        return queue.sync {
            return timers[identifier]?.isValid ?? false
        }
    }

    /// 获取当前活跃的定时器列表
    /// - Returns: 活跃定时器的标识符数组
    /// - Note: 主要用于调试和诊断
    func activeTimers() -> [String] {
        return queue.sync {
            return timers.keys.filter { timers[$0]?.isValid == true }
        }
    }

    // MARK: - Deinit

    deinit {
        invalidateAll()
    }
}

// MARK: - Timer Identifiers

/// 定时器标识符命名空间
/// 提供类型安全的定时器标识符常量
extension TimerManager {
    /// 定时器标识符枚举
    enum Identifier {
        /// 主数据刷新定时器
        static let mainRefresh = "mainRefresh"
        /// 弹出窗口实时刷新定时器（1秒间隔）
        static let popoverRefresh = "popoverRefresh"
        /// 重置验证定时器 - 重置后1秒
        static let resetVerify1 = "resetVerify1"
        /// 重置验证定时器 - 重置后10秒
        static let resetVerify2 = "resetVerify2"
        /// 重置验证定时器 - 重置后30秒
        static let resetVerify3 = "resetVerify3"
        /// 每日更新检查定时器
        static let dailyUpdate = "dailyUpdate"
    }
}
