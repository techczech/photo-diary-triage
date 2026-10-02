import AppKit
import CryptoKit
import Foundation
import Network
import Security

protocol GooglePhotosSecretStoring: Sendable {
    func read(_ key: String) throws -> Data?
    func write(_ data: Data?, key: String) throws
}
struct GooglePhotosKeychain: GooglePhotosSecretStoring {
    private let service = "com.techczech.PhotoDiaryTriage.google-photos"
    func read(_ key: String) throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw ArchiveFileVerification.failure("Google Photos credentials could not be read from Keychain.") }
        return data
    }
    func write(_ data: Data?, key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        if let data {
            let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if status == errSecItemNotFound {
                var attributes = query; attributes[kSecValueData as String] = data
                attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { throw ArchiveFileVerification.failure("Google Photos credentials could not be saved to Keychain.") }
            } else if status != errSecSuccess { throw ArchiveFileVerification.failure("Google Photos credentials could not be updated in Keychain.") }
        } else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw ArchiveFileVerification.failure("Google Photos credentials could not be removed from Keychain.") }
        }
    }
}
struct GooglePhotosAccount: Codable, Hashable, Sendable {
    var id: String
    var clientID: String
    var subject: String
    var displayName: String
}
private struct GooglePhotosTokens: Codable, Sendable {
    var account: GooglePhotosAccount
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var scopes: Set<String>
}
protocol GooglePhotosCredentials: Sendable {
    func account() async throws -> GooglePhotosAccount?
    func accessToken(accountID: String) async throws -> String
}
struct GooglePhotosOAuthRequest: Sendable {
    static let photosScopes: Set<String> = ["https://www.googleapis.com/auth/photoslibrary.appendonly", "https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata"]
    let state: String
    let verifier: String
    let redirect: URL
    let clientID: String
    init(clientID: String, redirect: URL, state: String? = nil, verifier: String? = nil) throws {
        guard clientID.nonEmpty != nil, redirect.scheme == "http", redirect.host == "127.0.0.1", redirect.port != nil,
              redirect.path == "/oauth2/callback", redirect.query == nil, redirect.fragment == nil else { throw ArchiveFileVerification.failure("Configure a Google Desktop OAuth client and a local callback.") }
        self.clientID = clientID; self.redirect = redirect
        self.state = try state ?? Self.random(); self.verifier = try verifier ?? Self.random()
    }
    private static func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw ArchiveFileVerification.failure("Secure sign-in state could not be generated.") }
        return Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    var challenge: String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    var authorizationURL: URL {
        var parts = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        parts.queryItems = [URLQueryItem(name: "client_id", value: clientID), .init(name: "redirect_uri", value: redirect.absoluteString),
            .init(name: "response_type", value: "code"), .init(name: "scope", value: (Self.photosScopes.union(["openid", "email"])).sorted().joined(separator: " ")),
            .init(name: "state", value: state), .init(name: "code_challenge", value: challenge), .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"), .init(name: "prompt", value: "consent select_account")]
        return parts.url!
    }
    func code(from callback: URL) throws -> String {
        guard callback.scheme == redirect.scheme, callback.host == redirect.host, callback.port == redirect.port,
              callback.path == redirect.path, callback.fragment == nil, let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false) else { throw ArchiveFileVerification.failure("The Google sign-in callback did not match this request.") }
        let query = parts.queryItems ?? []
        guard query.filter({ $0.name == "state" }).count == 1, query.first(where: { $0.name == "state" })?.value == state else { throw ArchiveFileVerification.failure("The Google sign-in state did not match. Start sign-in again.") }
        guard !query.contains(where: { $0.name == "error" }), query.filter({ $0.name == "code" }).count == 1,
              let code = query.first(where: { $0.name == "code" })?.value?.nonEmpty else { throw ArchiveFileVerification.failure("Google sign-in was declined or returned no code.") }
        return code
    }
}

// The listener binds only IPv4 loopback and never logs callback codes.
final class GooglePhotosLoopback: @unchecked Sendable {
    private let queue = DispatchQueue(label: "walkfolio.google-oauth-loopback")
    private var listener: NWListener?
    private var callback: CheckedContinuation<URL, Error>?
    private var ready: CheckedContinuation<URL, Error>?
    private var port: UInt16?
    private var finished = false
    private var terminalResult: Result<URL, Error>?
    func start() async throws -> URL {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard !self.finished else { continuation.resume(throwing: CancellationError()); return }
                do {
                    let parameters = NWParameters.tcp
                    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
                    let listener = try NWListener(using: parameters)
                    self.listener = listener; self.ready = continuation
                    listener.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            guard let port = listener.port?.rawValue else { self.finish(.failure(ArchiveFileVerification.failure("The local sign-in callback could not start."))); return }
                            self.port = port
                            self.ready?.resume(returning: URL(string: "http://127.0.0.1:\(port)/oauth2/callback")!); self.ready = nil
                        case .failed: self.finish(.failure(ArchiveFileVerification.failure("The local sign-in callback failed.")))
                        default: break
                        }
                    }
                    listener.newConnectionHandler = { connection in self.receive(connection, accumulated: Data()) }
                    listener.start(queue: self.queue)
                } catch { continuation.resume(throwing: error) }
            }
        }
        }, onCancel: { self.cancel() })
    }
    func wait() async throws -> URL {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    if let result = self.terminalResult { continuation.resume(with: result); return }
                    self.callback = continuation
                    self.queue.asyncAfter(deadline: .now() + 180) { self.finish(.failure(ArchiveFileVerification.failure("Google sign-in timed out. Start it again."))) }
                }
            }
        }, onCancel: { self.cancel() })
    }
    func cancel() { queue.async { self.finish(.failure(CancellationError())) } }
    private func finish(_ result: Result<URL, Error>) {
        guard !finished else { return }; finished = true; terminalResult = result
        ready?.resume(throwing: ArchiveFileVerification.failure("The local sign-in callback stopped.")); ready = nil
        callback?.resume(with: result); callback = nil
        listener?.cancel(); listener = nil
    }
    private func receive(_ connection: NWConnection, accumulated: Data) {
        if accumulated.isEmpty { connection.start(queue: queue) }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, complete, error in
            var bytes = accumulated; if let data { bytes.append(data) }
            guard bytes.count <= 16_384, error == nil else { connection.cancel(); return }
            guard let text = String(data: bytes, encoding: .utf8), text.contains("\r\n\r\n") else {
                if !complete { self.receive(connection, accumulated: bytes) } else { connection.cancel() }; return
            }
            let first = text.components(separatedBy: "\r\n").first?.split(separator: " ") ?? []
            guard first.count == 3, first[0] == "GET", let port = self.port, first[1].hasPrefix("/oauth2/callback?"),
                  let url = URL(string: "http://127.0.0.1:\(port)" + first[1]) else { connection.cancel(); return }
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\n\r\nReturn to Walkfolio. You can close this tab."
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            // wait() is registered before the browser is opened.
            self.finish(.success(url))
        }
    }
}

actor GooglePhotosAuthentication: GooglePhotosCredentials {
    let secrets: any GooglePhotosSecretStoring
    let transport: GooglePhotosHTTPTransport
    private var connecting = false
    private var authGeneration = 0
    private var refreshing: Task<GooglePhotosTokens, Error>?
    init(secrets: any GooglePhotosSecretStoring = GooglePhotosKeychain(), transport: GooglePhotosHTTPTransport = .live) { self.secrets = secrets; self.transport = transport }
    private func tokens() throws -> GooglePhotosTokens? { try secrets.read("account").map { try JSONDecoder().decode(GooglePhotosTokens.self, from: $0) } }
    func account() throws -> GooglePhotosAccount? { try tokens()?.account }
    func disconnect() throws { guard !connecting else { throw ArchiveFileVerification.failure("Cancel sign-in first.") }; authGeneration += 1; refreshing?.cancel(); refreshing = nil; try secrets.write(nil, key: "account") }
    func storeClientSecret(_ value: String, clientID: String) throws { try secrets.write(value.nonEmpty.map { Data($0.utf8) }, key: "client-" + MachineDescriptionHistory.digest(Data(clientID.utf8))) }
    private func clientSecret(_ clientID: String) throws -> String? { try secrets.read("client-" + MachineDescriptionHistory.digest(Data(clientID.utf8))).map { String(decoding: $0, as: UTF8.self) } }
    func connect(clientID: String, openBrowser: @escaping @Sendable (URL) async throws -> Void = { url in
        try await MainActor.run { guard NSWorkspace.shared.open(url) else { throw ArchiveFileVerification.failure("The system browser could not open Google sign-in.") } }
    }) async throws -> GooglePhotosAccount {
        guard !connecting else { throw ArchiveFileVerification.failure("Google sign-in is already running.") }
        connecting = true; authGeneration += 1; refreshing?.cancel(); refreshing = nil; defer { connecting = false }
        let loopback = GooglePhotosLoopback(); defer { loopback.cancel() }
        let request = try GooglePhotosOAuthRequest(clientID: clientID, redirect: await loopback.start())
        let callback = Task { try await loopback.wait() }
        do {
            try await openBrowser(request.authorizationURL)
            let code = try await withTaskCancellationHandler(operation: { try await callback.value }, onCancel: { callback.cancel(); loopback.cancel() })
            return try await exchange(code: request.code(from: code), request: request)
        } catch { callback.cancel(); throw error }
    }
    func exchange(code: String, request: GooglePhotosOAuthRequest) async throws -> GooglePhotosAccount {
        authGeneration += 1; refreshing?.cancel(); refreshing = nil
        let generation = authGeneration
        var fields = ["client_id": request.clientID, "code": code, "code_verifier": request.verifier, "redirect_uri": request.redirect.absoluteString, "grant_type": "authorization_code"]
        if let secret = try clientSecret(request.clientID) { fields["client_secret"] = secret }
        let response = try await tokenRequest(fields)
        guard let refresh = response["refresh_token"] as? String, refresh.nonEmpty != nil else { throw ArchiveFileVerification.failure("Google returned no offline credential. Sign in again with consent.") }
        let access = try accessFields(response, previousScopes: nil)
        var profile = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!); profile.setValue("Bearer " + access.token, forHTTPHeaderField: "Authorization")
        let result = try await transport.send(profile)
        guard result.response.statusCode == 200, let json = try JSONSerialization.jsonObject(with: result.data) as? [String: Any], let sub = (json["sub"] as? String)?.nonEmpty else { throw ArchiveFileVerification.failure("The signed-in Google account could not be identified.") }
        let account = GooglePhotosAccount(id: MachineDescriptionHistory.digest(Data((request.clientID + "\n" + sub).utf8)), clientID: request.clientID, subject: sub, displayName: (json["email"] as? String)?.nonEmpty ?? "Connected Google account")
        try Task.checkCancellation()
        guard generation == authGeneration else { throw CancellationError() }
        try secrets.write(JSONEncoder().encode(GooglePhotosTokens(account: account, accessToken: access.token, refreshToken: refresh, expiresAt: access.expiry, scopes: access.scopes)), key: "account")
        return account
    }
    private func accessFields(_ json: [String: Any], previousScopes: Set<String>?) throws -> (token: String, expiry: Date, scopes: Set<String>) {
        let scopes = (json["scope"] as? String).map { Set($0.split(separator: " ").map(String.init)) } ?? previousScopes ?? []
        guard let token = (json["access_token"] as? String)?.nonEmpty, let seconds = json["expires_in"] as? Double, seconds > 0,
              json["token_type"] as? String == "Bearer", GooglePhotosOAuthRequest.photosScopes.isSubset(of: scopes), scopes.contains("openid") else { throw ArchiveFileVerification.failure("Google Photos sign-in did not grant upload, verification and account identity permissions.") }
        return (token, Date().addingTimeInterval(seconds), scopes)
    }
    private func tokenRequest(_ fields: [String: String]) async throws -> [String: Any] {
        var parts = URLComponents(); parts.queryItems = fields.sorted { $0.key < $1.key }.map { .init(name: $0.key, value: $0.value) }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!); request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data((parts.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
        let result = try await transport.send(request)
        guard result.response.statusCode == 200, let json = try JSONSerialization.jsonObject(with: result.data) as? [String: Any] else { throw ArchiveFileVerification.failure("Google sign-in or refresh failed. Reconnect the account; credentials and server details are not shown.") }
        return json
    }
    func accessToken(accountID: String) async throws -> String {
        guard let current = try tokens(), current.account.id == accountID else { throw ArchiveFileVerification.failure("This delivery belongs to a different Google account. Reconnect its original account.") }
        if current.expiresAt.timeIntervalSinceNow > 60 { return current.accessToken }
        if let refreshing {
            let generation = authGeneration, result = try await refreshing.value
            guard generation == authGeneration, try tokens()?.account.id == accountID else { throw CancellationError() }; return result.accessToken
        }
        let generation = authGeneration
        let task = Task { [self] in
            var fields = ["client_id": current.account.clientID, "refresh_token": current.refreshToken, "grant_type": "refresh_token"]
            if let secret = try clientSecret(current.account.clientID) { fields["client_secret"] = secret }
            let json = try await tokenRequest(fields), access = try accessFields(json, previousScopes: current.scopes)
            guard generation == authGeneration, try tokens()?.account.id == current.account.id else { throw ArchiveFileVerification.failure("The connected account changed while refreshing.") }
            var updated = current; updated.accessToken = access.token; updated.expiresAt = access.expiry; updated.scopes = access.scopes
            if let refresh = (json["refresh_token"] as? String)?.nonEmpty { updated.refreshToken = refresh }
            try secrets.write(JSONEncoder().encode(updated), key: "account"); return updated
        }
        refreshing = task; defer { if generation == authGeneration { refreshing = nil } }
        let result = try await task.value
        guard generation == authGeneration, try tokens()?.account.id == accountID else { throw CancellationError() }; return result.accessToken
    }
}
