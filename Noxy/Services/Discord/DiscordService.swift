import Foundation

    // MARK: - Discord 設定

struct DiscordConfig {
    static var workerURL: String {
        "https://noxy-scheduler.watch-yugo.workers.dev"
    }
    static var userAccessToken: String {
        UserDefaults.standard.string(forKey: "discord_access_token") ?? ""
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
            Guild(
                id: g.id, discordId: g.id, name: g.name,
                iconUrl: g.iconUrl, memberCount: 0,
                userRole: g.owner == true ? .owner : .admin,
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
        let (data, _) = try await session.data(from: url)
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
        let (data, _) = try await session.data(from: url)
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
        let (data, _) = try await session.data(from: url)
        guard let inviteUrl = URL(string: String(data: data, encoding: .utf8) ?? "") else { return nil }
        return inviteUrl
    }

    /// サーバーロール一覧（Worker 経由）
    func fetchRoles(guildId: String) async throws -> [DiscordRole] {
        let url = URL(string: "\(DiscordConfig.workerURL)/bot/roles?guild_id=\(guildId)")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([DiscordRole].self, from: data)
    }

    // MARK: - 内部

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
