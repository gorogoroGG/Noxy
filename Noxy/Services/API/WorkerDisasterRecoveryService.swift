import Foundation

struct WorkerDisasterRecoveryService: DisasterRecoveryServiceProtocol {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func fetchDeletedGuilds() async throws -> [DeletedGuild] {
        try await get("/bot/disaster-recovery/deleted-guilds")
    }

    func fetchEligibleUsers(sourceGuildId: String) async throws -> [RecoveryEligibleUser] {
        try await get("/bot/disaster-recovery/eligible-users?source_guild_id=\(sourceGuildId)")
    }

    func fetchMemberCounts(guildIds: [String]) async throws -> [String: Int] {
        guard !guildIds.isEmpty else { return [:] }
        let joined = guildIds.joined(separator: ",")
        return try await get("/bot/disaster-recovery/member-counts?guild_ids=\(joined)")
    }

    func checkMembership(destGuildId: String, userIds: [String]) async throws -> [String] {
        struct Body: Encodable { let destGuildId: String; let userIds: [String] }
        struct Response: Decodable { let memberIds: [String] }
        let resp: Response = try await postReturning("/bot/disaster-recovery/check-membership", body: Body(destGuildId: destGuildId, userIds: userIds))
        return resp.memberIds
    }

    func executeRecovery(sourceGuildId: String, destinationGuildId: String, selectedUserIds: [String]) async throws -> RecoveryJob {
        struct Body: Encodable {
            let sourceGuildId: String
            let destinationGuildId: String
            let selectedUserIds: [String]
        }
        return try await postReturning("/bot/disaster-recovery/execute", body: Body(
            sourceGuildId: sourceGuildId, destinationGuildId: destinationGuildId, selectedUserIds: selectedUserIds
        ))
    }

    func fetchJobs(sourceGuildId: String) async throws -> [RecoveryJob] {
        try await get("/bot/disaster-recovery/jobs?source_guild_id=\(sourceGuildId)")
    }

    func fetchJobDetail(jobId: String) async throws -> RecoveryJobDetail {
        try await get("/bot/disaster-recovery/jobs/\(jobId)")
    }

    // MARK: - Internals

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
            f.formatOptions = [.withInternetDateTime]
            if let d = f.date(from: s) { return d }
            return Date()
        }
        return d
    }()

    private func authHeader() -> String? {
        WorkerClient.bearerToken().map { "Bearer \($0)" }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var req = URLRequest(url: URL(string: DiscordConfig.workerURL + path)!, timeoutInterval: 15)
        if let auth = authHeader() { req.setValue(auth, forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ServiceError.networkError }
        return try Self.decoder.decode(T.self, from: data)
    }

    private func postReturning<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        var req = URLRequest(url: URL(string: DiscordConfig.workerURL + path)!, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let auth = authHeader() { req.setValue(auth, forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ServiceError.networkError }
        return try Self.decoder.decode(T.self, from: data)
    }
}
