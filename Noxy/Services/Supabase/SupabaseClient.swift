import Foundation

// MARK: - Supabase 設定

struct SupabaseConfig {
    // #6: static var にすることで設定画面からの変更をリアルタイムに反映
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "supabase_url") ?? "https://byvwidopvpedslzwuksq.supabase.co"
    }
    static var anonKey: String {
        UserDefaults.standard.string(forKey: "supabase_anon_key") ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5dndpZG9wdnBlZHNsend1a3NxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxMTcyMzgsImV4cCI6MjA5NTY5MzIzOH0.pkJ_Roy8Ol7rTNS0Ud1ZkF7vX-ifgSXGA_SBqadDCxo"
    }

    static var isConfigured: Bool { !baseURL.isEmpty && !anonKey.isEmpty }
}

// MARK: - Supabase エラー

enum SupabaseError: LocalizedError {
    case notConfigured
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:              return "Supabaseが未設定です"
        case .httpError(let c, let m):    return "Supabase HTTP \(c): \(m)"
        case .decodingError(let e):       return "デコードエラー: \(e.localizedDescription)"
        case .networkError(let e):        return "通信エラー: \(e.localizedDescription)"
        }
    }
}

// MARK: - SupabaseClient

struct SupabaseClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Encoder/Decoder（snake_case ↔ camelCase 変換）

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: str) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            if let date = fmt.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return d
    }()

    // MARK: - REST メソッド

    func get<T: Decodable>(
        _ table: String,
        select: String = "*",
        query: [String: String] = [:],
        order: String? = nil,
        limit: Int? = nil
    ) async throws -> T {
        var params = query
        params["select"] = select
        if let order { params["order"] = order }
        if let limit { params["limit"] = "\(limit)" }
        let path = "/rest/v1/\(table)?\(queryString(params))"
        let data = try await request(method: "GET", path: path)
        return try decode(T.self, from: data)
    }

    func post<T: Encodable, R: Decodable>(
        _ table: String,
        body: T
    ) async throws -> R {
        let bodyData = try Self.encoder.encode(body)
        let path = "/rest/v1/\(table)"
        let data = try await request(method: "POST", path: path, body: bodyData)
        return try decode(R.self, from: data)
    }

    func patch<T: Encodable>(
        _ table: String,
        body: T,
        where column: String,
        equals value: String
    ) async throws {
        let bodyData = try Self.encoder.encode(body)
        let path = "/rest/v1/\(table)?\(column)=eq.\(value)"
        _ = try await request(method: "PATCH", path: path, body: bodyData)
    }

    func patchWithResponse<T: Encodable, R: Decodable>(
        _ table: String,
        body: T,
        where column: String,
        equals value: String
    ) async throws -> R {
        let bodyData = try Self.encoder.encode(body)
        let path = "/rest/v1/\(table)?\(column)=eq.\(value)"
        let data = try await request(method: "PATCH", path: path, body: bodyData)
        return try decode(R.self, from: data)
    }

    // MARK: - Supabase は配列でレスポンスを返すため、先頭要素を返す系メソッド

    /// INSERT → レスポンス配列の先頭を返す
    func postFirst<T: Encodable, R: Decodable>(_ table: String, body: T) async throws -> R {
        let bodyData = try Self.encoder.encode(body)
        let path = "/rest/v1/\(table)"
        let data = try await request(method: "POST", path: path, body: bodyData)
        let array: [R] = try decode([R].self, from: data)
        guard let first = array.first else {
            throw SupabaseError.httpError(statusCode: 0, message: "Empty response from Supabase")
        }
        return first
    }

    /// PATCH → レスポンス配列の先頭を返す
    func patchFirst<T: Encodable, R: Decodable>(
        _ table: String,
        body: T,
        where column: String,
        equals value: String
    ) async throws -> R {
        let bodyData = try Self.encoder.encode(body)
        let path = "/rest/v1/\(table)?\(column)=eq.\(value)"
        let data = try await request(method: "PATCH", path: path, body: bodyData)
        let array: [R] = try decode([R].self, from: data)
        guard let first = array.first else {
            throw SupabaseError.httpError(statusCode: 0, message: "Empty response from Supabase")
        }
        return first
    }

    /// INSERT してレスポンスを無視する（送信のみ）
    func postVoid<T: Encodable>(_ table: String, body: T) async throws {
        let bodyData = try Self.encoder.encode(body)
        let path = "/rest/v1/\(table)"
        _ = try await request(method: "POST", path: path, body: bodyData)
    }

    func delete(
        _ table: String,
        where column: String,
        equals value: String
    ) async throws {
        let path = "/rest/v1/\(table)?\(column)=eq.\(value)"
        _ = try await request(method: "DELETE", path: path)
    }

    // MARK: - 内部

    private func buildURL(_ path: String) throws -> URL {
        guard let url = URL(string: SupabaseConfig.baseURL + path) else {
            throw SupabaseError.notConfigured
        }
        return url
    }

    // MARK: - JWT helpers

    /// JWTペイロードから exp クレームを取得する（ネットワーク不要）
    private func jwtExpiry(from token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1])
        let rem = b64.count % 4
        if rem != 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private func request(method: String, path: String, body: Data? = nil) async throws -> Data {
        guard SupabaseConfig.isConfigured else { throw SupabaseError.notConfigured }

        // トークンの有効期限が5分以内なら事前リフレッシュ
        if let token = KeychainHelper.load(forKey: "supabase_access_token"),
           let expiry = jwtExpiry(from: token),
           expiry.timeIntervalSinceNow < 300 {
            _ = try? await refreshToken()
        }

        do {
            return try await performRequest(method: method, path: path, body: body)
        } catch let error as SupabaseError {
            if case .httpError(let code, _) = error, code == 401 {
                // トークン期限切れ → リフレッシュして再試行
                #if DEBUG
                print("[Supabase] 401 detected, refreshing token...")
                #endif
                if try await refreshToken() {
                    #if DEBUG
                    print("[Supabase] token refreshed, retrying...")
                    #endif
                    return try await performRequest(method: method, path: path, body: body)
                }
            }
            throw error
        }
    }

    private func performRequest(method: String, path: String, body: Data? = nil) async throws -> Data {
        let url = try buildURL(path)
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        let authToken = KeychainHelper.load(forKey: "supabase_access_token") ?? SupabaseConfig.anonKey
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        let (data, response) = try await session.data(for: req)
        let http = response as! HTTPURLResponse
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SupabaseError.httpError(statusCode: http.statusCode, message: msg)
        }
        return data
    }

    // MARK: - Token Refresh

    private func refreshToken() async throws -> Bool {
        guard let refreshToken = KeychainHelper.load(forKey: "supabase_refresh_token"),
              !refreshToken.isEmpty else {
            #if DEBUG
            print("[Supabase] no refresh token available")
            #endif
            return false
        }

        let url = try buildURL("/auth/v1/token?grant_type=refresh_token")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["refresh_token": refreshToken]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            #if DEBUG
            print("[Supabase] refresh failed")
            #endif
            return false
        }

        struct RefreshResponse: Decodable {
            let accessToken: String
            let refreshToken: String
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
            }
        }

        guard let resp = try? JSONDecoder().decode(RefreshResponse.self, from: data) else {
            return false
        }

        KeychainHelper.save(resp.accessToken,  forKey: "supabase_access_token")
        KeychainHelper.save(resp.refreshToken, forKey: "supabase_refresh_token")
        #if DEBUG
        print("[Supabase] token refreshed successfully")
        #endif
        return true
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw SupabaseError.decodingError(error)
        }
    }

    private func queryString(_ params: [String: String]) -> String {
        params.map { k, v in
            "\(k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k)=\(v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v)"
        }.joined(separator: "&")
    }
}
