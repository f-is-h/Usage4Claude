//
//  AntigravityUsageStore.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//

import Foundation
import Combine

/// Antigravity 用量状态的唯一来源
///
/// 由 DataRefreshManager 写入，菜单栏渲染器、详情列、设置页直接观察。
/// Claude/Codex 的状态是沿 MenuBarManager → MenuBarUI → UsageDetailView 逐层传递的；
/// Antigravity 改用共享 store，是为了少改上游文件，让 fork 跟进上游更新时冲突更少。
final class AntigravityUsageStore: ObservableObject {

    static let shared = AntigravityUsageStore()

    /// 最新用量数据（nil 表示未启用或拉取失败）
    @Published var data: AntigravityUsageData?
    /// 错误消息
    @Published var errorMessage: String?
    /// 当前错误是否需要用户处理（未安装或未登录 agy）
    @Published var errorRequiresAuthAction = false

    private init() {}
}
