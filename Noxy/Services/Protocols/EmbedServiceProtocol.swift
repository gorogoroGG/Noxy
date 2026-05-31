import Foundation

protocol EmbedServiceProtocol: Sendable {
    func fetchAll() async throws -> [EmbedModel]
    func fetch(id: String) async throws -> EmbedModel
    func create(_ embed: EmbedModel) async throws -> EmbedModel
    func update(_ embed: EmbedModel) async throws -> EmbedModel
    func delete(id: String) async throws
    func send(embedId: String, guildId: String, channelId: String) async throws
}
