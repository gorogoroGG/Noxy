import Foundation

protocol GuildServiceProtocol: Sendable {
    func fetchAll() async throws -> [Guild]
    func fetch(id: String) async throws -> Guild
    func fetchChannels(guildId: String) async throws -> [Channel]
}
