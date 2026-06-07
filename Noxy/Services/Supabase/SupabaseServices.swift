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
        // 1. 画像URLを事前取得
        let embeds: [EmbedModel] = try await client.get("embeds", query: ["id": "eq.\(id)"])
        let embed = embeds.first

        // 2. DBから削除
        try await client.delete("embeds", where: "id", equals: id)

        // 3. Storage画像を非同期で削除（失敗しても無視）
        if let embed = embed {
            var urls: [String] = []
            if let imageUrl = embed.imageUrl { urls.append(imageUrl) }
            if let thumbUrl = embed.thumbnailUrl { urls.append(thumbUrl) }
            if !urls.isEmpty {
                Task {
                    try? await deleteStorageImages(urls: urls)
                }
            }
        }
    }

    private func deleteStorageImages(urls: [String]) async throws {
        let endpoint = "\(DiscordConfig.workerURL)/upload/delete"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !DiscordConfig.workerAPISecret.isEmpty {
            request.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        }
        let body: [String: Any] = ["urls": urls]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func send(embedId: String, guildId: String, channelId: String) async throws {
        let embed = try await fetch(id: embedId)
        let endpoint = "\(DiscordConfig.workerURL)/bot/send-embed"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !DiscordConfig.workerAPISecret.isEmpty {
            request.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        }
        let body: [String: Any] = [
            "guildId": guildId,
            "channelId": channelId,
            "embed": embed.asDiscordPayload
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
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
