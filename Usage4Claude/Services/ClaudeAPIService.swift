//
//  ClaudeAPIService.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import OSLog

/// Claude API 服务类
/// 负责与 Claude.ai API 通信，获取用户的使用情况数据
/// 包含请求构建、认证处理、Cloudflare 绕过和数据解析功能
class ClaudeAPIService {
    // MARK: - Properties
    
    /// API 基础 URL
    private let baseURL = "https://claude.ai/api/organizations"
    
    /// 用户设置实例，用于获取认证信息
    private let settings = UserSettings.shared
    
    /// 共享的 URLSession 实例
    private let session: URLSession

    /// 当前正在执行的网络请求任务
    private var currentTask: URLSessionDataTask?

    // MARK: - Initialization
    
    init() {
        // 配置 URLSession
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30  // 请求超时：30秒
        configuration.timeoutIntervalForResource = 60 // 资源超时：60秒
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData  // 不使用缓存
        
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Public Methods
    
    /// 获取用户的 Claude 使用情况
    /// - Parameter completion: 完成回调，包含成功的 UsageData 或失败的 Error
    /// - Note: 请求会自动添加必要的 Headers 以绕过 Cloudflare 防护
    /// - Important: 调用前确保用户已配置有效的认证信息
    func fetchUsage(completion: @escaping (Result<UsageData, Error>) -> Void) {
        #if DEBUG
        // 调试模式：返回模拟数据
        if settings.debugModeEnabled && settings.debugScenario != .realData {
            let mockData = createMockData(for: settings.debugScenario)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(.success(mockData))
            }
            return
        }
        #endif

        // 取消之前的请求（如果存在）
        currentTask?.cancel()

        // 检查认证信息
        guard settings.hasValidCredentials else {
            completion(.failure(UsageError.noCredentials))
            return
        }
        
        let urlString = "\(baseURL)/\(settings.organizationId)/usage"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(UsageError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 添加完整的浏览器Headers以绕过Cloudflare
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "accept-language")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
                        forHTTPHeaderField: "user-agent")
        request.setValue("https://claude.ai", forHTTPHeaderField: "origin")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "referer")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        
        // 设置 Cookie
        let cookieString = "sessionKey=\(settings.sessionKey)"
        request.setValue(cookieString, forHTTPHeaderField: "Cookie")

        // 创建并保存任务引用
        currentTask = session.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.api.debug("Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(UsageError.networkError))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(UsageError.noData))
                }
                return
            }
            
            // 打印原始响应用于调试
            if let jsonString = String(data: data, encoding: .utf8) {
                Logger.api.debug("API Response: \(jsonString)")

                // 检查是否是HTML响应（Cloudflare拦截）
                if jsonString.contains("<!DOCTYPE html>") || jsonString.contains("<html") {
                    Logger.api.debug("⚠️ Received HTML response, possibly intercepted by Cloudflare.")

                    DispatchQueue.main.async {
                        completion(.failure(UsageError.cloudflareBlocked))
                    }
                    return
                }
            }

            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                Logger.api.debug("HTTP Status Code: \(httpResponse.statusCode)")

                // 处理各种 HTTP 错误状态码
                switch httpResponse.statusCode {
                case 200...299:
                    // 成功响应，继续处理
                    break
                case 401:
                    // 未授权，通常是认证信息无效
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.unauthorized))
                    }
                    return
                case 403:
                    // 禁止访问，可能是 Cloudflare 拦截
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.cloudflareBlocked))
                    }
                    return
                case 429:
                    // 请求频率过高
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.rateLimited))
                    }
                    return
                default:
                    // 其他 HTTP 错误
                    Logger.api.error("HTTP error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.httpError(statusCode: httpResponse.statusCode)))
                    }
                    return
                }
            }
            
            // 解码 JSON 响应
            let decoder = JSONDecoder()
            
            // 检查是否是错误响应
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data),
               errorResponse.error.type == "permission_error" {
                DispatchQueue.main.async {
                    completion(.failure(UsageError.sessionExpired))
                }
                return
            }
            
            // 解析成功响应
            do {
                let response = try decoder.decode(UsageResponse.self, from: data)
                let usageData = response.toUsageData()
                DispatchQueue.main.async {
                    completion(.success(usageData))
                }
            } catch {
                Logger.api.debug("Decoding error: \(error.localizedDescription)")

                DispatchQueue.main.async {
                    completion(.failure(UsageError.decodingError))
                }
            }
        }

        // 启动任务并在完成后清理引用
        currentTask?.resume()
    }

    /// 取消所有正在进行的网络请求
    /// 在应用退出或需要中断请求时调用
    func cancelAllRequests() {
        currentTask?.cancel()
        currentTask = nil
        Logger.api.debug("已取消所有网络请求")
    }

    // MARK: - Debug Mock Data

    #if DEBUG
    /// 创建分钟为00的未来时间
    /// - Parameter hoursFromNow: 从现在开始的小时数
    /// - Returns: 分钟为00的未来日期
    private func createResetTime(hoursFromNow: Double) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let targetDate = now.addingTimeInterval(3600 * hoursFromNow)
        
        // 获取目标日期的组件
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: targetDate)
        components.minute = 0
        components.second = 0
        
        // 返回分钟为00的时间
        return calendar.date(from: components) ?? targetDate
    }
    
    /// 创建模拟数据用于调试
    /// - Parameter scenario: 调试场景类型
    /// - Returns: 模拟的 UsageData 实例
    private func createMockData(for scenario: UserSettings.DebugScenario) -> UsageData {
        switch scenario {
        case .realData:
            fatalError("Should not call mock data for real scenario")

        case .fiveHourOnly:
            // 场景1a：只有5小时限制（使用用户设置的百分比）
            return UsageData(
                fiveHour: UsageData.LimitData(
                    percentage: settings.debugFiveHourPercentage,
                    resetsAt: createResetTime(hoursFromNow: 2.5)  // 2.5小时后重置，分钟为00
                ),
                sevenDay: nil
            )

        case .sevenDayOnly:
            // 场景1b：只有7天限制（使用用户设置的百分比）
            return UsageData(
                fiveHour: nil,
                sevenDay: UsageData.LimitData(
                    percentage: settings.debugSevenDayPercentage,
                    resetsAt: createResetTime(hoursFromNow: 24 * 3.5)  // 3.5天后重置，分钟为00
                )
            )

        case .both:
            // 场景2：同时有两种限制（使用用户设置的百分比）
            return UsageData(
                fiveHour: UsageData.LimitData(
                    percentage: settings.debugFiveHourPercentage,
                    resetsAt: createResetTime(hoursFromNow: 1.8)  // 1.8小时后重置，分钟为00
                ),
                sevenDay: UsageData.LimitData(
                    percentage: settings.debugSevenDayPercentage,
                    resetsAt: createResetTime(hoursFromNow: 24 * 2.3)  // 2.3天后重置，分钟为00
                )
            )
        }
    }
    #endif
}

// MARK: - 数据模型

/// API 响应数据模型
/// 对应 Claude API 返回的 JSON 结构
nonisolated struct UsageResponse: Codable, Sendable {
    /// 5小时用量限制数据
    let five_hour: LimitUsage
    /// 7天用量限制数据
    let seven_day: LimitUsage?
    /// 7天 OAuth 应用用量（暂未使用）
    let seven_day_oauth_apps: String?
    /// 7天 Opus 用量（暂未使用）
    let seven_day_opus: LimitUsage?

    /// 通用限制用量详情（适用于5小时、7天等各种限制）
    struct LimitUsage: Codable, Sendable {
        /// 当前使用率 (0-100 的整数)
        let utilization: Int
        /// 重置时间（ISO 8601 格式），nil 表示尚未开始使用
        let resets_at: String?
    }
    
    /// 将 API 响应转换为应用内部使用的 UsageData 模型
    /// - Returns: 转换后的 UsageData 实例
    /// - Note: 会自动处理时间四舍五入，确保显示准确
    func toUsageData() -> UsageData {
        // 解析5小时限制数据
        let fiveHourData = parseLimitData(five_hour)

        // 解析7天限制数据（仅当存在且有效时）
        let sevenDayData: UsageData.LimitData? = {
            guard let sevenDay = seven_day else {
                return nil
            }
            // 如果utilization为0且resets_at为空，视为无数据
            if sevenDay.utilization == 0 && sevenDay.resets_at == nil {
                return nil
            }
            let parsed = parseLimitData(sevenDay)
            return UsageData.LimitData(percentage: parsed.percentage, resetsAt: parsed.resetsAt)
        }()

        return UsageData(
            fiveHour: UsageData.LimitData(percentage: fiveHourData.percentage, resetsAt: fiveHourData.resetsAt),
            sevenDay: sevenDayData
        )
    }

    /// 解析单个限制的数据（5小时或7天）
    /// - Parameter limit: LimitUsage 结构
    /// - Returns: 包含百分比和重置时间的元组
    private func parseLimitData(_ limit: LimitUsage) -> (percentage: Double, resetsAt: Date?) {
        let resetsAt: Date?
        if let resetString = limit.resets_at {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: resetString) {
                // 对时间进行四舍五入到最接近的秒
                // 例如：05:59:59.645 → 06:00:00
                //       06:00:00.159 → 06:00:00
                let interval = date.timeIntervalSinceReferenceDate
                let roundedInterval = round(interval)
                resetsAt = Date(timeIntervalSinceReferenceDate: roundedInterval)
            } else {
                resetsAt = nil
            }
        } else {
            resetsAt = nil
        }

        return (percentage: Double(limit.utilization), resetsAt: resetsAt)
    }
}

/// 用量数据模型
/// 应用内部使用的标准化用量数据结构
struct UsageData: Sendable {
    /// 5小时限制数据（可选）
    let fiveHour: LimitData?
    /// 7天限制数据（可选）
    let sevenDay: LimitData?

    /// 单个限制的数据（5小时或7天）
    struct LimitData: Sendable {
        /// 当前使用百分比 (0-100)
        let percentage: Double
        /// 用量重置时间，nil 表示尚未开始使用
        let resetsAt: Date?

        /// 距离重置的剩余时间（秒）
        /// - Returns: 剩余秒数，如果 resetsAt 为 nil 则返回 nil
        var resetsIn: TimeInterval? {
            guard let resetsAt = resetsAt else { return nil }
            return resetsAt.timeIntervalSinceNow
        }

        /// 格式化的剩余时间字符串（用于5小时限制，显示X小时Y分）
        /// - Returns: 本地化的剩余时间描述（如 "2小时30分"）
        var formattedResetsInHours: String {
            guard let resetsAt = resetsAt else {
                return L.UsageData.notStartedReset
            }

            let resetsIn = resetsAt.timeIntervalSinceNow

            guard resetsIn > 0 else {
                return L.UsageData.resettingSoon
            }

            // 向上取整到分钟（使用 ceil 函数）
            let totalMinutes = Int(ceil(resetsIn / 60))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60

            if hours > 0 {
                return L.UsageData.resetsInHours(hours, minutes)
            } else {
                return L.UsageData.resetsInMinutes(minutes)
            }
        }

        /// 格式化的剩余时间字符串（用于7天限制，显示X天Y小时）
        /// - Returns: 本地化的剩余时间描述（如 "剩余约3天12小时"）
        var formattedResetsInDays: String {
            guard let resetsAt = resetsAt else {
                return L.UsageData.notStartedReset
            }

            let resetsIn = resetsAt.timeIntervalSinceNow

            guard resetsIn > 0 else {
                return L.UsageData.resettingSoon
            }

            // 向上取整到小时
            let totalHours = Int(ceil(resetsIn / 3600))
            let days = totalHours / 24
            let hours = totalHours % 24

            if days > 0 {
                return L.UsageData.resetsInDays(days, hours)
            } else {
                // 不足1天时，显示"约X小时"
                return L.UsageData.resetsInHours(hours, 0)
            }
        }

        /// 格式化的重置时间字符串（短格式，用于5小时限制）
        /// - Returns: 本地化的重置时间描述（如 "今天 14:30" 或 "明天 09:00"）
        var formattedResetTimeShort: String {
            guard let resetsAt = resetsAt else {
                return L.UsageData.unknown
            }

            let formatter = DateFormatter()
            formatter.locale = UserSettings.shared.appLocale
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "HH:mm"

            var calendar = Calendar.current
            calendar.locale = UserSettings.shared.appLocale
            let timeString = formatter.string(from: resetsAt)

            if calendar.isDateInToday(resetsAt) {
                return "\(L.UsageData.today) \(timeString)"
            } else if calendar.isDateInTomorrow(resetsAt) {
                return "\(L.UsageData.tomorrow) \(timeString)"
            } else {
                formatter.setLocalizedDateFormatFromTemplate("Md HH:mm")
                return formatter.string(from: resetsAt)
            }
        }

        /// 格式化的重置时间字符串（长格式，用于7天限制）
        /// - Returns: 本地化的重置日期描述（如 "11月29日 下午2时" (中文) 或 "Nov 29 2 PM" (英文)）
        var formattedResetDateLong: String {
            guard let resetsAt = resetsAt else {
                return L.UsageData.unknown
            }

            let formatter = DateFormatter()
            formatter.locale = UserSettings.shared.appLocale
            formatter.timeZone = TimeZone.current
            formatter.setLocalizedDateFormatFromTemplate("MMMd ha")

            return formatter.string(from: resetsAt)
        }

        // MARK: - 极简格式化方法（用于双模式两行显示）

        /// 极简格式化的剩余时间（省略零值单位）
        /// - 示例: "45m", "1h30m", "3d12h"
        var formattedCompactRemaining: String {
            guard let resetsAt = resetsAt else {
                return "-"
            }

            let resetsIn = resetsAt.timeIntervalSinceNow
            guard resetsIn > 0 else {
                return "即将重置"
            }

            let totalMinutes = Int(ceil(resetsIn / 60))

            // 如果不足1小时，只显示分钟
            if totalMinutes < 60 {
                return "\(totalMinutes)m"
            }

            let totalHours = totalMinutes / 60
            let minutes = totalMinutes % 60

            // 如果不足1天，显示小时(+分钟)
            if totalHours < 24 {
                if minutes > 0 {
                    return "\(totalHours)h\(minutes)m"
                } else {
                    return "\(totalHours)h"
                }
            }

            // 超过1天，显示天+小时
            let days = totalHours / 24
            let hours = totalHours % 24

            if hours > 0 {
                return "\(days)d\(hours)h"
            } else {
                return "\(days)d"
            }
        }

        /// 极简格式化的重置时间（用于5小时限制）
        /// - 示例: "15:07", "09:30"
        var formattedCompactResetTime: String {
            guard let resetsAt = resetsAt else {
                return "-"
            }

            let formatter = DateFormatter()
            formatter.locale = UserSettings.shared.appLocale
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "HH:mm"

            return formatter.string(from: resetsAt)
        }

        /// 极简格式化的重置日期（用于7天限制）
        /// - 示例: "11/29, 2 PM" (始终使用英文格式)
        var formattedCompactResetDate: String {
            guard let resetsAt = resetsAt else {
                return "-"
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")  // 强制使用英文格式
            formatter.timeZone = TimeZone.current
            formatter.setLocalizedDateFormatFromTemplate("Md ha")

            return formatter.string(from: resetsAt)
        }
    }

    /// 便捷访问：当前主要显示的数据（优先5小时，否则7天）
    var primaryLimit: LimitData? {
        return fiveHour ?? sevenDay
    }

    /// 是否同时有两种限制数据
    var hasBothLimits: Bool {
        return fiveHour != nil && sevenDay != nil
    }

    /// 是否只有7天限制数据
    var hasOnlySevenDay: Bool {
        return fiveHour == nil && sevenDay != nil
    }

    // MARK: - 向后兼容属性（保留用于旧代码）

    /// 当前使用百分比 (0-100)
    /// - Note: 向后兼容属性，返回主要限制的百分比
    var percentage: Double {
        return primaryLimit?.percentage ?? 0
    }

    /// 用量重置时间，nil 表示尚未开始使用
    /// - Note: 向后兼容属性，返回主要限制的重置时间
    var resetsAt: Date? {
        return primaryLimit?.resetsAt
    }

    /// 距离重置的剩余时间（秒）
    /// - Note: 向后兼容属性
    var resetsIn: TimeInterval? {
        return primaryLimit?.resetsIn
    }

    /// 格式化的剩余时间字符串
    /// - Note: 向后兼容属性
    var formattedResetsIn: String {
        return primaryLimit?.formattedResetsInHours ?? L.UsageData.notStartedReset
    }

    /// 格式化的重置时间字符串
    /// - Note: 向后兼容属性
    var formattedResetTime: String {
        return primaryLimit?.formattedResetTimeShort ?? L.UsageData.unknown
    }

    /// 根据使用百分比返回对应的状态颜色
    /// - Note: 向后兼容属性
    var statusColor: String {
        let percentage = self.percentage
        if percentage < 50 {
            return "green"
        } else if percentage < 70 {
            return "yellow"
        } else if percentage < 90 {
            return "orange"
        } else {
            return "red"
        }
    }
}

/// API 错误响应模型
/// 对应 Claude API 返回的错误信息结构
nonisolated struct ErrorResponse: Codable, Sendable {
    let type: String
    let error: ErrorDetail
    
    /// 错误详情
    struct ErrorDetail: Codable, Sendable {
        let type: String
        let message: String
    }
}

/// 用量查询相关错误
enum UsageError: LocalizedError {
    case invalidURL
    case noData
    case sessionExpired
    case cloudflareBlocked
    case noCredentials
    case networkError
    case decodingError
    case unauthorized              // 401 未授权
    case rateLimited               // 429 请求频率过高
    case httpError(statusCode: Int)  // 其他 HTTP 错误

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L.Error.invalidUrl
        case .noData:
            return L.Error.noData
        case .sessionExpired:
            return L.Error.sessionExpired
        case .cloudflareBlocked:
            return L.Error.cloudflareBlocked
        case .noCredentials:
            return L.Error.noCredentials
        case .networkError:
            return L.Error.networkFailed
        case .decodingError:
            return L.Error.decodingFailed
        case .unauthorized:
            return "认证失败，请检查您的凭据"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .httpError(let statusCode):
            return "HTTP 错误: \(statusCode)"
        }
    }
}
