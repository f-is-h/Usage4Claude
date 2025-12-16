//
//  DiagnosticLogger.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-11.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import OSLog

/// 诊断日志记录器
/// 提供详细的运行时日志，帮助追踪和诊断问题
@MainActor
class DiagnosticLogger {

    // MARK: - Singleton

    static let shared = DiagnosticLogger()

    // MARK: - Properties

    /// 日志级别
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    /// 日志文件URL
    private var logFileURL: URL?

    /// 日志队列（用于异步写入）
    private let logQueue = DispatchQueue(label: "com.f-is-h.Usage4Claude.logging", qos: .utility)

    /// 最大日志文件大小（5MB）
    private let maxLogFileSize: UInt64 = 5 * 1024 * 1024

    /// 是否启用日志记录
    private var isEnabled: Bool = true

    /// 系统日志器
    private let osLogger = Logger(subsystem: "com.f-is-h.Usage4Claude", category: "Diagnostics")

    // MARK: - Initialization

    private init() {
        setupLogFile()
    }

    // MARK: - Public Methods

    /// 记录调试信息
    func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(message, level: .debug, file: file, line: line, function: function)
    }

    /// 记录一般信息
    func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(message, level: .info, file: file, line: line, function: function)
    }

    /// 记录警告信息
    func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(message, level: .warning, file: file, line: line, function: function)
    }

    /// 记录错误信息
    func error(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(message, level: .error, file: file, line: line, function: function)
    }

    /// 获取日志文件路径
    func getLogFilePath() -> String? {
        return logFileURL?.path
    }

    /// 读取日志内容
    func readLogs(maxLines: Int = 1000) -> String {
        guard let logFileURL = logFileURL,
              FileManager.default.fileExists(atPath: logFileURL.path) else {
            return "No logs available"
        }

        do {
            let content = try String(contentsOf: logFileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let recentLines = lines.suffix(maxLines)
            return recentLines.joined(separator: "\n")
        } catch {
            return "Error reading logs: \(error.localizedDescription)"
        }
    }

    /// 清空日志
    func clearLogs() {
        guard let logFileURL = logFileURL else { return }

        logQueue.async {
            do {
                try "".write(to: logFileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to clear logs: \(error)")
            }
        }
    }

    /// 导出日志文件
    func exportLogs() -> URL? {
        return logFileURL
    }

    // MARK: - Private Methods

    /// 设置日志文件
    private func setupLogFile() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("❌ Failed to get Application Support directory")
            return
        }

        let logDirectory = appSupport.appendingPathComponent("Usage4Claude/logs")

        // 创建日志目录
        do {
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create log directory: \(error)")
            return
        }

        // 设置日志文件路径
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        logFileURL = logDirectory.appendingPathComponent("usage4claude_\(dateString).log")

        // 检查并轮转日志
        checkAndRotateLogIfNeeded()
    }

    /// 核心日志记录方法
    private func log(_ message: String, level: LogLevel, file: String, line: Int, function: String) {
        guard isEnabled else { return }

        // Release版本只记录warning和error，减少日志占用和隐私泄露
        #if !DEBUG
        guard level == .warning || level == .error else { return }
        #endif

        // 脱敏处理
        let sanitizedMessage = sanitize(message)

        // 提取文件名
        let fileName = (file as NSString).lastPathComponent

        // 构建日志消息
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(sanitizedMessage)\n"

        // 输出到控制台（仅在Debug模式）
        #if DEBUG
        print(logMessage, terminator: "")
        #endif

        // 输出到系统日志
        osLogger.log(level: osLogLevel(for: level), "\(sanitizedMessage)")

        // 异步写入文件
        writeToFile(logMessage)
    }

    /// 写入日志到文件
    private func writeToFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }

        logQueue.async {
            do {
                if FileManager.default.fileExists(atPath: logFileURL.path) {
                    // 文件存在，追加内容
                    let fileHandle = try FileHandle(forWritingTo: logFileURL)
                    defer { fileHandle.closeFile() }

                    if #available(macOS 10.15.4, *) {
                        try fileHandle.seekToEnd()
                        if let data = message.data(using: .utf8) {
                            try fileHandle.write(contentsOf: data)
                        }
                    } else {
                        fileHandle.seekToEndOfFile()
                        if let data = message.data(using: .utf8) {
                            fileHandle.write(data)
                        }
                    }
                } else {
                    // 文件不存在，创建新文件
                    try message.write(to: logFileURL, atomically: true, encoding: .utf8)
                }

                // 检查文件大小
                Task { @MainActor in
                    self.checkAndRotateLogIfNeeded()
                }
            } catch {
                print("❌ Failed to write log: \(error)")
            }
        }
    }

    /// 检查并轮转日志文件
    private func checkAndRotateLogIfNeeded() {
        guard let logFileURL = logFileURL else { return }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
            if let fileSize = attributes[.size] as? UInt64, fileSize > maxLogFileSize {
                // 文件过大，进行轮转
                rotateLog()
            }
        } catch {
            // 文件不存在或无法读取，忽略
        }
    }

    /// 轮转日志文件
    private func rotateLog() {
        guard let logFileURL = logFileURL else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let archiveURL = logFileURL.deletingLastPathComponent()
            .appendingPathComponent("usage4claude_\(timestamp).log.old")

        do {
            // 重命名当前日志文件
            try FileManager.default.moveItem(at: logFileURL, to: archiveURL)

            // 删除旧的归档文件（保留最近5个）
            cleanupOldLogs()
        } catch {
            print("❌ Failed to rotate log: \(error)")
        }
    }

    /// 清理旧日志文件
    private func cleanupOldLogs() {
        guard let logFileURL = logFileURL else { return }

        let logDirectory = logFileURL.deletingLastPathComponent()

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            // 只保留.old文件
            let oldLogs = fileURLs.filter { $0.pathExtension == "old" }

            // 按创建时间排序
            let sortedLogs = try oldLogs.sorted { url1, url2 in
                let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 > date2
            }

            // 删除超过5个的旧日志
            if sortedLogs.count > 5 {
                for logURL in sortedLogs.dropFirst(5) {
                    try FileManager.default.removeItem(at: logURL)
                }
            }
        } catch {
            print("❌ Failed to cleanup old logs: \(error)")
        }
    }

    /// 脱敏敏感信息
    private func sanitize(_ message: String) -> String {
        // 使用统一的敏感数据脱敏工具
        return SensitiveDataRedactor.redactText(message)
    }

    /// 转换为系统日志级别
    private func osLogLevel(for level: LogLevel) -> OSLogType {
        switch level {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        }
    }
}

// MARK: - Convenience Global Functions

/// 全局便捷日志函数
@MainActor
func logDebug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    DiagnosticLogger.shared.debug(message, file: file, line: line, function: function)
}

@MainActor
func logInfo(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    DiagnosticLogger.shared.info(message, file: file, line: line, function: function)
}

@MainActor
func logWarning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    DiagnosticLogger.shared.warning(message, file: file, line: line, function: function)
}

@MainActor
func logError(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    DiagnosticLogger.shared.error(message, file: file, line: line, function: function)
}
