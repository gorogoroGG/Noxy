import Foundation

// MARK: - DeletedGuild

struct DeletedGuild: Identifiable, Codable, Hashable, Sendable {
    let guildId: String
    let ownerId: String?
    let guildName: String
    let deletedAt: Date
    let notified: Bool

    var id: String { guildId }
}

// MARK: - RecoveryEligibleUser

struct RecoveryEligibleUser: Identifiable, Codable, Hashable, Sendable {
    let guildId: String
    let userId: String
    let username: String
    let avatarUrl: String?
    let authorizedAt: Date

    var id: String { userId }
}

// MARK: - RecoveryJob

enum RecoveryJobStatus: String, Codable {
    case running = "running"
    case completed = "completed"
    case failed = "failed"

    var label: String {
        switch self {
        case .running: "実行中"
        case .completed: "完了"
        case .failed: "失敗"
        }
    }

    var colorName: String {
        switch self {
        case .running: "accent"
        case .completed: "statusOK"
        case .failed: "statusBad"
        }
    }
}

struct RecoveryJob: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let sourceGuildId: String
    let destinationGuildId: String
    let status: RecoveryJobStatus
    let totalCount: Int
    let successCount: Int
    let failCount: Int
    let createdAt: Date
    let completedAt: Date?
}

struct RecoveryJobResult: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let userId: String
    let username: String
    let status: String
    let errorMessage: String?
    let attemptedAt: Date
}

struct RecoveryJobDetail: Codable, Sendable {
    let id: String
    let sourceGuildId: String
    let destinationGuildId: String
    let status: RecoveryJobStatus
    let totalCount: Int
    let successCount: Int
    let failCount: Int
    let createdAt: Date
    let completedAt: Date?
    let results: [RecoveryJobResult]
}
