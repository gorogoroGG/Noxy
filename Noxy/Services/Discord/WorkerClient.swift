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

    // MARK: - Auth helper

    /// Supabase アクセストークンを Authorization ヘッダー用に返す
    static func bearerToken() -> String? {
        guard let t = KeychainHelper.load(forKey: "supabase_access_token"), !t.isEmpty else { return nil }
        return t
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
        if let token = Self.bearerToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        return req
    }

    // MARK: - HTTP Methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await withRetry {
            guard let url = URL(string: DiscordConfig.workerURL + path) else {
                throw ServiceError.networkError
            }
            let (data, response) = try await self.session.data(for: self.makeRequest(url: url))
            try self.validate(response, data: data)
            return try Self.decoder.decode(T.self, from: data)
        }
    }

    func post(_ path: String) async throws {
        try await withRetry {
            guard let url = URL(string: DiscordConfig.workerURL + path) else {
                throw ServiceError.networkError
            }
            let req = self.makeRequest(url: url, method: "POST")
            let (data, response) = try await self.session.data(for: req)
            try self.validate(response, data: data)
        }
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let bodyData = try Self.encoder.encode(body)
        return try await withRetry {
            guard let url = URL(string: DiscordConfig.workerURL + path) else {
                throw ServiceError.networkError
            }
            let req = self.makeRequest(url: url, method: "POST", body: bodyData)
            let (data, response) = try await self.session.data(for: req)
            try self.validate(response, data: data)
            return try Self.decoder.decode(T.self, from: data)
        }
    }

    func postVoid<B: Encodable>(_ path: String, body: B) async throws {
        let bodyData = try Self.encoder.encode(body)
        try await withRetry {
            guard let url = URL(string: DiscordConfig.workerURL + path) else {
                throw ServiceError.networkError
            }
            let req = self.makeRequest(url: url, method: "POST", body: bodyData)
            let (data, response) = try await self.session.data(for: req)
            try self.validate(response, data: data)
        }
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let bodyData = try Self.encoder.encode(body)
        return try await withRetry {
            guard let url = URL(string: DiscordConfig.workerURL + path) else {
                throw ServiceError.networkError
            }
            let req = self.makeRequest(url: url, method: "PATCH", body: bodyData)
            let (data, response) = try await self.session.data(for: req)
            try self.validate(response, data: data)
            return try Self.decoder.decode(T.self, from: data)
        }
    }

    func delete(_ path: String) async throws {
        try await withRetry {
            guard let url = URL(string: DiscordConfig.workerURL + path) else {
                throw ServiceError.networkError
            }
            let req = self.makeRequest(url: url, method: "DELETE")
            let (data, response) = try await self.session.data(for: req)
            try self.validate(response, data: data)
        }
    }

    // MARK: - Retry

    /// 最初のリクエストが失敗した場合に1回だけ自動リトライする。
    /// 401/404 など確定エラーはリトライしない（同じ結果になるため）。
    private func withRetry<T>(attempts: Int = 2, delay: UInt64 = 800_000_000, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<attempts {
            do {
                return try await operation()
            } catch let error as ServiceError {
                switch error {
                case .unauthorizedWithDetail, .notFound:
                    throw error  // 確定エラーはリトライしない
                default:
                    lastError = error
                }
            } catch {
                lastError = error
            }
            if attempt < attempts - 1 {
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        throw lastError ?? ServiceError.networkError
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
