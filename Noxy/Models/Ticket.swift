import Foundation

// MARK: - TicketStatus

enum TicketStatus: String, Codable {
    case open, pending, closed
}

// MARK: - TicketPriority

enum TicketPriority: String, Codable {
    case low, medium, high, urgent
}

// MARK: - Ticket

struct Ticket: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let guildId: String
    let channelId: String
    let openedBy: String
    let subject: String
    var status: TicketStatus
    var priority: TicketPriority
    var assignedToUserId: String?
    let panelId: String?   // Worker は UUID 文字列を返すため String? に統一
    let openedAt: Date
    var closedAt: Date?
    var lastMessageAt: Date
    var messageCount: Int

    nonisolated init(id: String, guildId: String, channelId: String, openedBy: String,
         subject: String, status: TicketStatus, priority: TicketPriority,
         assignedToUserId: String? = nil, panelId: String? = nil,
         openedAt: Date, closedAt: Date? = nil,
         lastMessageAt: Date, messageCount: Int) {
        self.id = id
        self.guildId = guildId
        self.channelId = channelId
        self.openedBy = openedBy
        self.subject = subject
        self.status = status
        self.priority = priority
        self.assignedToUserId = assignedToUserId
        self.panelId = panelId
        self.openedAt = openedAt
        self.closedAt = closedAt
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
    }
}

// MARK: - TicketMessage

struct TicketMessage: Identifiable, Codable {
    let id: String
    let ticketId: String
    let userId: String
    let username: String
    let content: String
    let isStaff: Bool
    let createdAt: Date
    // "app" = アプリから送信、"discord" = Discordから送信、nil = 不明
    let source: String?
}
