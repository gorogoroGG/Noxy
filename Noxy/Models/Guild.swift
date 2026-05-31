import Foundation

enum GuildRole: String, Codable {
    case owner, admin, moderator
}

enum GuildCategory: String, Codable, CaseIterable {
    case gaming, vtuber, support, shop, community
}

struct Guild: Identifiable, Codable, Hashable {
    let id: String
    let discordId: String
    let name: String
    let iconUrl: String?
    let memberCount: Int
    let userRole: GuildRole
    let category: GuildCategory
}
