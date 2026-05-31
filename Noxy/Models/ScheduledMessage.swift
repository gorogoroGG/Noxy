import Foundation

enum RepeatRule: String, Codable {
    case none, daily, weekly, monthly
}

enum ScheduledStatus: String, Codable {
    case pending, sent, cancelled
}

struct ScheduledMessage: Identifiable, Codable, Hashable {
    let id: String
    let guildId: String
    let channelId: String
    let embedId: String
    var title: String = ""
    var scheduledFor: Date
    var repeatRule: RepeatRule
    var status: ScheduledStatus
    var endDate: Date? = nil
}
