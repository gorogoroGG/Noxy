import Foundation

protocol TempChannelServiceProtocol: Sendable {
    func fetchSettings(guildId: String) async throws -> TempChannelSettings
    func saveSettings(_ settings: TempChannelSettings) async throws -> TempChannelSettings
    func fetchActiveChannels(guildId: String) async throws -> [ActiveTempChannel]
}
