//
//  CommandCodeAPIService.swift
//  Usage4Claude
//
//  Command Code usage service. Reads the undocumented billing endpoints at
//  api.commandcode.ai with the signed-in web session cookie:
//
//    GET /internal/billing/credits        → balances + rolling 5h/weekly windows
//    GET /internal/billing/subscriptions  → plan ID + billing period
//
//  The endpoints are community-reverse-engineered and may drift, so all
//  decoding lives in CommandCodeAPIResponseModels (pure, unit-tested and
//  defensive) and the subscription lookup is treated as optional enrichment:
//  when it fails the credits still render, balance-only.
//
//  Completion callbacks are always delivered on the main thread (service-layer
//  convention shared with ClaudeAPIService/CodexAPIService).
//

import Foundation

/// Command Code API 服务类
class CommandCodeAPIService {

    // MARK: - Properties

    /// 一次性校验与诊断场景复用的共享实例。
    static let shared = CommandCodeAPIService()

    /// API 基础 URL
    private let baseURL = "https://api.commandcode.ai"

    /// 余额与滚动窗口端点
    private let creditsPath = "/internal/billing/credits"

    /// 套餐与账期端点（可选增强）
    private let subscriptionsPath = "/internal/billing/subscriptions"

    /// 用户设置实例，用于获取认证信息
    private let settings = UserSettings.shared

    /// 共享的 URLSession 实例（响应不写进 Cache.db，见 NetworkCachePolicy.swift）
    private let session: URLSession

    /// 进行中的任务，供 cancelAllRequests 统一取消
    private var activeTasks: [URLSessionDataTask] = []

    /// 保护 activeTasks 的锁
    private let tasksLock = NSLock()

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.uncached
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public Methods

    /// 获取 Command Code 用量（余额 + 5小时/每周滚动窗口 + 套餐）
    /// - Parameter completion: 成功返回 CommandCodeUsageData，失败返回 Error（主线程回调）
    func fetchUsage(completion: @escaping (Result<CommandCodeUsageData, Error>) -> Void) {
        #if DEBUG
        if settings.debugModeEnabled {
            DispatchQueue.main.async { completion(.success(Self.createMockData())) }
            return
        }
        #endif

        cancelAllRequests()

        guard settings.hasValidCommandCodeCredentials else {
            DispatchQueue.main.async { completion(.failure(UsageError.noCredentials)) }
            return
        }
        guard let cookie = CommandCodeCookieHeader.cookie(fromRaw: settings.commandCodeSessionCookie) else {
            AppLog.error(.auth, "Command Code session cookie could not be parsed from the stored credential")
            DispatchQueue.main.async { completion(.failure(UsageError.noCredentials)) }
            return
        }

        fetchCredits(cookie: cookie) { [weak self] creditsResult in
            guard let self = self else { return }
            switch creditsResult {
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }

            case .success(let credits):
                // 订阅端点是可选增强：失败时只用余额窗口，不整体失败
                self.fetchSubscription(cookie: cookie) { subscriptionResult in
                    let subscription: CommandCodeSubscriptionPayload?
                    switch subscriptionResult {
                    case .success(let payload):
                        subscription = payload
                    case .failure(let error):
                        AppLog.warning(.api, "Command Code subscription lookup failed; continuing balance-only: \(error.localizedDescription)")
                        subscription = nil
                    }
                    let data = CommandCodeUsageData.make(credits: credits, subscription: subscription)
                    DispatchQueue.main.async { completion(.success(data)) }
                }
            }
        }
    }

    /// `fetchUsage(completion:)` 的 async 包装，供结构化并发调用方使用。
    func fetchUsageResult() async -> Result<CommandCodeUsageData, Error> {
        await withCheckedContinuation { continuation in
            fetchUsage { continuation.resume(returning: $0) }
        }
    }

    /// 验证一个粘贴的会话 Cookie 是否可用（添加账户时调用）。
    /// 用 /internal/billing/credits 做一次探测：2xx 即视为有效。
    func validate(cookie rawCookie: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let cookie = CommandCodeCookieHeader.cookie(fromRaw: rawCookie) else {
            DispatchQueue.main.async { completion(.failure(UsageError.noCredentials)) }
            return
        }
        fetchCredits(cookie: cookie) { result in
            switch result {
            case .success:
                DispatchQueue.main.async { completion(.success(())) }
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// 取消所有正在进行的网络请求
    func cancelAllRequests() {
        tasksLock.lock()
        let tasks = activeTasks
        activeTasks.removeAll()
        tasksLock.unlock()
        tasks.forEach { $0.cancel() }
        AppLog.event(.api, "Cancelled all in-flight Command Code network requests")
    }

    // MARK: - Private: Endpoints

    private func fetchCredits(
        cookie: CommandCodeCookie,
        completion: @escaping (Result<CommandCodeCreditsPayload, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + creditsPath) else {
            completion(.failure(UsageError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        CommandCodeAPIHeaderBuilder.applyHeaders(to: &request, cookieHeader: cookie.headerValue)

        let task = session.dataTask(with: request) { data, response, error in
            let result: Result<CommandCodeCreditsPayload, Error> = {
                if let error = error {
                    AppLog.error(.api, "Command Code credits request failed with a network error: \(error.localizedDescription)")
                    return .failure(UsageError.fromTransportError(error))
                }
                guard let data = data else { return .failure(UsageError.noData) }
                if let failure = Self.httpFailure(data: data, response: response) {
                    return .failure(failure)
                }
                if let raw = String(data: data, encoding: .utf8) {
                    AppLog.trace(.api, "Command Code credits response body: \(raw.prefix(500))")
                }
                do {
                    return .success(try CommandCodeCreditsPayload.parse(from: data))
                } catch {
                    AppLog.error(.api, "Command Code credits response could not be decoded: \(error.localizedDescription)")
                    return .failure(UsageError.decodingError)
                }
            }()
            completion(result)
        }
        trackTask(task)
        task.resume()
    }

    private func fetchSubscription(
        cookie: CommandCodeCookie,
        completion: @escaping (Result<CommandCodeSubscriptionPayload?, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + subscriptionsPath) else {
            completion(.failure(UsageError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        CommandCodeAPIHeaderBuilder.applyHeaders(to: &request, cookieHeader: cookie.headerValue)

        let task = session.dataTask(with: request) { data, response, error in
            let result: Result<CommandCodeSubscriptionPayload?, Error> = {
                if let error = error {
                    AppLog.warning(.api, "Command Code subscription request failed with a network error: \(error.localizedDescription)")
                    return .failure(UsageError.fromTransportError(error))
                }
                guard let data = data else { return .failure(UsageError.noData) }
                if let failure = Self.httpFailure(data: data, response: response) {
                    return .failure(failure)
                }
                if let raw = String(data: data, encoding: .utf8) {
                    AppLog.trace(.api, "Command Code subscription response body: \(raw.prefix(300))")
                }
                do {
                    return .success(try CommandCodeSubscriptionPayload.parse(from: data))
                } catch {
                    AppLog.warning(.api, "Command Code subscription response could not be decoded: \(error.localizedDescription)")
                    return .failure(UsageError.decodingError)
                }
            }()
            completion(result)
        }
        trackTask(task)
        task.resume()
    }

    /// 把非 2xx / HTML 响应映射为 UsageError；2xx 返回 nil
    private static func httpFailure(data: Data, response: URLResponse?) -> UsageError? {
        if let raw = String(data: data, encoding: .utf8),
           raw.contains("<!DOCTYPE html>") || raw.contains("<html") {
            AppLog.warning(.api, "Command Code endpoint returned HTML instead of JSON")
            return .cloudflareBlocked
        }
        guard let http = response as? HTTPURLResponse else { return nil }
        AppLog.event(.api, "Command Code response received: HTTP \(http.statusCode)")
        switch http.statusCode {
        case 200...299:
            return nil
        case 401, 403:
            return .unauthorized
        case 429:
            return .fromRateLimitResponse(http)
        default:
            return .httpError(statusCode: http.statusCode)
        }
    }

    /// 线程安全地记录进行中的任务，供 cancelAllRequests 统一取消
    private func trackTask(_ task: URLSessionDataTask) {
        tasksLock.lock()
        activeTasks.append(task)
        tasksLock.unlock()
    }

    // MARK: - Debug Mock Data

    #if DEBUG
    private static func createMockData() -> CommandCodeUsageData {
        let now = Date()
        return CommandCodeUsageData(
            fiveHour: .init(percentage: 32, resetsAt: now.addingTimeInterval(3 * 3600 + 12 * 60)),
            weekly: .init(percentage: 41, resetsAt: now.addingTimeInterval(2 * 24 * 3600 + 4 * 3600)),
            monthlyCreditsRemaining: 42.5,
            monthlyCreditsGranted: 70,
            purchasedCredits: 0,
            planName: "GOAT",
            billingPeriodEnd: now.addingTimeInterval(27 * 24 * 3600)
        )
    }
    #endif
}
