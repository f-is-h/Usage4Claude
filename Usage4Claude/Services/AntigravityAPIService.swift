//
//  AntigravityAPIService.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//
//  两条数据来源：
//  - 本地账户：官方 CLI `agy -p /usage --output-format json`，不读取 agy 的 Keychain 凭据，
//    token 续期完全交给 agy 自己
//  - Google OAuth 账户：见 AntigravityOAuth/AntigravityOAuthUsage.swift，配额接口返回
//    无法识别的结构时，用该账户的 token 在隔离的 HOME 里回退到同一个 CLI
//

import Foundation

/// Antigravity 用量拉取失败的原因
enum AntigravityError: LocalizedError, Equatable {
    /// 找不到 agy 可执行文件
    case cliNotFound
    /// agy 未登录
    case notLoggedIn
    /// CLI 超时未返回
    case timeout
    /// CLI 返回非成功状态或异常退出
    case commandFailed(String)
    /// 输出无法解析
    case malformedOutput

    var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return L.Antigravity.errorCLINotFound
        case .notLoggedIn:
            return L.Antigravity.errorNotLoggedIn
        case .timeout:
            return L.Antigravity.errorTimeout
        case .commandFailed(let message):
            return L.Antigravity.errorCommandFailed(message)
        case .malformedOutput:
            return L.Error.decodingFailed
        }
    }

    /// 是否需要用户处理（安装或登录 agy），而不是等待自动重试
    var requiresUserAction: Bool {
        switch self {
        case .cliNotFound, .notLoggedIn:
            return true
        case .timeout, .commandFailed, .malformedOutput:
            return false
        }
    }
}

final class AntigravityAPIService {

    static let shared = AntigravityAPIService()

    /// agy 的常见安装位置。GUI 应用拿不到登录 shell 的 PATH，只能逐个探测
    static let cliCandidatePaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin/agy",
            "/opt/homebrew/bin/agy",
            "/usr/local/bin/agy",
            "\(home)/.antigravity/bin/agy"
        ]
    }()

    /// CLI 超时（秒）。正常约 6 秒；首次启动或网络慢时会更久
    private static let processTimeout: TimeInterval = 90
    /// 超时 terminate 后等待管道关闭的宽限时间（秒），过后改用 SIGKILL
    private static let terminateGracePeriod: TimeInterval = 5

    /// locateCLI 的缓存。外层 nil 表示尚未探测，内层 nil 表示探测过但没找到
    private static var cachedCLIURL: URL??
    private static let cliCacheLock = NSLock()

    private let lock = NSLock()
    /// 是否有一次 CLI 运行在进行中；与 pendingCompletions 在同一把锁内读写（single-flight）
    private var isRunning = false
    /// 正在运行的 CLI 进程，仅供 cancelAllRequests 终止
    private var runningProcess: Process?
    private var pendingCompletions: [(Result<AntigravityUsageData, Error>) -> Void] = []

    #if DEBUG
    private let settings = UserSettings.shared
    #endif

    // MARK: - Public

    /// 当前可用的 agy 路径
    /// - Parameter refresh: true 时重新探测磁盘；默认返回缓存结果。
    ///   视图 body 等高频路径只读缓存，实际运行 CLI、刷新轮次开始和用户点「重新检测」时才重新探测
    static func locateCLI(refresh: Bool = false) -> URL? {
        cliCacheLock.lock()
        defer { cliCacheLock.unlock() }
        if !refresh, let cached = cachedCLIURL {
            return cached
        }
        let url = cliCandidatePaths
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
        cachedCLIURL = .some(url)
        return url
    }

    /// 拉取用量。completion 一律在主线程回调
    /// - Note: 同一时间只运行一个 agy 进程，期间的其他请求共享这次结果
    func fetchUsage(completion: @escaping (Result<AntigravityUsageData, Error>) -> Void) {
        #if DEBUG
        if settings.debugModeEnabled {
            let mockData = Self.createMockData()
            DispatchQueue.main.async { completion(.success(mockData)) }
            return
        }
        #endif

        if let account = AntigravityAccountStore.shared.current, !account.isLocal {
            Task {
                let result: Result<AntigravityUsageData, Error>
                do { result = .success(try await AntigravityOAuthUsage.shared.fetch(account)) }
                catch { result = .failure(error) }
                await MainActor.run { completion(result) }
            }
            return
        }

        guard let cliURL = Self.locateCLI(refresh: true) else {
            DispatchQueue.main.async { completion(.failure(AntigravityError.cliNotFound)) }
            return
        }

        lock.lock()
        pendingCompletions.append(completion)
        let alreadyRunning = isRunning
        isRunning = true
        lock.unlock()
        guard !alreadyRunning else {
            AppLog.trace(.api, "Antigravity CLI already running; joining the in-flight run")
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let result = self.runCLI(at: cliURL)
            self.lock.lock()
            let completions = self.pendingCompletions
            self.pendingCompletions.removeAll()
            self.isRunning = false
            self.runningProcess = nil
            self.lock.unlock()
            DispatchQueue.main.async {
                completions.forEach { $0(result) }
            }
        }
    }

    func fetchUsageResult() async -> Result<AntigravityUsageData, Error> {
        await withCheckedContinuation { continuation in
            fetchUsage { continuation.resume(returning: $0) }
        }
    }

    func fetchScoped(_ credentials: AntigravityCredentials) async throws -> (AntigravityUsageData, AntigravityCredentials) {
        guard let url = Self.locateCLI() else { throw AntigravityError.cliNotFound }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var effective = credentials
                let result = self.runCLI(at: url, scoped: credentials, onCredentials: { effective = $0 })
                continuation.resume(with: result.map { ($0, effective) })
            }
        }
    }

    // MARK: - Private

    /// 同步运行一次 agy 并解析输出（在后台队列调用）
    private func runCLI(at cliURL: URL, scoped: AntigravityCredentials? = nil, onCredentials: ((AntigravityCredentials) -> Void)? = nil) -> Result<AntigravityUsageData, Error> {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("usage4claude-agy-" + UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            for launcher in ["open", "xdg-open", "browser"] {
                let file = tempDir.appendingPathComponent(launcher)
                try Data("#!/bin/sh\nexit 1\n".utf8).write(to: file)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
            }
            if let scoped {
                let file = tempDir.appendingPathComponent(".gemini/antigravity-cli/antigravity-oauth-token")
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                    withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let payload: [String: Any] = ["auth_method": "consumer", "token": [
                    "access_token": scoped.accessToken, "refresh_token": scoped.refreshToken,
                    "token_type": "Bearer", "expiry": AntigravityUsageParser.formatDate(scoped.expiresAt)]]
                let data = try JSONSerialization.data(withJSONObject: payload)
                guard FileManager.default.createFile(atPath: file.path, contents: data,
                    attributes: [.posixPermissions: 0o600]) else { throw AntigravityError.notLoggedIn }
            }
        } catch { return .failure(error) }
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let logFile = tempDir.appendingPathComponent("Usage4Claude-agy.log")
        let process = Process()
        process.executableURL = cliURL
        process.arguments = [
            "-p", "/usage",
            "--output-format", "json",
            "--print-timeout", "60s",
            // 固定日志文件：不指定时 agy 每次运行都会在 ~/.gemini/antigravity-cli/log 新建一个文件
            "--log-file", logFile.path
        ]
        process.currentDirectoryURL = tempDir
        var environment = ProcessInfo.processInfo.environment
        if scoped != nil {
            environment = environment.filter { ["PATH", "TMPDIR", "LANG", "LC_ALL", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY"].contains($0.key) }
            environment["HOME"] = tempDir.path
            environment["SSH_TTY"] = "usage4claude-scoped"
        }
        environment["BROWSER"] = tempDir.appendingPathComponent("browser").path
        environment["AGY_CLI_DISABLE_AUTO_UPDATE"] = "true"
        environment["PATH"] = [tempDir.path, cliURL.deletingLastPathComponent().path, environment["PATH"] ?? "/usr/bin:/bin"]
            .joined(separator: ":")
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            AppLog.error(.api, "Failed to launch Antigravity CLI: \(error.localizedDescription)")
            return .failure(AntigravityError.commandFailed(error.localizedDescription))
        }
        lock.lock()
        runningProcess = process
        lock.unlock()

        // 先在后台读完管道再等待退出，避免输出塞满管道缓冲区导致死锁
        var outputData = Data()
        var errorData = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }

        let timedOut = readGroup.wait(timeout: .now() + Self.processTimeout) == .timedOut
        if timedOut {
            // 不能无限期等待管道关闭：agy 可能忽略 SIGTERM，或其子进程继承管道后继续存活，
            // 那样 readGroup 永远不会 leave，single-flight 状态也永远不会清除
            process.terminate()
            if readGroup.wait(timeout: .now() + Self.terminateGracePeriod) == .timedOut, process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            // 读线程在管道真正关闭后自行结束；超时结果不再读取 outputData/errorData
            AppLog.warning(.api, "Antigravity CLI timed out after \(Int(Self.processTimeout))s")
            return .failure(AntigravityError.timeout)
        }
        process.waitUntilExit()

        let output = String(decoding: outputData, as: UTF8.self)
        do {
            let data = try AntigravityUsageParser.parse(cliOutput: output)
            if var effective = scoped {
                let file = tempDir.appendingPathComponent(".gemini/antigravity-cli/antigravity-oauth-token")
                guard let saved = try? Data(contentsOf: file),
                      let json = try? JSONSerialization.jsonObject(with: saved) as? [String: Any],
                      let token = json["token"] as? [String: Any],
                      let access = token["access_token"] as? String,
                      let refresh = token["refresh_token"] as? String else {
                    return .failure(AntigravityError.notLoggedIn)
                }
                // 只有 agy 真的换了 token 才采用它写回的过期时间，原样写回的值不算变化
                if access != effective.accessToken,
                   let expiry = token["expiry"] as? String, let date = AntigravityUsageParser.parseDate(expiry) {
                    effective.expiresAt = date
                }
                effective.accessToken = access; effective.refreshToken = refresh
                onCredentials?(effective)
            } else if let log = try? String(contentsOf: logFile, encoding: .utf8),
                      let email = AntigravityUsageParser.accountEmail(fromLog: log) {
                // 本地 agy 账户的邮箱只能从日志得到，临时目录删除前读取
                DispatchQueue.main.async { AntigravityAccountStore.shared.updateLocalEmail(email) }
            }
            AppLog.trace(.api, "Antigravity CLI succeeded")
            return .success(data)
        } catch let error as AntigravityParseError {
            let errorOutput = String(decoding: errorData, as: UTF8.self)
            if errorOutput.range(of: "not logged in", options: .caseInsensitive) != nil {
                return .failure(AntigravityError.notLoggedIn)
            }
            AppLog.warning(.api, "Antigravity CLI failed (exit \(process.terminationStatus)); raw output withheld")
            return .failure(Self.mapParseError(error, exitStatus: process.terminationStatus))
        } catch {
            return .failure(AntigravityError.malformedOutput)
        }
    }

    private static func mapParseError(_ error: AntigravityParseError, exitStatus: Int32) -> AntigravityError {
        switch error {
        case .notLoggedIn:
            return .notLoggedIn
        case .commandFailed(let message):
            return .commandFailed(message)
        case .noJSON:
            return exitStatus == 0 ? .malformedOutput : .commandFailed("exit \(exitStatus)")
        case .malformed:
            return .malformedOutput
        }
    }

    #if DEBUG
    private static func createMockData() -> AntigravityUsageData {
        let now = Date()
        return AntigravityUsageData(
            gemini: .init(
                fiveHour: .init(percentage: 42, resetsAt: now.addingTimeInterval(2 * 3600)),
                weekly: .init(percentage: 18, resetsAt: now.addingTimeInterval(4 * 86400))
            ),
            thirdParty: .init(
                fiveHour: .init(percentage: 73, resetsAt: now.addingTimeInterval(3600)),
                weekly: .init(percentage: 35, resetsAt: now.addingTimeInterval(5 * 86400))
            )
        )
    }
    #endif
}

// MARK: - UsageProvider

extension AntigravityAPIService: UsageProvider {
    var providerType: ProviderType { .antigravity }

    func cancelAllRequests() {
        lock.lock()
        let process = runningProcess
        lock.unlock()
        guard let process, process.isRunning else { return }
        process.terminate()
        AppLog.event(.api, "Terminated the in-flight Antigravity CLI run")
    }
}
