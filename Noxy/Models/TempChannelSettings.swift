import Foundation

struct TempChannelSettings: Identifiable, Codable {
    var id: String
    var guildId: String
    var enabled: Bool
    var categoryId: String?
    var channelNameFormat: String
    var autoDelete: Bool
    var deleteDelayMinutes: Int
    var joinLeaveNotification: Bool
    var watchAllVcs: Bool
    var watchVcIds: [String]
    var minMembers: Int

    static func defaultSettings(guildId: String) -> TempChannelSettings {
        TempChannelSettings(
            id: UUID().uuidString,
            guildId: guildId,
            enabled: false,
            categoryId: nil,
            channelNameFormat: "💬-{vc-name}",
            autoDelete: true,
            deleteDelayMinutes: 0,
            joinLeaveNotification: true,
            watchAllVcs: true,
            watchVcIds: [],
            minMembers: 1
        )
    }
}

struct ActiveTempChannel: Identifiable, Codable {
    let id: String
    let guildId: String
    let vcChannelId: String
    let textChannelId: String
    let createdAt: Date
}
