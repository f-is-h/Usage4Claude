//
//  NetworkCachePolicy.swift
//  Usage4Claude
//
//  Keeps fetched response bodies off disk.
//
//  A session built on URLSessionConfiguration.default writes responses into
//  the app's Cache.db under Library/Caches, and `reloadIgnoringLocalCacheData`
//  does not prevent that: the policy only skips reading the cache. 3.4.1 left
//  claude.ai usage and chatgpt.com wham/usage responses there. Measured in
//  2026-09, everything short of `Cache-Control: no-store` or a non-2xx status
//  was stored, including responses to requests carrying Authorization or
//  Cookie headers, and POST responses too, so only the servers' headers were
//  keeping token responses off disk.
//
//  Free of app dependencies so the SwiftPM test target can compile it.
//

import Foundation

nonisolated extension URLSessionConfiguration {
    /// `.default` 去掉 URL 缓存，其余保持不变。自家所有 URLSession 都应从这里起步。
    ///
    /// 刻意不用 `.ephemeral`：它会换成进程内的临时 cookie 存储，而 Codex 的 session-token
    /// 轮换要靠 `HTTPCookieStorage.shared` 接收服务端下发的新 cookie。
    /// 与 `.default` 一样每次访问都返回新实例，调用方可以继续改超时等参数。
    static var uncached: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        return configuration
    }
}

nonisolated enum NetworkCachePolicy {
    /// 启动时尽早调用一次，同步执行，保证返回时兜底已经生效。
    ///
    /// 先清掉旧版本已经写进 Cache.db 的响应（实测连 fsCachedData 里的大文件一起清掉），
    /// 再把共享 URLCache 的容量归零，覆盖第三方库和以后误用 `.default` 的代码。
    ///
    /// 顺序不能反：进程里还没用过缓存时先把容量归零，URLCache 就不会再去打开磁盘上的
    /// Cache.db，清理随之变成空操作，旧数据原样留着（2026-09 用两个进程实测）。
    static func applyAtLaunch() {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
    }
}
