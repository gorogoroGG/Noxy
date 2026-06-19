protocol DisasterRecoveryServiceProtocol: Sendable {
    func fetchDeletedGuilds() async throws -> [DeletedGuild]
    func fetchEligibleUsers(sourceGuildId: String) async throws -> [RecoveryEligibleUser]
    func fetchMemberCounts(guildIds: [String]) async throws -> [String: Int]
    func checkMembership(destGuildId: String, userIds: [String]) async throws -> [String]
    func executeRecovery(sourceGuildId: String, destinationGuildId: String, selectedUserIds: [String]) async throws -> RecoveryJob
    func fetchJobs(sourceGuildId: String) async throws -> [RecoveryJob]
    func fetchJobDetail(jobId: String) async throws -> RecoveryJobDetail
}
