import Foundation

// MARK: - StatType

enum StatType: String, Codable, CaseIterable, Identifiable {
    case members  = "members"
    case online   = "online"
    case boosts   = "boosts"
    case vcUsers  = "vc_users"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .members:  return "総メンバー数"
        case .online:   return "オンライン人数"
        case .boosts:   return "Boost 数"
        case .vcUsers:  return "VC 接続中"
        }
    }

    var icon: String {
        switch self {
        case .members:  return "👥"
        case .online:   return "🟢"
        case .boosts:   return "🚀"
        case .vcUsers:  return "🎙️"
        }
    }

    var systemImage: String {
        switch self {
        case .members:  return "person.3.fill"
        case .online:   return "circle.fill"
        case .boosts:   return "bolt.fill"
        case .vcUsers:  return "waveform.and.mic"
        }
    }

    var description: String {
        switch self {
        case .members:  return "サーバーの総メンバー数"
        case .online:   return "現在オンラインのメンバー数"
        case .boosts:   return "サーバーブースト数"
        case .vcUsers:  return "VC に接続中のメンバー数"
        }
    }

    func channelName(value: Int) -> String {
        switch self {
        case .members:  return "👥 メンバー: \(value)"
        case .online:   return "🟢 オンライン: \(value)"
        case .boosts:   return "🚀 Boost: \(value)"
        case .vcUsers:  return "🎙️ VC中: \(value)人"
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
