import Foundation

struct Member: Identifiable, Codable, Hashable {
    let id: String
    let guildId: String
    let username: String
    let displayName: String
    let discriminator: String
    let globalName: String?
    let nick: String?
    let avatarUrl: String?
    let bannerUrl: String?
    let accentColor: Int?
    let publicFlags: Int
    let isBot: Bool
    let roles: [String]
    let joinedAt: Date
    let createdAt: Date
    let isBoosting: Bool
    let boostSince: Date?
    let isDeaf: Bool
    let isMute: Bool
    let flags: Int
    let communicationDisabledUntil: Date?
    let status: MemberStatus

    /// Discord アカウント作成日（Snowflake ID から計算されたもの）
    var createdAtFormatted: String {
        createdAt.formatted(date: .long, time: .shortened)
    }

    /// 4桁のタグ付きユーザー名（例: username#1234）
    var fullUsername: String {
        if discriminator == "0" { return username }
        return "\(username)#\(discriminator)"
    }
}

enum MemberStatus: String, Codable {
    case online, idle, dnd, offline
}
