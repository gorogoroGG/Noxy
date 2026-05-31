import Foundation

enum ServiceError: LocalizedError {
    case networkError
    case notFound
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .networkError:   "Network connection failed"
        case .notFound:       "Resource not found"
        case .unauthorized:   "Not authorized"
        }
    }
}

private func mockDelay() async throws {
    try await Task.sleep(for: .milliseconds(.random(in: 200...600)))
}

// MARK: - Embed

actor MockEmbedService: EmbedServiceProtocol {
    private var embeds: [EmbedModel] = []
    private let storageURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = docs.appendingPathComponent("embeds.json")
        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([EmbedModel].self, from: data) {
            embeds = saved
        } else {
            embeds = MockData.embeds
        }
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(embeds) else { return }
        try? data.write(to: storageURL)
    }

    func fetchAll() async throws -> [EmbedModel] {
        try await mockDelay()
        return embeds
    }

    func fetch(id: String) async throws -> EmbedModel {
        try await mockDelay()
        guard let embed = embeds.first(where: { $0.id == id }) else { throw ServiceError.notFound }
        return embed
    }

    func create(_ embed: EmbedModel) async throws -> EmbedModel {
        try await mockDelay()
        embeds.append(embed)
        saveToDisk()
        return embed
    }

    func update(_ embed: EmbedModel) async throws -> EmbedModel {
        try await mockDelay()
        guard let idx = embeds.firstIndex(where: { $0.id == embed.id }) else { throw ServiceError.notFound }
        embeds[idx] = embed
        saveToDisk()
        return embed
    }

    func delete(id: String) async throws {
        try await mockDelay()
        embeds.removeAll { $0.id == id }
        saveToDisk()
    }

    func send(embedId: String, guildId: String, channelId: String) async throws {
        try await mockDelay()
    }
}

// MARK: - Guild

actor MockGuildService: GuildServiceProtocol {
    private let guilds = MockData.guilds
    private let channels = MockData.channels

    func fetchAll() async throws -> [Guild] {
        try await mockDelay()
        return guilds
    }

    func fetch(id: String) async throws -> Guild {
        try await mockDelay()
        guard let guild = guilds.first(where: { $0.id == id }) else { throw ServiceError.notFound }
        return guild
    }

    func fetchChannels(guildId: String) async throws -> [Channel] {
        try await mockDelay()
        return channels.filter { $0.guildId == guildId }
    }
}

// MARK: - Member

actor MockMemberService: MemberServiceProtocol {
    private var members = MockData.members

    func fetchMembers(guildId: String) async throws -> [Member] {
        try await mockDelay()
        return members.filter { $0.guildId == guildId }
    }

    func kick(memberId: String, guildId: String, reason: String?) async throws {
        try await mockDelay()
        members.removeAll { $0.id == memberId && $0.guildId == guildId }
    }

    func ban(memberId: String, guildId: String, reason: String?) async throws {
        try await mockDelay()
        members.removeAll { $0.id == memberId && $0.guildId == guildId }
    }

    func addRole(memberId: String, guildId: String, roleId: String) async throws {
        try await mockDelay()
        guard let idx = members.firstIndex(where: { $0.id == memberId }) else { return }
        var updated = members[idx]
        if !updated.roles.contains(roleId) {
            let newRoles = updated.roles + [roleId]
            updated = Member(id: updated.id, guildId: updated.guildId, username: updated.username,
                             displayName: updated.displayName, avatarUrl: updated.avatarUrl,
                             roles: newRoles, joinedAt: updated.joinedAt,
                             isBoosting: updated.isBoosting, status: updated.status)
            members[idx] = updated
        }
    }

    func removeRole(memberId: String, guildId: String, roleId: String) async throws {
        try await mockDelay()
        guard let idx = members.firstIndex(where: { $0.id == memberId }) else { return }
        var updated = members[idx]
        let newRoles = updated.roles.filter { $0 != roleId }
        updated = Member(id: updated.id, guildId: updated.guildId, username: updated.username,
                         displayName: updated.displayName, avatarUrl: updated.avatarUrl,
                         roles: newRoles, joinedAt: updated.joinedAt,
                         isBoosting: updated.isBoosting, status: updated.status)
        members[idx] = updated
    }
}

// MARK: - Ticket

actor MockTicketService: TicketServiceProtocol {
    private var tickets = MockData.tickets

    func fetchAll(guildId: String) async throws -> [Ticket] {
        try await mockDelay()
        return tickets.filter { $0.guildId == guildId }
    }

    func fetch(id: String) async throws -> Ticket {
        try await mockDelay()
        guard let ticket = tickets.first(where: { $0.id == id }) else { throw ServiceError.notFound }
        return ticket
    }

    func close(id: String) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        var t = tickets[idx]; t.status = .closed; tickets[idx] = t
    }

    func reopen(id: String) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        var t = tickets[idx]; t.status = .open; tickets[idx] = t
    }

    func updatePriority(id: String, priority: TicketPriority) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        var t = tickets[idx]; t.priority = priority; tickets[idx] = t
    }

    func reply(ticketId: String, message: String) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        var t = tickets[idx]
        t.messageCount += 1
        t.lastMessageAt = .now
        tickets[idx] = t
    }
}

// MARK: - AutoResponse

actor MockAutoResponseService: AutoResponseServiceProtocol {
    private var items = MockData.autoResponses

    func fetchAll(guildId: String) async throws -> [AutoResponse] {
        try await mockDelay()
        return items.filter { $0.guildId == guildId }
    }

    func create(_ item: AutoResponse) async throws -> AutoResponse {
        try await mockDelay()
        items.append(item)
        return item
    }

    func update(_ item: AutoResponse) async throws -> AutoResponse {
        try await mockDelay()
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { throw ServiceError.notFound }
        items[idx] = item
        return item
    }

    func delete(id: String) async throws {
        try await mockDelay()
        items.removeAll { $0.id == id }
    }

    func toggle(id: String, enabled: Bool) async throws {
        try await mockDelay()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].enabled = enabled
    }
}

// MARK: - ScheduledMessage

actor MockScheduledMessageService: ScheduledMessageServiceProtocol {
    private var messages: [ScheduledMessage] = []
    private let storageURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = docs.appendingPathComponent("scheduled_messages.json")
        // ローカル保存があれば読込、なければ MockData で初期化
        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([ScheduledMessage].self, from: data) {
            messages = saved
        } else {
            messages = MockData.scheduledMessages
        }
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: storageURL)
    }

    func fetchAll() async throws -> [ScheduledMessage] {
        try await mockDelay()
        return messages
    }

    func create(_ message: ScheduledMessage) async throws -> ScheduledMessage {
        try await mockDelay()
        messages.append(message)
        saveToDisk()
        return message
    }

    func update(_ message: ScheduledMessage) async throws -> ScheduledMessage {
        try await mockDelay()
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { throw ServiceError.notFound }
        messages[idx] = message
        saveToDisk()
        return message
    }

    func cancel(id: String) async throws {
        try await mockDelay()
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].status = .cancelled
        saveToDisk()
    }
}

// MARK: - AuditLog

struct MockAuditLogService: AuditLogServiceProtocol {
    private let pageSize = 20

    func fetch(guildId: String, page: Int) async throws -> [AuditLog] {
        try await mockDelay()
        let all = MockData.auditLogs.filter { $0.guildId == guildId }
        let start = page * pageSize
        guard start < all.count else { return [] }
        return Array(all[start..<min(start + pageSize, all.count)])
    }
}

// MARK: - Notification

actor MockNotificationService: NotificationServiceProtocol {
    private var notifications = MockData.notifications

    func fetchAll() async throws -> [AppNotification] {
        try await mockDelay()
        return notifications
    }

    func markRead(id: String) async throws {
        try await mockDelay()
        guard let idx = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[idx].read = true
    }

    func markAllRead() async throws {
        try await mockDelay()
        for idx in notifications.indices {
            notifications[idx].read = true
        }
    }
}

// MARK: - Analytics

struct MockAnalyticsService: AnalyticsServiceProtocol {
    func fetchStats(guildId: String) async throws -> AnalyticsStats {
        try await mockDelay()
        return MockData.analyticsStats(guildId: guildId)
    }
}

// MARK: - Bot

actor MockBotService: BotServiceProtocol {

    func fetchStatus() async throws -> BotStatus {
        let workerURL = DiscordConfig.workerURL
        var isOnline = false
        var latency = 0
        var guildCount = 0
        if let url = URL(string: "\(workerURL)/bot/guilds") {
            let start = Date()
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    isOnline = true
                    latency = Int(Date().timeIntervalSince(start) * 1000)
                    if let guilds = try? JSONDecoder().decode([DiscordGuild].self, from: data) {
                        guildCount = guilds.count
                    }
                }
            } catch {
                isOnline = false
            }
        }
        return BotStatus(isOnline: isOnline, latency: latency, uptime: 99.9,
                         activeGuilds: guildCount, totalCommands: 0)
    }

    func restart() async throws {
        try await Task.sleep(for: .seconds(1))
    }

    func fetchCommands() async throws -> [SlashCommand] { MockData.slashCommands }
    func toggleCommand(id: String, enabled: Bool) async throws { }
}

// MARK: - Auth

actor MockAuthService: AuthServiceProtocol {
    func login() async throws -> User {
        try await Task.sleep(for: .seconds(1))
        return MockData.currentUser
    }

    func logout() async throws {
        try await mockDelay()
    }

    func currentUser() async throws -> User? {
        try await mockDelay()
        return MockData.currentUser
    }
}
