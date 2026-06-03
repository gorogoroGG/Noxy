import Foundation

protocol AutoResponseServiceProtocol: Sendable {
    func fetchAll(guildId: String) async throws -> [AutoResponse]
    func create(_ item: AutoResponse) async throws -> AutoResponse
    func update(_ item: AutoResponse) async throws -> AutoResponse
    func delete(id: String) async throws
    func toggle(id: String, enabled: Bool) async throws
}

protocol ScheduledMessageServiceProtocol: Sendable {
    func fetchAll() async throws -> [ScheduledMessage]
    func create(_ message: ScheduledMessage) async throws -> ScheduledMessage
    func update(_ message: ScheduledMessage) async throws -> ScheduledMessage
    func cancel(id: String) async throws
}

protocol AuditLogServiceProtocol: Sendable {
    func fetch(guildId: String, page: Int) async throws -> [AuditLog]
}

protocol NotificationServiceProtocol: Sendable {
    func fetchAll() async throws -> [AppNotification]
    func markRead(id: String) async throws
    func markAllRead() async throws
}

protocol AnalyticsServiceProtocol: Sendable {
    func fetchStats(guildId: String) async throws -> AnalyticsStats
}

protocol BotServiceProtocol: Sendable {
    func fetchStatus() async throws -> BotStatus
    func restart() async throws
    func fetchCommands() async throws -> [SlashCommand]
    func toggleCommand(id: String, enabled: Bool) async throws
}

protocol ReactionRoleServiceProtocol: Sendable {
    func fetchAll(guildId: String) async throws -> [ReactionRoleItem]
    func create(_ item: ReactionRoleItem) async throws -> ReactionRoleItem
    func update(_ item: ReactionRoleItem) async throws -> ReactionRoleItem
    func delete(id: String) async throws
}

protocol AuthServiceProtocol: Sendable {
    func login() async throws -> User
    func logout() async throws
    func currentUser() async throws -> User?
}

protocol GreetingServiceProtocol: Sendable {
    func fetch(guildId: String) async throws -> GreetingSettings
    func save(_ settings: GreetingSettings) async throws -> GreetingSettings
}

protocol SubscriptionServiceProtocol: Sendable {
    /// Worker からサブスク状態を取得
    func fetchStatus(discordUserId: String) async throws -> SubscriptionStatus
    /// StoreKit 2 で購入を実行し、Worker に通知
    func purchase(productId: String) async throws -> SubscriptionStatus
    /// 購入復元
    func restore() async throws -> SubscriptionStatus
    /// サーバーを有効化（Worker 経由でオーナー検証 + DB 登録）
    func activateServer(guildId: String) async throws
    /// サーバーの有効化を解除
    func deactivateServer(guildId: String) async throws
}

protocol StatChannelServiceProtocol: Sendable {
    func fetchAll(guildId: String) async throws -> [StatChannel]
    func create(guildId: String, statType: StatType, categoryId: String?) async throws -> StatChannel
    func toggle(id: String, enabled: Bool) async throws -> StatChannel
    func delete(id: String) async throws
    func refresh(id: String) async throws
}
