import Foundation

struct Member: Identifiable, Codable, Hashable {
    let id: String
    let guildId: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let roles: [String]
    let joinedAt: Date
    let isBoosting: Bool
    let status: MemberStatus
}

enum MemberStatus: String, Codable {
    case online, idle, dnd, offline
}
