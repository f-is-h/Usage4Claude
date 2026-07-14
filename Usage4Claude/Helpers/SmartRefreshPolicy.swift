//
//  SmartRefreshPolicy.swift
//  Usage4Claude
//
//  Extracted from UserSettings.swift so the 4 级监控模式状态机 can live as pure,
//  UI/UserDefaults-free logic — cherry-pickable into a SwiftPM test target.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 智能刷新的 4 级监控模式状态机
/// 规则：任一 Provider 用量变化 → 立即切回活跃模式；全部无变化才逐级累计静默次数降频。
/// 纯逻辑，不依赖 Logger/UserDefaults/NotificationCenter —— 副作用（日志、通知）由调用方处理。
final class SmartRefreshPolicy {
    /// 当前监控模式
    var currentMode: MonitoringMode = .active
    /// 连续无变化次数
    var unchangedCount: Int = 0
    /// 保留旧字段语义，便于调试观察（等同于 claude 或首个 provider 的值）
    var lastUtilization: Double?

    private var lastUtilizationByProvider: [ProviderType: Double] = [:]

    /// 处理一轮用量检测结果
    /// - Parameter providerUtilizations: 本轮成功获取的 Provider 用量百分比
    /// - Returns: 是否发生了模式切换（调用方据此决定是否需要重启定时器/发通知）
    @discardableResult
    func update(providerUtilizations: [ProviderType: Double]) -> Bool {
        guard !providerUtilizations.isEmpty else { return false }

        let modeChanged: Bool
        if hasProviderUtilizationChanged(providerUtilizations) {
            modeChanged = switchToActiveMode()
        } else {
            modeChanged = handleNoChange()
        }

        for (provider, utilization) in providerUtilizations {
            lastUtilizationByProvider[provider] = utilization
        }
        lastUtilization = providerUtilizations[.claude] ?? providerUtilizations.values.first

        return modeChanged
    }

    /// 重置状态（切换到固定模式或用户手动刷新时调用）
    func reset() {
        lastUtilization = nil
        lastUtilizationByProvider.removeAll()
        unchangedCount = 0
        currentMode = .active
    }

    private func hasProviderUtilizationChanged(_ current: [ProviderType: Double]) -> Bool {
        current.contains { provider, utilization in
            guard let last = lastUtilizationByProvider[provider] else { return false }
            return abs(utilization - last) > 0.01
        }
    }

    @discardableResult
    private func switchToActiveMode() -> Bool {
        guard currentMode != .active else { return false }
        currentMode = .active
        unchangedCount = 0
        return true
    }

    @discardableResult
    private func handleNoChange() -> Bool {
        unchangedCount += 1
        guard let newMode = calculateNewMode() else { return false }
        currentMode = newMode
        unchangedCount = 0
        return true
    }

    /// 根据当前模式和无变化次数计算新模式
    /// - Returns: 如果需要切换，返回新模式；否则返回 nil
    private func calculateNewMode() -> MonitoringMode? {
        switch currentMode {
        case .active:
            // 活跃模式：连续3次无变化（3分钟） -> 短期静默
            return unchangedCount >= 3 ? .idleShort : nil
        case .idleShort:
            // 短期静默：连续6次无变化（18分钟） -> 中期静默
            return unchangedCount >= 6 ? .idleMedium : nil
        case .idleMedium:
            // 中期静默：连续12次无变化（60分钟） -> 长期静默
            return unchangedCount >= 12 ? .idleLong : nil
        case .idleLong:
            // 长期静默：保持当前模式
            return nil
        }
    }
}
