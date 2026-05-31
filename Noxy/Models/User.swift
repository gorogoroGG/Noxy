import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: String
    let discordId: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let createdAt: Date
}
