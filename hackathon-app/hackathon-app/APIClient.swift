import Foundation

// MARK: - Error type

enum APIError: LocalizedError, Sendable {
    case noBaseURL
    case noToken
    case http(statusCode: Int, body: APIErrorBody?)
    case decoding(String)
    case network(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .noBaseURL:
            return "API base URL is not configured."
        case .noToken:
            return "You are not signed in."
        case .http(_, let body):
            if let msg = body?.message { return msg }
            if let code = body?.error {
                return code.replacingOccurrences(of: "_", with: " ").localizedCapitalized
            }
            return "An unexpected server error occurred."
        case .decoding(let msg):
            return "Failed to read server response: \(msg)"
        case .network(let msg):
            return msg
        }
    }

    nonisolated var apiCode: String? {
        if case .http(_, let body) = self { return body?.error }
        return nil
    }

    nonisolated var statusCode: Int? {
        if case .http(let code, _) = self { return code }
        return nil
    }

    nonisolated var isUnauthorized: Bool { statusCode == 401 }
}

// MARK: - Client

@MainActor
final class APIClient {
    static let shared = APIClient()

    #if DEBUG
    var baseURL = "http://127.0.0.1:3000/v1"
    #else
    var baseURL = "https://your-production-url.com/v1"
    #endif

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        return URLSession(configuration: cfg)
    }()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Public API

    func getMe() async throws -> UserResponse {
        try await get("/me")
    }

    func createIntent(_ body: CreateIntentRequest) async throws -> CreateIntentResponse {
        try await post("/driver-intents", body: body)
    }

    func getMyIntents(from: String? = nil, to: String? = nil) async throws -> IntentListResponse {
        var q: [(String, String)] = []
        if let f = from { q.append(("from", f)) }
        if let t = to { q.append(("to", t)) }
        return try await get("/driver-intents/mine", query: q)
    }

    func deleteIntent(id: String) async throws {
        try await fire(.delete, "/driver-intents/\(id)")
    }

    func searchMatches(_ body: MatchesRequest) async throws -> MatchesResponse {
        try await post("/driver-intents/matches", body: body)
    }

    func applyToIntent(intentId: String, body: ApplyRequest) async throws -> ApplicationResponse {
        try await post("/driver-intents/\(intentId)/applications", body: body)
    }

    func cancelApplication(id: String, timeZone tz: String) async throws {
        let body = CancelApplicationRequest(clientTimeZone: tz)
        try await fire(.delete, "/applications/\(id)", body: body)
    }

    func getIntentDetail(id: String) async throws -> IntentDetailResponse {
        try await get("/driver-intents/\(id)/detail")
    }

    // MARK: - Internal

    private enum Method: String { case get = "GET", post = "POST", delete = "DELETE" }

    private func get<T: Decodable>(_ path: String, query: [(String, String)] = []) async throws -> T {
        let req = try makeRequest(.get, path: path, query: query)
        return try await execute(req)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let data = try encoder.encode(body)
        let req = try makeRequest(.post, path: path, bodyData: data)
        return try await execute(req)
    }

    private func fire(_ method: Method, _ path: String) async throws {
        let req = try makeRequest(method, path: path)
        try await executeNoContent(req)
    }

    private func fire<B: Encodable>(_ method: Method, _ path: String, body: B) async throws {
        let bodyData = try encoder.encode(body)
        let req = try makeRequest(method, path: path, bodyData: bodyData)
        try await executeNoContent(req)
    }

    private func makeRequest(
        _ method: Method,
        path: String,
        query: [(String, String)] = [],
        bodyData: Data? = nil
    ) throws -> URLRequest {
        guard var comps = URLComponents(string: baseURL + path) else { throw APIError.noBaseURL }
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        guard let url = comps.url else { throw APIError.noBaseURL }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let token = AuthKeychain.idToken() else { throw APIError.noToken }
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        req.httpBody = bodyData
        return req
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, resp) = try await performRequest(request)
        let http = resp as! HTTPURLResponse

        guard (200...299).contains(http.statusCode) else {
            let body = try? decoder.decode(APIErrorBody.self, from: data)
            throw APIError.http(statusCode: http.statusCode, body: body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func executeNoContent(_ request: URLRequest) async throws {
        let (data, resp) = try await performRequest(request)
        let http = resp as! HTTPURLResponse

        guard (200...299).contains(http.statusCode) else {
            let body = try? decoder.decode(APIErrorBody.self, from: data)
            throw APIError.http(statusCode: http.statusCode, body: body)
        }
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }
}
