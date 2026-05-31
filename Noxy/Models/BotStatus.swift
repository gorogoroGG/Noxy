import Foundation

struct BotStatus: Codable, Hashable {
    var isOnline: Bool
    var latency: Int
    var uptime: Double
    var activeGuilds: Int
    var totalCommands: Int
}

struct AnalyticsStats: Codable, Hashable {
    let guildId: String
    let totalMembers: Int
    let memberGrowthPercent: Double
    let messagesToday: Int
    let messageGrowthPercent: Double
    let commandsUsed: Int
    let commandGrowthPercent: Double
    let activeTickets: Int
    let voiceMinutes: Int
    let memberHistory: [Int]
    let messageHistory: [Int]
}
