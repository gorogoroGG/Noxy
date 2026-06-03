import Foundation

enum NotificationType: String, Codable {
    case mention, ticket, system, memberJoin, botStatus, scheduledSend
}

struct AppNotification: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let guildId: String?
    var read: Bool
    let timestamp: Date
}
