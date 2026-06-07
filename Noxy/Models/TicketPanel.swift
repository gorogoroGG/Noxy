import Foundation

struct TicketPanel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var guildId: String
    var channelId: String
    var messageId: String?
    var title: String
    var description: String
    var color: Int          // パネルEmbedの左カラーバー色
    var buttonColor: Int    // ボタンの背景色
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

    enum CodingKeys: String, CodingKey {
        case id, guildId, channelId, messageId, title, description, color
        case buttonColor
        case buttonLabel, buttonEmoji
        case supportRoleId, openCategoryId, closedCategoryId
        case ticketMsgContent, ticketEmbedTitle, ticketEmbedColor
        case maxOpenPerUser, createdAt
    }

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
            buttonColor: 0x6366f1,
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

extension TicketPanel {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self, forKey: .id)
        guildId          = try c.decode(String.self, forKey: .guildId)
        channelId        = try c.decode(String.self, forKey: .channelId)
        messageId        = try c.decodeIfPresent(String.self, forKey: .messageId)
        title            = try c.decode(String.self, forKey: .title)
        description      = try c.decode(String.self, forKey: .description)
        color            = try c.decode(Int.self, forKey: .color)
        buttonColor      = try c.decodeIfPresent(Int.self, forKey: .buttonColor) ?? color
        buttonLabel      = try c.decode(String.self, forKey: .buttonLabel)
        buttonEmoji      = try c.decode(String.self, forKey: .buttonEmoji)
        supportRoleId    = try c.decodeIfPresent(String.self, forKey: .supportRoleId)
        openCategoryId   = try c.decodeIfPresent(String.self, forKey: .openCategoryId)
        closedCategoryId = try c.decodeIfPresent(String.self, forKey: .closedCategoryId)
        ticketMsgContent = try c.decodeIfPresent(String.self, forKey: .ticketMsgContent)
        ticketEmbedTitle = try c.decode(String.self, forKey: .ticketEmbedTitle)
        ticketEmbedColor = try c.decode(Int.self, forKey: .ticketEmbedColor)
        maxOpenPerUser   = try c.decode(Int.self, forKey: .maxOpenPerUser)
        createdAt        = try c.decode(Date.self, forKey: .createdAt)
    }
}
