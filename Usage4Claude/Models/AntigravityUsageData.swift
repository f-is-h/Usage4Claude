//
//  AntigravityUsageData.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//
//  Pure-data types + parsing for the `agy -p /usage --output-format json` output.
//  Lives here (not Helpers/) so it can be cherry-picked into the SwiftPM test
//  target — every symbol here must stay free of `L.*`/`Logger`/UI dependency.
//

import Foundation

// MARK: - 内部数据模型

/// Antigravity 使用量数据（应用内部使用的标准化结构）
///
/// 配额按「模型组」划分：Gemini 一组，Claude/GPT 等第三方模型一组。
/// 每组最多两个窗口：5 小时（付费档才有）和每周。
nonisolated struct AntigravityUsageData: Sendable {
    /// Gemini 模型组
    let gemini: GroupLimits
    /// Claude / GPT 等第三方模型组
    let thirdParty: GroupLimits

    struct GroupLimits: Sendable {
        /// 5小时窗口用量，免费档没有此窗口
        let fiveHour: UsageData.LimitData?
        /// 每周窗口用量
        let weekly: UsageData.LimitData?

        static let empty = GroupLimits(fiveHour: nil, weekly: nil)

        var hasAnyLimit: Bool { fiveHour != nil || weekly != nil }
    }

    /// 是否至少有一个窗口的数据
    var hasAnyLimit: Bool { gemini.hasAnyLimit || thirdParty.hasAnyLimit }

    /// 所有窗口中的最高使用百分比，供智能刷新模式判断用量是否变化
    var maxPercentage: Double? {
        [gemini.fiveHour, gemini.weekly, thirdParty.fiveHour, thirdParty.weekly]
            .compactMap { $0?.percentage }
            .max()
    }
}

// MARK: - CLI 输出模型

/// `agy -p /usage --output-format json` 的输出
///
/// 示例（agy 1.4.9）：
/// ```
/// {"status":"SUCCESS","response":"...","command":{"name":"usage","data":{
///   "groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-weekly","window":"weekly",
///   "remaining_fraction":0.9975,"reset_time":"2026-11-04T18:31:45Z"}]}]}}}
/// ```
nonisolated struct AntigravityUsageCLIOutput: Codable, Sendable {
    let status: String?
    let response: String?
    let command: Command?

    struct Command: Codable, Sendable {
        let name: String?
        let data: QuotaData?
    }

    struct QuotaData: Codable, Sendable {
        let description: String?
        let groups: [Group]?
    }

    struct Group: Codable, Sendable {
        let name: String?
        let description: String?
        let buckets: [Bucket]?
    }

    struct Bucket: Codable, Sendable {
        /// 已知取值：gemini-5h / gemini-weekly / 3p-5h / 3p-weekly
        let id: String?
        let name: String?
        let description: String?
        /// "5h" 或 "weekly"
        let window: String?
        /// 剩余比例 (0-1)
        let remaining_fraction: Double?
        /// RFC 3339 时间
        let reset_time: String?
    }
}

// MARK: - 解析

/// CLI 输出解析失败的原因
nonisolated enum AntigravityParseError: Error, Equatable, Sendable {
    /// 输出中找不到 JSON
    case noJSON
    /// agy 未登录
    case notLoggedIn
    /// status 不是 SUCCESS，附带 CLI 给出的说明
    case commandFailed(String)
    /// JSON 结构不符合预期
    case malformed
}

nonisolated enum AntigravityUsageParser {

    /// 解析 CLI 的标准输出
    /// - Note: stdout 里可能混入更新提示等非 JSON 行，取最后一个以 `{` 开头的行
    static func parse(cliOutput: String) throws -> AntigravityUsageData {
        if cliOutput.range(of: "not logged in", options: .caseInsensitive) != nil {
            throw AntigravityParseError.notLoggedIn
        }
        guard let jsonLine = cliOutput
            .split(whereSeparator: \.isNewline)
            .last(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("{") }),
              let data = String(jsonLine).data(using: .utf8) else {
            throw AntigravityParseError.noJSON
        }
        let output: AntigravityUsageCLIOutput
        do {
            output = try JSONDecoder().decode(AntigravityUsageCLIOutput.self, from: data)
        } catch {
            throw AntigravityParseError.malformed
        }
        return try toUsageData(output)
    }

    /// 从 agy 日志里取当前登录的账户邮箱（`OAuth: authenticated successfully as …`），用量 JSON 本身不含邮箱
    static func accountEmail(fromLog log: String) -> String? {
        guard let range = log.range(of: "authenticated successfully as ", options: .backwards) else { return nil }
        let email = log[range.upperBound...].prefix { !$0.isWhitespace }
        return email.contains("@") ? String(email) : nil
    }

    static func toUsageData(_ output: AntigravityUsageCLIOutput) throws -> AntigravityUsageData {
        guard output.status?.uppercased() == "SUCCESS" else {
            let message = output.response?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if isNotLoggedInMessage(message) {
                throw AntigravityParseError.notLoggedIn
            }
            throw AntigravityParseError.commandFailed(message.isEmpty ? (output.status ?? "unknown") : message)
        }
        guard let groups = output.command?.data?.groups else {
            throw AntigravityParseError.malformed
        }

        var geminiFiveHour: UsageData.LimitData?
        var geminiWeekly: UsageData.LimitData?
        var thirdPartyFiveHour: UsageData.LimitData?
        var thirdPartyWeekly: UsageData.LimitData?

        for group in groups {
            for bucket in group.buckets ?? [] {
                guard let slot = slot(for: bucket, groupName: group.name),
                      let limit = limitData(for: bucket) else { continue }
                switch slot {
                case .geminiFiveHour: geminiFiveHour = limit
                case .geminiWeekly: geminiWeekly = limit
                case .thirdPartyFiveHour: thirdPartyFiveHour = limit
                case .thirdPartyWeekly: thirdPartyWeekly = limit
                }
            }
        }

        return AntigravityUsageData(
            gemini: .init(fiveHour: geminiFiveHour, weekly: geminiWeekly),
            thirdParty: .init(fiveHour: thirdPartyFiveHour, weekly: thirdPartyWeekly)
        )
    }

    // MARK: - Private

    /// 只认明确表示「未登录」的说法。单纯含 "sign in"/"log in" 的消息
    /// （如 "Failed to sign in to quota service: network unreachable"）是瞬时错误，
    /// 误判成未登录会清掉缓存数据并跳过退避
    private static let notLoggedInPhrases = [
        "not logged in", "not signed in", "please log in", "please sign in",
        "login required", "sign-in required", "unauthenticated"
    ]

    private static func isNotLoggedInMessage(_ message: String) -> Bool {
        notLoggedInPhrases.contains { message.range(of: $0, options: .caseInsensitive) != nil }
    }

    private enum Slot {
        case geminiFiveHour, geminiWeekly, thirdPartyFiveHour, thirdPartyWeekly
    }

    /// 先按 bucket id 精确匹配；id 未知时退回按组名（没有组名才看 id）+ window 判断，未知窗口忽略
    private static func slot(for bucket: AntigravityUsageCLIOutput.Bucket, groupName: String?) -> Slot? {
        switch bucket.id {
        case "gemini-5h": return .geminiFiveHour
        case "gemini-weekly": return .geminiWeekly
        case "3p-5h": return .thirdPartyFiveHour
        case "3p-weekly": return .thirdPartyWeekly
        default: break
        }
        // 组名比改名后的 bucket id 可靠：Gemini 组里的 "flash-weekly" 不能被归到第三方
        let isGemini = (groupName ?? bucket.id ?? "").lowercased().contains("gemini")
        switch bucket.window?.lowercased() {
        case "5h": return isGemini ? .geminiFiveHour : .thirdPartyFiveHour
        case "weekly": return isGemini ? .geminiWeekly : .thirdPartyWeekly
        default: return nil
        }
    }

    /// 剩余比例换算成使用百分比
    /// - Note: 剩余 100% 时 reset_time 是「现在 + 窗口长度」，并非真实的重置时间，
    ///   与 Codex 一致视为窗口尚未开始，resetsAt 置 nil
    private static func limitData(for bucket: AntigravityUsageCLIOutput.Bucket) -> UsageData.LimitData? {
        guard let remaining = bucket.remaining_fraction else { return nil }
        let clamped = min(max(remaining, 0), 1)
        let percentage = (1 - clamped) * 100
        let resetsAt = clamped >= 1 ? nil : bucket.reset_time.flatMap(parseDate)
        return UsageData.LimitData(percentage: percentage, resetsAt: resetsAt)
    }

    /// agy 写回的 token 过期时间是 Go RFC3339Nano（可能带小数秒），两种都要能解析
    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
