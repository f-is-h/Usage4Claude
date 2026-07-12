//
//  LaunchAtLoginManager.swift
//  Usage4Claude
//
//  Extracted from UserSettings.swift（审计报告 4.1）。原实现用一个存储的 Bool +
//  isSyncingLaunchStatus 标志位防止 didSet 递归触发注册/注销，且失败时靠
//  DispatchQueue.main.async 异步写回旧值，这本身有竞态（写回执行前用户再次切换
//  Toggle，标志位状态就乱了）。SMAppService.mainApp.status 才是真正的事实来源——
//  现有代码本来就在启动和 didBecomeActive 时用它覆盖存储值，所以这里把 isEnabled
//  改成直接派生自 status 的计算属性，从根上消灭标志位和竞态：Toggle 绑定
//  isEnabled，失败时 refreshStatus() 让 status 保持原值，SwiftUI 自动把 Toggle 弹回。
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import Combine
import ServiceManagement
import OSLog

/// 开机启动的注册/注销与状态同步
final class LaunchAtLoginManager: ObservableObject {
    private let defaults = UserDefaults.standard

    /// 唯一事实来源：系统实际注册状态
    @Published private(set) var status: SMAppService.Status

    init() {
        status = SMAppService.mainApp.status
    }

    /// 供 Toggle 双向绑定；set 直接调用 enable()/disable()，不经过任何存储属性的 didSet，
    /// 因此不存在递归触发的问题，也就不需要 isSyncingLaunchStatus 这类标志位。
    var isEnabled: Bool {
        get { status == .enabled }
        set { newValue ? enable() : disable() }
    }

    /// 启用开机启动
    func enable() {
        do {
            try SMAppService.mainApp.register()
            Logger.settings.notice("开机启动已启用")
        } catch {
            Logger.settings.error("启用开机启动失败: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: .launchAtLoginError,
                object: nil,
                userInfo: ["error": error, "operation": "enable"]
            )
        }
        // 成功或失败都以系统状态为准；失败时 status 保持不变，Toggle 会自动弹回
        refreshStatus()
    }

    /// 禁用开机启动
    func disable() {
        let currentStatus = SMAppService.mainApp.status

        // 如果服务未注册或未找到，直接同步状态，不执行 unregister 操作
        guard currentStatus != .notRegistered && currentStatus != .notFound else {
            Logger.settings.notice("开机启动服务未注册，已更新设置")
            refreshStatus()
            return
        }

        do {
            try SMAppService.mainApp.unregister()
            Logger.settings.notice("开机启动已禁用")
        } catch {
            Logger.settings.error("禁用开机启动失败: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: .launchAtLoginError,
                object: nil,
                userInfo: ["error": error, "operation": "disable"]
            )
        }
        refreshStatus()
    }

    /// 从系统读取实际状态并更新
    /// 替代原 syncLaunchAtLoginStatus，应用启动和 didBecomeActive 时调用
    func refreshStatus() {
        let newStatus = SMAppService.mainApp.status
        DispatchQueue.main.async {
            // @Published 赋值即使值不变也会触发 objectWillChange，
            // 确保 Toggle 在失败路径下也能重新读取 isEnabled 并弹回
            self.status = newStatus
            // 镜像写入 UserDefaults，兼容任何仍读取这个 key 的旧逻辑（目前没有）
            self.defaults.set(newStatus == .enabled, forKey: "launchAtLogin")
        }
        Logger.settings.debug("开机启动状态: \(String(describing: newStatus))")
    }
}
