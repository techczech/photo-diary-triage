import Foundation

struct GooglePhotosHTTPResult: @unchecked Sendable { var data: Data; var response: HTTPURLResponse }
struct GooglePhotosHTTPTransport: Sendable {
    var send: @Sendable (URLRequest) async throws -> GooglePhotosHTTPResult
    static let live = Self(send: { request in
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120; configuration.timeoutIntervalForResource = 150
        let session = URLSession(configuration: configuration, delegate: GooglePhotosNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse, data.count <= 4_000_000 else { throw GooglePhotosFailure.invalidResponse }
            return .init(data: data, response: response)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw GooglePhotosFailure.network
        }
    })
}
private final class GooglePhotosNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
enum GooglePhotosFailure: LocalizedError, Sendable {
    case notSent, network, invalidResponse, authentication, permission, sessionExpired, quota(Date), server(Int), membershipMissing, ambiguousAlbum
    var errorDescription: String? {
        switch self {
        case .notSent: return "The request was not sent. Google Photos credentials need reconnection, or the action was cancelled."
        case .network: return "The Google Photos request was interrupted. Saved progress is retained; Resume reconciles it."
        case .invalidResponse: return "Google Photos returned an incomplete or invalid response. Saved progress is retained."
        case .authentication: return "Google Photos authorisation expired. Reconnect the original account."
        case .permission: return "Google Photos denied this operation. Check account permissions and storage; no quality downgrade was made."
        case .sessionExpired: return "The resumable upload expired. Resume uploads the same captured original again."
        case .quota: return "Google Photos rate or storage quota was reached. Saved progress is retained; retry is delayed."
        case .server(let code): return "Google Photos returned HTTP \(code). Saved progress is retained."
        case .membershipMissing: return "The media item is not yet visible in the selected album. Retry verification; the original will not be uploaded again."
        case .ambiguousAlbum: return "Album creation may have succeeded. Select the created album from Reconcile before resuming; another album will not be created automatically."
        }
    }
}
struct GooglePhotosAlbum: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var title: String
    var productURL: String?
}
struct GooglePhotosUploadSession: Codable, Sendable {
    var url: URL
    var granularity: Int
    var createdAt = Date()
}
struct GooglePhotosUploadProgress: Sendable { var offset: Int64; var active: Bool; var token: String? }
struct GooglePhotosCreatedMedia: Codable, Hashable, Sendable { var id: String; var mimeType: String; var productURL: String? }
protocol GooglePhotosDelivering: Sendable {
    func albums(accountID: String) async throws -> [GooglePhotosAlbum]
    func createAlbum(title: String, accountID: String) async throws -> GooglePhotosAlbum
    func startUpload(size: Int64, mimeType: String, accountID: String) async throws -> GooglePhotosUploadSession
    func queryUpload(_ session: GooglePhotosUploadSession, accountID: String) async throws -> GooglePhotosUploadProgress
    func upload(_ session: GooglePhotosUploadSession, offset: Int64, data: Data, final: Bool, accountID: String) async throws -> String?
    func createMedia(token: String, fileName: String, albumID: String, accountID: String) async throws -> GooglePhotosCreatedMedia
    func memberIDs(albumID: String, accountID: String) async throws -> Set<String>
}
struct GooglePhotosClient: GooglePhotosDelivering {
    let credentials: any GooglePhotosCredentials
    var transport: GooglePhotosHTTPTransport = .live
    private let base = "https://photoslibrary.googleapis.com/v1/"
    private func response(_ request: URLRequest, accountID: String, accepted: Set<Int> = [200]) async throws -> GooglePhotosHTTPResult {
        guard request.url?.scheme == "https", request.url?.host == "photoslibrary.googleapis.com", request.url?.user == nil, request.url?.password == nil,
              request.url?.port == nil, request.url?.fragment == nil else { throw GooglePhotosFailure.invalidResponse }
        var request = request
        do {
            request.setValue("Bearer " + (try await credentials.accessToken(accountID: accountID)), forHTTPHeaderField: "Authorization")
            try Task.checkCancellation()
        } catch { throw GooglePhotosFailure.notSent }
        let result = try await transport.send(request)
        guard result.data.count <= 4_000_000 else { throw GooglePhotosFailure.invalidResponse }
        guard accepted.contains(result.response.statusCode) else {
            switch result.response.statusCode {
            case 401: throw GooglePhotosFailure.authentication
            case 403: throw GooglePhotosFailure.permission
            case 404, 410: throw GooglePhotosFailure.sessionExpired
            case 429:
                let delay = max(30, Double(result.response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30)
                throw GooglePhotosFailure.quota(Date().addingTimeInterval(delay))
            default: throw GooglePhotosFailure.server(result.response.statusCode)
            }
        }
        return result
    }
    private func jsonRequest(_ path: String, body: [String: Any], accountID: String, accepted: Set<Int> = [200]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: base + path)!); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let result = try await response(request, accountID: accountID, accepted: accepted)
        guard let json = try JSONSerialization.jsonObject(with: result.data) as? [String: Any] else { throw GooglePhotosFailure.invalidResponse }; return json
    }
    private func album(_ json: [String: Any]) throws -> GooglePhotosAlbum {
        guard let id = (json["id"] as? String)?.nonEmpty, let title = (json["title"] as? String)?.nonEmpty else { throw GooglePhotosFailure.invalidResponse }
        return .init(id: id, title: title, productURL: safeProductURL(json["productUrl"] as? String))
    }
    private func safeProductURL(_ value: String?) -> String? {
        guard let value, let url = URL(string: value), url.scheme == "https", url.host == "photos.google.com", url.user == nil, url.password == nil else { return nil }; return value
    }
    func albums(accountID: String) async throws -> [GooglePhotosAlbum] {
        var albums: [GooglePhotosAlbum] = [], page: String?, seen = Set<String>()
        repeat {
            var parts = URLComponents(string: base + "albums")!; parts.queryItems = [.init(name: "pageSize", value: "50")]
            if let page { parts.queryItems!.append(.init(name: "pageToken", value: page)) }
            let result = try await response(URLRequest(url: parts.url!), accountID: accountID)
            guard let json = try JSONSerialization.jsonObject(with: result.data) as? [String: Any] else { throw GooglePhotosFailure.invalidResponse }
            if let rows = json["albums"] as? [[String: Any]] { albums += try rows.map(album) }
            else if json["albums"] != nil { throw GooglePhotosFailure.invalidResponse }
            page = (json["nextPageToken"] as? String)?.nonEmpty
            if let page { guard seen.insert(page).inserted, seen.count < 1000 else { throw GooglePhotosFailure.invalidResponse } }
        } while page != nil
        guard Set(albums.map(\.id)).count == albums.count else { throw GooglePhotosFailure.invalidResponse }
        return albums
    }
    func createAlbum(title: String, accountID: String) async throws -> GooglePhotosAlbum {
        guard title.nonEmpty != nil, title.count <= 500 else { throw ArchiveFileVerification.failure("Google Photos album titles must contain 1–500 characters.") }
        return try album(await jsonRequest("albums", body: ["album": ["title": title]], accountID: accountID))
    }
    private func checkedSession(_ session: GooglePhotosUploadSession) throws {
        guard session.url.scheme == "https", session.url.host == "photoslibrary.googleapis.com", session.url.path == "/v1/uploads", session.url.user == nil,
              session.url.password == nil, session.url.port == nil, session.url.fragment == nil, session.granularity > 0, session.granularity <= 8_388_608 else { throw GooglePhotosFailure.invalidResponse }
    }
    func startUpload(size: Int64, mimeType: String, accountID: String) async throws -> GooglePhotosUploadSession {
        var request = URLRequest(url: URL(string: base + "uploads")!); request.httpMethod = "POST"; request.httpBody = Data()
        request.setValue("0", forHTTPHeaderField: "Content-Length"); request.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol"); request.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Content-Type")
        request.setValue(String(size), forHTTPHeaderField: "X-Goog-Upload-Raw-Size")
        let result = try await response(request, accountID: accountID)
        guard let value = result.response.value(forHTTPHeaderField: "X-Goog-Upload-URL"), let url = URL(string: value),
              let granularity = result.response.value(forHTTPHeaderField: "X-Goog-Upload-Chunk-Granularity").flatMap(Int.init) else { throw GooglePhotosFailure.invalidResponse }
        let session = GooglePhotosUploadSession(url: url, granularity: granularity); try checkedSession(session); return session
    }
    func queryUpload(_ session: GooglePhotosUploadSession, accountID: String) async throws -> GooglePhotosUploadProgress {
        try checkedSession(session)
        var request = URLRequest(url: session.url); request.httpMethod = "POST"; request.httpBody = Data()
        request.setValue("query", forHTTPHeaderField: "X-Goog-Upload-Command"); request.setValue("0", forHTTPHeaderField: "Content-Length")
        let result = try await response(request, accountID: accountID)
        guard let status = result.response.value(forHTTPHeaderField: "X-Goog-Upload-Status"), ["active", "final", "cancelled"].contains(status) else { throw GooglePhotosFailure.invalidResponse }
        let offset = result.response.value(forHTTPHeaderField: "X-Goog-Upload-Size-Received").flatMap(Int64.init) ?? 0
        let token = String(data: result.data, encoding: .utf8)?.nonEmpty
        return .init(offset: offset, active: status == "active", token: status == "final" ? token : nil)
    }
    func upload(_ session: GooglePhotosUploadSession, offset: Int64, data: Data, final: Bool, accountID: String) async throws -> String? {
        try checkedSession(session)
        guard offset >= 0, final || (data.count > 0 && data.count % session.granularity == 0) else { throw GooglePhotosFailure.invalidResponse }
        var request = URLRequest(url: session.url); request.httpMethod = "POST"; request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type"); request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        request.setValue(String(offset), forHTTPHeaderField: "X-Goog-Upload-Offset"); request.setValue(final ? "upload, finalize" : "upload", forHTTPHeaderField: "X-Goog-Upload-Command")
        let result = try await response(request, accountID: accountID)
        if !final { return nil }
        guard let token = String(data: result.data, encoding: .utf8)?.nonEmpty, token.count <= 16_384 else { throw GooglePhotosFailure.invalidResponse }; return token
    }
    func createMedia(token: String, fileName: String, albumID: String, accountID: String) async throws -> GooglePhotosCreatedMedia {
        // Google prohibits generated metadata/descriptions in the description field.
        let json = try await jsonRequest("mediaItems:batchCreate", body: ["albumId": albumID,
            "newMediaItems": [["simpleMediaItem": ["uploadToken": token, "fileName": fileName]]]], accountID: accountID, accepted: [200, 207])
        guard let rows = json["newMediaItemResults"] as? [[String: Any]], rows.count == 1, rows[0]["uploadToken"] as? String == token,
              let status = rows[0]["status"] as? [String: Any] else { throw GooglePhotosFailure.invalidResponse }
        let code = status["code"] as? Int ?? 0
        guard code == 0 else {
            if code == 8 { throw GooglePhotosFailure.quota(Date().addingTimeInterval(30)) }
            throw ArchiveFileVerification.failure("Google Photos could not create this media item (status \(code)). Its original and saved progress remain; no downgrade was made.")
        }
        guard let media = rows[0]["mediaItem"] as? [String: Any], let id = (media["id"] as? String)?.nonEmpty,
              let mime = (media["mimeType"] as? String)?.nonEmpty else { throw GooglePhotosFailure.invalidResponse }
        return .init(id: id, mimeType: mime, productURL: safeProductURL(media["productUrl"] as? String))
    }
    func memberIDs(albumID: String, accountID: String) async throws -> Set<String> {
        var ids = Set<String>(), page: String?, seen = Set<String>()
        repeat {
            var body: [String: Any] = ["albumId": albumID, "pageSize": 100]
            if let page { body["pageToken"] = page }
            let json = try await jsonRequest("mediaItems:search", body: body, accountID: accountID)
            if let rows = json["mediaItems"] as? [[String: Any]] {
                for row in rows { guard let id = (row["id"] as? String)?.nonEmpty else { throw GooglePhotosFailure.invalidResponse }; ids.insert(id) }
            } else if json["mediaItems"] != nil { throw GooglePhotosFailure.invalidResponse }
            page = (json["nextPageToken"] as? String)?.nonEmpty
            if let page { guard seen.insert(page).inserted, seen.count < 1000 else { throw GooglePhotosFailure.invalidResponse } }
        } while page != nil
        return ids
    }
}
