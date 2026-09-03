//
//  AccountTokenRotation.swift
//  Usage4Claude
//
//  决定一次 token 轮换该落到哪个账号上。
//  Lives here (not Helpers/) so it can be cherry-picked into a SwiftPM test
//  target — 与 CodexUsageData.swift 同一约定，本文件不得依赖 `L.*`/`Logger`/UI。
//
//  背景：token 刷新是异步的，从发起到回调之间用户随时可能切换账号。此前所有写回
//  都走「当前选中账号」（silentlyUpdateCurrentXxxSessionToken），于是切换一次就
//  可能把 A 的新 token 写进 B 的条目。Claude OAuth 侧后果最重：refresh_token 一
//  经轮换，旧值即被服务端作废，于是 A 丢了新值、B 被覆盖，两个账号同时永久登出。
//
//  修复思路是不再依赖「当前是谁」，改用发起刷新时那一刻的旧 token 反查账号——
//  token 唯一，找不到就说明账号已被删除或已被另一次刷新写过，此时宁可不写。
//
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Foundation

/// 把「新 token 该写给谁」这一判断从 AccountStore 里剥出来，使其可被单元测试覆盖
enum AccountTokenRotation {

    /// 一次轮换的处置结果
    enum Outcome: Equatable {
        /// 写入 accounts[index]
        case apply(index: Int)
        /// 不写入，并说明原因（调用方据此打日志）
        case skip(Reason)

        enum Reason: Equatable {
            /// 找不到持有旧 token 的账号：刷新期间账号被删除，或已被另一次刷新写成别的值。
            /// 这正是必须放弃写入的情形——回退到「当前账号」就会污染别人的凭据。
            case accountGone
            /// 新旧 token 相同，服务端未续期，无需落盘
            case unchanged
            /// 新 token 为空，不能拿它覆盖仍然有效的凭据
            case emptyToken
        }
    }

    /// 解析一次 token 轮换的目标账号
    /// - Parameters:
    ///   - accounts: 当前账号列表（Claude 或 Codex 各自的列表）
    ///   - oldToken: 发起刷新时该账号持有的 token
    ///   - newToken: 服务端返回的新 token
    static func resolve(accounts: [Account], replacing oldToken: String, with newToken: String) -> Outcome {
        guard !newToken.isEmpty else { return .skip(.emptyToken) }
        guard newToken != oldToken else { return .skip(.unchanged) }
        guard let index = accounts.firstIndex(where: { $0.sessionKey == oldToken }) else {
            return .skip(.accountGone)
        }
        return .apply(index: index)
    }
}
