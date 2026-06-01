import Foundation

struct TempVCSource: Identifiable, Codable, Equatable {
    var id: String?
    var guildId: String
    var triggerVcId: String?
    var triggerVcName: String
    var vcCategoryId: String
    var textChannelCategoryId: String
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
            triggerVcId: nil,
            triggerVcName: "一時VCを作成",
            vcCategoryId: "",
            textChannelCategoryId: "",
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
