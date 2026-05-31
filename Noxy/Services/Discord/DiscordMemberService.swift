import Foundation

// Worker 経由で Discord メンバー情報を取得・操作するサービス

struct DiscordMemberService: MemberServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - メンバー一覧取得

    func fetchMembers(guildId: String) async throws -> [Member] {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/members?guild_id=\(guildId)")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Member].self, from: data)
    }

    // MARK: - モデレーションアクション

    func kick(memberId: String, guildId: String, reason: String?) async throws {
        try await modAction(
            path: "kick",
            body: ModerationBody(memberId: memberId, guildId: guildId, reason: reason)
        )
    }

    func ban(memberId: String, guildId: String, reason: String?) async throws {
        try await modAction(
            path: "ban",
            body: ModerationBody(memberId: memberId, guildId: guildId, reason: reason)
        )
    }

    func timeout(memberId: String, guildId: String, until: Date) async throws {
        let iso = ISO8601DateFormatter().string(from: until)
        try await modAction(
            path: "timeout",
            body: TimeoutBody(memberId: memberId, guildId: guildId, until: iso)
        )
    }

    func addRole(memberId: String, guildId: String, roleId: String) async throws {
        // TODO: Worker エンドポイント追加後に実装
    }

    func removeRole(memberId: String, guildId: String, roleId: String) async throws {
        // TODO: Worker エンドポイント追加後に実装
    }

    // MARK: - 内部ヘルパー

    private func modAction<T: Encodable>(path: String, body: T) async throws {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/members/\(path)")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ServiceError.networkError
        }
    }
}

// MARK: - リクエストボディ

private struct ModerationBody: Encodable {
    let memberId: String
    let guildId: String
    let reason: String?
}

private struct TimeoutBody: Encodable {
    let memberId: String
    let guildId: String
    let until: String
}
