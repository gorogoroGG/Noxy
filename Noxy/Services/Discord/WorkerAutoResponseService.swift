import Foundation

// MARK: - WorkerAutoResponseService

struct WorkerAutoResponseService: AutoResponseServiceProtocol {
    private let client = WorkerClient()

    func fetchAll(guildId: String) async throws -> [AutoResponse] {
        try await client.get("/bot/auto-responses?guild_id=\(guildId)")
    }

    func create(_ item: AutoResponse) async throws -> AutoResponse {
        try await client.post("/bot/auto-responses", body: item)
    }

    func update(_ item: AutoResponse) async throws -> AutoResponse {
        try await client.patch("/bot/auto-responses/\(item.id)", body: item)
    }

    func delete(id: String) async throws {
        try await client.delete("/bot/auto-responses/\(id)")
    }

    func toggle(id: String, enabled: Bool) async throws {
        struct Body: Encodable { let enabled: Bool }
        let _: AnyCodable = try await client.post("/bot/auto-responses/\(id)/toggle", body: Body(enabled: enabled))
    }
}

// void を返す POST のため
private struct AnyCodable: Decodable {}
