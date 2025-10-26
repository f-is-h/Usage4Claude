//
//  ClaudeAPIService.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

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
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
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
                #if DEBUG
                print("API Response: \(jsonString)")
                #endif
                
                // 检查是否是HTML响应（Cloudflare拦截）
                if jsonString.contains("<!DOCTYPE html>") || jsonString.contains("<html") {
                    #if DEBUG
                    print("⚠️ Received HTML response, possibly intercepted by Cloudflare.")
                    #endif
                    
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.cloudflareBlocked))
                    }
                    return
                }
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                #if DEBUG
                print("HTTP Status Code: \(httpResponse.statusCode)")
                #endif
                
                if httpResponse.statusCode == 403 {
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.cloudflareBlocked))
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
                #if DEBUG
                print("Decoding error: \(error)")
                #endif
                
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// MARK: - 数据模型

/// API 响应数据模型
/// 对应 Claude API 返回的 JSON 结构
nonisolated struct UsageResponse: Codable, Sendable {
    /// 5小时用量限制数据
    let five_hour: FiveHourUsage
    /// 7天用量（暂未使用）
    let seven_day: String?
    /// 7天 OAuth 应用用量（暂未使用）
    let seven_day_oauth_apps: String?
    /// 7天 Opus 用量（暂未使用）
    let seven_day_opus: String?
    
    /// 5小时用量详情
    struct FiveHourUsage: Codable, Sendable {
        /// 当前使用率 (0-100 的整数)
        let utilization: Int
        /// 重置时间（ISO 8601 格式），nil 表示尚未开始使用
        let resets_at: String?
    }
    
    /// 将 API 响应转换为应用内部使用的 UsageData 模型
    /// - Returns: 转换后的 UsageData 实例
    /// - Note: 会自动处理时间四舍五入，确保显示准确
    func toUsageData() -> UsageData {
        let resetsAt: Date?
        if let resetString = five_hour.resets_at {
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
        
        return UsageData(
            percentage: Double(five_hour.utilization),
            resetsAt: resetsAt
        )
    }
}

/// 用量数据模型
/// 应用内部使用的标准化用量数据结构
struct UsageData: Sendable {
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
    
    /// 格式化的剩余时间字符串
    /// - Returns: 本地化的剩余时间描述（如 "2小时30分钟后重置"）
    var formattedResetsIn: String {
        // 如果 resetsAt 为 nil，说明还未开始使用
        guard let resetsAt = resetsAt else {
            return L.UsageData.notStartedReset
        }
        
        // 计算剩余时间
        let resetsIn = resetsAt.timeIntervalSinceNow
        
        // 如果时间已过或即将到达，显示即将重置
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
    
    /// 格式化的重置时间字符串
    /// - Returns: 本地化的重置时间描述（如 "今天 14:30" 或 "明天 09:00"）
    var formattedResetTime: String {
        guard let resetsAt = resetsAt else {
            return L.UsageData.unknown
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        
        let calendar = Calendar.current
        let timeString = formatter.string(from: resetsAt)
        
        if calendar.isDateInToday(resetsAt) {
            return "\(L.UsageData.today) \(timeString)"
        } else if calendar.isDateInTomorrow(resetsAt) {
            return "\(L.UsageData.tomorrow) \(timeString)"
        } else {
            formatter.dateFormat = "M月d日 HH:mm"
            return formatter.string(from: resetsAt)
        }
    }
    
    /// 根据使用百分比返回对应的状态颜色
    /// - Returns: 颜色名称字符串
    /// - Note: green (0-50%), yellow (50-70%), orange (70-90%), red (90-100%)
    var statusColor: String {
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
        }
    }
}
