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
    
    /// 获取用户的 Claude 使用情况（并行获取主用量和 Extra Usage）
    /// - Parameter completion: 完成回调，包含成功的 UsageData 或失败的 Error
    /// - Note: 请求会自动添加必要的 Headers 以绕过 Cloudflare 防护
    /// - Important: 调用前确保用户已配置有效的认证信息
    /// - Note: 同时并行调用主 usage API 和 Extra Usage API，Extra Usage 失败不影响主功能
    func fetchUsage(completion: @escaping (Result<UsageData, Error>) -> Void) {
        #if DEBUG
        // 调试模式：返回模拟数据（立即返回，无延迟）
        if settings.debugModeEnabled {
            let mockData = createMockData()
            DispatchQueue.main.async {
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

        // 使用 DispatchGroup 并行请求两个 API
        let dispatchGroup = DispatchGroup()
        var mainUsageData: UsageData?
        var extraUsageData: ExtraUsageData?
        var mainError: Error?

        // ========== 请求1: 主 Usage API ==========
        dispatchGroup.enter()
        fetchMainUsage { result in
            switch result {
            case .success(let data):
                mainUsageData = data
            case .failure(let error):
                mainError = error
            }
            dispatchGroup.leave()
        }

        // ========== 请求2: Extra Usage API（可选） ==========
        dispatchGroup.enter()
        fetchExtraUsage { result in
            switch result {
            case .success(let data):
                extraUsageData = data  // 可能为 nil（功能未启用或失败）
            case .failure:
                // Extra Usage 失败不影响主功能，保持 extraUsageData 为 nil
                Logger.api.info("Extra Usage API failed, continuing with main usage data only")
            }
            dispatchGroup.leave()
        }

        // ========== 等待两个请求完成后合并结果 ==========
        dispatchGroup.notify(queue: .main) {
            // 如果主 API 失败，则整体失败
            if let error = mainError {
                completion(.failure(error))
                return
            }

            // 主 API 成功，合并 Extra Usage 数据
            guard var finalData = mainUsageData else {
                completion(.failure(UsageError.decodingError))
                return
            }

            // 创建包含 Extra Usage 的完整数据
            finalData = UsageData(
                fiveHour: finalData.fiveHour,
                sevenDay: finalData.sevenDay,
                opus: finalData.opus,
                sonnet: finalData.sonnet,
                extraUsage: extraUsageData  // 可能为 nil
            )

            completion(.success(finalData))
        }
    }

    /// 获取主 Usage API 数据（内部方法）
    /// - Parameter completion: 完成回调
    private func fetchMainUsage(completion: @escaping (Result<UsageData, Error>) -> Void) {
        let urlString = "\(baseURL)/\(settings.organizationId)/usage"

        guard let url = URL(string: urlString) else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 使用统一的 Header 构建器添加完整的浏览器 Headers 以绕过 Cloudflare
        ClaudeAPIHeaderBuilder.applyHeaders(
            to: &request,
            organizationId: settings.organizationId,
            sessionKey: settings.sessionKey
        )

        // 创建并保存任务引用
        currentTask = session.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.api.debug("Network error: \(error.localizedDescription)")
                completion(.failure(UsageError.networkError))
                return
            }

            guard let data = data else {
                completion(.failure(UsageError.noData))
                return
            }

            // 打印原始响应用于调试
            if let jsonString = String(data: data, encoding: .utf8) {
                Logger.api.debug("Main Usage API Response: \(jsonString)")

                // 检查是否是HTML响应（Cloudflare拦截）
                if jsonString.contains("<!DOCTYPE html>") || jsonString.contains("<html") {
                    Logger.api.debug("⚠️ Received HTML response, possibly intercepted by Cloudflare.")
                    completion(.failure(UsageError.cloudflareBlocked))
                    return
                }
            }

            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                Logger.api.debug("Main Usage HTTP Status: \(httpResponse.statusCode)")

                // 处理各种 HTTP 错误状态码
                switch httpResponse.statusCode {
                case 200...299:
                    // 成功响应，继续处理
                    break
                case 401:
                    // 未授权，通常是认证信息无效
                    completion(.failure(UsageError.unauthorized))
                    return
                case 403:
                    // 禁止访问，可能是 Cloudflare 拦截
                    completion(.failure(UsageError.cloudflareBlocked))
                    return
                case 429:
                    // 请求频率过高
                    completion(.failure(UsageError.rateLimited))
                    return
                default:
                    // 其他 HTTP 错误
                    Logger.api.error("HTTP error: \(httpResponse.statusCode)")
                    completion(.failure(UsageError.httpError(statusCode: httpResponse.statusCode)))
                    return
                }
            }

            // 解码 JSON 响应
            let decoder = JSONDecoder()

            // 检查是否是错误响应
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data),
               errorResponse.error.type == "permission_error" {
                completion(.failure(UsageError.sessionExpired))
                return
            }

            // 解析成功响应
            do {
                let response = try decoder.decode(UsageResponse.self, from: data)
                let usageData = response.toUsageData()
                completion(.success(usageData))
            } catch {
                Logger.api.debug("Decoding error: \(error.localizedDescription)")
                completion(.failure(UsageError.decodingError))
            }
        }

        // 启动任务
        currentTask?.resume()
    }

    /// 获取用户的组织列表
    /// - Parameters:
    ///   - sessionKey: 可选的 sessionKey，如果不提供则使用 settings.sessionKey
    ///   - completion: 完成回调，包含成功的组织数组或失败的 Error
    /// - Note: 用于自动获取 Organization ID，简化用户配置流程
    func fetchOrganizations(sessionKey: String? = nil, completion: @escaping (Result<[Organization], Error>) -> Void) {
        let urlString = "\(baseURL.replacingOccurrences(of: "/organizations", with: ""))/organizations"

        guard let url = URL(string: urlString) else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 使用统一的 Header 构建器，仅需要 sessionKey
        // 如果提供了 sessionKey 参数则使用它，否则使用 settings.sessionKey
        let actualSessionKey = sessionKey ?? settings.sessionKey
        ClaudeAPIHeaderBuilder.applyHeaders(
            to: &request,
            organizationId: nil,  // 获取组织列表不需要 organizationId
            sessionKey: actualSessionKey
        )

        let task = session.dataTask(with: request) { data, response, error in
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
                Logger.api.debug("Organizations API Response: \(jsonString)")
            }

            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                Logger.api.debug("HTTP Status Code: \(httpResponse.statusCode)")

                switch httpResponse.statusCode {
                case 200...299:
                    // 成功响应，继续处理
                    break
                case 401:
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.unauthorized))
                    }
                    return
                case 403:
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.cloudflareBlocked))
                    }
                    return
                default:
                    Logger.api.error("HTTP error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.httpError(statusCode: httpResponse.statusCode)))
                    }
                    return
                }
            }

            // 解码 JSON 响应
            let decoder = JSONDecoder()
            do {
                let organizations = try decoder.decode([Organization].self, from: data)
                DispatchQueue.main.async {
                    completion(.success(organizations))
                }
            } catch {
                Logger.api.debug("Decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(UsageError.decodingError))
                }
            }
        }

        task.resume()
    }

    /// 获取 Extra Usage 额外用量数据
    /// - Parameter completion: 完成回调，包含成功的 ExtraUsageData 或失败的 Error
    /// - Note: 此方法是可选的，即使失败也不应影响主要功能
    func fetchExtraUsage(completion: @escaping (Result<ExtraUsageData?, Error>) -> Void) {
        // 检查认证信息
        guard settings.hasValidCredentials else {
            completion(.failure(UsageError.noCredentials))
            return
        }

        let urlString = "\(baseURL)/\(settings.organizationId)/overage_spend_limit"

        guard let url = URL(string: urlString) else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 使用统一的 Header 构建器添加完整的浏览器 Headers
        ClaudeAPIHeaderBuilder.applyHeaders(
            to: &request,
            organizationId: settings.organizationId,
            sessionKey: settings.sessionKey
        )

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.api.debug("Extra Usage API network error: \(error.localizedDescription)")
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
                Logger.api.debug("Extra Usage API Response: \(jsonString)")
            }

            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                Logger.api.debug("Extra Usage HTTP Status: \(httpResponse.statusCode)")

                switch httpResponse.statusCode {
                case 200...299:
                    // 成功响应，继续处理
                    break
                case 403, 404:
                    // Extra Usage 未启用或无权限，返回 nil 表示功能不可用
                    Logger.api.info("Extra Usage not available (HTTP \(httpResponse.statusCode))")
                    DispatchQueue.main.async {
                        completion(.success(nil))
                    }
                    return
                case 401:
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.unauthorized))
                    }
                    return
                default:
                    Logger.api.warning("Extra Usage HTTP error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(.success(nil))  // 优雅降级
                    }
                    return
                }
            }

            // 解码 JSON 响应
            let decoder = JSONDecoder()
            do {
                let extraUsageResponse = try decoder.decode(ExtraUsageResponse.self, from: data)
                let extraUsageData = extraUsageResponse.toExtraUsageData()
                DispatchQueue.main.async {
                    completion(.success(extraUsageData))
                }
            } catch {
                Logger.api.debug("Extra Usage decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.success(nil))  // 优雅降级
                }
            }
        }

        task.resume()
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
    /// - Returns: 模拟的 UsageData 实例，基于各个百分比滑块的值
    private func createMockData() -> UsageData {
        // 根据各个滑块值创建对应的限制数据
        let extraUsageData: ExtraUsageData? = {
            guard settings.debugExtraUsageEnabled else {
                return ExtraUsageData(enabled: false, used: nil, limit: nil, currency: "USD")
            }
            return ExtraUsageData(
                enabled: true,
                used: settings.debugExtraUsageUsed,
                limit: settings.debugExtraUsageLimit,
                currency: "USD"
            )
        }()

        return UsageData(
            fiveHour: UsageData.LimitData(
                percentage: settings.debugFiveHourPercentage,
                resetsAt: createResetTime(hoursFromNow: 1.8)  // 1.8小时后重置
            ),
            sevenDay: UsageData.LimitData(
                percentage: settings.debugSevenDayPercentage,
                resetsAt: createResetTime(hoursFromNow: 24 * 2.3)  // 2.3天后重置
            ),
            opus: UsageData.LimitData(
                percentage: settings.debugOpusPercentage,
                resetsAt: createResetTime(hoursFromNow: 24 * 4.5)  // 4.5天后重置
            ),
            sonnet: UsageData.LimitData(
                percentage: settings.debugSonnetPercentage,
                resetsAt: createResetTime(hoursFromNow: 24 * 5.2)  // 5.2天后重置
            ),
            extraUsage: extraUsageData
        )
    }
    #endif
}

// MARK: - 数据模型

/// Organization 组织信息模型
/// 对应 Claude API /api/organizations 返回的组织信息
nonisolated struct Organization: Codable, Sendable {
    /// 组织数字 ID
    let id: Int
    /// 组织 UUID（用于 API 调用）
    let uuid: String
    /// 组织名称
    let name: String
    /// 创建时间
    let created_at: String?
    /// 更新时间
    let updated_at: String?
    /// 组织权限列表
    let capabilities: [String]?
}

/// API 响应数据模型
/// 对应 Claude API 返回的 JSON 结构
nonisolated struct UsageResponse: Codable, Sendable {
    /// 5小时用量限制数据
    let five_hour: LimitUsage
    /// 7天用量限制数据
    let seven_day: LimitUsage?
    /// 7天 OAuth 应用用量（暂未使用）
    let seven_day_oauth_apps: LimitUsage?
    /// 7天 Opus 用量限制数据
    let seven_day_opus: LimitUsage?
    /// 7天 Sonnet 用量限制数据（新字段）
    let seven_day_sonnet: LimitUsage?

    /// 通用限制用量详情（适用于5小时、7天等各种限制）
    struct LimitUsage: Codable, Sendable {
        /// 当前使用率 (0-100，可以是浮点数)
        let utilization: Double
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

        // 解析 Opus 限制数据（仅当存在且有效时）
        let opusData: UsageData.LimitData? = {
            guard let opus = seven_day_opus else {
                return nil
            }
            if opus.utilization == 0 && opus.resets_at == nil {
                return nil
            }
            let parsed = parseLimitData(opus)
            return UsageData.LimitData(percentage: parsed.percentage, resetsAt: parsed.resetsAt)
        }()

        // 解析 Sonnet 限制数据（仅当存在且有效时）
        let sonnetData: UsageData.LimitData? = {
            guard let sonnet = seven_day_sonnet else {
                return nil
            }
            if sonnet.utilization == 0 && sonnet.resets_at == nil {
                return nil
            }
            let parsed = parseLimitData(sonnet)
            return UsageData.LimitData(percentage: parsed.percentage, resetsAt: parsed.resetsAt)
        }()

        return UsageData(
            fiveHour: UsageData.LimitData(percentage: fiveHourData.percentage, resetsAt: fiveHourData.resetsAt),
            sevenDay: sevenDayData,
            opus: opusData,
            sonnet: sonnetData,
            extraUsage: nil  // Extra Usage 将在阶段5通过单独的 API 获取
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

/// Extra Usage API 响应模型
/// 用于解析 /api/organizations/{id}/overage_spend_limit 接口返回的数据
nonisolated struct ExtraUsageResponse: Codable, Sendable {
    /// 类型标识
    let type: String
    /// 货币单位（如 "usd"）
    let spend_limit_currency: String
    /// 限额（单位：分）
    let spend_limit_amount_cents: Int?
    /// 已使用金额（单位：分）
    let balance_cents: Int?

    /// 转换为 ExtraUsageData
    /// - Returns: 转换后的 ExtraUsageData，如果数据无效则返回 nil
    func toExtraUsageData() -> ExtraUsageData? {
        // 如果没有限额，说明 Extra Usage 未启用
        guard let limitCents = spend_limit_amount_cents, limitCents > 0 else {
            return ExtraUsageData(
                enabled: false,
                used: nil,
                limit: nil,
                currency: spend_limit_currency.uppercased()
            )
        }

        // 转换为美元（或其他货币单位）
        let limit = Double(limitCents) / 100.0
        let used = balance_cents.map { Double($0) / 100.0 } ?? 0.0

        return ExtraUsageData(
            enabled: true,
            used: used,
            limit: limit,
            currency: spend_limit_currency.uppercased()
        )
    }
}

/// 用量数据模型
/// 应用内部使用的标准化用量数据结构
struct UsageData: Sendable {
    /// 5小时限制数据（可选）
    let fiveHour: LimitData?
    /// 7天限制数据（可选）
    let sevenDay: LimitData?
    /// Opus 每周限制数据（可选）
    let opus: LimitData?
    /// Sonnet 每周限制数据（可选）
    let sonnet: LimitData?
    /// Extra Usage 限额数据（可选）
    let extraUsage: ExtraUsageData?

    /// 单个限制的数据（5小时、7天、Opus、Sonnet）
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

            var calendar = Calendar.current
            calendar.locale = UserSettings.shared.appLocale
            let timeString = TimeFormatHelper.formatTimeOnly(resetsAt)

            if calendar.isDateInToday(resetsAt) {
                return "\(L.UsageData.today) \(timeString)"
            } else if calendar.isDateInTomorrow(resetsAt) {
                return "\(L.UsageData.tomorrow) \(timeString)"
            } else {
                return TimeFormatHelper.formatDateTime(resetsAt, dateTemplate: "Md")
            }
        }

        /// 格式化的重置时间字符串（长格式，用于7天限制）
        /// - Returns: 本地化的重置日期描述（如 "11月29日 14时" 或 "Nov 29 2 PM"）
        var formattedResetDateLong: String {
            guard let resetsAt = resetsAt else {
                return L.UsageData.unknown
            }

            return TimeFormatHelper.formatDateHour(resetsAt, dateTemplate: "MMMd")
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
                return L.UsageData.compactResettingSoon
            }

            let totalMinutes = Int(ceil(resetsIn / 60))

            // 如果不足1小时，只显示分钟
            if totalMinutes < 60 {
                return L.UsageData.compactRemainingMinutes(totalMinutes)
            }

            let totalHours = totalMinutes / 60
            let remainingMinutes = totalMinutes % 60

            // 如果不足1天，显示小时+分钟
            if totalHours < 24 {
                return L.UsageData.compactRemainingHours(totalHours, remainingMinutes)
            }

            // 超过1天，显示天+小时
            let days = totalHours / 24
            let hours = totalHours % 24

            return L.UsageData.compactRemainingDays(days, hours)
        }

        /// 格式化的重置时间（用于5小时限制）
        /// - 示例: "Today 15:07" / "Today 3:07 PM", "Tomorrow 09:30" / "Tomorrow 9:30 AM"
        var formattedCompactResetTime: String {
            guard let resetsAt = resetsAt else {
                return "-"
            }

            let calendar = Calendar.current

            // 判断是今天还是明天
            let prefix: String
            if calendar.isDateInToday(resetsAt) {
                prefix = L.UsageData.today
            } else if calendar.isDateInTomorrow(resetsAt) {
                prefix = L.UsageData.tomorrow
            } else {
                // 其他日期显示月日
                let formatter = DateFormatter()
                formatter.locale = UserSettings.shared.appLocale
                formatter.timeZone = TimeZone.current
                // 根据语言使用不同的日期格式
                let langCode = UserSettings.shared.appLocale.identifier
                if langCode.hasPrefix("zh") || langCode.hasPrefix("ja") {
                    formatter.dateFormat = "M月d日"  // 中文/日语：12月25日
                } else if langCode.hasPrefix("ko") {
                    formatter.dateFormat = "M월d일"  // 韩语：12월25일
                } else {
                    formatter.dateFormat = "MMM d"   // 英文：Dec 25
                }
                prefix = formatter.string(from: resetsAt)
            }

            let timeString = TimeFormatHelper.formatTimeOnly(resetsAt)

            return "\(prefix) \(timeString)"
        }

        /// 格式化的重置日期（用于7天限制，精确到小时）
        /// - 示例: "Dec 16 15:00" / "Dec 16 3 PM" (英文), "12月16日 15时" (中文)
        var formattedCompactResetDate: String {
            guard let resetsAt = resetsAt else {
                return "-"
            }

            return TimeFormatHelper.formatDateHour(resetsAt, dateTemplate: "MMMd")
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

/// Extra Usage 数据模型
/// 额外付费用量数据结构（金额而非百分比）
struct ExtraUsageData: Sendable {
    /// 是否启用 Extra Usage
    let enabled: Bool
    /// 已使用金额（美元）
    let used: Double?
    /// 总限额（美元）
    let limit: Double?
    /// 货币单位
    let currency: String

    /// 使用百分比（用于统一显示）
    var percentage: Double? {
        guard let used = used, let limit = limit, limit > 0 else {
            return nil
        }
        return (used / limit) * 100.0
    }

    // MARK: - Formatting Methods

    /// 格式化的使用金额/总额度字符串（默认模式）
    /// - Returns: 如 "$12.50 / $50.00"
    var formattedUsageAmount: String {
        guard enabled, let used = used, let limit = limit else {
            return L.ExtraUsage.notEnabled
        }
        return L.ExtraUsage.usageAmount(used, limit)
    }

    /// 格式化的剩余金额字符串（剩余模式）
    /// - Returns: 如 "还可使用 $37"
    var formattedRemainingAmount: String {
        guard enabled, let used = used, let limit = limit else {
            return L.ExtraUsage.notEnabled
        }
        let remaining = max(0, limit - used)
        return L.ExtraUsage.remainingAmount(remaining)
    }

    /// 极简格式化的使用金额（用于列表显示）
    /// - Returns: 如 "$10/$25"
    var formattedCompactAmount: String {
        guard enabled, let used = used, let limit = limit else {
            return "-"
        }
        return String(format: "$%.0f/$%.0f", used, limit)
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
            return L.Error.unauthorized
        case .rateLimited:
            return L.Error.rateLimited
        case .httpError(let statusCode):
            return "HTTP 错误: \(statusCode)"
        }
    }
}
