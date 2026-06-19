import Foundation

struct WorkerInviteTrackerService: InviteTrackerServiceProtocol {
    private let client = WorkerClient()

    func fetchLeaderboard(guildId: String, period: InvitePeriod) async throws -> [InviteStats] {
        try await client.get("/bot/invite-tracker/leaderboard?guild_id=\(guildId)&period=\(period.rawValue)")
    }

    func fetchMemberDetail(guildId: String, userId: String) async throws -> InviteMemberDetail {
        try await client.get("/bot/invite-tracker/member?guild_id=\(guildId)&user_id=\(userId)")
    }

    func fetchTree(guildId: String, userId: String) async throws -> InviteTreeNode {
        try await client.get("/bot/invite-tracker/tree?guild_id=\(guildId)&user_id=\(userId)")
    }

    func fetchSettings(guildId: String) async throws -> InviteTrackerSettings {
        try await client.get("/bot/invite-tracker/settings?guild_id=\(guildId)")
    }

    func saveSettings(_ settings: InviteTrackerSettings) async throws -> InviteTrackerSettings {
        try await client.post("/bot/invite-tracker/settings", body: settings)
    }

    // MARK: - Invite Panel

    func deployInvitePanel(guildId: String, channelId: String, channelName: String) async throws -> InvitePanel {
        struct Body: Encodable { let guildId: String; let channelId: String; let channelName: String }
        return try await client.post("/bot/invite-tracker/panel",
                                     body: Body(guildId: guildId, channelId: channelId, channelName: channelName))
    }

    func fetchInvitePanels(guildId: String) async throws -> [InvitePanel] {
        try await client.get("/bot/invite-tracker/panels?guild_id=\(guildId)")
    }

    func deleteInvitePanel(id: String) async throws {
        try await client.delete("/bot/invite-tracker/panels/\(id)")
    }

    // MARK: - Personal Invite Links

    func fetchPersonalInviteLinks(guildId: String) async throws -> [PersonalInviteLink] {
        try await client.get("/bot/invite-tracker/personal-invites?guild_id=\(guildId)")
    }

    func revokePersonalInviteLink(id: String) async throws {
        try await client.delete("/bot/invite-tracker/personal-invites/\(id)")
    }
}
