//
//  KimiAPIService.swift
//  Usage4Claude
//
//  Kimi for Coding (kimi.com) usage support. A Kimi account is modeled as a
//  Claude-family Account whose sessionKey is the `sk-kimi-…` API key;
//  ClaudeAPIService.fetchUsage routes those accounts here. The
//  GET /coding/v1/usages payload maps cleanly onto UsageData:
//    limits[] (300-minute window) -> fiveHour
//    usage (7-day quota)          -> sevenDay
//    boosterWallet (monthly $)    -> extraUsage
//

import Foundation
import OSLog

final class KimiAPIService {
    static let usagesURL = "https://api.kimi.com/coding/v1/usages"
    static let messagesURL = "https://api.kimi.com/coding/v1/messages"
    /// 已验证可用于 1-token warm-up 的模型
    static let warmupModel = "kimi-k2-thinking"

    static func isKimiKey(_ credential: String) -> Bool {
        credential.hasPrefix("sk-kimi-")
    }

    // MARK: - Wire models（protobuf-JSON：int64 编码为字符串）

    private struct UsagesResponse: Decodable {
        struct Usage: Decodable {
            let limit: String?
            let used: String?
            let remaining: String?
            let resetTime: String?
        }
        struct LimitEntry: Decodable {
            struct Window: Decodable {
                let duration: Int?
                let timeUnit: String?
            }
            struct Detail: Decodable {
                let limit: String?
                let remaining: String?
                let resetTime: String?
            }
            let window: Window?
            let detail: Detail?
        }
        struct Money: Decodable {
            let currency: String?
            let priceInCents: String?
        }
        struct BoosterWallet: Decodable {
            let status: String?
            let monthlyChargeLimit: Money?
            let monthlyUsed: Money?
        }
        let usage: Usage?
        let limits: [LimitEntry]?
        let boosterWallet: BoosterWallet?
    }

    // MARK: - Fetch

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func fetchUsage(apiKey: String, completion: @escaping (Result<UsageData, Error>) -> Void) {
        guard let url = URL(string: Self.usagesURL) else {
            DispatchQueue.main.async { completion(.failure(UsageError.invalidURL)) }
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: request) { data, response, error in
            let finish: (Result<UsageData, Error>) -> Void = { result in
                DispatchQueue.main.async { completion(result) }
            }
            if let error {
                Logger.api.error("Kimi usage request failed: \(error.localizedDescription)")
                finish(.failure(UsageError.networkError))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                Logger.api.error("Kimi usage HTTP \(http.statusCode)")
                finish(.failure(http.statusCode == 401 ? UsageError.unauthorized : UsageError.httpError(statusCode: http.statusCode)))
                return
            }
            guard let data else {
                finish(.failure(UsageError.noData))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(UsagesResponse.self, from: data)
                finish(.success(Self.mapToUsageData(decoded)))
            } catch {
                Logger.api.error("Kimi usage decode failed: \(error.localizedDescription)")
                finish(.failure(UsageError.decodingError))
            }
        }.resume()
    }

    // MARK: - Mapping

    private static func mapToUsageData(_ response: UsagesResponse) -> UsageData {
        // 5小时窗口：limits[] 里 window ≈ 300 分钟的条目（当前 API 只有这一个）
        var fiveHour: UsageData.LimitData?
        if let entry = response.limits?.first(where: { isFiveHourWindow($0.window) }) ?? response.limits?.first,
           let detail = entry.detail,
           let limit = doubleValue(detail.limit), limit > 0 {
            let remaining = doubleValue(detail.remaining) ?? limit
            let percentage = max(0, min(100, (limit - remaining) / limit * 100))
            fiveHour = UsageData.LimitData(
                percentage: percentage,
                resetsAt: parseDate(detail.resetTime)
            )
        }

        // 7天配额：顶层 usage 块（resetTime 是 7 天滚动窗口）
        var sevenDay: UsageData.LimitData?
        if let usage = response.usage,
           let limit = doubleValue(usage.limit), limit > 0 {
            let used = doubleValue(usage.used) ?? 0
            let percentage = max(0, min(100, used / limit * 100))
            sevenDay = UsageData.LimitData(
                percentage: percentage,
                resetsAt: parseDate(usage.resetTime)
            )
        }

        // 月度 booster 钱包（付费额度）→ Extra Usage，仅启用时显示
        var extraUsage: ExtraUsageData?
        if let wallet = response.boosterWallet, wallet.status == "STATUS_ENABLED",
           let limitCents = doubleValue(wallet.monthlyChargeLimit?.priceInCents), limitCents > 0 {
            let usedCents = doubleValue(wallet.monthlyUsed?.priceInCents) ?? 0
            extraUsage = ExtraUsageData(
                enabled: true,
                used: usedCents / 100.0,
                limit: limitCents / 100.0,
                currency: wallet.monthlyChargeLimit?.currency ?? "USD"
            )
        }

        return UsageData(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            opus: nil,
            sonnet: nil,
            extraUsage: extraUsage
        )
    }

    private static func isFiveHourWindow(_ window: UsagesResponse.LimitEntry.Window?) -> Bool {
        guard let window, let duration = window.duration else { return false }
        switch window.timeUnit {
        case "TIME_UNIT_MINUTE": return duration == 300
        case "TIME_UNIT_HOUR": return duration == 5
        case "TIME_UNIT_SECOND": return duration == 18000
        default: return false
        }
    }

    private static func doubleValue(_ string: String?) -> Double? {
        guard let string else { return nil }
        return Double(string)
    }

    /// 解析 "2026-07-25T06:42:02.124558Z"（微秒精度的 RFC 3339）
    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }

        // 兜底：去掉小数秒后按标准格式解析
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let dotIndex = string.firstIndex(of: "."),
           let zIndex = string.lastIndex(of: "Z") {
            let stripped = String(string[..<dotIndex]) + String(string[zIndex...])
            return plain.date(from: stripped)
        }
        return plain.date(from: string)
    }
}
