import SwiftUI
import Combine

@MainActor
final class AntigravityOAuthCoordinator: ObservableObject {
    enum State: Equatable { case starting, waiting, exchanging, success, failed(String) }
    @Published var state: State = .starting
    private let server = OAuthCallbackServer()
    private var task: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var client: AntigravityOAuthClient?
    private var stateID = ""
    private var codeVerifier = ""
    private var redirect = ""
    private var url: URL?

    func start() {
        cancel(); state = .starting
        // 与 Claude/Codex 相同用 PKCE：client_secret 是公开的，单凭 code 不足以换到 token
        let pkce = PKCECodes()
        stateID = pkce.state; codeVerifier = pkce.codeVerifier
        let transaction = stateID
        task = Task { [weak self] in
            let found = await Task.detached { AntigravityOAuthConfig.resolvedClient() }.value
            guard let self, !Task.isCancelled, transaction == self.stateID else { return }
            self.begin(with: found, codeChallenge: pkce.codeChallenge)
        }
    }
    private func begin(with found: AntigravityOAuthClient?, codeChallenge: String) {
        guard let found else { state = .failed(L.Antigravity.clientUnavailable); return }
        client = found
        guard let port = server.start(ports: [51121, 51122], loopbackOnly: true, onCallback: { [weak self] query in
            Task { @MainActor in self?.handle(query) }
        }) else { state = .failed(L.Antigravity.callbackBusy); return }
        redirect = "http://127.0.0.1:\(port)/auth/callback"
        var components = URLComponents(url: AntigravityOAuthConfig.authURL, resolvingAgainstBaseURL: false)!
        components.queryItems = ["client_id": found.clientID, "redirect_uri": redirect,
            "response_type": "code", "scope": AntigravityOAuthConfig.scopes.joined(separator: " "),
            "access_type": "offline", "prompt": "select_account consent", "state": stateID,
            "code_challenge": codeChallenge, "code_challenge_method": "S256"]
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        url = components.url; state = .waiting; reopen()
        timeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.server.stop(); self.task?.cancel(); self.state = .failed(L.WebLogin.codexOAuthTimeout)
        }
    }
    func reopen() { if let url { NSWorkspace.shared.open(url) } }
    func cancel() { task?.cancel(); timeout?.cancel(); server.stop(); stateID = UUID().uuidString }
    func manual(_ text: String) {
        guard let items = URLComponents(string: text)?.queryItems else { return }
        handle(Dictionary(items.compactMap { item in item.value.map { (item.name, $0) } }, uniquingKeysWith: { _, new in new }))
    }
    private func handle(_ query: [String: String]) {
        guard case .waiting = state else { return }
        guard query["state"] == stateID, query["error"] == nil, let code = query["code"], let client else {
            server.stop(); timeout?.cancel(); state = .failed(L.WebLogin.codexOAuthFailed); return
        }
        server.stop(); state = .exchanging
        let transaction = stateID
        let values = ["grant_type": "authorization_code", "code": code, "redirect_uri": redirect,
            "client_id": client.clientID, "client_secret": client.clientSecret, "code_verifier": codeVerifier]
        task = Task { [weak self] in
            do {
                let tokens = try await AntigravityOAuthService.token(values)
                let identity = try await AntigravityOAuthService.identity(tokens.accessToken)
                guard let self, !Task.isCancelled, self.stateID == transaction else { return }
                try AntigravityAccountStore.shared.upsert(AntigravityAccount(email: identity.email, subject: identity.subject, credentials: tokens))
                self.timeout?.cancel(); self.state = .success
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.timeout?.cancel(); self.state = .failed(error.localizedDescription)
            }
        }
    }
}

struct AntigravityOAuthLoginView: View {
    @StateObject private var coordinator = AntigravityOAuthCoordinator()
    @State private var showManual = false
    @State private var callback = ""
    var body: some View {
        VStack(spacing: 18) {
            switch coordinator.state {
            case .starting:
                ProgressView(); Text(L.WebLogin.codexOAuthPreparing)
            case .exchanging:
                ProgressView(); Text(L.WebLogin.codexOAuthExchanging)
            case .waiting:
                Image(systemName: "safari").font(.system(size: 44)).foregroundColor(.indigo)
                Text(L.WebLogin.codexOAuthWaitingBrowser).font(.headline)
                Text(L.Antigravity.loginHint).font(.callout).foregroundColor(.secondary)
                Button(L.WebLogin.codexOAuthReopenBrowser) { coordinator.reopen() }.buttonStyle(.link)
                if showManual {
                    TextField(L.WebLogin.codexOAuthManualPrompt, text: $callback).textFieldStyle(.roundedBorder)
                    Button(L.WebLogin.codexOAuthManualSubmit) { coordinator.manual(callback) }
                } else {
                    Button(L.WebLogin.codexOAuthManualHint) { showManual = true }.buttonStyle(.link)
                }
            case .success:
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundColor(.green)
                Text(L.Antigravity.statusConnected).font(.headline)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundColor(.orange)
                Text(message).font(.callout).foregroundColor(.secondary)
                Button(L.WebLogin.codexOAuthRetry) { coordinator.start() }
            }
        }
        .multilineTextAlignment(.center).padding(32).frame(width: 440, height: 380)
        .onAppear { coordinator.start() }.onDisappear { coordinator.cancel() }
        .onChange(of: coordinator.state) { state in
            if state == .success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    WebLoginWindowManager.shared.closeAntigravityLoginWindow()
                }
            }
        }
    }
}
