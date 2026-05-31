import Foundation

enum TicketStatus: String, Codable {
    case open, pending, closed
}

enum TicketPriority: String, Codable {
    case low, medium, high, urgent
}

struct Ticket: Identifiable, Codable, Hashable {
    let id: String
    let guildId: String
    let channelId: String
    let openedBy: String
    let subject: String
    var status: TicketStatus
    var priority: TicketPriority
    let openedAt: Date
    var lastMessageAt: Date
    var messageCount: Int
}
