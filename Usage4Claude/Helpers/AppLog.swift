//
//  AppLog.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-09.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import OSLog

/// 应用统一日志入口
///
/// 取代原先并行的两套日志：`Logger`（OSLog，205 处调用）和 `DiagnosticLogger`
/// （文件，0 处调用，"打开日志文件夹" 按钮指向的正是这套死代码）。
///
/// 两个写入目标各补一个洞，缺一不可：
/// - **系统统一日志**：由 logd 写，进程被 SIGKILL 也不丢尾部；用户可用
///   `log show` 或 Console.app 自助导出。但沙盒挡死了 app 自己读取
///   （`OSLogStore(scope: .system)` 报 "Connection to logd failed"），
///   且只能读到当前进程，对崩溃取证无用。
/// - **文件日志**：app 自己读得到，能进诊断报告，能跨进程存活。
///
/// 三条硬约束：
/// 1. **可读**：所有消息以 `privacy: .public` 写入。OSLog 默认把插值字符串打成
///    `<private>`，旧代码 205 处里有 122 处中招，用户导出后看到的全是 `<private>`。
/// 2. **安全**：可读的前提是入口强制脱敏，见 `SensitiveDataRedactor.redactLogMessage`。
/// 3. **不占地方**：文件总量硬上限 512 KB（见 `LogRetentionPolicy`），
///    重复行折叠，超长消息截断，trace 级在 Release 一个字节都不写。
///
/// 线程安全：静态方法可从任意线程调用（大量调用点在后台回调里），
/// 内部用串行队列做文件 I/O、用锁保护折叠器状态。
nonisolated enum AppLog {

    // MARK: - Public API

    /// 开发期细节。Release 下只进系统日志的 .debug（实测不落盘），不占用户磁盘。
    static func trace(_ category: LogCategory, _ message: @autoclosure () -> String) {
        write(.trace, category, message())
    }

    /// 生命周期与状态转移。出事后靠它还原 app 当时在做什么。
    static func event(_ category: LogCategory, _ message: @autoclosure () -> String) {
        write(.event, category, message())
    }

    /// 功能降级但仍可用。
    static func warning(_ category: LogCategory, _ message: @autoclosure () -> String) {
        write(.warning, category, message())
    }

    /// 功能失败，用户能感知到。
    static func error(_ category: LogCategory, _ message: @autoclosure () -> String) {
        write(.error, category, message())
    }

    // MARK: - Session Lifecycle

    /// 上一次会话的结束方式，启动时判定一次后缓存。
    ///
    /// Issue #79 要的就是这个：静默退出且系统里没有 .ips 时，
    /// 靠「有 SESSION START 但没有 SESSION END」断定进程是被外部杀掉的。
    static var previousSessionOutcome: SessionLogScanner.PreviousSessionOutcome {
        store.previousSessionOutcome
    }

    /// 应用启动时尽早调用一次，强制日志系统就位。
    ///
    /// 会话标记的写入本身发生在 `LogStore` 初始化里，所以它总是本进程日志的第一行，
    /// 无论谁先打日志。这个调用只是把「初始化」这一步提前到一个确定的时机，
    /// 免得应用一路没打日志、会话标记迟迟不落盘。
    static func startSession() {
        _ = store
    }

    /// 应用正常退出时调用：写入结束标记。缺失该标记即代表被外部终止。
    static func endSession() {
        store.endSession()
    }

    // MARK: - Log Access

    /// 日志目录（供「打开日志文件夹」按钮使用）
    static var logDirectory: URL? { store.logDirectory }

    /// 读取最近若干行日志，供诊断报告嵌入
    /// - Parameter maxLines: 最多返回的行数
    /// - Returns: 日志文本；无日志时返回 nil
    static func recentLines(maxLines: Int = 200) -> String? {
        store.recentLines(maxLines: maxLines)
    }

    /// 全部日志文件当前占用的字节数
    static func diskUsageBytes() -> UInt64 { store.diskUsageBytes() }

    // MARK: - Internals

    private static let store = LogStore()

    private static func write(_ level: LogLevel, _ category: LogCategory, _ rawMessage: String) {
        store.record(level: level, category: category, message: rawMessage)
    }
}

// MARK: - LogLevel → OSLogType

private extension LogLevel {
    var osLogType: OSLogType {
        switch self {
        case .trace:   return .debug
        // .notice 是默认落盘的最低级别；.info 需要 log show --info 才可见
        case .event:   return .default
        case .warning: return .error
        case .error:   return .error
        }
    }
}

// MARK: - LogStore

/// 日志的实际存储：OSLog 句柄 + 文件读写 + 轮转 + 折叠
///
/// 非 private：轮转、折叠、会话标记这些行为必须对着真实实现测，
/// 而不是测一份平行的副本。测试用 `init(directory:)` 指到临时目录。
final class LogStore: @unchecked Sendable {

    // MARK: Paths

    let logDirectory: URL?
    let currentLogURL: URL?
    private let archiveLogURL: URL?

    // MARK: State

    /// 文件 I/O 串行队列。日志调用点遍布后台回调，必须能从任意线程进入。
    private let queue = DispatchQueue(label: "xyz.fi5h.Usage4Claude.applog", qos: .utility)

    private let lock = NSLock()
    private var collapser = RepeatCollapser()
    private var loggers: [LogCategory: Logger] = [:]
    private var sessionStartedAt: Date?

    private(set) var previousSessionOutcome: SessionLogScanner.PreviousSessionOutcome = .unknown

    private let subsystem = Bundle.main.bundleIdentifier ?? "xyz.fi5h.Usage4Claude"

    /// Debug 构建的日志文件名前缀，避免与 Release 实例互相污染
    private static var filePrefix: String {
        #if DEBUG
        return "debug-"
        #else
        return ""
        #endif
    }

    private var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: Init

    /// - Parameter directory: 日志目录。传 nil 时用 Application Support 下的默认位置。
    init(directory: URL? = nil) {
        let resolved = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Usage4Claude/logs", isDirectory: true)

        guard let directory = resolved else {
            logDirectory = nil
            currentLogURL = nil
            archiveLogURL = nil
            return
        }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        logDirectory = directory
        // 固定两个文件，不再按日期开新文件。旧实现每天一个 5 MB 文件且从不清理，
        // 是无上限增长；这里让用户磁盘上的占用有确定天花板。
        // Debug 与 Release 共用沙盒容器，日志文件必须按构建配置分开——沿用凭据的
        // DEBUG_ 隔离惯例。共用一个文件会让两个实例交错追加（跨进程的 seekToEnd
        // 不是原子的），更会让两边的会话标记混在一起，把「上次是否被外部终止」
        // 的判定变成噪声。
        currentLogURL = directory.appendingPathComponent("\(Self.filePrefix)current.log")
        archiveLogURL = directory.appendingPathComponent("\(Self.filePrefix)previous.log")

        // 在 init 里写会话标记，保证它是本进程日志的第一行——store 是懒加载的，
        // 第一次调 AppLog 时才构造，标记因此必然先于那条日志落盘。
        beginSession()
    }

    // MARK: OSLog handles

    func osLogger(for category: LogCategory) -> Logger {
        lock.lock()
        defer { lock.unlock() }
        if let existing = loggers[category] { return existing }
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }

    // MARK: Session

    /// 写入会话开始标记。由 `init` 调用，保证它先于本进程的任何一行日志落盘。
    ///
    /// 曾经放在 `applicationDidFinishLaunching` 里，但 SwiftUI 构造 App 结构时
    /// 就已经初始化了 `UserSettings`/`AccountStore`，它们的日志会排在标记之前，
    /// 读日志的人会把这些行错误地归给上一个会话。
    private func beginSession() {
        queue.sync {
            pruneExpiredArchive()

            // 先判上一次会话的结局，再写本次的开始标记，否则会被自己的标记污染
            let existing = currentLogURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            previousSessionOutcome = SessionLogScanner.previousSessionOutcome(in: existing)

            sessionStartedAt = Date()
            let startLine = LogFormatting.sessionStartLine(
                timestamp: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                osVersion: Self.osVersion(),
                arch: Self.architecture(),
                pid: ProcessInfo.processInfo.processIdentifier
            )
            appendRaw(startLine)
            // 标记也进系统日志：用户若用 log show 而非文件导出，
            // 会话边界是整份日志里最有价值的两行，不该只存在于一个渠道。
            emitSessionMarkerToOSLog(startLine)

            // 直接写，不能走 record()：此刻 AppLog.store 仍在初始化中，
            // record() 会重入这个 lazy static，造成死锁。
            guard previousSessionOutcome == .terminatedUnexpectedly else { return }
            let warning = "Previous session ended without a clean-exit marker — the process was terminated externally (crash, force quit, or the system reclaiming memory)"
            osLogger(for: .lifecycle).log(level: LogLevel.warning.osLogType, "\(warning, privacy: .public)")
            appendRaw(LogFormatting.line(
                timestamp: Date(), level: .warning, category: .lifecycle, message: warning
            ))
        }
    }

    func endSession() {
        queue.sync {
            flushCollapsed()
            let uptime = sessionStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            let endLine = LogFormatting.sessionEndLine(timestamp: Date(), uptime: uptime)
            appendRaw(endLine)
            emitSessionMarkerToOSLog(endLine)
        }
    }

    /// 会话标记写入系统日志。用 `.event` 级别，保证默认可见（`.debug` 不落盘）。
    private func emitSessionMarkerToOSLog(_ line: String) {
        osLogger(for: .lifecycle).log(level: LogLevel.event.osLogType, "\(line, privacy: .public)")
    }

    // MARK: Writing

    /// 唯一的写入路径：脱敏 → 系统日志 → 文件
    func record(level: LogLevel, category: LogCategory, message rawMessage: String) {
        // 入口强制脱敏：可读性建立在这一步之上
        let message = SensitiveDataRedactor.redactLogMessage(rawMessage)

        // 系统统一日志。显式 .public，否则用户导出后只能看到 <private>。
        osLogger(for: category).log(level: level.osLogType, "\(message, privacy: .public)")

        appendToFile(level: level, category: category, message: message)
    }

    func appendToFile(level: LogLevel, category: LogCategory, message: String) {
        guard LogRetentionPolicy.shouldWriteToFile(level, isDebugBuild: isDebugBuild) else { return }

        let timestamp = Date()
        queue.async { [weak self] in
            guard let self else { return }

            // 折叠重复行：断网时每个刷新周期都写同一条错误，一夜就是几百行
            let key = "\(level.rawValue)|\(category.rawValue)|\(message)"
            self.lock.lock()
            let decision = self.collapser.admit(key: key, level: level)
            self.lock.unlock()

            switch decision {
            case .suppress:
                return
            case .write(let flushedSummary):
                if let flushed = flushedSummary {
                    self.appendRaw(LogFormatting.repeatSummaryLine(
                        timestamp: timestamp, count: flushed.count, level: flushed.level
                    ))
                }
                self.appendRaw(LogFormatting.line(timestamp: timestamp, level: level, category: category, message: message))
            }
        }
    }

    /// 直接写一行（已在 queue 上）
    private func appendRaw(_ line: String) {
        guard let currentLogURL else { return }
        let payload = Data((line + "\n").utf8)

        rotateIfNeeded(pendingBytes: payload.count)

        if !FileManager.default.fileExists(atPath: currentLogURL.path) {
            FileManager.default.createFile(atPath: currentLogURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: currentLogURL) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: payload)
            // 立即落盘。进程随时可能被 SIGKILL，而崩溃前最后几行恰恰最有价值；
            // 本应用日志量在每天几百行量级，fsync 的代价可以忽略。
            try handle.synchronize()
        } catch {
            // 日志系统自身的失败不能再走日志，否则可能递归
        }
    }

    // MARK: Rotation

    private func rotateIfNeeded(pendingBytes: Int) {
        guard let currentLogURL, let archiveLogURL else { return }

        let size = Self.fileSize(at: currentLogURL)
        guard LogRetentionPolicy.shouldRotate(currentSize: size, pendingBytes: pendingBytes) else { return }

        try? FileManager.default.removeItem(at: archiveLogURL)
        try? FileManager.default.moveItem(at: currentLogURL, to: archiveLogURL)
    }

    private func pruneExpiredArchive() {
        guard let archiveLogURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: archiveLogURL.path),
              let modified = attributes[.modificationDate] as? Date else { return }

        if LogRetentionPolicy.isArchiveExpired(modifiedAt: modified) {
            try? FileManager.default.removeItem(at: archiveLogURL)
        }
    }

    private func flushCollapsed() {
        lock.lock()
        let pending = collapser.flush()
        lock.unlock()
        if let flushed = pending {
            appendRaw(LogFormatting.repeatSummaryLine(
                timestamp: Date(), count: flushed.count, level: flushed.level
            ))
        }
    }

    /// 等待队列中的写入全部落盘。日志写入是异步的，测试需要一个确定的观察点。
    func waitForPendingWrites() {
        queue.sync {}
    }

    // MARK: Reading

    func recentLines(maxLines: Int) -> String? {
        queue.sync {
            guard let currentLogURL else { return nil }
            var text = (try? String(contentsOf: currentLogURL, encoding: .utf8)) ?? ""

            // 当前文件行数不够时，从归档里往前补
            if text.split(separator: "\n").count < maxLines, let archiveLogURL,
               let archived = try? String(contentsOf: archiveLogURL, encoding: .utf8) {
                text = archived + text
            }

            let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            guard !lines.isEmpty else { return nil }
            return lines.suffix(maxLines).joined(separator: "\n")
        }
    }

    func diskUsageBytes() -> UInt64 {
        [currentLogURL, archiveLogURL].compactMap { $0 }
            .reduce(into: UInt64(0)) { $0 += Self.fileSize(at: $1) }
    }

    /// 文件字节数，不存在或读不到时返回 0
    private static func fileSize(at url: URL) -> UInt64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? UInt64 else { return 0 }
        return size
    }

    // MARK: Helpers

    /// 系统版本，形如 `27.0.0 (26A5416b)`
    ///
    /// 刻意不用 `ProcessInfo.operatingSystemVersionString`：那是本地化文案，
    /// 中文环境下会输出「版本27.0（版号26A5416b）」，混进英文日志。
    private static func osVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let numeric = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        guard let build = sysctlString(name: "kern.osversion") else { return numeric }
        return "\(numeric) (\(build))"
    }

    /// 读取 sysctl 字符串值
    private static func sysctlString(name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
