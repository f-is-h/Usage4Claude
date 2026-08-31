//
//  CodexResetAnnouncementService.swift
//  Usage4Claude
//
//  Fetches Codex reset announcements from codex-reset.com (Beta feature; the
//  data source is an independent third-party community project with no SLA).
//
//  Two-stage probing to keep this cheap on both ends:
//    1. GET /api/forecast (~1.5KB). If `official_signal` / `teased_window` /
//       `signal_percent` / `commitment` are all absent-or-null (the only
//       "quiet" state ever observed during development), there is no
//       announcement — stop here, never fetch stage 2.
//    2. GET /api/timeline (~46KB), only reached when stage 1 looks non-quiet.
//       Parsed for the nearest still-pending `preview` event.
//
//  Cadence/backoff decisions live in CodexAnnouncementFetchPolicy.swift (pure,
//  unit-tested); this class only owns the mutable state and network I/O.
//
//  Failure-silence contract (see project plan doc): every failure path ends
//  in `completion(nil)`. This must never surface as a UI error, a system
//  notification, a menu bar change, or a RefreshState mutation — callers
//  should treat "nil" identically whether it means "no announcement",
//  "network failed", "parse failed", or "feature disabled". Only Logger sees
//  failures, for diagnostics.
//
//  Concurrency: the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION =
//  MainActor, so this type (and every mutation of its cache/backoff state) is
//  MainActor-isolated. The `await`s below suspend without blocking the main
//  thread, and no extra locking is needed. Don't move this off MainActor
//  without also guarding the mutable state.
//

import Foundation
import OSLog

final class CodexResetAnnouncementService {

    /// 非 2xx 响应。单独建型是为了在 performFetch 里与网络/解码错误走同一条静默路径
    private enum FetchError: Error {
        case badStatus(Int)
    }

    // MARK: - Properties

    private let forecastURL = URL(string: "https://codex-reset.com/api/forecast")!
    private let timelineURL = URL(string: "https://codex-reset.com/api/timeline")!
    private let session: URLSession

    private var cachedAnnouncement: CodexResetAnnouncement?
    private var cachedAt: Date?
    private var lastAttemptAt: Date?
    private var consecutiveFailures = 0
    private var inFlight: Task<CodexResetAnnouncement?, Never>?

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.default
        // 非关键路径的可选信息：超时收紧到 10s（其他服务是 30s），快速失败优于让用户等待
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
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
            let forecastData = try await fetchJSON(from: forecastURL)

            if CodexForecastQuietState.isQuiet(jsonData: forecastData) {
                recordSuccess(announcement: nil)
                return nil
            }

            let timelineData = try await fetchJSON(from: timelineURL)
            let timeline = try JSONDecoder().decode(CodexTimelineResponse.self, from: timelineData)
            let announcement = timeline.activeAnnouncement(now: Date())
            recordSuccess(announcement: announcement)
            return announcement
        } catch {
            // 失败静默契约：只记日志，绝不向调用方传播错误
            Logger.api.debug("Codex reset announcement (Beta) fetch failed, silently ignored: \(error.localizedDescription)")
            consecutiveFailures += 1
            return nil
        }
    }

    /// 校验 HTTP 状态码后返回响应体。没有这层校验的话，源站返回 404/5xx 的错误页面时，
    /// isQuiet 会因解析不出 JSON 而判定为「非安静」，进而白白发出第二个 46KB 的
    /// timeline 请求——结果同样是失败，只是多打扰了源站一次。
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
