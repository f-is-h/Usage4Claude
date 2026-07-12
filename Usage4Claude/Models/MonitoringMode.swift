//
//  MonitoringMode.swift
//  Usage4Claude
//
//  Extracted from UserSettings.swift so SmartRefreshPolicy (and its tests) don't
//  need to pull in UserSettings' full AppKit/Keychain dependency footprint.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 监控模式（内部使用，智能频率下的4级模式）
enum MonitoringMode: String, Codable {
    /// 活跃模式 - 1分钟刷新
    case active = "active"
    /// 短期静默 - 3分钟刷新
    case idleShort = "idle_short"
    /// 中期静默 - 5分钟刷新
    case idleMedium = "idle_medium"
    /// 长期静默 - 10分钟刷新
    case idleLong = "idle_long"

    /// 获取对应的刷新间隔（秒）
    var interval: Int {
        switch self {
        case .active:
            return 60      // 1分钟
        case .idleShort:
            return 180     // 3分钟
        case .idleMedium:
            return 300     // 5分钟
        case .idleLong:
            return 600     // 10分钟
        }
    }
}
