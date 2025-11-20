//
//  LocalizationManager.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-11-05.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import Combine
import OSLog

/// 本地化管理器
/// 负责监听语言变化并触发视图更新，实现即时语言切换
class LocalizationManager: ObservableObject {
    /// 单例实例
    static let shared = LocalizationManager()
    
    /// 更新触发器，当语言变化时递增，用于强制视图重新创建
    @Published var updateTrigger: Int = 0
    
    /// 通知观察者
    private var cancellable: AnyCancellable?
    
    private init() {
        // 监听语言变化通知
        cancellable = NotificationCenter.default
            .publisher(for: .languageChanged)
            .sink { [weak self] _ in
                // 语言变化时递增触发器，所有使用 .id(updateTrigger) 的视图会重新创建
                self?.updateTrigger += 1
                Logger.localization.debug("语言已切换，触发视图更新")
            }
    }
    
    deinit {
        cancellable?.cancel()
    }
}
