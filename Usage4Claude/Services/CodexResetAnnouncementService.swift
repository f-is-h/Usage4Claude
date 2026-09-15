//
//  CodexResetAnnouncementService.swift
//  Usage4Claude
//
//  Fetches Codex reset announcements from codex-reset.com (Beta feature; the
//  data source is an independent third-party community project with no SLA).
//
//  One request: GET /api/forecast (~6KB), parsed for `latest_alert`. See
//  CodexResetAnnouncement.swift for why this replaced 3.4.x's two-stage
//  forecast + timeline probe.
//
//  Nothing fetched is kept on the machine. The site answers
//  `cache-control: public, max-age=60`, and a default URLSession would write
//  every response body into the app's Cache.db (`reloadIgnoringLocalCacheData`
//  only skips reading the cache, not storing into it). The session here is
//  ephemeral with no URL cache and no cookie storage, so only the parsed struct
//  survives, in memory. 3.4.x did use the default session, so init also purges
//  the responses it left behind.
//
//  Cadence/backoff decisions live in CodexAnnouncementFetchPolicy.swift (pure,
//  unit-tested); this class only owns the mutable state and network I/O.
//
//  Failure-silence contract: every failure path ends in `completion(nil)`.
//  This must never surface as a UI error, a system notification, a menu bar
//  change, or a RefreshState mutation — callers should treat "nil" identically
//  whether it means "no announcement", "network failed", "parse failed", or
//  "feature disabled". Only AppLog sees failures, for diagnostics.
//
//  Concurrency: the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION =
//  MainActor, so this type (and every mutation of its cache/backoff state) is
//  MainActor-isolated. The `await`s below suspend without blocking the main
//  thread, and no extra locking is needed. Don't move this off MainActor
//  without also guarding the mutable state.
//

import Foundation

final class CodexResetAnnouncementService {

    /// 非 2xx 响应。单独建型是为了在 performFetch 里与网络/解码错误走同一条静默路径
    private enum FetchError: Error {
        case badStatus(Int)
    }

    // MARK: - Properties

    private let forecastURL = URL(string: "https://codex-reset.com/api/forecast")!
    private let session: URLSession

    /// 3.4.x 经默认 URLSession 写进 URLCache.shared 的两个端点
    nonisolated private static let legacyCachedURLs = [
        URL(string: "https://codex-reset.com/api/forecast")!,
        URL(string: "https://codex-reset.com/api/timeline")!,
    ]

    private var cachedAnnouncement: CodexResetAnnouncement?
    private var cachedAt: Date?
    private var lastAttemptAt: Date?
    private var consecutiveFailures = 0
    private var inFlight: Task<CodexResetAnnouncement?, Never>?

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        // 非关键路径的可选信息：超时收紧到 10s（其他服务是 30s），快速失败优于让用户等待
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        // 请求到的原文不在本机留存：ephemeral 本身不落盘，再去掉它的内存缓存和 cookie 存储。
        // 需要保留的只有解析后的那一个结构体
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        self.session = URLSession(configuration: configuration)

        // 清掉 3.4.x 留下的响应原文；没装过 3.4.x 时是空操作。
        // 放到后台做：这是一次 SQLite 写，不值得占用启动时的主线程
        Task.detached(priority: .utility) {
            for url in Self.legacyCachedURLs {
                URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
            }
        }
    }

    // MARK: - Public

    /// 主入口。缓存新鲜、被频率策略拦下、请求失败——一律经由 completion(nil ~ 有效预告) 同步语义返回，
    /// 调用方无需区分「没有预告」和「这次没去问」。completion 一律主线程回调。
    func announcement(completion: @escaping (CodexResetAnnouncement?) -> Void) {
        let now = Date()
        let state = CodexAnnouncementFetchPolicy.State(
            lastAttemptAt: lastAttemptAt,
            cachedAt: cachedAt,
            hasActiveAnnouncement: cachedAnnouncement?.isActive(at: now) ?? false,
            consecutiveFailures: consecutiveFailures
        )

        guard CodexAnnouncementFetchPolicy.shouldFetch(state: state, now: now) else {
            completion(freshCachedAnnouncement(at: now))
            return
        }

        if let inFlight {
            Task { @MainActor in completion(await inFlight.value) }
            return
        }

        lastAttemptAt = now
        let task = Task<CodexResetAnnouncement?, Never> { [weak self] in
            await self?.performFetch()
        }
        inFlight = task

        Task { @MainActor [weak self] in
            let result = await task.value
            self?.inFlight = nil
            completion(result)
        }
    }

    // MARK: - Private

    /// 缓存里的预告若已过期，视同「无预告」——不依赖下次抓取周期才消失
    private func freshCachedAnnouncement(at now: Date) -> CodexResetAnnouncement? {
        guard let cachedAnnouncement, cachedAnnouncement.isActive(at: now) else { return nil }
        return cachedAnnouncement
    }

    private func performFetch() async -> CodexResetAnnouncement? {
        do {
            let data = try await fetchJSON(from: forecastURL)
            let forecast = try JSONDecoder().decode(CodexForecastResponse.self, from: data)

            if forecast.hasUnrecognizedSignal {
                // 仍按「无预告」处理（失败静默契约），但必须留下痕迹：
                // 3.4.x 读错数据源漏掉 2026-09-12 的预告时，日志里什么都没有
                let kind = forecast.latestAlert?.kind ?? "nil"
                let state = forecast.latestAlert?.state ?? "nil"
                AppLog.warning(.api, "Codex reset announcement (Beta): forecast reports an official signal but latest_alert is missing or unrecognized (kind=\(kind), state=\(state)); the source schema may have changed")
            }

            let announcement = forecast.activeAnnouncement(now: Date())
            recordSuccess(announcement: announcement)
            return announcement
        } catch {
            // 失败静默契约：只记日志，绝不向调用方传播错误
            AppLog.trace(.api, "Codex reset announcement (Beta) fetch failed; ignoring silently by design: \(error.localizedDescription)")
            consecutiveFailures += 1
            return nil
        }
    }

    /// 校验 HTTP 状态码后返回响应体，让源站的 404/5xx 错误页直接走失败路径（计入退避），
    /// 而不是交给 JSONDecoder 报一个误导性的解码错误
    private func fetchJSON(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: makeRequest(url: url))
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw FetchError.badStatus(http.statusCode)
        }
        return data
    }

    private func recordSuccess(announcement: CodexResetAnnouncement?) {
        consecutiveFailures = 0
        cachedAnnouncement = announcement
        cachedAt = Date()
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // 诚实标识，不沿用其他 Codex 请求为过 Cloudflare 而伪装的浏览器 UA——
        // 这是无鉴权公开端点，源站 robots.txt 明确欢迎抓取，理应让站长能识别流量来源
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private static let userAgent: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return "Usage4Claude/\(version) (+https://github.com/f-is-h/Usage4Claude)"
    }()
}
