import Foundation

// MARK: - WorkerClient
// Worker API へのすべての HTTP リクエストを一元管理。
// - X-Bot-Secret ヘッダーを自動付与
// - JSONDecoder を static 共有
// - タイムアウトを統一

struct WorkerClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Static shared decoder（#9: JSONDecoder を毎回生成しない）

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }
            return Date()
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: - Request Builder

    private func makeRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        // #1: 認証ヘッダーを全リクエストに自動付与
        req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        return req
    }

    // MARK: - HTTP Methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: DiscordConfig.workerURL + path) else {
            throw ServiceError.networkError
        }
        let (data, response) = try await session.data(for: makeRequest(url: url))
        try validate(response, data: data)
        return try Self.decoder.decode(T.self, from: data)
    }

    func post(_ path: String) async throws {
        guard let url = URL(string: DiscordConfig.workerURL + path) else {
            throw ServiceError.networkError
        }
        let req = makeRequest(url: url, method: "POST")
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: DiscordConfig.workerURL + path) else {
            throw ServiceError.networkError
        }
        let bodyData = try Self.encoder.encode(body)
        let req = makeRequest(url: url, method: "POST", body: bodyData)
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
        return try Self.decoder.decode(T.self, from: data)
    }

    func postVoid<B: Encodable>(_ path: String, body: B) async throws {
        guard let url = URL(string: DiscordConfig.workerURL + path) else {
            throw ServiceError.networkError
        }
        let bodyData = try Self.encoder.encode(body)
        let req = makeRequest(url: url, method: "POST", body: bodyData)
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: DiscordConfig.workerURL + path) else {
            throw ServiceError.networkError
        }
        let bodyData = try Self.encoder.encode(body)
        let req = makeRequest(url: url, method: "PATCH", body: bodyData)
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
        return try Self.decoder.decode(T.self, from: data)
    }

    func delete(_ path: String) async throws {
        guard let url = URL(string: DiscordConfig.workerURL + path) else {
            throw ServiceError.networkError
        }
        let req = makeRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
    }

    // MARK: - Helpers

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ServiceError.networkError }
        switch http.statusCode {
        case 200..<300: return
        case 401:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.unauthorizedWithDetail(msg)
        case 404:       throw ServiceError.notFound
        default:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.workerError(status: http.statusCode, message: msg)
        }
    }
}
