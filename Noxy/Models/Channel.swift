import Foundation

enum ChannelKind: String, Codable {
    case text, voice, announcement
}

struct Channel: Identifiable, Codable, Hashable {
    let id: String
    let guildId: String
    let name: String
    let type: ChannelKind
    let categoryName: String?
    let botCanSend: Bool
}
