//
//  CommandCodeCookieHeader.swift
//  Usage4Claude
//
//  Parses a pasted Command Code session cookie into a `Cookie:` header value.
//  Lives in Helpers/ so it can be cherry-picked into a SwiftPM test target —
//  every symbol must stay free of L.*/Logger/UI dependencies.
//
//  Command Code uses better-auth. The production cookie is
//  `__Secure-commandcode_prod_.session_token`; explicitly named legacy
//  better-auth cookies remain supported so a pasted dev cookie still works.
//  The user pastes either a bare token, a `name=value` pair, a full `Cookie:`
//  header, or a cURL capture — `cookie(fromRaw:)` accepts all of them.
//

import Foundation

/// A resolved Command Code session cookie ready to send in a `Cookie:` header.
nonisolated struct CommandCodeCookie: Sendable, Equatable {
    /// Cookie name (e.g. `__Secure-commandcode_prod_.session_token`).
    let name: String
    /// Cookie value.
    let token: String

    /// `name=value` header value.
    var headerValue: String { "\(name)=\(token)" }
}

nonisolated enum CommandCodeCookieHeader {

    /// Cookie names used by better-auth in production (HTTPS) and dev (HTTP).
    /// The `__Secure-` variant is the standard production deployment.
    static let supportedSessionCookieNames = [
        "__Secure-commandcode_prod_.session_token",
        "commandcode_prod_.session_token",
        "__Host-commandcode_prod_.session_token",
        "__Host-better-auth.session_token",
        "__Secure-better-auth.session_token",
        "better-auth.session_token"
    ]

    /// Name assumed when the user pastes a bare token with no `name=value` form.
    static let defaultSessionCookieName = "__Secure-commandcode_prod_.session_token"

    /// Extract a session cookie from a list of `HTTPCookie` records.
    static func cookie(fromCookies cookies: [HTTPCookie]) -> CommandCodeCookie? {
        extractSessionCookie(from: cookies.map { (name: $0.name, value: $0.value) })
    }

    /// Parse a raw pasted value — a bare token, a `Cookie:` header, or cURL
    /// capture — and extract the Command Code session cookie.
    /// - Parameter raw: whatever the user pasted.
    /// - Returns: the session cookie, or nil when nothing usable was found.
    static func cookie(fromRaw raw: String?) -> CommandCodeCookie? {
        guard var trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        // Tolerate a pasted full header line ("Cookie: a=b; c=d").
        if let range = trimmed.range(of: "cookie:", options: [.caseInsensitive, .anchored]) {
            trimmed = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Bare tokens carry no '=' or ';' — assume the production cookie name.
        if !trimmed.contains("="), !trimmed.contains(";") {
            return CommandCodeCookie(name: defaultSessionCookieName, token: trimmed)
        }

        var pairs: [(name: String, value: String)] = []
        for chunk in trimmed.split(separator: ";") {
            let piece = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = piece.firstIndex(of: "=") else { continue }
            let key = String(piece[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(piece[piece.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }
            pairs.append((name: key, value: value))
        }
        return extractSessionCookie(from: pairs)
    }

    private static func extractSessionCookie(from pairs: [(name: String, value: String)]) -> CommandCodeCookie? {
        var byLowerName: [String: (name: String, value: String)] = [:]
        for pair in pairs {
            byLowerName[pair.name.lowercased()] = pair
        }
        for expected in supportedSessionCookieNames {
            if let match = byLowerName[expected.lowercased()] {
                return CommandCodeCookie(name: match.name, token: match.value)
            }
        }
        return nil
    }
}
