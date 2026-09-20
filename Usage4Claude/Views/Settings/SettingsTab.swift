//
//  SettingsTab.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-09-20.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Foundation

/// 设置窗口的标签页
///
/// rawValue 会被 `openSettingsWithTab` 通知和 `SettingsView(initialTab:)` 用到，
/// 调整顺序时改这里即可，不要在调用点写裸数字
enum SettingsTab: Int, CaseIterable {
    /// 菜单栏外观、显示哪些限额、图表样式、外观、时间格式
    case display = 0
    /// 刷新、通知、Codex 重置预告
    case data = 1
    /// 账号登录与凭据
    case accounts = 2
    /// 语言、开机启动、恢复默认、调试
    case general = 3
    /// 版本与链接
    case about = 4

    /// 越界时落回第一页，通知里传来的是裸 Int，不保证有效
    init(index: Int) {
        self = SettingsTab(rawValue: index) ?? .display
    }

    var icon: String {
        switch self {
        case .display: return "menubar.rectangle"
        case .data: return "arrow.triangle.2.circlepath"
        case .accounts: return "key.horizontal"
        case .general: return "gearshape"
        case .about: return "info.circle"
        }
    }

    var title: String {
        switch self {
        case .display: return L.SettingsTab.display
        case .data: return L.SettingsTab.data
        case .accounts: return L.SettingsTab.accounts
        case .general: return L.SettingsTab.general
        case .about: return L.SettingsTab.about
        }
    }
}
