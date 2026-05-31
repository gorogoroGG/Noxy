import Foundation

struct SlashCommand: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    var options: [String]
    var enabled: Bool
    var usageCount: Int
}
