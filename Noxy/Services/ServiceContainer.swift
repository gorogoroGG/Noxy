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
    let scheduledMessages:  any ScheduledMessageServiceProtocol
    let auditLogs:          any AuditLogServiceProtocol
    let notifications:      any NotificationServiceProtocol
    let analytics:          any AnalyticsServiceProtocol
    let bot:                any BotServiceProtocol
    let auth:               any AuthServiceProtocol
    let reactionRoles:      any ReactionRoleServiceProtocol

    private init(
        embeds:            any EmbedServiceProtocol,
        guilds:            any GuildServiceProtocol,
        members:           any MemberServiceProtocol,
        tickets:           any TicketServiceProtocol,
        autoResponses:     any AutoResponseServiceProtocol,
        scheduledMessages: any ScheduledMessageServiceProtocol,
        auditLogs:         any AuditLogServiceProtocol,
        notifications:     any NotificationServiceProtocol,
        analytics:         any AnalyticsServiceProtocol,
        bot:               any BotServiceProtocol,
        auth:              any AuthServiceProtocol,
        reactionRoles:     any ReactionRoleServiceProtocol
    ) {
        self.embeds = embeds
        self.guilds = guilds
        self.members = members
        self.tickets = tickets
        self.autoResponses = autoResponses
        self.scheduledMessages = scheduledMessages
        self.auditLogs = auditLogs
        self.notifications = notifications
        self.analytics = analytics
        self.bot = bot
        self.auth = auth
        self.reactionRoles = reactionRoles
    }

    /// 本番用（Supabase）
    static func live() -> ServiceContainer {
        ServiceContainer(
            embeds:            SupabaseEmbedService(),
            guilds:            DiscordService(),
            members:           MockMemberService(),
            tickets:           MockTicketService(),
            autoResponses:     MockAutoResponseService(),
            scheduledMessages: SupabaseScheduledMessageService(),
            auditLogs:         MockAuditLogService(),
            notifications:     MockNotificationService(),
            analytics:         MockAnalyticsService(),
            bot:               MockBotService(),
            auth:              SupabaseAuthService(),
            reactionRoles:     SupabaseReactionRoleService()
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
