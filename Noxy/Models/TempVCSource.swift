import Foundation

struct TempVCSource: Identifiable, Codable, Equatable {
    var id: String?
    var guildId: String
    var sourceVcId: String
    var name: String
    var categoryId: String
    var vcNameFormat: String
    var channelNameFormat: String
    var userLimit: Int
    var autoDelete: Bool
    var deleteDelayMinutes: Int
    var joinLeaveNotification: Bool
    var enabled: Bool
    var createdAt: Date?

    var effectiveId: String { id ?? UUID().uuidString }

    static func defaultSource(guildId: String) -> TempVCSource {
        TempVCSource(
            id: nil,
            guildId: guildId,
            sourceVcId: "",
            name: "",
            categoryId: "",
            vcNameFormat: "{user-name}のVC",
            channelNameFormat: "{user-name}の部屋",
            userLimit: 0,
            autoDelete: true,
            deleteDelayMinutes: 0,
            joinLeaveNotification: true,
            enabled: true,
            createdAt: nil
        )
    }
}
