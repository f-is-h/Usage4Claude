//
//  ClaudeWarmupService.swift
//  Usage4Claude
//
//  Manual inference warm-ups, ported from UsageResetter's lib/warmup.ts.
//

import Foundation
import OSLog

struct ClaudeWarmupResult {
    let accountID: UUID
    let accountName: String
    let succeeded: Bool
    let statusCode: Int?
    let error: String?
}

struct ClaudeWarmupSummary {
    let results: [ClaudeWarmupResult]

    var succeeded: Int { results.filter(\.succeeded).count }
    var total: Int { results.count }
}

final class ClaudeWarmupService {
    static let shared = ClaudeWarmupService()

    private static let messagesURL = "https://api.anthropic.com/v1/messages"
    private static let model = "claude-haiku-4-5"

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func warmUp(
        accounts: [Account],
        completion: @escaping (ClaudeWarmupSummary) -> Void
    ) {
        guard !accounts.isEmpty else {
            DispatchQueue.main.async { completion(ClaudeWarmupSummary(results: [])) }
            return
        }

        let group = DispatchGroup()
        let resultQueue = DispatchQueue(label: "xyz.fi5h.Usage4Claude.warmup-results")
        var results: [ClaudeWarmupResult] = []

        for account in accounts {
            group.enter()
            warmUp(account: account) { result in
                resultQueue.async {
                    results.append(result)
                    group.leave()
                }
            }
        }

        group.notify(queue: resultQueue) {
            let ordered = accounts.compactMap { account in
                results.first { $0.accountID == account.id }
            }
            DispatchQueue.main.async {
                completion(ClaudeWarmupSummary(results: ordered))
            }
        }
    }

    private func warmUp(account: Account, completion: @escaping (ClaudeWarmupResult) -> Void) {
        let token = account.oauthToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            completion(ClaudeWarmupResult(
                accountID: account.id,
                accountName: account.displayName,
                succeeded: false,
                statusCode: nil,
                error: "No OAuth token configured"
            ))
            return
        }

        // Kimi for Coding key → Kimi 的 Anthropic 兼容端点；否则走 Anthropic 官方端点
        let isKimi = KimiAPIService.isKimiKey(token)
        let urlString = isKimi ? KimiAPIService.messagesURL : Self.messagesURL
        let model = isKimi ? KimiAPIService.warmupModel : Self.model

        guard let url = URL(string: urlString),
              let body = try? JSONSerialization.data(withJSONObject: [
                "model": model,
                "max_tokens": 1,
                "messages": [["role": "user", "content": "hi"]]
              ]) else {
            completion(ClaudeWarmupResult(
                accountID: account.id,
                accountName: account.displayName,
                succeeded: false,
                statusCode: nil,
                error: "Could not build warm-up request"
            ))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if !isKimi {
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue(ClaudeOAuthConfig.betaHeader, forHTTPHeaderField: "anthropic-beta")
        }

        session.dataTask(with: request) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let succeeded = statusCode.map { (200...299).contains($0) } ?? false
            let upstreamError = succeeded ? nil : Self.errorMessage(data: data, statusCode: statusCode, error: error)

            if let upstreamError {
                Logger.api.info("Warm-up failed for \(account.displayName, privacy: .public): \(upstreamError, privacy: .public)")
            }

            completion(ClaudeWarmupResult(
                accountID: account.id,
                accountName: account.displayName,
                succeeded: succeeded,
                statusCode: statusCode,
                error: upstreamError
            ))
        }.resume()
    }

    private static func errorMessage(data: Data?, statusCode: Int?, error: Error?) -> String {
        if let error { return error.localizedDescription }
        if let data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObject = json["error"] as? [String: Any],
           let message = errorObject["message"] as? String,
           !message.isEmpty {
            return message
        }
        if let statusCode { return "HTTP \(statusCode)" }
        return "Network error"
    }
}
