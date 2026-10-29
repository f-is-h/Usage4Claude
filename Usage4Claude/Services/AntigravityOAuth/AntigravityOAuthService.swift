import Foundation

struct AntigravityOAuthService {
    static let session: URLSession = {
        let config = URLSessionConfiguration.uncached
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()
    static func form(_ values: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return values.sorted { $0.key < $1.key }.map {
            $0.key.addingPercentEncoding(withAllowedCharacters: allowed)! + "=" +
            $0.value.addingPercentEncoding(withAllowedCharacters: allowed)!
        }.joined(separator: "&").data(using: .utf8)!
    }
    static func json(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AntigravityError.malformedOutput }
        if http.statusCode == 401 || http.statusCode == 403 { throw AntigravityError.notLoggedIn }
        guard (200..<300).contains(http.statusCode) else { throw AntigravityError.commandFailed("HTTP \(http.statusCode)") }
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AntigravityError.malformedOutput }
        return result
    }
    static func token(_ values: [String: String], previous: AntigravityCredentials? = nil) async throws -> AntigravityCredentials {
        var request = URLRequest(url: AntigravityOAuthConfig.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form(values)
        let result = try await json(request)
        guard let access = result["access_token"] as? String,
              let refresh = result["refresh_token"] as? String ?? previous?.refreshToken,
              !access.isEmpty, !refresh.isEmpty else { throw AntigravityError.notLoggedIn }
        return AntigravityCredentials(accessToken: access, refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(result["expires_in"] as? Double ?? 1800),
            clientID: values["client_id"]!, clientSecret: values["client_secret"]!, projectID: previous?.projectID)
    }
    static func identity(_ access: String) async throws -> (subject: String, email: String) {
        var request = URLRequest(url: AntigravityOAuthConfig.userInfoURL)
        request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let profile = try await json(request)
        guard let email = profile["email"] as? String, !email.isEmpty,
              profile["verified_email"] as? Bool == true else { throw AntigravityError.notLoggedIn }
        return (profile["id"] as? String ?? email.lowercased(), email)
    }
}
