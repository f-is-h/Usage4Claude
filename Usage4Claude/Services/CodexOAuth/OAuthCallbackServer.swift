//
//  OAuthCallbackServer.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-18.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Foundation
import Network
import OSLog

/// 本地 OAuth 回调服务器（基于 Network.framework，无第三方依赖）
///
/// 监听 localhost 指定端口，捕获系统浏览器重定向回来的
/// `/auth/callback?code=...&state=...`，向浏览器返回一个成功页面，
/// 并把 query 参数通过 onCallback 投递给上层。
final class OAuthCallbackServer {

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "xyz.fi5h.Usage4Claude.oauth.callback")
    private(set) var port: UInt16 = 0
    private var onCallback: (([String: String]) -> Void)?
    private var didDeliver = false

    /// 依次尝试端口列表，绑定第一个可用端口
    /// - Returns: 成功绑定的端口；全部失败返回 nil
    func start(ports: [UInt16], onCallback: @escaping ([String: String]) -> Void) -> UInt16? {
        self.onCallback = onCallback
        for p in ports where startListener(on: p) {
            self.port = p
            return p
        }
        return nil
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func startListener(on port: UInt16) -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        // 不强制 requiredLocalEndpoint：同时监听 IPv4/IPv6 回环，
        // 避免浏览器把 localhost 解析为 ::1 而服务器只绑 127.0.0.1 导致连接空白。
        // OAuth code 受 PKCE + state 保护且一次性、短时有效，监听回环可接受。

        let listener: NWListener
        do {
            listener = try NWListener(using: params, on: nwPort)
        } catch {
            Logger.settings.error("OAuthCallbackServer: 端口 \(port) 创建监听失败 - \(error.localizedDescription, privacy: .public)")
            return false
        }

        let sema = DispatchSemaphore(value: 0)
        var ready = false
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready = true
                sema.signal()
            case .waiting(let error):
                // 端口被占用时 NWListener 进入 waiting（持续重试），不会 failed。
                // 立即 signal 以便快速切换到下一个端口，并记录真实原因。
                Logger.settings.error("OAuthCallbackServer: 端口 \(port) 不可用（\(error.localizedDescription, privacy: .public)），尝试下一个")
                sema.signal()
            case .failed(let error):
                Logger.settings.error("OAuthCallbackServer: 端口 \(port) 监听失败 - \(error.localizedDescription, privacy: .public)")
                sema.signal()
            case .cancelled:
                sema.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener.start(queue: queue)

        // 等待最多 2 秒确认绑定结果
        _ = sema.wait(timeout: .now() + 2)
        if ready {
            self.listener = listener
            Logger.settings.info("OAuthCallbackServer: 监听 localhost:\(port)")
            return true
        }
        listener.cancel()
        Logger.settings.error("OAuthCallbackServer: 端口 \(port) 未能在超时内就绪")
        return false
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self = self,
                  let data = data,
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let query = self.parseQuery(fromRequestLine: request)

            let body = Self.responseHTML(success: query["code"] != nil)
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html; charset=utf-8\r
            Content-Length: \(body.utf8.count)\r
            Connection: close\r
            \r
            \(body)
            """
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })

            // 仅投递第一次有效回调（code 或 error）
            if !self.didDeliver, query["code"] != nil || query["error"] != nil {
                self.didDeliver = true
                DispatchQueue.main.async { self.onCallback?(query) }
            }
        }
    }

    /// 从 HTTP 请求行解析 query 参数
    /// 例：`GET /auth/callback?code=...&state=... HTTP/1.1`
    private func parseQuery(fromRequestLine request: String) -> [String: String] {
        guard let firstLine = request.split(separator: "\r\n").first else { return [:] }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return [:] }
        let path = String(parts[1])
        guard let qIndex = path.firstIndex(of: "?") else { return [:] }

        let queryString = String(path[path.index(after: qIndex)...])
        var result: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard let k = kv.first else { continue }
            let key = String(k).removingPercentEncoding ?? String(k)
            let rawValue = kv.count > 1 ? String(kv[1]) : ""
            result[key] = rawValue.removingPercentEncoding ?? rawValue
        }
        return result
    }

    private static func responseHTML(success: Bool) -> String {
        let title = success ? "Signed in" : "Sign-in failed"
        let heading = success ? "✅ Signed in successfully" : "⚠️ Sign-in failed"
        let message = success
            ? "You can close this tab and return to Usage4Claude."
            : "Something went wrong. Please return to Usage4Claude and try again."
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8"><title>\(title)</title></head>
        <body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;text-align:center;padding-top:80px;color:#1d1d1f;background:#f5f5f7">
        <h2>\(heading)</h2>
        <p>\(message)</p>
        </body></html>
        """
    }
}
