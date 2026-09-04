//
//  LogFormatting.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-09.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

// MARK: - LogLevel

/// 日志级别
///
/// 只有四级，每级有明确契约。旧的六级（debug/info/notice/warning/error/fault）
/// 里 debug 占了 64 处却一条都不落盘，warning 只有 6 处、fault 只有 1 处，
/// 选级别无规则可循。这里按「这条日志出了事之后还看不看得到」重新划分。
nonisolated enum LogLevel: Int, Comparable, CaseIterable, Sendable {

    /// 开发期细节。只进系统日志的 .debug（实测不落盘），Release 从不写文件。
    case trace = 0

    /// 生命周期与状态转移：启动、退出、刷新调度、账号切换、token 续期。
    /// 出事后要靠它还原「app 当时在干什么」，必须落盘。
    case event = 1

    /// 功能降级但仍可用：命中缓存、回退到备用路径、单次重试失败。
    case warning = 2

    /// 功能失败，用户能感知到。
    case error = 3

    /// 报告与文件里的固定宽度标签，对齐后便于用户肉眼扫读
    var label: String {
        switch self {
        case .trace:   return "TRACE"
        case .event:   return "EVENT"
        case .warning: return "WARN "
        case .error:   return "ERROR"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - LogCategory

/// 日志分类，对应统一日志里的 category，用户可据此在 Console.app 里筛选
nonisolated enum LogCategory: String, CaseIterable, Sendable {
    case lifecycle    = "Lifecycle"
    case api          = "API"
    case refresh      = "Refresh"
    case auth         = "Auth"
    case settings     = "Settings"
    case keychain     = "Keychain"
    case menuBar      = "MenuBar"
    case localization = "Localization"
}

// MARK: - LogFormatting

/// 日志行的格式化与解析（纯函数）
nonisolated enum LogFormatting {

    /// 单条消息的最大长度。防止一整个响应体被塞进日志把文件撑爆。
    static let maxMessageLength = 512

    /// 分类字段的对齐宽度
    private static let categoryWidth = 12

    /// 会话标记前缀，`SessionLogScanner` 依赖它来判断上次是否正常退出
    static let sessionStartMarker = "===== SESSION START"
    static let sessionEndMarker = "===== SESSION END"

    /// 把消息截断到上限，超长时保留头部并标注被截掉多少
    static func truncate(_ message: String, limit: Int = maxMessageLength) -> String {
        guard message.count > limit else { return message }
        let dropped = message.count - limit
        return String(message.prefix(limit)) + "… (+\(dropped) chars truncated)"
    }

    /// 格式化一条日志行（不含换行）
    ///
    ///     2026-09-04T13:20:29.123Z ERROR API          Claude usage request failed: HTTP 403
    static func line(timestamp: Date, level: LogLevel, category: LogCategory, message: String) -> String {
        let paddedCategory = category.rawValue.padding(toLength: categoryWidth, withPad: " ", startingAt: 0)
        return "\(iso8601(timestamp)) \(level.label) \(paddedCategory) \(truncate(message))"
    }

    /// 会话开始标记
    ///
    /// - Note: `osVersion` 必须是 `27.0.0` 这种数字形式。用
    ///   `ProcessInfo.operatingSystemVersionString` 会得到本地化文案
    ///   （中文环境下是「版本27.0（版号26A5416b）」），混进英文日志里。
    static func sessionStartLine(timestamp: Date, appVersion: String, osVersion: String, arch: String, pid: Int32) -> String {
        "\(iso8601(timestamp)) \(sessionStartMarker) app=\(appVersion) os=\(osVersion) arch=\(arch) pid=\(pid)"
    }

    /// 会话结束标记。只有正常退出路径会写，缺失即代表进程是被外部杀掉的。
    static func sessionEndLine(timestamp: Date, uptime: TimeInterval) -> String {
        "\(iso8601(timestamp)) \(sessionEndMarker) reason=clean uptime=\(Int(uptime))s"
    }

    /// 被折叠的重复行的汇总提示
    ///
    /// 级别跟随被折叠的那条消息：一串 ERROR 折叠后若汇总成 EVENT，
    /// 按 ERROR 过滤日志的人就会漏掉这个计数。
    static func repeatSummaryLine(timestamp: Date, count: Int, level: LogLevel) -> String {
        let paddedCategory = "—".padding(toLength: categoryWidth, withPad: " ", startingAt: 0)
        return "\(iso8601(timestamp)) \(level.label) \(paddedCategory) ⤷ previous message repeated \(count) more time\(count == 1 ? "" : "s")"
    }

    /// 毫秒精度的 ISO 8601（UTC）。用户跨时区贴日志时以 UTC 为准，省掉时区歧义。
    static func iso8601(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

// MARK: - RepeatCollapser

/// 重复行折叠器（纯状态机）
///
/// 断网时每个刷新周期都会写同一条错误，一晚上就是几百行一模一样的内容，
/// 既撑大文件又淹没真正有用的行。这里按 syslog 的老办法折叠成一行计数。
nonisolated struct RepeatCollapser {

    /// 一批被折叠的重复行
    struct FlushedRepeat: Equatable {
        let count: Int
        /// 被折叠消息的级别，汇总行沿用它
        let level: LogLevel
    }

    /// 折叠决策
    enum Decision: Equatable {
        /// 照常写入。`flushedSummary` 非空时，要先补写上一批被折叠行的汇总。
        case write(flushedSummary: FlushedRepeat?)
        /// 与上一条相同，吞掉不写
        case suppress
    }

    private var lastKey: String?
    private var lastLevel: LogLevel = .event
    private var suppressedCount = 0

    init() {}

    /// 提交一条日志，返回该写还是该吞
    mutating func admit(key: String, level: LogLevel) -> Decision {
        if key == lastKey {
            suppressedCount += 1
            return .suppress
        }
        let flushed = suppressedCount > 0
            ? FlushedRepeat(count: suppressedCount, level: lastLevel)
            : nil
        suppressedCount = 0
        lastKey = key
        lastLevel = level
        return .write(flushedSummary: flushed)
    }

    /// 收尾（轮转、会话结束、退出前）：把还没汇总的折叠计数吐出来
    mutating func flush() -> FlushedRepeat? {
        guard suppressedCount > 0 else { return nil }
        let flushed = FlushedRepeat(count: suppressedCount, level: lastLevel)
        suppressedCount = 0
        lastKey = nil
        return flushed
    }
}

// MARK: - SessionLogScanner

/// 从日志文本里判断上一次会话是怎么结束的（纯函数）
///
/// 这是 Issue #79 要的那一个 bit：app 静默消失、用户重开，系统里连 .ips 都没有。
/// 正常退出会写 SESSION END，被 SIGKILL（jetsam 等）则不会——所以「最后一个
/// SESSION START 之后没有 SESSION END」就等于「上次是被外部杀掉的」。
nonisolated enum SessionLogScanner {

    /// 上一次会话的结束方式
    enum PreviousSessionOutcome: String, Codable, Equatable, Sendable {
        /// 正常退出
        case clean
        /// 有开始标记但没有结束标记：进程被外部终止
        case terminatedUnexpectedly
        /// 日志里没有任何会话记录（首次启动，或日志已被轮转掉）
        case unknown
    }

    static func previousSessionOutcome(in logText: String) -> PreviousSessionOutcome {
        var sawStart = false
        var endedAfterLastStart = false

        for line in logText.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.contains(LogFormatting.sessionStartMarker) {
                sawStart = true
                endedAfterLastStart = false
            } else if line.contains(LogFormatting.sessionEndMarker) {
                endedAfterLastStart = true
            }
        }

        guard sawStart else { return .unknown }
        return endedAfterLastStart ? .clean : .terminatedUnexpectedly
    }
}

// MARK: - LogRetentionPolicy

/// 磁盘占用策略（纯函数）
///
/// 硬上限 512 KB：两个文件各 256 KB。旧实现是「每天一个 5 MB 文件 + 只清理 .old
/// 归档」，每日文件永远不删，等于无上限增长；这里改成固定两文件轮转，
/// 用户磁盘上的占用有确定的天花板。
nonisolated enum LogRetentionPolicy {

    /// 单个日志文件的字节上限
    static let maxFileBytes: UInt64 = 256 * 1024

    /// 保留的历史文件数（current + previous）
    static let retainedFileCount = 2

    /// 全部日志占用的硬上限
    static var maxTotalBytes: UInt64 { maxFileBytes * UInt64(retainedFileCount) }

    /// 归档文件的最长保留天数，超期在启动时清掉
    static let maxArchiveAgeDays = 14

    /// 写入 `pendingBytes` 字节前是否需要先轮转
    static func shouldRotate(currentSize: UInt64, pendingBytes: Int) -> Bool {
        currentSize + UInt64(pendingBytes) > maxFileBytes
    }

    /// 归档文件是否已超期
    static func isArchiveExpired(modifiedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(modifiedAt) > Double(maxArchiveAgeDays) * 24 * 3600
    }

    /// Release 构建下该级别是否写入文件
    ///
    /// trace 只进系统日志的 .debug（实测不落盘），不占用户一个字节。
    static func shouldWriteToFile(_ level: LogLevel, isDebugBuild: Bool) -> Bool {
        isDebugBuild ? true : level >= .event
    }
}
