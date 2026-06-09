import Foundation

enum ServiceError: LocalizedError {
    case networkError
    case notFound
    case unauthorized
    case unauthorizedWithDetail(String)
    case invalidData
    case workerError(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .networkError:   "Network connection failed"
        case .notFound:       "Resource not found"
        case .unauthorized:   "Not authorized"
        case .unauthorizedWithDetail(let detail):   "Not authorized: \(detail)"
        case .invalidData:    "Invalid data"
        case .workerError(let status, let message):   "Worker error \(status): \(message)"
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

    func fetchByGuild(_ guildId: String) async throws -> [EmbedModel] {
        try await mockDelay()
        return embeds.filter { $0.guildId == guildId }
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

    func fetchBotGuildIds() async throws -> Set<String> {
        try await mockDelay()
        return Set(guilds.filter { $0.userRole == .owner }.map(\.id))
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

    func timeout(memberId: String, guildId: String, until: Date) async throws {
        try await mockDelay()
    }

    func sendDM(memberId: String, message: String) async throws {
        try await mockDelay()
    }

    func addRole(memberId: String, guildId: String, roleId: String) async throws {
        try await mockDelay()
        guard let idx = members.firstIndex(where: { $0.id == memberId }) else { return }
        var updated = members[idx]
        if !updated.roles.contains(roleId) {
            let newRoles = updated.roles + [roleId]
            updated = Member(id: updated.id, guildId: updated.guildId, username: updated.username,
                             displayName: updated.displayName,
                             discriminator: updated.discriminator, globalName: updated.globalName, nick: updated.nick,
                             avatarUrl: updated.avatarUrl, bannerUrl: updated.bannerUrl,
                             accentColor: updated.accentColor, publicFlags: updated.publicFlags, isBot: updated.isBot,
                             roles: newRoles, joinedAt: updated.joinedAt, createdAt: updated.createdAt,
                             isBoosting: updated.isBoosting, boostSince: updated.boostSince,
                             isDeaf: updated.isDeaf, isMute: updated.isMute, flags: updated.flags,
                             communicationDisabledUntil: updated.communicationDisabledUntil, status: updated.status)
            members[idx] = updated
        }
    }

    func removeRole(memberId: String, guildId: String, roleId: String) async throws {
        try await mockDelay()
        guard let idx = members.firstIndex(where: { $0.id == memberId }) else { return }
        var updated = members[idx]
        let newRoles = updated.roles.filter { $0 != roleId }
        updated = Member(id: updated.id, guildId: updated.guildId, username: updated.username,
                         displayName: updated.displayName,
                         discriminator: updated.discriminator, globalName: updated.globalName, nick: updated.nick,
                         avatarUrl: updated.avatarUrl, bannerUrl: updated.bannerUrl,
                         accentColor: updated.accentColor, publicFlags: updated.publicFlags, isBot: updated.isBot,
                         roles: newRoles, joinedAt: updated.joinedAt, createdAt: updated.createdAt,
                         isBoosting: updated.isBoosting, boostSince: updated.boostSince,
                         isDeaf: updated.isDeaf, isMute: updated.isMute, flags: updated.flags,
                         communicationDisabledUntil: updated.communicationDisabledUntil, status: updated.status)
        members[idx] = updated
    }
}

// MARK: - Ticket

actor MockTicketService: TicketServiceProtocol {
    private var tickets = MockData.tickets
    private var messages = MockData.ticketMessages

    func fetchAll(guildId: String) async throws -> [Ticket] {
        try await mockDelay()
        return tickets.filter { $0.guildId == guildId }
    }

    func create(guildId: String, subject: String) async throws -> Ticket {
        try await mockDelay()
        let t = Ticket(id: UUID().uuidString, guildId: guildId, channelId: "mock-ch",
                       openedBy: "admin", subject: subject, status: .open, priority: .medium,
                       openedAt: .now, lastMessageAt: .now, messageCount: 0)
        tickets.insert(t, at: 0)
        return t
    }

    func fetch(id: String) async throws -> Ticket {
        try await mockDelay()
        guard let ticket = tickets.first(where: { $0.id == id }) else { throw ServiceError.notFound }
        return ticket
    }

    func close(id: String) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        var t = tickets[idx]; t.status = .closed; t.closedAt = .now; tickets[idx] = t
    }

    func reopen(id: String) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        var t = tickets[idx]; t.status = .open; t.closedAt = nil; tickets[idx] = t
    }

    func setStatus(id: String, status: TicketStatus) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        var t = tickets[idx]
        t.status = status
        if status == .closed {
            t.closedAt = .now
        } else {
            t.closedAt = nil
        }
        tickets[idx] = t
    }

    func updatePriority(id: String, priority: TicketPriority) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == id }) else { return }
        var t = tickets[idx]; t.priority = priority; tickets[idx] = t
    }

    func fetchMessages(ticketId: String) async throws -> [TicketMessage] {
        try await mockDelay()
        return messages.filter { $0.ticketId == ticketId }
    }

    func reply(ticketId: String, message: String) async throws {
        try await mockDelay()
        let msg = TicketMessage(
            id: UUID().uuidString, ticketId: ticketId,
            userId: "staff001", username: "Noxy Bot",
            content: message, isStaff: true, createdAt: .now
        )
        messages.append(msg)
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        var t = tickets[idx]; t.messageCount += 1; t.lastMessageAt = .now; tickets[idx] = t
    }

    func assign(ticketId: String, userId: String) async throws {
        try await mockDelay()
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        var t = tickets[idx]; t.assignedToUserId = userId; tickets[idx] = t
    }

    // MARK: - Panels (mock)

    func fetchPanels(guildId: String) async throws -> [TicketPanel] {
        try await mockDelay()
        return [
            TicketPanel(id: "p001", guildId: guildId, channelId: "c001", messageId: "m001",
                        title: "一般サポート", description: "不具合報告やご質問はこちら。",
                        color: 0x6366f1, buttonColor: 0x6366f1,
                        buttonLabel: "チケットを作成", buttonEmoji: "🎫",
                        supportRoleId: nil, openCategoryId: nil, closedCategoryId: nil,
                        ticketMsgContent: nil, ticketEmbedTitle: "チケット",
                        ticketEmbedColor: 0x6366f1, maxOpenPerUser: 1, createdAt: .now),
        ]
    }
    func createPanel(_ panel: TicketPanel) async throws -> TicketPanel {
        try await mockDelay(); return panel
    }
    func updatePanel(_ panel: TicketPanel) async throws -> TicketPanel {
        try await mockDelay(); return panel
    }
    func deletePanel(id: String) async throws { try await mockDelay() }
    func deployPanel(id: String, channelId: String) async throws -> TicketPanel {
        try await mockDelay()
        return TicketPanel.blank(guildId: "g003")
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
        let workerURL = await MainActor.run { DiscordConfig.workerURL }
        let apiSecret = await MainActor.run { DiscordConfig.workerAPISecret }

        // /bot/status（認証不要・Discord API 不使用）で疎通確認
        guard let statusURL = URL(string: "\(workerURL)/bot/status") else {
            return BotStatus(isOnline: false, latency: 0, uptime: 0, activeGuilds: 0, totalCommands: 0)
        }
        var req = URLRequest(url: statusURL, timeoutInterval: 10)
        if !apiSecret.isEmpty {
            req.setValue(apiSecret, forHTTPHeaderField: "X-Bot-Secret")
        }
        let start = Date()
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                return BotStatus(isOnline: false, latency: latency, uptime: 0, activeGuilds: 0, totalCommands: 0)
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let isOnline = json?["isOnline"] as? Bool ?? false
            return BotStatus(isOnline: isOnline, latency: latency, uptime: 0, activeGuilds: 0, totalCommands: 0)
        } catch {
            // フォールバック: /bot/ping
            if let pingURL = URL(string: "\(workerURL)/bot/ping") {
                if let (_, resp) = try? await URLSession.shared.data(from: pingURL),
                   (resp as? HTTPURLResponse)?.statusCode == 200 {
                    return BotStatus(isOnline: true, latency: 0, uptime: 0, activeGuilds: 0, totalCommands: 0)
                }
            }
            return BotStatus(isOnline: false, latency: 0, uptime: 0, activeGuilds: 0, totalCommands: 0)
        }
    }

    func restart() async throws {
        try await Task.sleep(for: .seconds(1))
    }

    func fetchCommands() async throws -> [SlashCommand] {
        await MainActor.run { MockData.slashCommands }
    }
    func toggleCommand(id: String, enabled: Bool) async throws { }
}

// MARK: - Auth

actor MockAuthService: AuthServiceProtocol {
    func login() async throws -> User {
        try await Task.sleep(for: .seconds(1))
        return await MainActor.run { MockData.currentUser }
    }

    func logout() async throws {
        try await mockDelay()
    }

    func currentUser() async throws -> User? {
        try await mockDelay()
        return await MainActor.run { MockData.currentUser }
    }
}

// MARK: - TempChannel

actor MockTempChannelService: TempChannelServiceProtocol {
    func fetchSettings(guildId: String) async throws -> TempChannelSettings {
        try await mockDelay()
        return TempChannelSettings.defaultSettings(guildId: guildId)
    }
    func saveSettings(_ settings: TempChannelSettings) async throws -> TempChannelSettings {
        try await mockDelay(); return settings
    }
    func fetchActiveChannels(guildId: String) async throws -> [ActiveTempChannel] {
        try await mockDelay(); return []
    }
}

// MARK: - ReactionRole

actor MockReactionRoleService: ReactionRoleServiceProtocol {
    nonisolated(unsafe) private var items: [ReactionRoleItem] = []

    func fetchAll(guildId: String) async throws -> [ReactionRoleItem] {
        try await mockDelay()
        return items.filter { $0.guildId == guildId }
    }
    func create(_ item: ReactionRoleItem) async throws -> ReactionRoleItem {
        try await mockDelay()
        items.append(item)
        return item
    }
    func update(_ item: ReactionRoleItem) async throws -> ReactionRoleItem {
        try await mockDelay()
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { throw ServiceError.notFound }
        items[idx] = item
        return item
    }
    func delete(id: String) async throws {
        try await mockDelay()
        items.removeAll { $0.id == id }
    }
}

// MARK: - Shop

actor MockShopService: ShopServiceProtocol {
    nonisolated(unsafe) private var shops: [Shop] = []
    nonisolated(unsafe) private var products: [Product] = []
    nonisolated(unsafe) private var orders: [Order] = []

    func fetchShops(guildId: String) async throws -> [Shop] {
        try await mockDelay()
        return shops.filter { $0.guildId == guildId }
    }
    func createShop(_ shop: Shop) async throws -> Shop {
        try await mockDelay()
        shops.append(shop)
        return shop
    }
    func updateShop(_ shop: Shop) async throws -> Shop {
        try await mockDelay()
        guard let idx = shops.firstIndex(where: { $0.id == shop.id }) else { throw ServiceError.notFound }
        shops[idx] = shop
        return shop
    }
    func deleteShop(id: String) async throws {
        try await mockDelay()
        shops.removeAll { $0.id == id }
    }
    func deployShop(id: String, channelId: String) async throws -> Shop {
        try await mockDelay()
        guard let idx = shops.firstIndex(where: { $0.id == id }) else { throw ServiceError.notFound }
        shops[idx].channelId = channelId
        shops[idx].messageId = "mock-msg-\(UUID().uuidString.prefix(8))"
        return shops[idx]
    }

    func fetchProducts(shopId: String) async throws -> [Product] {
        try await mockDelay()
        return products.filter { $0.shopId == shopId }
    }
    func createProduct(_ product: Product) async throws -> Product {
        try await mockDelay()
        products.append(product)
        return product
    }
    func updateProduct(_ product: Product) async throws -> Product {
        try await mockDelay()
        guard let idx = products.firstIndex(where: { $0.id == product.id }) else { throw ServiceError.notFound }
        products[idx] = product
        return product
    }
    func deleteProduct(id: String) async throws {
        try await mockDelay()
        products.removeAll { $0.id == id }
    }

    func fetchOrders(guildId: String, status: OrderStatus?) async throws -> [Order] {
        try await mockDelay()
        var base = orders.filter { $0.guildId == guildId }
        if let status { base = base.filter { $0.status == status } }
        return base
    }
    func fetchOrder(id: String) async throws -> Order {
        try await mockDelay()
        guard let order = orders.first(where: { $0.id == id }) else { throw ServiceError.notFound }
        return order
    }
    func confirmPayment(orderId: String) async throws -> Order {
        try await mockDelay()
        guard let idx = orders.firstIndex(where: { $0.id == orderId }) else { throw ServiceError.notFound }
        orders[idx].status = .delivered
        orders[idx].paidAt = .now
        orders[idx].deliveredAt = .now
        return orders[idx]
    }
    func completeOrder(orderId: String, party: String) async throws -> Order {
        try await mockDelay()
        guard let idx = orders.firstIndex(where: { $0.id == orderId }) else { throw ServiceError.notFound }
        if party == "buyer" {
            orders[idx].buyerConfirmed = true
            orders[idx].status = .completed
            orders[idx].completedAt = .now
        }
        return orders[idx]
    }
}


// MARK: - Verify

actor MockVerifyService: VerifyServiceProtocol {
    nonisolated(unsafe) private var panels: [VerifyPanel] = []
    nonisolated(unsafe) private var requests: [VerifyRequest] = []

    func fetchPanels(guildId: String) async throws -> [VerifyPanel] {
        try await mockDelay(); return panels.filter { $0.guildId == guildId }
    }
    func createPanel(_ panel: VerifyPanel) async throws -> VerifyPanel {
        try await mockDelay(); panels.append(panel); return panel
    }
    func updatePanel(_ panel: VerifyPanel) async throws -> VerifyPanel {
        try await mockDelay()
        guard let idx = panels.firstIndex(where: { $0.id == panel.id }) else { throw ServiceError.notFound }
        panels[idx] = panel; return panel
    }
    func deletePanel(id: String) async throws {
        try await mockDelay(); panels.removeAll { $0.id == id }
    }
    func deployPanel(id: String, channelId: String) async throws -> VerifyPanel {
        try await mockDelay()
        guard let idx = panels.firstIndex(where: { $0.id == id }) else { throw ServiceError.notFound }
        panels[idx].channelId = channelId
        panels[idx].messageId = "mock-msg-\(UUID().uuidString.prefix(8))"
        return panels[idx]
    }
    func resetPanel(id: String) async throws -> VerifyPanel {
        try await mockDelay()
        guard let idx = panels.firstIndex(where: { $0.id == id }) else { throw ServiceError.notFound }
        panels[idx].channelId = ""
        panels[idx].messageId = nil
        return panels[idx]
    }
    func createRole(guildId: String, name: String, color: Int,
                    channelPermissions: [ChannelPermissionInput]) async throws -> CreatedRole {
        try await mockDelay()
        return CreatedRole(id: UUID().uuidString, name: name, color: color)
    }

    func fetchRequests(guildId: String, status: VerifyRequestStatus?) async throws -> [VerifyRequest] {
        try await mockDelay()
        var base = requests.filter { $0.guildId == guildId }
        if let s = status { base = base.filter { $0.status == s } }
        return base
    }
    func approveRequest(id: String) async throws -> VerifyRequest {
        try await mockDelay()
        guard let idx = requests.firstIndex(where: { $0.id == id }) else { throw ServiceError.notFound }
        requests[idx].status = .approved; requests[idx].resolvedAt = .now
        return requests[idx]
    }
    func denyRequest(id: String) async throws -> VerifyRequest {
        try await mockDelay()
        guard let idx = requests.firstIndex(where: { $0.id == id }) else { throw ServiceError.notFound }
        requests[idx].status = .denied; requests[idx].resolvedAt = .now
        return requests[idx]
    }
}

// MARK: - Subscription

actor MockSubscriptionService: SubscriptionServiceProtocol {
    private var status: SubscriptionStatus = .inactive

    func fetchStatus(discordUserId: String) async throws -> SubscriptionStatus {
        try await mockDelay()
        return status
    }

    func purchase(productId: String) async throws -> SubscriptionStatus {
        try await mockDelay()
        let slots = ["jp.noxyapp.stat.1server": 1, "jp.noxyapp.stat.2server": 2,
                     "jp.noxyapp.stat.3server": 3, "jp.noxyapp.stat.5server": 5][productId] ?? 1
        status = SubscriptionStatus(
            purchasedSlots: slots, usedSlots: status.usedSlots,
            productId: productId,
            expiresAt: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            activatedGuildIds: status.activatedGuildIds
        )
        return status
    }

    func restore() async throws -> SubscriptionStatus {
        try await mockDelay()
        return status
    }

    func activateServer(guildId: String) async throws {
        try await mockDelay()
        // availableSlots を直接計算（@MainActor の computed property を避ける）
        let available = max(0, status.purchasedSlots - status.usedSlots)
        guard available > 0 else { throw ServiceError.networkError }
        var ids = status.activatedGuildIds
        if !ids.contains(guildId) { ids.append(guildId) }
        status = SubscriptionStatus(
            purchasedSlots: status.purchasedSlots,
            usedSlots: ids.count,
            productId: status.productId,
            expiresAt: status.expiresAt,
            activatedGuildIds: ids
        )
    }

    func deactivateServer(guildId: String) async throws {
        try await mockDelay()
        let ids = status.activatedGuildIds.filter { $0 != guildId }
        status = SubscriptionStatus(
            purchasedSlots: status.purchasedSlots,
            usedSlots: ids.count,
            productId: status.productId,
            expiresAt: status.expiresAt,
            activatedGuildIds: ids
        )
    }
}
