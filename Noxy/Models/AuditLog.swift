import Foundation

struct AuditLog: Identifiable, Codable, Hashable {
    let id: String
    let guildId: String
    let userId: String
    let action: String
    let target: String
    let timestamp: Date
    let details: String?
}
