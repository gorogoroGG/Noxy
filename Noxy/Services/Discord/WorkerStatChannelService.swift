import Foundation

struct WorkerStatChannelService: StatChannelServiceProtocol {
    private let client = WorkerClient()

    func fetchAll(guildId: String) async throws -> [StatChannel] {
        try await client.get("/bot/stat-channels?guild_id=\(guildId)")
    }

    func create(guildId: String, statType: StatType, categoryId: String?) async throws -> StatChannel {
        struct Body: Encodable {
            let guildId: String
            let statType: String
            let categoryId: String?
        }
        return try await client.post(
            "/bot/stat-channels",
            body: Body(guildId: guildId, statType: statType.rawValue, categoryId: categoryId)
        )
    }

    func toggle(id: String, enabled: Bool) async throws -> StatChannel {
        struct Body: Encodable { let enabled: Bool }
        return try await client.patch("/bot/stat-channels/\(id)/toggle", body: Body(enabled: enabled))
    }

    func delete(id: String) async throws {
        try await client.delete("/bot/stat-channels/\(id)")
    }

    func refresh(id: String) async throws {
        struct Empty: Encodable {}
        let _: OkResponse = try await client.post("/bot/stat-channels/\(id)/refresh", body: Empty())
    }
}

private struct OkResponse: Decodable { let ok: Bool }
