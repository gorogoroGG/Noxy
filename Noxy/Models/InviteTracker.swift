import Foundation

// MARK: - Period

enum InvitePeriod: String, Codable, CaseIterable, Sendable {
    case today    = "today"
    case week     = "week"
    case month    = "month"
    case allTime  = "all_time"

    var label: String {
        switch self {
        case .today:   return "今日"
        case .week:    return "今週"
        case .month:   return "今月"
        case .allTime: return "全期間"
        }
    }
}

// MARK: - Leaderboard / Stats

struct InviteStats: Codable, Identifiable, Hashable, Sendable {
    let userId: String
    let guildId: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let totalInvites: Int
    let validInvites: Int      // still in server
    let leftInvites: Int       // joined then left
    let fakeInvites: Int       // suspected fake / bot
    let influenceScore: Int    // tree-weighted score
    let treeSize: Int          // total descendants
    let retentionRate: Double  // valid / (valid + left)
    let rank: Int?

    var id: String { userId }
}

// MARK: - Tree

struct InviteTreeNode: Codable, Identifiable, Sendable {
    let userId: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let isCurrentMember: Bool
    let joinedAt: Date?
    let leftAt: Date?
    let directInvites: Int
    let totalDescendants: Int
    let children: [InviteTreeNode]

    var id: String { userId }

    // OutlineGroup 用: 子なし = nil
    var childrenIfAny: [InviteTreeNode]? {
        children.isEmpty ? nil : children
    }
}

// MARK: - Member Detail

struct InviteMemberDetail: Codable, Sendable {
    let stats: InviteStats
    let recentInvitees: [InviteEventEntry]
    let invitedByUserId: String?
    let invitedByUsername: String?
    let invitedByDisplayName: String?
    let invitePathDisplayNames: [String]   // chain from root → this person
}

struct InviteEventEntry: Codable, Identifiable, Sendable {
    let userId: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let joinedAt: Date
    let leftAt: Date?
    var isCurrentMember: Bool { leftAt == nil }

    var id: String { userId }
}

// MARK: - Settings

struct InviteTrackerSettings: Codable, Sendable {
    let guildId: String
    var isEnabled: Bool
    var logChannelId: String?
    var notifyOnJoin: Bool
    var notifyOnLeave: Bool
    var fakeInviteThresholdHours: Int
    var milestones: [InviteMilestone]
}

struct InviteMilestone: Codable, Identifiable, Sendable {
    let id: String
    let guildId: String
    let count: Int
    let roleId: String
    let roleName: String
}

// MARK: - Invite Panel

struct InvitePanel: Codable, Identifiable, Sendable {
    let id: String
    let guildId: String
    let channelId: String
    let channelName: String?
    let messageId: String?
    let createdAt: Date
}

// MARK: - Personal Invite Link

struct PersonalInviteLink: Codable, Identifiable, Sendable {
    let id: String
    let guildId: String
    let userId: String
    let username: String
    let displayName: String
    let inviteCode: String
    let inviteUrl: String
    let channelId: String
    let createdAt: Date
}
