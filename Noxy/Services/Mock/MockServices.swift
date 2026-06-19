import Foundation

extension NSNotification.Name {
    /// MockService が外部アクション（Discord への送信・メンバー操作等）を実行したときに post する。
    /// RootView がデモモード中のみリッスンし、アップセルモーダルを表示する。
    static let mockExternalAction = NSNotification.Name("com.noxy.mockExternalAction")
}

private func notifyDemoAction(_ actionName: String) {
    NotificationCenter.default.post(name: .mockExternalAction, object: actionName)
}

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
        notifyDemoAction("埋め込みメッセージを Discord に送信")
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
        notifyDemoAction("メンバーをキック")
    }

    func ban(memberId: String, guildId: String, reason: String?) async throws {
        try await mockDelay()
        members.removeAll { $0.id == memberId && $0.guildId == guildId }
        notifyDemoAction("メンバーを BAN")
    }

    func timeout(memberId: String, guildId: String, until: Date) async throws {
        try await mockDelay()
        notifyDemoAction("メンバーをタイムアウト")
    }

    func sendDM(memberId: String, message: String) async throws {
        try await mockDelay()
        notifyDemoAction("メンバーに DM を送信")
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
        notifyDemoAction("メンバーにロールを付与")
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
        notifyDemoAction("メンバーからロールを削除")
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
            content: message, isStaff: true, createdAt: .now    , source: "app"
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
        notifyDemoAction("チケットパネルを Discord チャンネルに設置")
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

    func delete(id: String) async throws {
        try await mockDelay()
        notifications.removeAll { $0.id == id }
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
        // /bot/status（認証不要・Discord API 不使用）で疎通確認
        guard let statusURL = URL(string: "\(workerURL)/bot/status") else {
            return BotStatus(isOnline: false, latency: 0, uptime: 0, activeGuilds: 0, totalCommands: 0)
        }
        let req = URLRequest(url: statusURL, timeoutInterval: 10)
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
        notifyDemoAction("Bot を再起動")
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

// MARK: - VCNotification

actor MockVCNotificationService: VCNotificationServiceProtocol {
    private var stored: [String: VCNotificationSettings] = [:]

    func fetchSettings(guildId: String) async throws -> VCNotificationSettings {
        try await mockDelay()
        return stored[guildId] ?? VCNotificationSettings.defaultSettings(guildId: guildId)
    }

    func saveSettings(_ settings: VCNotificationSettings) async throws -> VCNotificationSettings {
        try await mockDelay()
        stored[settings.guildId] = settings
        return settings
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
    nonisolated(unsafe) private var orders: [Order] = (1...14).map { i in
        let statuses: [OrderStatus] = [.open, .paid, .delivered, .completed, .cancelled, .disputed]
        return Order(id: "o\(i)", shopId: "s1", productId: "p1", guildId: "g001", channelId: "c1",
                     buyerUserId: "u\(i)", buyerUsername: "buyer\(i)", productName: "サンプル商品 \(i)",
                     productPriceDisplay: "¥\(i * 120)", status: statuses[i % statuses.count],
                     buyerConfirmed: false, sellerConfirmed: false, buyerCancelRequested: false,
                     sellerCancelRequested: false, paymentUrl: i % 2 == 0 ? "https://example.com/pay" : nil,
                     paymentSubmittedAt: nil, createdAt: Date().addingTimeInterval(Double(-i * 3600)),
                     paidAt: nil, deliveredAt: nil, completedAt: nil, cancelledAt: nil,
                     archivedAt: nil, autoDeleteAt: nil)
    } // TEMP-TEST seed

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
        orders[idx].status = .completed
        orders[idx].paidAt = .now
        orders[idx].completedAt = .now
        return orders[idx]
    }
    func completeOrder(orderId: String, party: String) async throws -> Order {
        try await mockDelay()
        guard let idx = orders.firstIndex(where: { $0.id == orderId }) else { throw ServiceError.notFound }
        orders[idx].status = .completed
        orders[idx].completedAt = .now
        return orders[idx]
    }
    func archiveOrder(orderId: String) async throws -> Order {
        try await mockDelay()
        guard let idx = orders.firstIndex(where: { $0.id == orderId }) else { throw ServiceError.notFound }
        orders[idx].status = .archived
        orders[idx].archivedAt = .now
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
        notifyDemoAction("認証パネルを Discord チャンネルに設置")
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

// MARK: - InviteTracker

actor MockInviteTrackerService: InviteTrackerServiceProtocol {
    // MARK: Seed data

    private static let guildId = "g001"

    private static let leaderboard: [InviteStats] = [
        InviteStats(userId: "u001", guildId: guildId, username: "taro_san",   displayName: "太郎",    avatarUrl: nil, totalInvites: 15, validInvites: 12, leftInvites: 2, fakeInvites: 1, influenceScore: 34, treeSize: 22, retentionRate: 0.857, rank: 1),
        InviteStats(userId: "u002", guildId: guildId, username: "hanako_777", displayName: "花子",    avatarUrl: nil, totalInvites: 10, validInvites: 8,  leftInvites: 2, fakeInvites: 0, influenceScore: 18, treeSize: 11, retentionRate: 0.800, rank: 2),
        InviteStats(userId: "u003", guildId: guildId, username: "ryo_game",   displayName: "涼",      avatarUrl: nil, totalInvites: 8,  validInvites: 7,  leftInvites: 1, fakeInvites: 0, influenceScore: 14, treeSize: 7,  retentionRate: 0.875, rank: 3),
        InviteStats(userId: "u004", guildId: guildId, username: "mika_art",   displayName: "美香",    avatarUrl: nil, totalInvites: 6,  validInvites: 4,  leftInvites: 1, fakeInvites: 1, influenceScore: 8,  treeSize: 4,  retentionRate: 0.800, rank: 4),
        InviteStats(userId: "u005", guildId: guildId, username: "kenji_dev",  displayName: "健二",    avatarUrl: nil, totalInvites: 5,  validInvites: 5,  leftInvites: 0, fakeInvites: 0, influenceScore: 7,  treeSize: 2,  retentionRate: 1.000, rank: 5),
        InviteStats(userId: "u006", guildId: guildId, username: "yuki_music", displayName: "雪",      avatarUrl: nil, totalInvites: 4,  validInvites: 3,  leftInvites: 1, fakeInvites: 0, influenceScore: 5,  treeSize: 1,  retentionRate: 0.750, rank: 6),
        InviteStats(userId: "u007", guildId: guildId, username: "haru_net",   displayName: "春太",    avatarUrl: nil, totalInvites: 3,  validInvites: 3,  leftInvites: 0, fakeInvites: 0, influenceScore: 3,  treeSize: 0,  retentionRate: 1.000, rank: 7),
        InviteStats(userId: "u008", guildId: guildId, username: "sora_blue",  displayName: "空",      avatarUrl: nil, totalInvites: 2,  validInvites: 1,  leftInvites: 1, fakeInvites: 0, influenceScore: 2,  treeSize: 0,  retentionRate: 0.500, rank: 8),
    ]

    private static let tree = InviteTreeNode(
        userId: "u001", username: "taro_san", displayName: "太郎",
        avatarUrl: nil, isCurrentMember: true,
        joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 90),
        leftAt: nil, directInvites: 3, totalDescendants: 22,
        children: [
            InviteTreeNode(
                userId: "u002", username: "hanako_777", displayName: "花子",
                avatarUrl: nil, isCurrentMember: true,
                joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 60),
                leftAt: nil, directInvites: 4, totalDescendants: 11,
                children: [
                    InviteTreeNode(
                        userId: "u005", username: "kenji_dev", displayName: "健二",
                        avatarUrl: nil, isCurrentMember: true,
                        joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 40),
                        leftAt: nil, directInvites: 2, totalDescendants: 2,
                        children: [
                            InviteTreeNode(userId: "u012", username: "rin_ui", displayName: "凛", avatarUrl: nil, isCurrentMember: true, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 20), leftAt: nil, directInvites: 0, totalDescendants: 0, children: []),
                            InviteTreeNode(userId: "u013", username: "ao_chan", displayName: "葵", avatarUrl: nil, isCurrentMember: false, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 15), leftAt: Date().addingTimeInterval(-60 * 60 * 24 * 5), directInvites: 0, totalDescendants: 0, children: []),
                        ]
                    ),
                    InviteTreeNode(
                        userId: "u006", username: "yuki_music", displayName: "雪",
                        avatarUrl: nil, isCurrentMember: true,
                        joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 35),
                        leftAt: nil, directInvites: 1, totalDescendants: 1,
                        children: [
                            InviteTreeNode(userId: "u014", username: "souta_x", displayName: "奏太", avatarUrl: nil, isCurrentMember: true, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 10), leftAt: nil, directInvites: 0, totalDescendants: 0, children: []),
                        ]
                    ),
                    InviteTreeNode(userId: "u015", username: "nana_77", displayName: "七", avatarUrl: nil, isCurrentMember: false, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 50), leftAt: Date().addingTimeInterval(-60 * 60 * 24 * 30), directInvites: 0, totalDescendants: 0, children: []),
                    InviteTreeNode(userId: "u016", username: "riku_z",  displayName: "陸", avatarUrl: nil, isCurrentMember: true, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 45), leftAt: nil, directInvites: 0, totalDescendants: 0, children: []),
                ]
            ),
            InviteTreeNode(
                userId: "u003", username: "ryo_game", displayName: "涼",
                avatarUrl: nil, isCurrentMember: true,
                joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 55),
                leftAt: nil, directInvites: 3, totalDescendants: 7,
                children: [
                    InviteTreeNode(userId: "u007", username: "haru_net", displayName: "春太", avatarUrl: nil, isCurrentMember: true, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 30), leftAt: nil, directInvites: 0, totalDescendants: 0, children: []),
                    InviteTreeNode(userId: "u008", username: "sora_blue", displayName: "空", avatarUrl: nil, isCurrentMember: false, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 28), leftAt: Date().addingTimeInterval(-60 * 60 * 24 * 3), directInvites: 0, totalDescendants: 0, children: []),
                    InviteTreeNode(userId: "u009", username: "mei_star", displayName: "芽衣", avatarUrl: nil, isCurrentMember: true, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 25), leftAt: nil, directInvites: 0, totalDescendants: 0, children: []),
                ]
            ),
            InviteTreeNode(
                userId: "u004", username: "mika_art", displayName: "美香",
                avatarUrl: nil, isCurrentMember: true,
                joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 70),
                leftAt: nil, directInvites: 2, totalDescendants: 4,
                children: [
                    InviteTreeNode(userId: "u010", username: "kai_99", displayName: "海", avatarUrl: nil, isCurrentMember: true, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 50), leftAt: nil, directInvites: 0, totalDescendants: 0, children: []),
                    InviteTreeNode(userId: "u011", username: "tsuki_m", displayName: "月", avatarUrl: nil, isCurrentMember: false, joinedAt: Date().addingTimeInterval(-60 * 60 * 24 * 48), leftAt: Date().addingTimeInterval(-60 * 60 * 24 * 10), directInvites: 0, totalDescendants: 0, children: []),
                ]
            ),
        ]
    )

    nonisolated(unsafe) private var settings = InviteTrackerSettings(
        guildId: "g001", isEnabled: true, logChannelId: nil,
        notifyOnJoin: true, notifyOnLeave: false,
        fakeInviteThresholdHours: 24,
        milestones: [
            InviteMilestone(id: "m1", guildId: "g001", count: 5,  roleId: "r1", roleName: "招待者"),
            InviteMilestone(id: "m2", guildId: "g001", count: 20, roleId: "r2", roleName: "招待マスター"),
        ]
    )

    // MARK: Protocol

    func fetchLeaderboard(guildId: String, period: InvitePeriod) async throws -> [InviteStats] {
        try await mockDelay()
        return Self.leaderboard.map { InviteStats(userId: $0.userId, guildId: guildId, username: $0.username, displayName: $0.displayName, avatarUrl: $0.avatarUrl, totalInvites: $0.totalInvites, validInvites: $0.validInvites, leftInvites: $0.leftInvites, fakeInvites: $0.fakeInvites, influenceScore: $0.influenceScore, treeSize: $0.treeSize, retentionRate: $0.retentionRate, rank: $0.rank) }
    }

    func fetchMemberDetail(guildId: String, userId: String) async throws -> InviteMemberDetail {
        try await mockDelay()
        let stat = Self.leaderboard.first { $0.userId == userId } ?? Self.leaderboard[0]
        let count = min(stat.validInvites + stat.leftInvites, 6)
        var invitees: [InviteEventEntry] = []
        for i in 0..<count {
            let left: Date? = (i % 4 == 0) ? Date().addingTimeInterval(Double(-i * 86400)) : nil
            invitees.append(InviteEventEntry(
                userId: "inv\(i)", username: "user_\(i)", displayName: "招待者\(i + 1)",
                avatarUrl: nil,
                joinedAt: Date().addingTimeInterval(Double(-i * 86400 * 3)),
                leftAt: left
            ))
        }
        let invitedByUserId: String? = userId == "u001" ? nil : "u001"
        let invitedByUsername: String? = userId == "u001" ? nil : "taro_san"
        let invitedByDisplayName: String? = userId == "u001" ? nil : "太郎"
        let path: [String] = userId == "u001" ? [] : ["太郎", stat.displayName]
        return InviteMemberDetail(
            stats: stat, recentInvitees: invitees,
            invitedByUserId: invitedByUserId,
            invitedByUsername: invitedByUsername,
            invitedByDisplayName: invitedByDisplayName,
            invitePathDisplayNames: path
        )
    }

    func fetchTree(guildId: String, userId: String) async throws -> InviteTreeNode {
        try await mockDelay()
        return Self.tree
    }

    func fetchSettings(guildId: String) async throws -> InviteTrackerSettings {
        try await mockDelay(); return settings
    }

    func saveSettings(_ s: InviteTrackerSettings) async throws -> InviteTrackerSettings {
        try await mockDelay(); settings = s; return s
    }

    // MARK: - Invite Panel

    nonisolated(unsafe) var panels: [InvitePanel] = [
        InvitePanel(id: "p1", guildId: "g001", channelId: "ch001", channelName: "📩招待リンク",
                    messageId: "msg001", createdAt: Date().addingTimeInterval(-86400 * 3)),
    ]

    nonisolated(unsafe) var personalInvites: [PersonalInviteLink] = [
        PersonalInviteLink(id: "pi1", guildId: "g001", userId: "u001", username: "taro_san",
                           displayName: "太郎", inviteCode: "abc123", inviteUrl: "https://discord.gg/abc123",
                           channelId: "ch001", createdAt: Date().addingTimeInterval(-86400 * 2)),
        PersonalInviteLink(id: "pi2", guildId: "g001", userId: "u002", username: "hanako",
                           displayName: "花子", inviteCode: "def456", inviteUrl: "https://discord.gg/def456",
                           channelId: "ch001", createdAt: Date().addingTimeInterval(-86400)),
        PersonalInviteLink(id: "pi3", guildId: "g001", userId: "u003", username: "ryo_san",
                           displayName: "涼", inviteCode: "ghi789", inviteUrl: "https://discord.gg/ghi789",
                           channelId: "ch001", createdAt: Date().addingTimeInterval(-3600 * 5)),
    ]

    func deployInvitePanel(guildId: String, channelId: String, channelName: String) async throws -> InvitePanel {
        try await mockDelay()
        let panel = InvitePanel(id: UUID().uuidString, guildId: guildId, channelId: channelId,
                                channelName: channelName, messageId: "new_msg", createdAt: Date())
        panels.append(panel)
        notifyDemoAction("招待パネルを Discord チャンネルに設置")
        return panel
    }

    func fetchInvitePanels(guildId: String) async throws -> [InvitePanel] {
        try await mockDelay(); return panels.filter { $0.guildId == guildId }
    }

    func deleteInvitePanel(id: String) async throws {
        try await mockDelay(); panels.removeAll { $0.id == id }
    }

    func fetchPersonalInviteLinks(guildId: String) async throws -> [PersonalInviteLink] {
        try await mockDelay(); return personalInvites.filter { $0.guildId == guildId }
    }

    func revokePersonalInviteLink(id: String) async throws {
        try await mockDelay(); personalInvites.removeAll { $0.id == id }
    }
}

// MARK: - Disaster Recovery

actor MockDisasterRecoveryService: DisasterRecoveryServiceProtocol {
    func fetchDeletedGuilds() async throws -> [DeletedGuild] {
        try await mockDelay()
        return [
            DeletedGuild(guildId: "g999", ownerId: "u001", guildName: "削除されたサーバー", deletedAt: Date().addingTimeInterval(-86400), notified: true)
        ]
    }

    func fetchEligibleUsers(sourceGuildId: String) async throws -> [RecoveryEligibleUser] {
        try await mockDelay()
        return [
            RecoveryEligibleUser(guildId: sourceGuildId, userId: "u001", username: "taro_san", avatarUrl: nil, authorizedAt: Date().addingTimeInterval(-86400 * 2)),
            RecoveryEligibleUser(guildId: sourceGuildId, userId: "u002", username: "hanako", avatarUrl: nil, authorizedAt: Date().addingTimeInterval(-86400)),
        ]
    }

    func fetchMemberCounts(guildIds: [String]) async throws -> [String: Int] {
        try await mockDelay()
        return Dictionary(uniqueKeysWithValues: guildIds.enumerated().map { ($1, ($0 + 1) * 3) })
    }

    func checkMembership(destGuildId: String, userIds: [String]) async throws -> [String] {
        try await mockDelay()
        // モック: u001 はすでに参加済み
        return userIds.filter { $0 == "u001" }
    }

    func executeRecovery(sourceGuildId: String, destinationGuildId: String, selectedUserIds: [String]) async throws -> RecoveryJob {
        try await mockDelay()
        notifyDemoAction("サーバー復旧を実行")
        return RecoveryJob(id: UUID().uuidString, sourceGuildId: sourceGuildId, destinationGuildId: destinationGuildId,
                           status: .running, totalCount: selectedUserIds.count, successCount: 0, failCount: 0, createdAt: Date(), completedAt: nil)
    }

    func fetchJobs(sourceGuildId: String) async throws -> [RecoveryJob] {
        try await mockDelay()
        return []
    }

    func fetchJobDetail(jobId: String) async throws -> RecoveryJobDetail {
        try await mockDelay()
        return RecoveryJobDetail(id: jobId, sourceGuildId: "g999", destinationGuildId: "g001",
                                 status: .completed, totalCount: 2, successCount: 2, failCount: 0,
                                 createdAt: Date(), completedAt: Date(), results: [])
    }
}
