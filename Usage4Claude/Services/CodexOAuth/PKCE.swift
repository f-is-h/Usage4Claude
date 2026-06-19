//
//  PKCE.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-18.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Foundation
import CryptoKit

/// PKCE（RFC 7636）参数，外加 OAuth state（防 CSRF）
/// code_challenge 使用 S256（SHA-256 + base64url）
struct PKCECodes {
    let codeVerifier: String
    let codeChallenge: String
    let state: String

    init() {
        codeVerifier = Self.randomURLSafe(byteCount: 64)
        state = Self.randomURLSafe(byteCount: 32)
        let digest = SHA256.hash(data: Data(codeVerifier.utf8))
        codeChallenge = Self.base64URL(Data(digest))
    }

    /// 生成 URL-safe 随机串（base64url，无填充）
    private static func randomURLSafe(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return base64URL(Data(bytes))
    }

    /// base64url 编码（无填充）
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
