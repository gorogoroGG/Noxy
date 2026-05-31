import Foundation

struct DiscordMemberService: MemberServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

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

    func kick(memberId: String, guildId: String, reason: String?) async throws {
        try await post("kick", body: ModerationBody(memberId: memberId, guildId: guildId, reason: reason))
    }

    func ban(memberId: String, guildId: String, reason: String?) async throws {
        try await post("ban", body: ModerationBody(memberId: memberId, guildId: guildId, reason: reason))
    }

    func timeout(memberId: String, guildId: String, until: Date) async throws {
        let iso = ISO8601DateFormatter().string(from: until)
        try await post("timeout", body: TimeoutBody(memberId: memberId, guildId: guildId, until: iso))
    }

    func sendDM(memberId: String, message: String) async throws {
        try await post("dm", body: DMBody(memberId: memberId, message: message))
    }

    func addRole(memberId: String, guildId: String, roleId: String) async throws {
        try await post("role/add", body: RoleBody(memberId: memberId, guildId: guildId, roleId: roleId))
    }

    func removeRole(memberId: String, guildId: String, roleId: String) async throws {
        try await post("role/remove", body: RoleBody(memberId: memberId, guildId: guildId, roleId: roleId))
    }

    // MARK: - 内部

    private func post<T: Encodable>(_ path: String, body: T) async throws {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/members/\(path)")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.networkError
        }
    }
}

private struct ModerationBody: Encodable { let memberId: String; let guildId: String; let reason: String? }
private struct TimeoutBody:     Encodable { let memberId: String; let guildId: String; let until: String }
private struct DMBody:          Encodable { let memberId: String; let message: String }
private struct RoleBody:        Encodable { let memberId: String; let guildId: String; let roleId: String }
