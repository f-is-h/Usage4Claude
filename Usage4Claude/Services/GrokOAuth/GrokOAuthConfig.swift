//
//  GrokOAuthConfig.swift
//  Usage4Claude
//
//  OIDC config for Grok Build / xAI auth.
//  Reuses the official Grok CLI public client (PKCE / device-code, no secret).
//  Constants observed from Grok CLI auth (`auth.x.ai` OIDC + `~/.grok/auth.json`).
//

import Foundation

enum GrokOAuthConfig {
    /// OIDC issuer
    static let issuer = "https://auth.x.ai"
    /// Authorization endpoint
    static let authorizeURL = "\(issuer)/oauth2/authorize"
    /// Token / refresh endpoint
    static let tokenURL = "\(issuer)/oauth2/token"
    /// Device authorization endpoint
    static let deviceCodeURL = "\(issuer)/oauth2/device/code"
    /// Userinfo endpoint
    static let userinfoURL = "\(issuer)/oauth2/userinfo"

    /// Grok CLI public OAuth client id (no client secret; supports device code + PKCE)
    static let clientID = "b1a00492-073a-47ea-816f-4c329264a828"

    /// Scopes required for billing/usage + silent refresh
    static let scope = "openid profile email offline_access grok-cli:access api:access conversations:read conversations:write"

    /// Grok Build billing/usage API base (includes `/v1`)
    static let billingBaseURL = "https://cli-chat-proxy.grok.com/v1"

    /// Credits-format weekly quota
    static var creditsBillingURL: URL {
        URL(string: "\(billingBaseURL)/billing?format=credits")!
    }

    /// Monthly included allowance form
    static var monthlyBillingURL: URL {
        URL(string: "\(billingBaseURL)/billing")!
    }

    /// Default path for Grok CLI credentials (import helper)
    static var defaultAuthJSONPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".grok")
            .appendingPathComponent("auth.json")
    }
}
