//
//  ResetTimeChange.swift
//  Usage4Claude
//
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 检测重置时间是否发生变化，用于决定「重置验证」定时器该取消还是重新调度
/// - Parameters:
///   - oldTime: 上次记录的重置时间
///   - newTime: 最新拉取到的重置时间
/// - Returns: 若两者相差超过 1 秒（含一个为 nil 一个不为 nil 的情况）则视为发生了变化
func hasResetTimeChanged(from oldTime: Date?, to newTime: Date?) -> Bool {
    if oldTime == nil && newTime == nil {
        return false
    }
    if (oldTime == nil) != (newTime == nil) {
        return true
    }
    if let old = oldTime, let new = newTime {
        return abs(old.timeIntervalSince(new)) > 1.0
    }
    return false
}
