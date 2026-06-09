import Foundation

    // MARK: - Discord 設定

struct DiscordConfig {
    nonisolated static var workerURL: String {
        "https://noxy-scheduler.watch-yugo.workers.dev"
    }
    /// Worker API 認証シークレット (#1)
    /// wrangler secret put WORKER_API_SECRET で設定した値と一致させる
    nonisolated static var workerAPISecret: String {
        // Keychain に保存されていればそちらを優先。未設定時は空文字（ヘッダー送信しない）
        KeychainHelper.load(forKey: "worker_api_secret") ?? ""
    }
    nonisolated static var userAccessToken: String {
        KeychainHelper.load(forKey: "discord_access_token") ?? ""
    }

    /// Worker への認証付きリクエストを生成する（ビュー層からも使用可）
    static func makeWorkerRequest(url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        if !workerAPISecret.isEmpty {
            req.setValue(workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        }
        return req
    }
}

// MARK: - Discord API モデル

struct DiscordGuild: Decodable {
    let id: String
    let name: String
    let icon: String?
    let owner: Bool?
    let permissions: String?

    var iconUrl: String? {
        guard let icon else { return nil }
        return "https://cdn.discordapp.com/icons/\(id)/\(icon).png"
    }
}

private struct DiscordChannel: Decodable {
    let id: String
    let name: String
    let type: Int
    let parentId: String?
}

struct DiscordRole: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var color: Int
    var position: Int
    let managed: Bool
    var permissions: String
    var mentionable: Bool

    // デフォルト値付きイニシャライザ（既存コードとの互換性維持）
    init(id: String, name: String, color: Int, position: Int, managed: Bool,
         permissions: String = "0", mentionable: Bool = false) {
        self.id = id; self.name = name; self.color = color
        self.position = position; self.managed = managed
        self.permissions = permissions; self.mentionable = mentionable
    }
}

// MARK: - DiscordService

struct DiscordService: GuildServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - GuildServiceProtocol

    func fetchAll() async throws -> [Guild] {
        let discordGuilds: [DiscordGuild] = try await discordRequest(
            path: "/users/@me/guilds",
            token: DiscordConfig.userAccessToken
        )
        return discordGuilds.map { g in
            let isOwner = g.owner == true
            let hasAdmin = isOwner || (Int64(g.permissions ?? "0") ?? 0) & (1 << 3) != 0
            let role: GuildRole
            if isOwner { role = .owner }
            else if hasAdmin { role = .admin }
            else { role = .moderator }
            return Guild(
                id: g.id, discordId: g.id, name: g.name,
                iconUrl: g.iconUrl, memberCount: 0,
                userRole: role,
                category: .community
            )
        }
    }

    func fetch(id: String) async throws -> Guild {
        let guilds = try await fetchAll()
        guard let guild = guilds.first(where: { $0.id == id }) else {
            throw ServiceError.notFound
        }
        return guild
    }

    func fetchChannels(guildId: String) async throws -> [Channel] {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)")!
        let (data, _) = try await session.data(for: workerRequest(url: url))
        let channels: [DiscordChannel] = try JSONDecoder().decode([DiscordChannel].self, from: data)
        return channels.compactMap { ch in
            let kind: ChannelKind?
            switch ch.type {
            case 0: kind = .text
            case 2: kind = .voice
            case 5: kind = .announcement
            default: kind = nil
            }
            guard let kind else { return nil }
            return Channel(
                id: ch.id, guildId: guildId, name: ch.name,
                type: kind, categoryName: nil,
                botCanSend: ch.type == 0 || ch.type == 5
            )
        }
    }

    // MARK: - Bot API（Worker 経由）

    func fetchBotGuilds() async throws -> [Guild] {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/guilds")!
        let (data, _) = try await session.data(for: workerRequest(url: url))
        let dgs = try JSONDecoder().decode([DiscordGuild].self, from: data)
        return dgs.map { g in
            Guild(id: g.id, discordId: g.id, name: g.name,
                  iconUrl: g.iconUrl, memberCount: 0,
                  userRole: .owner, category: .community)
        }
    }

    func fetchBotGuildIds() async throws -> Set<String> {
        let guilds: [Guild] = try await fetchBotGuilds()
        return Set(guilds.map(\.id))
    }

    func inviteURL(guildId: String) async throws -> URL? {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/invite-url?guild_id=\(guildId)")!
        let (data, _) = try await session.data(for: workerRequest(url: url))
        guard let inviteUrl = URL(string: String(data: data, encoding: .utf8) ?? "") else { return nil }
        return inviteUrl
    }

    /// 汎用 Bot 招待 URL（guild_id 指定なし）
    func generalInviteURL() async throws -> URL? {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/invite-url")!
        let (data, response) = try await session.data(for: workerRequest(url: url))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        return URL(string: String(data: data, encoding: .utf8) ?? "")
    }

    /// サーバーロール一覧（Worker 経由）
    func fetchRoles(guildId: String) async throws -> [DiscordRole] {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/roles?guild_id=\(guildId)")!
        let (data, _) = try await session.data(for: workerRequest(url: url))
        return try JSONDecoder().decode([DiscordRole].self, from: data)
    }

    /// ロール並び順を Discord に保存（Worker 経由）
    func reorderRoles(guildId: String, positions: [(id: String, position: Int)]) async throws {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/roles/reorder")!
        var req = workerRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "guildId": guildId,
            "positions": positions.map { ["id": $0.id, "position": $0.position] }
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - 内部

    /// Worker リクエストに認証ヘッダーを付与 (#1)
    private func workerRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: 15)
        if !DiscordConfig.workerAPISecret.isEmpty {
            req.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        }
        return req
    }

    private func discordRequest<T: Decodable>(path: String, token: String) async throws -> T {
        let url = URL(string: "https://discord.com/api/v10\(path)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: msg)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
