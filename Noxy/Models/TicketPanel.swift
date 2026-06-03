import Foundation

struct TicketPanel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var guildId: String
    var channelId: String
    var messageId: String?
    var title: String
    var description: String
    var color: Int
    var buttonLabel: String
    var buttonEmoji: String
    var supportRoleId: String?
    var openCategoryId: String?
    var closedCategoryId: String?
    var ticketMsgContent: String?
    var ticketEmbedTitle: String
    var ticketEmbedColor: Int
    var maxOpenPerUser: Int
    let createdAt: Date

    /// Discord にデプロイ済みかどうか
    var isDeployed: Bool { messageId != nil && !(messageId!.isEmpty) }

    nonisolated static func blank(guildId: String) -> TicketPanel {
        TicketPanel(
            id: UUID().uuidString,
            guildId: guildId,
            channelId: "",
            messageId: nil,
            title: "サポートチケット",
            description: "ボタンをクリックしてチケットを開きます。\nスタッフが迅速に対応します。",
            color: 0x6366f1,
            buttonLabel: "チケットを作成",
            buttonEmoji: "🎫",
            supportRoleId: nil,
            openCategoryId: nil,
            closedCategoryId: nil,
            ticketMsgContent: "{user.mention} さん、チケットを作成しました。\nスタッフが確認次第、対応いたします。\n\n**件名：**{subject}",
            ticketEmbedTitle: "チケット",
            ticketEmbedColor: 0x6366f1,
            maxOpenPerUser: 1,
            createdAt: .now
        )
    }
}
