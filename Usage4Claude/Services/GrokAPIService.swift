//
//  GrokAPIService.swift
//  Usage4Claude
//
//  Grok Build usage service.
//  Auth: OIDC refresh_token (stored in Account.sessionKey) → access_token.
//  Usage: GET cli-chat-proxy.grok.com/v1/billing (?format=credits + monthly form).
//

import Foundation
import OSLog

/// Grok usage API service
class GrokAPIService {

    // MARK: - Properties

    private let settings = UserSettings.shared
    private let session: URLSession
    private var activeTasks: [URLSessionDataTask] = []
    private let tasksLock = NSLock()

    /// Refresh when access token is within 20 minutes of expiry
    private static let tokenRefreshMargin: TimeInterval = 20 * 60

    private let tokenCache = OAuthTokenCache()

    private func trackTask(_ task: URLSessionDataTask) {
        tasksLock.lock()
        activeTasks.append(task)
        tasksLock.unlock()
    }

    func clearAccessTokenCache() {
        Task { await tokenCache.clear() }
    }

    // MARK: - Init

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public

    /// Fetch Grok usage (refresh token → access token → billing endpoints)
    func fetchUsage(completion: @escaping (Result<GrokUsageData, Error>) -> Void) {
        #if DEBUG
        if settings.debugModeEnabled {
            let mock = createMockData()
            DispatchQueue.main.async { completion(.success(mock)) }
            return
        }
        #endif

        cancelAllRequests()

        guard settings.hasValidGrokCredentials else {
            completion(.failure(UsageError.noCredentials))
            return
        }

        let refreshToken = settings.grokRefreshToken

        fetchAccessToken(refreshToken: refreshToken) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let accessToken):
                self.fetchBilling(accessToken: accessToken) { usageResult in
                    DispatchQueue.main.async { completion(usageResult) }
                }
            }
        }
    }

    func fetchUsageResult() async -> Result<GrokUsageData, Error> {
        await withCheckedContinuation { continuation in
            fetchUsage { continuation.resume(returning: $0) }
        }
    }

    /// Validate credentials by refreshing + hitting credits billing once
    func validateAndFetchIdentity(
        refreshToken: String,
        completion: @escaping (Result<(email: String, teamId: String), Error>) -> Void
    ) {
        GrokOAuthService.refresh(refreshToken: refreshToken) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let tokens):
                let email = tokens.email ?? "Grok"
                let teamId = tokens.teamId ?? tokens.userId ?? UUID().uuidString
                // Confirm billing is reachable
                self.fetchBilling(accessToken: tokens.accessToken) { billing in
                    switch billing {
                    case .success:
                        completion(.success((email: email, teamId: teamId)))
                    case .failure(let error):
                        // Auth worked even if billing fails; still accept the account
                        if case UsageError.unauthorized = error {
                            completion(.failure(error))
                        } else {
                            completion(.success((email: email, teamId: teamId)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Token

    private func fetchAccessToken(
        refreshToken: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                let accessToken = try await tokenCache.accessToken(
                    refreshToken: refreshToken,
                    margin: Self.tokenRefreshMargin
                ) { [weak self] credential in
                    guard self != nil else { throw UsageError.networkError }
                    let tokens = try await GrokOAuthService.refresh(refreshToken: credential)
                    // Persist rotated refresh_token if present
                    if tokens.refreshToken != credential, !tokens.refreshToken.isEmpty {
                        await MainActor.run {
                            UserSettings.shared.silentlyUpdateCurrentGrokRefreshToken(tokens.refreshToken)
                        }
                    }
                    return tokens
                }
                await MainActor.run { completion(.success(accessToken)) }
            } catch {
                switch error {
                case UsageError.unauthorized, UsageError.sessionExpired:
                    break
                default:
                    if let fallback = await tokenCache.validCachedToken(refreshToken: refreshToken) {
                        Logger.api.warning("Grok token refresh failed (\(error.localizedDescription)), using cached token")
                        await MainActor.run { completion(.success(fallback)) }
                        return
                    }
                }
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Billing

    private func fetchBilling(
        accessToken: String,
        completion: @escaping (Result<GrokUsageData, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var creditsResponse: GrokCreditsBillingResponse?
        var monthlyResponse: GrokMonthlyBillingResponse?
        var firstError: Error?
        let lock = NSLock()

        group.enter()
        fetchJSON(
            url: GrokOAuthConfig.creditsBillingURL,
            accessToken: accessToken
        ) { (result: Result<GrokCreditsBillingResponse, Error>) in
            lock.lock()
            switch result {
            case .success(let value): creditsResponse = value
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        fetchJSON(
            url: GrokOAuthConfig.monthlyBillingURL,
            accessToken: accessToken
        ) { (result: Result<GrokMonthlyBillingResponse, Error>) in
            lock.lock()
            switch result {
            case .success(let value): monthlyResponse = value
            case .failure(let error):
                // Monthly is supplemental; only record error if credits also failed
                if firstError == nil { firstError = error }
            }
            lock.unlock()
            group.leave()
        }

        group.notify(queue: .main) {
            if creditsResponse == nil && monthlyResponse == nil {
                completion(.failure(firstError ?? UsageError.noData))
                return
            }
            // If credits failed with unauthorized, surface that
            if creditsResponse == nil, let err = firstError as? UsageError {
                switch err {
                case .unauthorized, .sessionExpired:
                    completion(.failure(err))
                    return
                default:
                    break
                }
            }
            let data = GrokUsageDataBuilder.combine(credits: creditsResponse, monthly: monthlyResponse)
            if data.weekly == nil && data.monthly == nil && data.credits == nil {
                completion(.failure(UsageError.noData))
                return
            }
            completion(.success(data))
        }
    }

    private func fetchJSON<T: Decodable>(
        url: URL,
        accessToken: String,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Usage4Claude/Grok", forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                Logger.api.debug("Grok billing error: \(error.localizedDescription)")
                completion(.failure(UsageError.networkError))
                return
            }
            guard let data else {
                completion(.failure(UsageError.noData))
                return
            }
            if let http = response as? HTTPURLResponse {
                Logger.api.debug("Grok billing HTTP \(http.statusCode) for \(url.lastPathComponent)")
                switch http.statusCode {
                case 200...299:
                    break
                case 401:
                    Task { await self?.tokenCache.clear() }
                    completion(.failure(UsageError.unauthorized))
                    return
                case 403:
                    completion(.failure(UsageError.cloudflareBlocked))
                    return
                case 429:
                    completion(.failure(UsageError.rateLimited))
                    return
                default:
                    completion(.failure(UsageError.httpError(statusCode: http.statusCode)))
                    return
                }
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                Logger.api.debug("Grok billing decode error: \(error.localizedDescription)")
                completion(.failure(UsageError.decodingError))
            }
        }
        trackTask(task)
        task.resume()
    }

    // MARK: - Debug mock

    #if DEBUG
    private func createMockData() -> GrokUsageData {
        let weeklyPct = Double(settings.debugGrokWeeklyPercentage)
        let monthlyPct = Double(settings.debugGrokMonthlyPercentage)
        let weeklyReset = Date().addingTimeInterval(3600 * 24 * 3.5)
        let monthlyReset = Date().addingTimeInterval(3600 * 24 * 12)
        return GrokUsageData(
            weekly: .init(percentage: weeklyPct, resetsAt: weeklyReset, used: nil, limit: nil),
            monthly: .init(
                percentage: monthlyPct,
                resetsAt: monthlyReset,
                used: monthlyPct * 1500,
                limit: 150_000
            ),
            credits: GrokCreditsData(
                prepaidBalance: 0,
                onDemandCap: 0,
                onDemandUsed: 0,
                creditUsagePercent: weeklyPct,
                isUnifiedBillingUser: true
            )
        )
    }
    #endif
}

// MARK: - UsageProvider

extension GrokAPIService: UsageProvider {
    var providerType: ProviderType { .grok }

    func cancelAllRequests() {
        tasksLock.lock()
        let tasks = activeTasks
        activeTasks.removeAll()
        tasksLock.unlock()
        tasks.forEach { $0.cancel() }
        Logger.api.debug("Grok: cancelled in-flight network requests")
    }
}
