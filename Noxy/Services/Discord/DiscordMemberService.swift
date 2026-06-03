import Foundation

struct DiscordMemberService: MemberServiceProtocol {
    private let client = WorkerClient()

    func fetchMembers(guildId: String) async throws -> [Member] {
        try await client.get("/bot/members?guild_id=\(guildId)")
    }

    func kick(memberId: String, guildId: String, reason: String?) async throws {
        struct Body: Encodable { let memberId: String; let guildId: String; let reason: String? }
        try await client.postVoid("/bot/members/kick", body: Body(memberId: memberId, guildId: guildId, reason: reason))
    }

    func ban(memberId: String, guildId: String, reason: String?) async throws {
        struct Body: Encodable { let memberId: String; let guildId: String; let reason: String? }
        try await client.postVoid("/bot/members/ban", body: Body(memberId: memberId, guildId: guildId, reason: reason))
    }

    func timeout(memberId: String, guildId: String, until: Date) async throws {
        struct Body: Encodable { let memberId: String; let guildId: String; let until: String }
        let iso = ISO8601DateFormatter().string(from: until)
        try await client.postVoid("/bot/members/timeout", body: Body(memberId: memberId, guildId: guildId, until: iso))
    }

    func sendDM(memberId: String, message: String) async throws {
        struct Body: Encodable { let memberId: String; let message: String }
        try await client.postVoid("/bot/members/dm", body: Body(memberId: memberId, message: message))
    }

    func addRole(memberId: String, guildId: String, roleId: String) async throws {
        struct Body: Encodable { let memberId: String; let guildId: String; let roleId: String }
        try await client.postVoid("/bot/members/role/add", body: Body(memberId: memberId, guildId: guildId, roleId: roleId))
    }

    func removeRole(memberId: String, guildId: String, roleId: String) async throws {
        struct Body: Encodable { let memberId: String; let guildId: String; let roleId: String }
        try await client.postVoid("/bot/members/role/remove", body: Body(memberId: memberId, guildId: guildId, roleId: roleId))
    }
}
