import Foundation

struct SupabaseReactionRoleService: ReactionRoleServiceProtocol {
    private let client = SupabaseClient()

    func fetchAll(guildId: String) async throws -> [ReactionRoleItem] {
        try await client.get("reaction_roles", query: ["guild_id": "eq.\(guildId)"], order: "created_at.desc")
    }

    func create(_ item: ReactionRoleItem) async throws -> ReactionRoleItem {
        try await client.post("reaction_roles", body: item)
    }

    func update(_ item: ReactionRoleItem) async throws -> ReactionRoleItem {
        try await client.patchWithResponse("reaction_roles", body: item, where: "id", equals: item.id)
    }

    func delete(id: String) async throws {
        try await client.delete("reaction_roles", where: "id", equals: id)
    }
}
