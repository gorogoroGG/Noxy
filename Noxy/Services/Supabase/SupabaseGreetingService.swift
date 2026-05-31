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
        // 存在チェック: fetch して存在すれば PATCH、なければ POST（upsert）
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
