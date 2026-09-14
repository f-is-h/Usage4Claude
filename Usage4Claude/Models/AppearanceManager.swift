//
//  AppearanceManager.swift
//  Usage4Claude
//
//  Extracted from UserSettings.swift（审计报告 4.1）：外观模式持久化、应用到 NSApp、
//  以及系统主题切换的观察者，原样平移。
//  Copyright © 2025 f-is-h. All rights reserved.
//

import AppKit
import Combine

/// 应用外观（浅色/深色/跟随系统）管理
final class AppearanceManager: ObservableObject {
    private let defaults = UserDefaults.standard
    private var themeObserver: NSObjectProtocol?

    @Published var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance")
            apply()
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    init() {
        if let appearanceString = defaults.string(forKey: "appearance"),
           let loaded = AppAppearance(rawValue: appearanceString) {
            appearance = loaded
        } else {
            appearance = .system
        }

        apply()

        // 监听系统外观变化，「跟随系统」模式下自动更新
        themeObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.appearance == .system else { return }
            self.apply()
            // 外观依赖的图标渲染（如彩色带背景样式）需要跟着重绘，否则图标缓存会显示陈旧外观
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    deinit {
        if let themeObserver {
            DistributedNotificationCenter.default().removeObserver(themeObserver)
        }
    }

    /// 将当前外观设置应用到 NSApp，全局生效
    /// 注意：对于菜单栏应用（accessory 激活策略），NSApp.appearance = nil 不能可靠地跟随系统外观
    /// 因此「跟随系统」模式下主动读取系统外观并显式设置
    func apply() {
        DispatchQueue.main.async {
            switch self.appearance {
            case .system:
                let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
                NSApp.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
}
