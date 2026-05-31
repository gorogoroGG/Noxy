import Foundation

// MARK: - 設定

struct APIConfig {
    /// Tailscale または LAN の IP/ドメイン（末尾スラッシュなし）
    /// 例: "http://100.64.0.1:3000" or "http://192.168.1.2:3000"
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "api_base_url") ?? "http://192.168.1.2:3000"
    }

    /// .env の API_KEY（未設定なら空文字）
    static var apiKey: String {
        UserDefaults.standard.string(forKey: "api_key") ?? ""
    }
}

// MARK: - エラー

enum APIError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "URLが無効です"
        case .httpError(let c, let m):  return "HTTPエラー \(c): \(m)"
        case .decodingError(let e):     return "デコードエラー: \(e.localizedDescription)"
        case .networkError(let e):      return "通信エラー: \(e.localizedDescription)"
        }
    }
}

// MARK: - HTTP クライアント

struct APIClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // ---- Decoder ----
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // "2024-01-01T12:00:00.000Z" or "2024-01-01T12:00:00Z"
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }
            // fallback
            return Date()
        }
        return d
    }()

    // ---- GET ----
    func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await request(method: "GET", path: path, body: nil)
        return try decode(T.self, from: data)
    }

    // ---- POST (no body) ----
    func post(_ path: String) async throws {
        _ = try await request(method: "POST", path: path, body: nil)
    }

    // ---- POST (JSON body) ----
    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        let data = try await request(method: "POST", path: path, body: bodyData)
        return try decode(T.self, from: data)
    }

    // ---- PUT (JSON body) ----
    func put<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        let data = try await request(method: "PUT", path: path, body: bodyData)
        return try decode(T.self, from: data)
    }

    // ---- DELETE ----
    func delete(_ path: String) async throws {
        _ = try await request(method: "DELETE", path: path, body: nil)
    }

    // ---- POST (JSON body, no response) ----
    func postBody(_ path: String, body: some Encodable) async throws {
        let bodyData = try JSONEncoder().encode(body)
        _ = try await request(method: "POST", path: path, body: bodyData)
    }

    // ---- 内部 ----
    private func request(method: String, path: String, body: Data?) async throws -> Data {
        let urlStr = APIConfig.baseURL + path
        guard let url = URL(string: urlStr) else { throw APIError.invalidURL }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !APIConfig.apiKey.isEmpty {
            req.setValue(APIConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        }
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: req)
            let http = response as! HTTPURLResponse
            guard (200..<300).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "Unknown"
                throw APIError.httpError(statusCode: http.statusCode, message: msg)
            }
            return data
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
