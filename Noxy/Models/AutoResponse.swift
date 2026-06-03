import Foundation

enum MatchType: String, Codable {
    case exact, contains, regex, startsWith
}

struct AutoResponse: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let guildId: String
    var trigger: String
    var response: String
    var matchType: MatchType
    var enabled: Bool
    var cooldownSeconds: Int
    var channelIds: [String]
}
