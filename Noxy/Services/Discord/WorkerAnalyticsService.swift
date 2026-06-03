import Foundation

// MARK: - WorkerAnalyticsService

struct WorkerAnalyticsService: AnalyticsServiceProtocol {
    private let client = WorkerClient()

    func fetchStats(guildId: String) async throws -> AnalyticsStats {
        try await client.get("/bot/analytics?guild_id=\(guildId)")
    }
}
