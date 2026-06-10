import SwiftUI
import Observation

// MARK: - ServiceContainer（Supabase 専用）

@Observable
final class ServiceContainer {
    let embeds:   any EmbedServiceProtocol
    let guilds:   any GuildServiceProtocol
    let members:  any MemberServiceProtocol
    let tickets:  any TicketServiceProtocol
    let autoResponses:      any AutoResponseServiceProtocol
    let auditLogs:          any AuditLogServiceProtocol
    let notifications:      any NotificationServiceProtocol
    let analytics:          any AnalyticsServiceProtocol
    let bot:                any BotServiceProtocol
    let auth:               any AuthServiceProtocol
    let reactionRoles:      any ReactionRoleServiceProtocol
    let greeting:           any GreetingServiceProtocol
    let tempChannel:        any TempChannelServiceProtocol
    let tempVCSource:       any TempVCSourceServiceProtocol
    let shops:              any ShopServiceProtocol
    let statChannels:       any StatChannelServiceProtocol
    let subscription:       any SubscriptionServiceProtocol
    let verify:             any VerifyServiceProtocol

    private init(
        embeds:            any EmbedServiceProtocol,
        guilds:            any GuildServiceProtocol,
        members:           any MemberServiceProtocol,
        tickets:           any TicketServiceProtocol,
        autoResponses:     any AutoResponseServiceProtocol,
        auditLogs:         any AuditLogServiceProtocol,
        notifications:     any NotificationServiceProtocol,
        analytics:         any AnalyticsServiceProtocol,
        bot:               any BotServiceProtocol,
        auth:              any AuthServiceProtocol,
        reactionRoles:     any ReactionRoleServiceProtocol,
        greeting:          any GreetingServiceProtocol,
        tempChannel:       any TempChannelServiceProtocol,
        tempVCSource:      any TempVCSourceServiceProtocol,
        shops:             any ShopServiceProtocol,
        statChannels:      any StatChannelServiceProtocol,
        subscription:      any SubscriptionServiceProtocol,
        verify:            any VerifyServiceProtocol
    ) {
        self.embeds = embeds
        self.guilds = guilds
        self.members = members
        self.tickets = tickets
        self.autoResponses = autoResponses
        self.auditLogs = auditLogs
        self.notifications = notifications
        self.analytics = analytics
        self.bot = bot
        self.auth = auth
        self.reactionRoles = reactionRoles
        self.greeting = greeting
        self.tempChannel = tempChannel
        self.tempVCSource = tempVCSource
        self.shops = shops
        self.statChannels = statChannels
        self.subscription = subscription
        self.verify = verify
    }

    /// モック用（プレビュー・テスト）
    static func mock() -> ServiceContainer {
        ServiceContainer(
            embeds:            MockEmbedService(),
            guilds:            MockGuildService(),
            members:           MockMemberService(),
            tickets:           MockTicketService(),
            autoResponses:     MockAutoResponseService(),
            auditLogs:         MockAuditLogService(),
            notifications:     MockNotificationService(),
            analytics:         MockAnalyticsService(),
            bot:               MockBotService(),
            auth:              MockAuthService(),
            reactionRoles:     MockReactionRoleService(),
            greeting:          MockGreetingService(),
            tempChannel:       MockTempChannelService(),
            tempVCSource:      MockTempVCSourceService(),
            shops:             MockShopService(),
            statChannels:      WorkerStatChannelService(),
            subscription:      MockSubscriptionService(),
            verify:            MockVerifyService()
        )
    }

    /// 本番用（Worker + Supabase）
    static func live() -> ServiceContainer {
        ServiceContainer(
            embeds:            SupabaseEmbedService(),
            guilds:            DiscordService(),
            members:           DiscordMemberService(),
            tickets:           WorkerTicketService(),
            autoResponses:     WorkerAutoResponseService(),
            auditLogs:         MockAuditLogService(),
            notifications:     WorkerNotificationService(),
            analytics:         WorkerAnalyticsService(),
            bot:               WorkerBotService(),
            auth:              SupabaseAuthService(),
            reactionRoles:     SupabaseReactionRoleService(),
            greeting:          SupabaseGreetingService(),
            tempChannel:       WorkerTempChannelService(),
            tempVCSource:      WorkerTempVCSourceService(),
            shops:             WorkerShopService(),
            statChannels:      WorkerStatChannelService(),
            subscription:      WorkerSubscriptionService(),
            verify:            WorkerVerifyService()
        )
    }
}

// MARK: - Environment

private struct ServiceContainerKey: EnvironmentKey {
    @MainActor static let defaultValue = ServiceContainer.live()
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}
