//
//  LoggerExtension.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-11-10.
//  Copyright © 2025 f-is-h. All rights reserved.
//


import OSLog

extension Logger {
    /// 应用的统一 subsystem 标识符
    private static var subsystem = Bundle.main.bundleIdentifier ?? "xyz.fi5h.Usage4Claude"

    /// 菜单栏管理器日志
    /// 用于记录菜单栏、刷新、更新检查等相关操作
    static let menuBar = Logger(subsystem: subsystem, category: "MenuBar")

    /// 用户设置日志
    /// 用于记录设置变更、智能模式切换、开机启动等操作
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// Keychain 管理日志
    /// 用于记录敏感信息的存储、读取和删除操作
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")

    /// API 服务日志
    /// 用于记录 API 请求、响应和错误
    static let api = Logger(subsystem: subsystem, category: "API")

    /// 本地化管理日志
    /// 用于记录语言切换和本地化相关操作
    static let localization = Logger(subsystem: subsystem, category: "Localization")
}

// MARK: - 日志级别说明
/*
 OSLog 提供5个日志级别，Release 版本会自动禁用低级别日志：

 1. .debug    - 调试信息，仅开发时输出，Release 不执行
 2. .info     - 一般信息，默认不持久化
 3. .notice   - 重要事件，默认持久化
 4. .error    - 错误信息，总是持久化
 5. .fault    - 严重错误，总是持久化

 使用示例：
 ```swift
 Logger.menuBar.debug("调试信息")
 Logger.menuBar.info("一般信息")
 Logger.menuBar.notice("重要事件")
 Logger.menuBar.error("错误: \(error.localizedDescription)")
 Logger.menuBar.fault("严重错误")
 ```

 查看日志：
 1. Xcode Console (开发时)
 2. Console.app (搜索 subsystem:xyz.fi5h.Usage4Claude)
 3. 命令行: log show --predicate 'subsystem == "xyz.fi5h.Usage4Claude"' --last 1h
 */
