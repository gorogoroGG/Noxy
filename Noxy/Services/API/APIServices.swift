import Foundation

// ============================================================
// MARK: - Guild Service
// ============================================================

struct APIGuildService: GuildServiceProtocol {
    private let client = APIClient()

    func fetchAll() async throws -> [Guild] {
        try await client.get("/api/v1/guilds")
    }
    func fetch(id: String) async throws -> Guild {
        try await client.get("/api/v1/guilds/\(id)")
    }
    func fetchChannels(guildId: String) async throws -> [Channel] {
        try await client.get("/api/v1/guilds/\(guildId)/channels")
    }
    func fetchBotGuildIds() async throws -> Set<String> {
        let guilds: [Guild] = try await fetchAll()
        return Set(guilds.map(\.id))
    }
}

// ============================================================
// MARK: - Ticket Service
// ============================================================

struct APITicketService: TicketServiceProtocol {
    private let client = APIClient()

    func fetchAll(guildId: String) async throws -> [Ticket] {
        try await client.get("/api/v1/tickets?guildId=\(guildId)")
    }
    func create(guildId: String, subject: String) async throws -> Ticket {
        struct Body: Encodable { let guildId: String; let subject: String }
        return try await client.post("/api/v1/tickets/create", body: Body(guildId: guildId, subject: subject))
    }
    func fetch(id: String) async throws -> Ticket {
        try await client.get("/api/v1/tickets/\(id)")
    }
    func close(id: String) async throws {
        try await client.post("/api/v1/tickets/\(id)/close")
    }
    func reopen(id: String) async throws {
        try await client.post("/api/v1/tickets/\(id)/reopen")
    }
    func updatePriority(id: String, priority: TicketPriority) async throws {
        struct Body: Encodable { let priority: String }
        try await client.postBody("/api/v1/tickets/\(id)/priority", body: Body(priority: priority.rawValue))
    }
    func fetchMessages(ticketId: String) async throws -> [TicketMessage] {
        try await client.get("/api/v1/tickets/\(ticketId)/messages")
    }
    func reply(ticketId: String, message: String) async throws {
        struct Body: Encodable { let content: String }
        try await client.postBody("/api/v1/tickets/\(ticketId)/reply", body: Body(content: message))
    }
    func assign(ticketId: String, userId: String) async throws {
        struct Body: Encodable { let userId: String }
        try await client.postBody("/api/v1/tickets/\(ticketId)/assign", body: Body(userId: userId))
    }
    func fetchPanels(guildId: String) async throws -> [TicketPanel] { [] }
    func createPanel(_ panel: TicketPanel) async throws -> TicketPanel { panel }
    func updatePanel(_ panel: TicketPanel) async throws -> TicketPanel { panel }
    func deletePanel(id: String) async throws {}
    func deployPanel(id: String, channelId: String) async throws -> TicketPanel { throw ServiceError.networkError }
    func setStatus(id: String, status: TicketStatus) async throws {}
}

// ============================================================
// MARK: - Member Service
// NOTE: 本番では DiscordMemberService を使用（Worker API 実装済み）
// ============================================================

struct APIMemberService: MemberServiceProtocol {
    private let client = APIClient()

    func fetchMembers(guildId: String) async throws -> [Member] {
        try await client.get("/api/v1/members?guildId=\(guildId)")
    }
    func kick(memberId: String, guildId: String, reason: String?) async throws {
        throw ServiceError.networkError // Worker API は DiscordMemberService で実装済み
    }
    func ban(memberId: String, guildId: String, reason: String?) async throws {
        throw ServiceError.networkError
    }
    func timeout(memberId: String, guildId: String, until: Date) async throws {
        throw ServiceError.networkError
    }
    func sendDM(memberId: String, message: String) async throws {
        throw ServiceError.networkError
    }
    func addRole(memberId: String, guildId: String, roleId: String) async throws {
        throw ServiceError.networkError
    }
    func removeRole(memberId: String, guildId: String, roleId: String) async throws {
        throw ServiceError.networkError
    }
}

// ============================================================
// MARK: - Embed Service
// ============================================================

struct APIEmbedService: EmbedServiceProtocol {
    private let client = APIClient()

    func fetchAll() async throws -> [EmbedModel] {
        try await client.get("/api/v1/embeds")
    }
    func fetch(id: String) async throws -> EmbedModel {
        try await client.get("/api/v1/embeds/\(id)")
    }
    func create(_ embed: EmbedModel) async throws -> EmbedModel {
        try await client.post("/api/v1/embeds", body: EmbedRequest(embed))
    }
    func update(_ embed: EmbedModel) async throws -> EmbedModel {
        try await client.put("/api/v1/embeds/\(embed.id)", body: EmbedRequest(embed))
    }
    func delete(id: String) async throws {
        try await client.delete("/api/v1/embeds/\(id)")
    }
    func send(embedId: String, guildId: String, channelId: String) async throws {
        struct SendBody: Encodable { let guildId: String; let channelId: String }
        try await client.postBody("/api/v1/embeds/\(embedId)/send", body: SendBody(guildId: guildId, channelId: channelId))
    }
}

private struct EmbedRequest: Encodable {
    let name: String
    let messageContent: String?
    let title: String?
    let embedUrl: String?
    let description: String?
    let colorHex: UInt32
    let fields: [FieldRequest]
    let imageUrl: String?
    let thumbnailUrl: String?
    let footerText: String?
    let footerIconUrl: String?
    let showTimestamp: Bool

    struct FieldRequest: Encodable {
        let name: String; let value: String; let inline: Bool
    }

    init(_ e: EmbedModel) {
        name           = e.name
        messageContent = e.messageContent
        title          = e.title
        embedUrl      = e.embedUrl
        description   = e.description
        colorHex      = e.colorHex
        fields        = e.fields.map { FieldRequest(name: $0.name, value: $0.value, inline: $0.inline) }
        imageUrl      = e.imageUrl
        thumbnailUrl  = e.thumbnailUrl
        footerText    = e.footerText
        footerIconUrl = e.footerIconUrl
        showTimestamp = e.showTimestamp
    }
}

// ============================================================
// MARK: - Auto Response Service
// ============================================================

struct APIAutoResponseService: AutoResponseServiceProtocol {
    private let client = APIClient()

    func fetchAll(guildId: String) async throws -> [AutoResponse] {
        try await client.get("/api/v1/auto-responses?guildId=\(guildId)")
    }
    func create(_ item: AutoResponse) async throws -> AutoResponse {
        try await client.post("/api/v1/auto-responses", body: AutoResponseRequest(item))
    }
    func update(_ item: AutoResponse) async throws -> AutoResponse {
        try await client.post("/api/v1/auto-responses/\(item.id)", body: AutoResponseRequest(item))
    }
    func delete(id: String) async throws {
        try await client.post("/api/v1/auto-responses/\(id)/delete")
    }
    func toggle(id: String, enabled: Bool) async throws {
        struct ToggleBody: Encodable { let enabled: Bool }
        try await client.postBody("/api/v1/auto-responses/\(id)/toggle", body: ToggleBody(enabled: enabled))
    }
}

private struct AutoResponseRequest: Encodable {
    let guildId: String
    let trigger: String
    let response: String
    let matchType: String
    let enabled: Bool
    let cooldownSeconds: Int
    let channelIds: [String]

    init(_ ar: AutoResponse) {
        guildId         = ar.guildId
        trigger         = ar.trigger
        response        = ar.response
        matchType       = ar.matchType.rawValue
        enabled         = ar.enabled
        cooldownSeconds = ar.cooldownSeconds
        channelIds      = ar.channelIds
    }
}

// ============================================================
// ============================================================
// MARK: - Audit Log Service
// ============================================================

struct APIAuditLogService: AuditLogServiceProtocol {
    private let client = APIClient()

    func fetch(guildId: String, page: Int) async throws -> [AuditLog] {
        try await client.get("/api/v1/audit-logs?guildId=\(guildId)&page=\(page)")
    }
}

// ============================================================
// MARK: - Notification Service
// ============================================================

struct APINotificationService: NotificationServiceProtocol {
    private let client = APIClient()

    func fetchAll() async throws -> [AppNotification] {
        // guildId は AppState から取得するのが理想だが、
        // プロトコルに guildId 引数がないため UserDefaults から読む
        let guildId = UserDefaults.standard.string(forKey: "selected_guild_id") ?? ""
        if guildId.isEmpty { return [] }
        return try await client.get("/api/v1/notifications?guildId=\(guildId)")
    }
    func markRead(id: String) async throws {
        // サーバー側に既読管理なし（監査ログ由来のため常にread=true）
    }
    func markAllRead() async throws { }
}

// ============================================================
// MARK: - Analytics Service
// NOTE: 本番では WorkerAnalyticsService を使用
// ============================================================

struct APIAnalyticsService: AnalyticsServiceProtocol {
    func fetchStats(guildId: String) async throws -> AnalyticsStats {
        // 旧 REST API は削除済み。Worker 経由は WorkerAnalyticsService を使用。
        throw ServiceError.networkError
    }
}

// ============================================================
// MARK: - Bot Service
// NOTE: 本番では MockBotService（実装対象外）
// ============================================================

struct APIBotService: BotServiceProtocol {
    func fetchStatus() async throws -> BotStatus {
        throw ServiceError.networkError
    }
    func restart() async throws { }
    func fetchCommands() async throws -> [SlashCommand] { return [] }
    func toggleCommand(id: String, enabled: Bool) async throws { }
}
