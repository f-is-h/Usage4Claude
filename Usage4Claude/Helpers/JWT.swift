//
//  JWT.swift
//  Usage4Claude
//
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 从 JWT 中解析 payload 的 `exp` 字段
/// - Note: JWT payload 使用 base64url 编码（字母表含 `-`/`_`，无 padding），
///   必须先转换为标准 base64 字母表再解码，否则含 `-`/`_` 的 payload 会解码失败。
func jwtExpiry(from token: String) -> Date? {
    let parts = token.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    var base64 = String(parts[1])
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let remainder = base64.count % 4
    if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
    guard let data = Data(base64Encoded: base64),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let exp = json["exp"] as? TimeInterval else { return nil }
    return Date(timeIntervalSince1970: exp)
}
