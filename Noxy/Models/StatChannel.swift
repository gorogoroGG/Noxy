import Foundation

// MARK: - StatType

enum StatType: String, Codable, CaseIterable, Identifiable {
    case members  = "members"
    case online   = "online"
    case boosts   = "boosts"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .members:  return "総メンバー数"
        case .online:   return "オンライン人数"
        case .boosts:   return "Boost 数"
        }
    }

    var icon: String {
        switch self {
        case .members:  return "👥"
        case .online:   return "🟢"
        case .boosts:   return "🚀"
        }
    }

    var systemImage: String {
        switch self {
        case .members:  return "person.3.fill"
        case .online:   return "circle.fill"
        case .boosts:   return "bolt.fill"
        }
    }

    var description: String {
        switch self {
        case .members:  return "サーバーの総メンバー数"
        case .online:   return "現在オンラインのメンバー数"
        case .boosts:   return "サーバーブースト数"
        }
    }

    func channelName(value: Int) -> String {
        switch self {
        case .members:  return "👥 メンバー: \(value)"
        case .online:   return "🟢 オンライン: \(value)"
        case .boosts:   return "🚀 Boost: \(value)"
        }
    }
}

// MARK: - StatChannel

struct StatChannel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let guildId: String
    let channelId: String
    let statType: StatType
    var isEnabled: Bool
    let lastValue: Int
    let lastUpdatedAt: Date?

    var displayValue: String {
        guard lastValue >= 0 else { return "—" }
        return "\(lastValue)"
    }

    var channelName: String {
        statType.channelName(value: max(lastValue, 0))
    }
}
