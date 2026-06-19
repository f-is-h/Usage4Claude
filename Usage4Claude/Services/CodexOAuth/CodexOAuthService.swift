//
//  CodexOAuthService.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-18.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Foundation
import OSLog

/// OAuth token 端点返回的凭据
struct CodexOAuthTokens {
    let idToken: String
    let accessToken: String
    /// refresh 端点未轮换时可能为空字符串，调用方应保留旧值
    let refreshToken: String
    let accountId: String?
}

/// Codex OAuth token 端点交互
///
/// 两类请求 body 编码不同，与 OpenAI 官方 Codex CLI 一致：
///   - 授权码交换（authorization_code）：`application/x-www-form-urlencoded`
///   - refresh_token 续期：`application/json`
enum CodexOAuthService {

    // MARK: - 授权码换 token（form-urlencoded）

    static func exchangeCode(
        code: String,
        codeVerifier: String,
        redirectURI: String,
        completion: @escaping (Result<CodexOAuthTokens, Error>) -> Void
    ) {
        guard let url = URL(string: CodexOAuthConfig.tokenURL) else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: CodexOAuthConfig.clientID),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = (comps.percentEncodedQuery ?? "").data(using: .utf8)
        send(request, completion: completion)
    }

    // MARK: - refresh_token 续期（JSON）

    static func refresh(
        refreshToken: String,
        completion: @escaping (Result<CodexOAuthTokens, Error>) -> Void
    ) {
        guard let url = URL(string: CodexOAuthConfig.tokenURL) else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        let payload: [String: String] = [
            "client_id": CodexOAuthConfig.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(UsageError.decodingError))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        send(request, completion: completion)
    }

    // MARK: - Private

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static func send(_ request: URLRequest, completion: @escaping (Result<CodexOAuthTokens, Error>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.api.error("Codex OAuth token 请求失败: \(error.localizedDescription)")
                completion(.failure(UsageError.networkError))
                return
            }
            guard let data = data else {
                completion(.failure(UsageError.noData))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                Logger.api.error("Codex OAuth token HTTP \(http.statusCode): \(bodyText.prefix(200))")
                completion(.failure(http.statusCode == 401 ? UsageError.unauthorized
                                    : UsageError.httpError(statusCode: http.statusCode)))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
                completion(.failure(UsageError.decodingError))
                return
            }
            let idToken = json["id_token"] as? String ?? ""
            // refresh 端点未轮换时可能不返回 refresh_token，置空由调用方保留旧值
            let refreshToken = json["refresh_token"] as? String ?? ""
            let accountId = jwtClaim("chatgpt_account_id", fromAuthClaimOf: accessToken)
                ?? jwtClaim("chatgpt_account_id", fromAuthClaimOf: idToken)
            completion(.success(CodexOAuthTokens(
                idToken: idToken,
                accessToken: accessToken,
                refreshToken: refreshToken,
                accountId: accountId
            )))
        }.resume()
    }

    // MARK: - JWT 解析辅助

    /// 解析 JWT payload 为字典
    private static func jwtPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem != 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// 从 JWT 的 `https://api.openai.com/auth` claim 下取某字段（如 chatgpt_account_id）
    private static func jwtClaim(_ key: String, fromAuthClaimOf token: String) -> String? {
        guard let payload = jwtPayload(token),
              let auth = payload["https://api.openai.com/auth"] as? [String: Any] else { return nil }
        return auth[key] as? String
    }

    /// 从 id_token 解析 email（用于账户显示名）
    static func email(fromIDToken token: String) -> String? {
        jwtPayload(token)?["email"] as? String
    }
}
