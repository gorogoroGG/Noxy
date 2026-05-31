import Foundation

struct SupabaseGreetingService: GreetingServiceProtocol {
    private let client = SupabaseClient()

    func fetch(guildId: String) async throws -> GreetingSettings {
        let results: [GreetingSettings] = try await client.get(
            "greeting_settings",
            query: ["guild_id": "eq.\(guildId)"]
        )
        return results.first ?? GreetingSettings.defaultSettings(guildId: guildId)
    }

    func save(_ settings: GreetingSettings) async throws -> GreetingSettings {
        // upsert: 存在すれば更新、なければ挿入
        let path = "/rest/v1/greeting_settings?guild_id=eq.\(settings.guildId)"
        let bodyData = try SupabaseClient.encoder.encode(settings)

        // まず PUT（upsert）
        var req = URLRequest(url: URL(string: SupabaseConfig.baseURL + path)!)
        req.httpMethod = "GET"
        // 存在チェック: fetch して存在すれば PATCH、なければ POST
        let existing: [GreetingSettings] = try await client.get(
            "greeting_settings",
            query: ["guild_id": "eq.\(settings.guildId)"]
        )

        if existing.isEmpty {
            return try await client.postFirst("greeting_settings", body: settings)
        } else {
            return try await client.patchFirst(
                "greeting_settings",
                body: settings,
                where: "guild_id",
                equals: settings.guildId
            )
        }
    }
}

// MARK: - Mock（開発中フォールバック）

struct MockGreetingService: GreetingServiceProtocol {
    private var storedSettings: [String: GreetingSettings] = [:]

    func fetch(guildId: String) async throws -> GreetingSettings {
        storedSettings[guildId] ?? GreetingSettings.defaultSettings(guildId: guildId)
    }

    func save(_ settings: GreetingSettings) async throws -> GreetingSettings {
        return settings
    }
}
