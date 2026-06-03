import Foundation

// MARK: - API Response Types

private struct DiscordBanEntry: Decodable {
    struct User: Decodable {
        let id: String
        let username: String
        let globalName: String?
        let avatar: String?
    }
    let user: User
    let reason: String?
}

private struct SupabaseWarning: Decodable {
    let id: String
    let guildId: String
    let userId: String
    let username: String
    let displayName: String
    let reason: String
    let staffId: String
    let staffName: String
    let autoAction: String?
    let isRevoked: Bool
    let revokedAt: Date?
    let revokedBy: String?
    let createdAt: Date
}

// MARK: - ModerationService

struct ModerationService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - BAN

    func fetchBans(guildId: String) async throws -> [BannedUser] {
        let data = try await get("/bot/bans?guild_id=\(guildId)")
        let entries = try workerDecoder.decode([DiscordBanEntry].self, from: data)
        return entries.map {
            BannedUser(
                id: $0.user.id,
                username: $0.user.username,
                displayName: $0.user.globalName ?? $0.user.username,
                reason: $0.reason,
                bannedAt: nil   // Discord APIはBAN日時を返さない
            )
        }
    }

    func unban(userId: String, guildId: String) async throws {
        let req = makeRequest("/bot/bans/\(userId)?guild_id=\(guildId)", method: "DELETE")
        try await execute(req)
    }

    // MARK: - Timeout

    func fetchTimeouts(guildId: String) async throws -> [TimedOutMember] {
        let data = try await get("/bot/timeouts?guild_id=\(guildId)")
        return try workerDecoder.decode([TimedOutMember].self, from: data)
    }

    func removeTimeout(userId: String, guildId: String) async throws {
        struct Body: Encodable { let guildId: String }
        var req = makeRequest("/bot/members/\(userId)/untimeout", method: "PATCH")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Body(guildId: guildId))
        try await execute(req)
    }

    // MARK: - Warning

    func fetchWarnings(guildId: String) async throws -> [ModWarning] {
        let data = try await get("/bot/warnings?guild_id=\(guildId)")
        let raw = try workerDecoder.decode([SupabaseWarning].self, from: data)
        return raw.map { s in
            ModWarning(id: s.id, userId: s.userId, username: s.username,
                       displayName: s.displayName, reason: s.reason,
                       staffName: s.staffName, createdAt: s.createdAt,
                       isRevoked: s.isRevoked)
        }
    }

    func addWarning(guildId: String, userId: String, username: String,
                    displayName: String, reason: String,
                    staffId: String, staffName: String,
                    autoAction: String?) async throws -> ModWarning {
        struct Body: Encodable {
            let guildId, userId, username, displayName, reason, staffId, staffName: String
            let autoAction: String?
        }
        let body = Body(guildId: guildId, userId: userId, username: username,
                        displayName: displayName, reason: reason,
                        staffId: staffId, staffName: staffName, autoAction: autoAction)
        let data = try await post("/bot/warnings", body: body)
        let raw = try workerDecoder.decode(SupabaseWarning.self, from: data)
        return ModWarning(id: raw.id, userId: raw.userId, username: raw.username,
                          displayName: raw.displayName, reason: raw.reason,
                          staffName: raw.staffName, createdAt: raw.createdAt,
                          isRevoked: raw.isRevoked)
    }

    func revokeWarning(id: String) async throws {
        let req = makeRequest("/bot/warnings/\(id)/revoke", method: "PATCH")
        try await execute(req)
    }

    // MARK: - Internals

    private func makeRequest(_ path: String, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: URL(string: DiscordConfig.workerURL + path)!, timeoutInterval: 15)
        req.httpMethod = method
        // #1: 認証ヘッダーを追加
        req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        return req
    }

    private func get(_ path: String) async throws -> Data {
        let req = makeRequest(path)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return data
    }

    private func post(_ path: String, body: some Encodable) async throws -> Data {
        var req = makeRequest(path, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        return data
    }

    private func execute(_ req: URLRequest) async throws {
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) || http.statusCode == 204 else {
            throw ServiceError.networkError
        }
    }

    private var workerDecoder: JSONDecoder {
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
    }
}
