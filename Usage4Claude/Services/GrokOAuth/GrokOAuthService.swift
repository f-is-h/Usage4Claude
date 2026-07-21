//
//  GrokOAuthService.swift
//  Usage4Claude
//
//  Grok OIDC helpers: refresh_token → access_token, device-code login,
//  and import of credentials from Grok CLI's ~/.grok/auth.json.
//

import Foundation
import OSLog

struct GrokOAuthTokens: Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let email: String?
    let teamId: String?
    let userId: String?
}

enum GrokOAuthService {

    // MARK: - Refresh

    /// Exchange a refresh_token for a new access_token (and possibly rotated refresh_token).
    static func refresh(
        refreshToken: String,
        completion: @escaping (Result<GrokOAuthTokens, Error>) -> Void
    ) {
        guard let url = URL(string: GrokOAuthConfig.tokenURL) else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": GrokOAuthConfig.clientID
        ]
        request.httpBody = formURLEncoded(body).data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                Logger.api.debug("Grok OAuth refresh network error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(UsageError.networkError)) }
                return
            }
            guard let data else {
                DispatchQueue.main.async { completion(.failure(UsageError.noData)) }
                return
            }
            if let http = response as? HTTPURLResponse {
                Logger.api.debug("Grok OAuth refresh HTTP \(http.statusCode)")
                if http.statusCode == 401 || http.statusCode == 400 {
                    DispatchQueue.main.async { completion(.failure(UsageError.unauthorized)) }
                    return
                }
                guard (200...299).contains(http.statusCode) else {
                    DispatchQueue.main.async { completion(.failure(UsageError.httpError(statusCode: http.statusCode))) }
                    return
                }
            }
            do {
                let tokens = try decodeTokenResponse(data, fallbackRefresh: refreshToken)
                DispatchQueue.main.async { completion(.success(tokens)) }
            } catch {
                Logger.api.debug("Grok OAuth refresh decode error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(UsageError.decodingError)) }
            }
        }.resume()
    }

    /// Async wrapper used by OAuthTokenCache
    static func refresh(refreshToken: String) async throws -> OAuthTokenCache.Tokens {
        try await withCheckedThrowingContinuation { continuation in
            refresh(refreshToken: refreshToken) { result in
                switch result {
                case .success(let t):
                    continuation.resume(returning: OAuthTokenCache.Tokens(
                        accessToken: t.accessToken,
                        refreshToken: t.refreshToken ?? refreshToken,
                        expiresAt: t.expiresAt
                    ))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Device code flow

    struct DeviceCodeResponse: Sendable {
        let deviceCode: String
        let userCode: String
        let verificationURI: URL
        let verificationURIComplete: URL?
        let expiresIn: Int
        let interval: Int
    }

    static func requestDeviceCode(
        completion: @escaping (Result<DeviceCodeResponse, Error>) -> Void
    ) {
        guard let url = URL(string: GrokOAuthConfig.deviceCodeURL) else {
            completion(.failure(UsageError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = [
            "client_id": GrokOAuthConfig.clientID,
            "scope": GrokOAuthConfig.scope
        ]
        request.httpBody = formURLEncoded(body).data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                Logger.api.debug("Grok device code error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(UsageError.networkError)) }
                return
            }
            guard let data else {
                DispatchQueue.main.async { completion(.failure(UsageError.noData)) }
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                DispatchQueue.main.async { completion(.failure(UsageError.httpError(statusCode: http.statusCode))) }
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                guard let deviceCode = json["device_code"] as? String,
                      let userCode = json["user_code"] as? String,
                      let uriString = json["verification_uri"] as? String,
                      let uri = URL(string: uriString) else {
                    DispatchQueue.main.async { completion(.failure(UsageError.decodingError)) }
                    return
                }
                let complete = (json["verification_uri_complete"] as? String).flatMap(URL.init(string:))
                let expiresIn = (json["expires_in"] as? Int) ?? 600
                let interval = (json["interval"] as? Int) ?? 5
                let response = DeviceCodeResponse(
                    deviceCode: deviceCode,
                    userCode: userCode,
                    verificationURI: uri,
                    verificationURIComplete: complete,
                    expiresIn: expiresIn,
                    interval: interval
                )
                DispatchQueue.main.async { completion(.success(response)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(UsageError.decodingError)) }
            }
        }.resume()
    }

    /// Poll the token endpoint until authorized, expired, or cancelled.
    static func pollDeviceToken(
        deviceCode: String,
        interval: Int,
        expiresIn: Int,
        shouldCancel: @escaping () -> Bool = { false },
        completion: @escaping (Result<GrokOAuthTokens, Error>) -> Void
    ) {
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        let pollInterval = max(interval, 3)

        func pollOnce() {
            if shouldCancel() {
                completion(.failure(UsageError.sessionExpired))
                return
            }
            if Date() > deadline {
                completion(.failure(UsageError.sessionExpired))
                return
            }

            guard let url = URL(string: GrokOAuthConfig.tokenURL) else {
                completion(.failure(UsageError.invalidURL))
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let body = [
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "device_code": deviceCode,
                "client_id": GrokOAuthConfig.clientID
            ]
            request.httpBody = formURLEncoded(body).data(using: .utf8)

            URLSession.shared.dataTask(with: request) { data, response, error in
                if shouldCancel() {
                    DispatchQueue.main.async { completion(.failure(UsageError.sessionExpired)) }
                    return
                }
                if error != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(pollInterval)) { pollOnce() }
                    return
                }
                guard let data else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(pollInterval)) { pollOnce() }
                    return
                }

                // Pending / slow-down responses come back as JSON error objects
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = json["error"] as? String {
                    switch err {
                    case "authorization_pending", "slow_down":
                        let delay = err == "slow_down" ? pollInterval + 5 : pollInterval
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(delay)) { pollOnce() }
                        return
                    case "expired_token", "access_denied":
                        DispatchQueue.main.async { completion(.failure(UsageError.sessionExpired)) }
                        return
                    default:
                        DispatchQueue.main.async { completion(.failure(UsageError.unauthorized)) }
                        return
                    }
                }

                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    // Retry on transient server errors
                    if (500...599).contains(http.statusCode) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pollInterval)) { pollOnce() }
                        return
                    }
                    DispatchQueue.main.async { completion(.failure(UsageError.httpError(statusCode: http.statusCode))) }
                    return
                }

                do {
                    let tokens = try decodeTokenResponse(data, fallbackRefresh: nil)
                    DispatchQueue.main.async { completion(.success(tokens)) }
                } catch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(pollInterval)) { pollOnce() }
                }
            }.resume()
        }

        pollOnce()
    }

    // MARK: - Import ~/.grok/auth.json

    /// Parse Grok CLI auth.json and return the first usable credential set.
    static func importFromAuthJSON(at url: URL) throws -> GrokOAuthTokens {
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.decodingError
        }

        // Shape: { "https://auth.x.ai::<client_id>": { key, refresh_token, email, team_id, ... } }
        for (_, value) in root {
            guard let entry = value as? [String: Any] else { continue }
            let access = (entry["key"] as? String) ?? (entry["access_token"] as? String)
            let refresh = entry["refresh_token"] as? String
            guard let refresh, !refresh.isEmpty else { continue }

            let expiresAt: Date = {
                if let s = entry["expires_at"] as? String {
                    let f1 = ISO8601DateFormatter()
                    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let d = f1.date(from: s) { return d }
                    let f2 = ISO8601DateFormatter()
                    f2.formatOptions = [.withInternetDateTime]
                    if let d = f2.date(from: s) { return d }
                }
                // Default: treat existing access token as short-lived; force refresh soon
                return Date().addingTimeInterval(5 * 60)
            }()

            return GrokOAuthTokens(
                accessToken: access ?? "",
                refreshToken: refresh,
                expiresAt: expiresAt,
                email: entry["email"] as? String,
                teamId: entry["team_id"] as? String,
                userId: entry["user_id"] as? String
            )
        }
        throw UsageError.noCredentials
    }

    // MARK: - Helpers

    private static func formURLEncoded(_ params: [String: String]) -> String {
        params
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }

    private static func decodeTokenResponse(
        _ data: Data,
        fallbackRefresh: String?
    ) throws -> GrokOAuthTokens {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let access = json["access_token"] as? String, !access.isEmpty else {
            throw UsageError.decodingError
        }
        let refresh = (json["refresh_token"] as? String) ?? fallbackRefresh
        let expiresIn = (json["expires_in"] as? Int) ?? 3600
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

        // Optional identity fields (present on some login responses / userinfo)
        let email = json["email"] as? String
        let teamId = (json["team_id"] as? String) ?? (json["teamId"] as? String)
        let userId = (json["user_id"] as? String) ?? (json["sub"] as? String)

        return GrokOAuthTokens(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: expiresAt,
            email: email,
            teamId: teamId,
            userId: userId
        )
    }
}
