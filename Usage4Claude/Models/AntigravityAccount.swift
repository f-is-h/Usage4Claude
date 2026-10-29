import Foundation

nonisolated struct AntigravityAccount: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var email: String
    var subject: String
    var alias: String = ""
    var credentials: AntigravityCredentials?
    var displayName: String { alias.isEmpty ? email : alias }
    var isLocal: Bool { credentials == nil }
}

nonisolated struct AntigravityCredentials: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var clientID: String
    var clientSecret: String
    var projectID: String?
}
