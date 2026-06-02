import SwiftUI

// MARK: - BannedUser

struct BannedUser: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let reason: String?
    let bannedAt: Date?
}

// MARK: - TimedOutMember

struct TimedOutMember: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let timeoutUntil: Date
    let reason: String?
    let mutedByName: String

    var remaining: TimeInterval { max(0, timeoutUntil.timeIntervalSinceNow) }
    var isExpired: Bool { remaining <= 0 }

    var remainingLabel: String {
        let s = Int(remaining)
        if s <= 0     { return "終了" }
        if s < 3600   { return "\(s / 60)分\(s % 60)秒" }
        if s < 86400  { return "\(s / 3600)時間\((s % 3600) / 60)分" }
        return "\(s / 86400)日\((s % 86400) / 3600)時間"
    }

    var severityColor: Color {
        if remaining > 86400 { return Color(uiColor: UIColor(hex: 0xEF4444)) }
        if remaining > 3600  { return .accentOrange }
        return .accentGreen
    }
}

// MARK: - ModWarning

struct ModWarning: Identifiable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let reason: String
    let staffName: String
    let createdAt: Date
    var isRevoked: Bool
}

// MARK: - Escalation Rule

struct EscalationRule: Identifiable {
    let id = UUID()
    let threshold: Int
    let action: EscalationAction
    let label: String

    enum EscalationAction {
        case timeout(hours: Int), ban
        var icon: String {
            switch self { case .timeout: "timer"; case .ban: "hand.raised.slash.fill" }
        }
        var color: Color {
            switch self { case .timeout: .accentOrange; case .ban: Color(uiColor: UIColor(hex: 0xEF4444)) }
        }
    }

    static let defaults: [EscalationRule] = [
        EscalationRule(threshold: 3, action: .timeout(hours: 1),  label: "3回目 → 1時間タイムアウト"),
        EscalationRule(threshold: 5, action: .timeout(hours: 24), label: "5回目 → 24時間タイムアウト"),
        EscalationRule(threshold: 7, action: .ban,                label: "7回目 → BAN"),
    ]
}

// MARK: - ModerationAction (recent history)

struct ModerationLogEntry: Identifiable {
    let id: String
    let type: ActionType
    let targetName: String
    let staffName: String
    let reason: String?
    let timestamp: Date

    enum ActionType {
        case ban, kick, timeout, unban, warn, untimeout

        var icon: String {
            switch self {
            case .ban:       "hand.raised.slash.fill"
            case .kick:      "person.fill.xmark"
            case .timeout:   "timer"
            case .unban:     "checkmark.circle.fill"
            case .warn:      "exclamationmark.triangle.fill"
            case .untimeout: "timer.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .ban:       Color(uiColor: UIColor(hex: 0xEF4444))
            case .kick:      .accentOrange
            case .timeout:   .accentPurple
            case .unban:     .accentGreen
            case .warn:      .accentOrange
            case .untimeout: .accentGreen
            }
        }
        var label: String {
            switch self {
            case .ban:       "BAN"
            case .kick:      "キック"
            case .timeout:   "タイムアウト"
            case .unban:     "アンBAN"
            case .warn:      "警告"
            case .untimeout: "タイムアウト解除"
            }
        }
    }
}

// MARK: - Mock Data

extension BannedUser {
    static let mock: [BannedUser] = [
        BannedUser(id: "u001", username: "toxic_gamer99", displayName: "ToxicGamer",
                   reason: "暴言・ハラスメント", bannedAt: .now.addingTimeInterval(-604_800)),
        BannedUser(id: "u002", username: "spam_bot_2024", displayName: "SpamBot",
                   reason: "スパム・宣伝", bannedAt: .now.addingTimeInterval(-2_592_000)),
        BannedUser(id: "u003", username: "rule_breaker", displayName: "RuleBreaker",
                   reason: "規約違反を繰り返したため", bannedAt: .now.addingTimeInterval(-86_400)),
        BannedUser(id: "u004", username: "troll_king", displayName: "TrollKing",
                   reason: "荒らし行為", bannedAt: .now.addingTimeInterval(-1_209_600)),
    ]
}

extension TimedOutMember {
    static let mock: [TimedOutMember] = [
        TimedOutMember(id: "m010", username: "shadow_x",     displayName: "ShadowX",
                       timeoutUntil: .now.addingTimeInterval(3_900),   reason: "スパム",   mutedByName: "Admin"),
        TimedOutMember(id: "m002", username: "valorant_pro", displayName: "ProPlayer99",
                       timeoutUntil: .now.addingTimeInterval(82_000),  reason: "暴言",     mutedByName: "Mod"),
        TimedOutMember(id: "m009", username: "rika_chan",     displayName: "リカちゃん",
                       timeoutUntil: .now.addingTimeInterval(172_800), reason: "荒らし",   mutedByName: "Admin"),
    ]
}

extension ModWarning {
    static let mock: [ModWarning] = [
        ModWarning(id: "w1",  userId: "m010", username: "shadow_x",     displayName: "ShadowX",
                   reason: "スパム連投", staffName: "Admin",
                   createdAt: .now.addingTimeInterval(-7_200), isRevoked: false),
        ModWarning(id: "w2",  userId: "m010", username: "shadow_x",     displayName: "ShadowX",
                   reason: "暴言", staffName: "Mod",
                   createdAt: .now.addingTimeInterval(-3_600), isRevoked: false),
        ModWarning(id: "w3",  userId: "m010", username: "shadow_x",     displayName: "ShadowX",
                   reason: "他メンバーへの嫌がらせ", staffName: "Admin",
                   createdAt: .now.addingTimeInterval(-1_800), isRevoked: false),
        ModWarning(id: "w4",  userId: "m002", username: "valorant_pro", displayName: "ProPlayer99",
                   reason: "試合中の暴言", staffName: "Mod",
                   createdAt: .now.addingTimeInterval(-86_400), isRevoked: false),
        ModWarning(id: "w5",  userId: "m002", username: "valorant_pro", displayName: "ProPlayer99",
                   reason: "規約違反（差別的発言）", staffName: "Admin",
                   createdAt: .now.addingTimeInterval(-43_200), isRevoked: false),
        ModWarning(id: "w6",  userId: "m006", username: "yuki_gamer",   displayName: "雪ゲーマー",
                   reason: "スパム", staffName: "Mod",
                   createdAt: .now.addingTimeInterval(-172_800), isRevoked: true),
        ModWarning(id: "w7",  userId: "m009", username: "rika_chan",     displayName: "リカちゃん",
                   reason: "荒らし", staffName: "Admin",
                   createdAt: .now.addingTimeInterval(-259_200), isRevoked: false),
    ]
}

extension ModerationLogEntry {
    static let mock: [ModerationLogEntry] = [
        ModerationLogEntry(id: "l1", type: .warn,      targetName: "ShadowX",     staffName: "Admin", reason: "スパム連投",         timestamp: .now.addingTimeInterval(-1_800)),
        ModerationLogEntry(id: "l2", type: .timeout,   targetName: "ProPlayer99", staffName: "Mod",   reason: "暴言",              timestamp: .now.addingTimeInterval(-3_600)),
        ModerationLogEntry(id: "l3", type: .ban,       targetName: "RuleBreaker", staffName: "Admin", reason: "規約違反を繰り返した", timestamp: .now.addingTimeInterval(-86_400)),
        ModerationLogEntry(id: "l4", type: .unban,     targetName: "OldUser",     staffName: "Admin", reason: nil,                 timestamp: .now.addingTimeInterval(-172_800)),
        ModerationLogEntry(id: "l5", type: .kick,      targetName: "NoobSpam",    staffName: "Mod",   reason: "招待スパム",         timestamp: .now.addingTimeInterval(-259_200)),
        ModerationLogEntry(id: "l6", type: .untimeout, targetName: "雪ゲーマー",   staffName: "Admin", reason: nil,                 timestamp: .now.addingTimeInterval(-345_600)),
    ]
}
