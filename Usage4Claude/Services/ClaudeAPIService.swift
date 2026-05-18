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
        request.assumesHTTP3Capable = false

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
                    // HTML 已在上方提前返回 cloudflareBlocked，此处 403 均为 JSON 鉴权失败
                    completion(.failure(UsageError.unauthorized))
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
        request.assumesHTTP3Capable = false

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
                    // Cloudflare 拦截返回 HTML；API 鉴权失败返回 JSON
                    let isHTML = String(data: data, encoding: .utf8).map {
                        $0.contains("<!DOCTYPE html>") || $0.contains("<html")
                    } ?? false
                    DispatchQueue.main.async {
                        completion(.failure(isHTML ? UsageError.cloudflareBlocked : UsageError.unauthorized))
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
        request.assumesHTTP3Capable = false

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
            // 调试数据以美分为单位存储，与真实 API 格式一致，除以 100 转换为美元
            return ExtraUsageData(
                enabled: true,
                used: settings.debugExtraUsageUsed / 100.0,
                limit: Double(settings.debugExtraUsageLimit) / 100.0,
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

// MARK: - UsageProvider

extension ClaudeAPIService: UsageProvider {
    var providerType: ProviderType { .claude }
}
