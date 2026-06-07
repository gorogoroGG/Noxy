import Foundation

struct WorkerVerifyService: VerifyServiceProtocol {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    // MARK: - Panels

    func fetchPanels(guildId: String) async throws -> [VerifyPanel] {
        try await get("/bot/verify-panels?guild_id=\(guildId)")
    }
    func createPanel(_ panel: VerifyPanel) async throws -> VerifyPanel {
        struct Body: Encodable {
            let guildId, name, description, channelId, roleId: String
            let color: Int
            let footerText, buttonLabel, verifyType, reactionEmoji: String
            let manualChannelId: String?
            let enabled: Bool
        }
        return try await postReturning("/bot/verify-panels", body: Body(
            guildId: panel.guildId, name: panel.name, description: panel.description,
            channelId: panel.channelId, roleId: panel.roleId, color: panel.color,
            footerText: panel.footerText, buttonLabel: panel.buttonLabel,
            verifyType: panel.verifyType.rawValue, reactionEmoji: panel.reactionEmoji,
            manualChannelId: panel.manualChannelId, enabled: panel.enabled
        ))
    }
    func updatePanel(_ panel: VerifyPanel) async throws -> VerifyPanel {
        struct Body: Encodable {
            let name, description, channelId, roleId: String
            let color: Int
            let footerText, buttonLabel, verifyType, reactionEmoji: String
            let manualChannelId: String?
            let enabled: Bool
        }
        return try await patchReturning("/bot/verify-panels/\(panel.id)", body: Body(
            name: panel.name, description: panel.description,
            channelId: panel.channelId, roleId: panel.roleId, color: panel.color,
            footerText: panel.footerText, buttonLabel: panel.buttonLabel,
            verifyType: panel.verifyType.rawValue, reactionEmoji: panel.reactionEmoji,
            manualChannelId: panel.manualChannelId, enabled: panel.enabled
        ))
    }
    func deletePanel(id: String) async throws { try await delete("/bot/verify-panels/\(id)") }
    func deployPanel(id: String, channelId: String) async throws -> VerifyPanel {
        struct Body: Encodable { let channelId: String }
        return try await postReturning("/bot/verify-panels/\(id)/deploy", body: Body(channelId: channelId))
    }
    func resetPanel(id: String) async throws -> VerifyPanel {
        struct Empty: Encodable {}
        return try await postReturning("/bot/verify-panels/\(id)/reset", body: Empty())
    }

    // MARK: - Role Creation

    func createRole(guildId: String, name: String, color: Int,
                    channelPermissions: [ChannelPermissionInput]) async throws -> CreatedRole {
        struct Body: Encodable {
            let guildId: String
            let name: String
            let color: Int
            let channelPermissions: [ChannelPermissionInput]
        }
        return try await postReturning("/bot/roles/create", body: Body(
            guildId: guildId, name: name, color: color, channelPermissions: channelPermissions
        ))
    }

    // MARK: - Manual Requests

    func fetchRequests(guildId: String, status: VerifyRequestStatus?) async throws -> [VerifyRequest] {
        var path = "/bot/verify-requests?guild_id=\(guildId)"
        if let s = status { path += "&status=\(s.rawValue)" }
        return try await get(path)
    }
    func approveRequest(id: String) async throws -> VerifyRequest {
        struct Empty: Encodable {}
        return try await postReturning("/bot/verify-requests/\(id)/approve", body: Empty())
    }
    func denyRequest(id: String) async throws -> VerifyRequest {
        struct Empty: Encodable {}
        return try await postReturning("/bot/verify-requests/\(id)/deny", body: Empty())
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

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var req = URLRequest(url: URL(string: DiscordConfig.workerURL + path)!, timeoutInterval: 15)
        req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ServiceError.networkError }
        return try Self.decoder.decode(T.self, from: data)
    }
    private func delete(_ path: String) async throws {
        var req = URLRequest(url: URL(string: DiscordConfig.workerURL + path)!, timeoutInterval: 15)
        req.httpMethod = "DELETE"
        req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ServiceError.networkError }
    }
    private func postReturning<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        var req = URLRequest(url: URL(string: DiscordConfig.workerURL + path)!, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ServiceError.networkError }
        return try Self.decoder.decode(T.self, from: data)
    }
    private func patchReturning<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        var req = URLRequest(url: URL(string: DiscordConfig.workerURL + path)!, timeoutInterval: 15)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ServiceError.networkError }
        return try Self.decoder.decode(T.self, from: data)
    }
}
