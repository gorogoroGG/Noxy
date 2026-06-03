import Foundation

// ============================================================
// MARK: - Supabase Embed Service
// ============================================================

struct SupabaseEmbedService: EmbedServiceProtocol {
    private let client = SupabaseClient()

    func fetchAll() async throws -> [EmbedModel] {
        try await client.get("embeds", order: "created_at.desc")
    }

    func fetchByGuild(_ guildId: String) async throws -> [EmbedModel] {
        try await client.get("embeds", query: ["guild_id": "eq.\(guildId)"], order: "created_at.desc")
    }

    func fetch(id: String) async throws -> EmbedModel {
        let result: [EmbedModel] = try await client.get("embeds", query: ["id": "eq.\(id)"])
        guard let embed = result.first else { throw ServiceError.notFound }
        return embed
    }

    func create(_ embed: EmbedModel) async throws -> EmbedModel {
        try await client.postFirst("embeds", body: embed)
    }

    func update(_ embed: EmbedModel) async throws -> EmbedModel {
        try await client.patchFirst("embeds", body: embed, where: "id", equals: embed.id)
    }

    func delete(id: String) async throws {
        try await client.delete("embeds", where: "id", equals: id)
    }

    func send(embedId: String, guildId: String, channelId: String) async throws {
        let body = ScheduledMessage(
            id: UUID().uuidString,
            guildId: guildId,
            channelId: channelId,
            embedId: embedId,
            title: "",
            scheduledFor: Date(),
            repeatRule: .none,
            status: .pending,
            endDate: nil
        )
        try await client.postVoid("scheduled_messages", body: body)
    }
}

// ============================================================
// MARK: - Supabase ScheduledMessage Service
// ============================================================

struct SupabaseScheduledMessageService: ScheduledMessageServiceProtocol {
    private let client = SupabaseClient()

    func fetchAll() async throws -> [ScheduledMessage] {
        try await client.get("scheduled_messages", order: "scheduled_for.desc")
    }

    func fetchByGuild(_ guildId: String) async throws -> [ScheduledMessage] {
        try await client.get("scheduled_messages", query: ["guild_id": "eq.\(guildId)"], order: "scheduled_for.desc")
    }

    func create(_ message: ScheduledMessage) async throws -> ScheduledMessage {
        try await client.postFirst("scheduled_messages", body: message)
    }

    func update(_ message: ScheduledMessage) async throws -> ScheduledMessage {
        try await client.patchFirst("scheduled_messages", body: message, where: "id", equals: message.id)
    }

    func cancel(id: String) async throws {
        let body = ["status": "cancelled"]
        try await client.patch("scheduled_messages", body: body, where: "id", equals: id)
    }
}

// ============================================================
// MARK: - Supabase Guild Service
// ============================================================

struct SupabaseGuildService: GuildServiceProtocol {
    private let client = SupabaseClient()

    func fetchAll() async throws -> [Guild] {
        try await client.get("guilds", order: "name.asc")
    }

    func fetch(id: String) async throws -> Guild {
        let result: [Guild] = try await client.get("guilds", query: ["id": "eq.\(id)"])
        guard let guild = result.first else { throw ServiceError.notFound }
        return guild
    }

    func fetchChannels(guildId: String) async throws -> [Channel] {
        try await client.get("channels", query: ["guild_id": "eq.\(guildId)"], order: "name.asc")
    }

    func fetchBotGuildIds() async throws -> Set<String> {
        let guilds: [Guild] = try await fetchAll()
        return Set(guilds.map(\.id))
    }
}
