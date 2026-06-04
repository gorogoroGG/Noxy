import Foundation

enum MockData {
    nonisolated static let currentUser = User(
        id: "u001",
        discordId: "123456789012345678",
        username: "gorogoroGG",
        displayName: "GoroGoro",
        avatarUrl: nil,
        createdAt: Date(timeIntervalSince1970: 1_600_000_000)
    )

    nonisolated static let guilds: [Guild] = [
        Guild(id: "g001", discordId: "111111111111111111", name: "Valorant JP",
              iconUrl: nil, memberCount: 1234, userRole: .admin, category: .gaming),
        Guild(id: "g002", discordId: "222222222222222222", name: "星宮ルナFanclub",
              iconUrl: nil, memberCount: 3892, userRole: .owner, category: .vtuber),
        Guild(id: "g003", discordId: "333333333333333333", name: "DevHub Support",
              iconUrl: nil, memberCount: 567, userRole: .admin, category: .support),
        Guild(id: "g004", discordId: "444444444444444444", name: "Premium Shop",
              iconUrl: nil, memberCount: 2103, userRole: .owner, category: .shop),
        Guild(id: "g005", discordId: "555555555555555555", name: "Anime Lounge",
              iconUrl: nil, memberCount: 8455, userRole: .moderator, category: .community),
        Guild(id: "g006", discordId: "666666666666666666", name: "Staff HQ",
              iconUrl: nil, memberCount: 42, userRole: .owner, category: .community),
    ]

    nonisolated static let channels: [Channel] = [
        Channel(id: "c001", guildId: "g001", name: "general",       type: .text,         categoryName: "General",    botCanSend: true),
        Channel(id: "c002", guildId: "g001", name: "announcements", type: .announcement, categoryName: "General",    botCanSend: true),
        Channel(id: "c003", guildId: "g001", name: "valorant-tips", type: .text,         categoryName: "Gaming",     botCanSend: true),
        Channel(id: "c004", guildId: "g001", name: "vc-lobby",      type: .voice,        categoryName: "Voice",      botCanSend: false),
        Channel(id: "c005", guildId: "g001", name: "staff-only",    type: .text,         categoryName: "Staff",      botCanSend: false),
        Channel(id: "c006", guildId: "g002", name: "general",       type: .text,         categoryName: "General",    botCanSend: true),
        Channel(id: "c007", guildId: "g002", name: "luna-fan-art",  type: .text,         categoryName: "Fan Content",botCanSend: true),
        Channel(id: "c008", guildId: "g002", name: "stream-notify", type: .announcement, categoryName: "General",    botCanSend: true),
    ]

    private static func date(daysAgo: Int = 0, hoursAgo: Int = 0, minutesAgo: Int = 0) -> Date {
        Calendar.current.date(byAdding: .minute, value: -(daysAgo * 1440 + hoursAgo * 60 + minutesAgo), to: .now)!
    }

    nonisolated static let embeds: [EmbedModel] = [
        EmbedModel(id: "e001", name: "Welcome Message",
                   title: "Welcome to Valorant JP! 🎮", embedUrl: nil,
                   description: "Read the rules, have fun, and GG!", colorHex: 0x7C3AED,
                   fields: [
                    EmbedFieldModel(id: "ef001", name: "Rules", value: "#rules", inline: true),
                    EmbedFieldModel(id: "ef002", name: "Support", value: "#help", inline: true),
                    EmbedFieldModel(id: "ef003", name: "Announcements", value: "Latest patch notes in #announcements", inline: false),
                   ],
                   imageUrl: nil, thumbnailUrl: nil,
                   footerText: "BotForge", footerIconUrl: nil, showTimestamp: false,
                   createdAt: date(daysAgo: 10), updatedAt: date(daysAgo: 2)),

        EmbedModel(id: "e002", name: "Stream Started",
                   title: "星宮ルナ is LIVE! 🎤", embedUrl: nil,
                   description: "Playing Minecraft tonight — come watch!", colorHex: 0xEC4899,
                   fields: [],
                   imageUrl: "https://example.com/stream.jpg", thumbnailUrl: nil,
                   footerText: "Twitch · Now", footerIconUrl: nil, showTimestamp: true,
                   createdAt: date(daysAgo: 5), updatedAt: date(daysAgo: 1)),

        EmbedModel(id: "e003", name: "Tournament Open",
                   title: "⚔️ VALORANT TOURNAMENT", embedUrl: nil,
                   description: "Registration is open! Prize pool: ¥50,000", colorHex: 0x23A55A,
                   fields: [
                    EmbedFieldModel(id: "ef004", name: "Date", value: "June 15, 2026", inline: true),
                    EmbedFieldModel(id: "ef005", name: "Format", value: "5v5 Single Elim", inline: true),
                    EmbedFieldModel(id: "ef006", name: "How to Join", value: "DM @staff with your team", inline: false),
                   ],
                   imageUrl: nil, thumbnailUrl: nil,
                   footerText: "Deadline: June 10", footerIconUrl: nil, showTimestamp: false,
                   createdAt: date(daysAgo: 3), updatedAt: date(daysAgo: 3)),

        EmbedModel(id: "e004", name: "Shop Update",
                   title: "🛍 New Merch Drop!", embedUrl: nil,
                   description: "Limited edition hoodies now available. Only 50 in stock!", colorHex: 0xF59E0B,
                   fields: [
                    EmbedFieldModel(id: "ef007", name: "Price", value: "¥4,800", inline: true),
                    EmbedFieldModel(id: "ef008", name: "Stock", value: "50 remaining", inline: true),
                   ],
                   imageUrl: "https://example.com/hoodie.jpg", thumbnailUrl: nil,
                   footerText: "Premium Shop", footerIconUrl: nil, showTimestamp: false,
                   createdAt: date(daysAgo: 1), updatedAt: date(daysAgo: 1)),

        EmbedModel(id: "e005", name: "Server Rules",
                   title: "📋 Server Rules", embedUrl: nil,
                   description: "Please read all rules carefully.", colorHex: 0xEF4444,
                   fields: [
                    EmbedFieldModel(id: "ef009", name: "Rule 1", value: "Be respectful to everyone", inline: false),
                    EmbedFieldModel(id: "ef010", name: "Rule 2", value: "No spam or self-promotion", inline: false),
                    EmbedFieldModel(id: "ef011", name: "Rule 3", value: "Keep content SFW", inline: false),
                   ],
                   imageUrl: nil, thumbnailUrl: nil,
                   footerText: "Last updated", footerIconUrl: nil, showTimestamp: true,
                   createdAt: date(daysAgo: 30), updatedAt: date(daysAgo: 7)),
    ]

    nonisolated static let members: [Member] = [
        Member(id: "m001", guildId: "g001", username: "luna_chan", displayName: "Luna 🌙",
               discriminator: "0", globalName: "Luna 🌙", nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil, publicFlags: 0, isBot: false,
               roles: ["Admin", "Booster"], joinedAt: date(daysAgo: 300), createdAt: date(daysAgo: 1000), isBoosting: true, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .online),
        Member(id: "m002", guildId: "g001", username: "valorant_pro99", displayName: "ProPlayer99",
               discriminator: "1234", globalName: nil, nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil, publicFlags: 0, isBot: false,
               roles: ["Member"], joinedAt: date(daysAgo: 180), createdAt: date(daysAgo: 900), isBoosting: false, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .online),
        Member(id: "m003", guildId: "g001", username: "tanaka_taro", displayName: "田中太郎",
               discriminator: "0", globalName: "田中太郎", nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil, publicFlags: 0, isBot: false,
               roles: ["Moderator", "OG"], joinedAt: date(daysAgo: 400), createdAt: date(daysAgo: 1100), isBoosting: false, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .idle),
        Member(id: "m004", guildId: "g001", username: "sakura_hana", displayName: "桜花",
               discriminator: "5678", globalName: nil, nick: "桜花", avatarUrl: nil, bannerUrl: nil, accentColor: 0xFF69B4, publicFlags: 0, isBot: false,
               roles: ["Member", "Booster"], joinedAt: date(daysAgo: 90), createdAt: date(daysAgo: 800), isBoosting: true, boostSince: date(daysAgo: 30),
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .dnd),
        Member(id: "m005", guildId: "g001", username: "kenji_dev", displayName: "KenjiDev",
               discriminator: "0", globalName: "KenjiDev", nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil, publicFlags: 0, isBot: false,
               roles: ["Admin"], joinedAt: date(daysAgo: 500), createdAt: date(daysAgo: 1200), isBoosting: false, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .offline),
        Member(id: "m006", guildId: "g001", username: "yuki_gamer", displayName: "雪ゲーマー",
               discriminator: "0", globalName: "雪ゲーマー", nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil, publicFlags: 0, isBot: false,
               roles: ["Member"], joinedAt: date(daysAgo: 45), createdAt: date(daysAgo: 600), isBoosting: false, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .online),
        Member(id: "m007", guildId: "g002", username: "luna_watcher", displayName: "LunaWatcher",
               discriminator: "0", globalName: "LunaWatcher", nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil, publicFlags: 0, isBot: false,
               roles: ["Verified Fan", "Booster"], joinedAt: date(daysAgo: 200), createdAt: date(daysAgo: 700), isBoosting: true, boostSince: date(daysAgo: 10),
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .online),
        Member(id: "m008", guildId: "g002", username: "mochi_kun", displayName: "もちくん",
               discriminator: "0", globalName: "もちくん", nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil, publicFlags: 0, isBot: false,
               roles: ["Member"], joinedAt: date(daysAgo: 60), createdAt: date(daysAgo: 500), isBoosting: false, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .idle),
        Member(id: "m009", guildId: "g001", username: "rika_chan", displayName: "リカちゃん",
               discriminator: "0", globalName: "リカちゃん", nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil, publicFlags: 0, isBot: false,
               roles: ["Member"], joinedAt: date(daysAgo: 15), createdAt: date(daysAgo: 400), isBoosting: false, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .offline),
        Member(id: "m010", guildId: "g001", username: "shadow_x", displayName: "ShadowX",
               discriminator: "9999", globalName: nil, nick: "ShadowX", avatarUrl: nil, bannerUrl: nil, accentColor: 0x4B0082, publicFlags: 0, isBot: false,
               roles: ["Member"], joinedAt: date(daysAgo: 7), createdAt: date(daysAgo: 300), isBoosting: false, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0, communicationDisabledUntil: nil, status: .online),
    ]

    nonisolated static let tickets: [Ticket] = [
        Ticket(id: "t001", guildId: "g003", channelId: "c001", openedBy: "m002",
               subject: "Bot not responding to /help command", status: .open,
               priority: .high, openedAt: date(hoursAgo: 2), lastMessageAt: date(hoursAgo: 1), messageCount: 3),
        Ticket(id: "t002", guildId: "g003", channelId: "c001", openedBy: "m003",
               subject: "Embed color not saving properly", status: .pending,
               priority: .medium, openedAt: date(daysAgo: 1), lastMessageAt: date(hoursAgo: 4), messageCount: 7),
        Ticket(id: "t003", guildId: "g003", channelId: "c001", openedBy: "m006",
               subject: "Cannot add bot to new server", status: .open,
               priority: .urgent, openedAt: date(hoursAgo: 6), lastMessageAt: date(hoursAgo: 5), messageCount: 2),
        Ticket(id: "t004", guildId: "g003", channelId: "c001", openedBy: "m007",
               subject: "Scheduled message sent twice", status: .pending,
               priority: .medium, openedAt: date(daysAgo: 2), lastMessageAt: date(daysAgo: 1), messageCount: 5),
        Ticket(id: "t005", guildId: "g003", channelId: "c001", openedBy: "m008",
               subject: "Auto-response triggering on own messages", status: .closed,
               priority: .low, openedAt: date(daysAgo: 5), lastMessageAt: date(daysAgo: 3), messageCount: 9),
        Ticket(id: "t006", guildId: "g003", channelId: "c001", openedBy: "m009",
               subject: "Request: add reaction role support", status: .closed,
               priority: .low, openedAt: date(daysAgo: 7), lastMessageAt: date(daysAgo: 6), messageCount: 4),
    ]

    nonisolated static let ticketMessages: [TicketMessage] = [
        // t001 のメッセージ
        TicketMessage(id: "tm001", ticketId: "t001", userId: "m002", username: "ShadowFox",
                      content: "/helpコマンドを打っても反応がありません。他のコマンドは動いています。", isStaff: false,
                      createdAt: date(hoursAgo: 2)),
        TicketMessage(id: "tm002", ticketId: "t001", userId: "staff001", username: "Admin",
                      content: "ご報告ありがとうございます。Botの設定を確認します。少々お待ちください。", isStaff: true,
                      createdAt: date(minutesAgo: 90)),
        TicketMessage(id: "tm003", ticketId: "t001", userId: "m002", username: "ShadowFox",
                      content: "了解です。よろしくお願いします。", isStaff: false,
                      createdAt: date(minutesAgo: 60)),
        // t002 のメッセージ
        TicketMessage(id: "tm004", ticketId: "t002", userId: "m003", username: "NeonByte",
                      content: "Embedのカラーを変更して保存しても、次回開いたときに元に戻っています。", isStaff: false,
                      createdAt: date(hoursAgo: 26)),
        TicketMessage(id: "tm005", ticketId: "t002", userId: "staff001", username: "Admin",
                      content: "再現確認できました。修正対応中です。", isStaff: true,
                      createdAt: date(hoursAgo: 20)),
        TicketMessage(id: "tm006", ticketId: "t002", userId: "m003", username: "NeonByte",
                      content: "ありがとうございます。修正完了したら教えてください。", isStaff: false,
                      createdAt: date(hoursAgo: 18)),
    ]

    nonisolated static let autoResponses: [AutoResponse] = [
        AutoResponse(id: "ar001", guildId: "g001", trigger: "!gg", response: "GG! Great game everyone! 🎮",
                     matchType: .exact, enabled: true, cooldownSeconds: 30, channelIds: []),
        AutoResponse(id: "ar002", guildId: "g001", trigger: "discord invite", response: "No invite links please! Check #rules.",
                     matchType: .contains, enabled: true, cooldownSeconds: 0, channelIds: []),
        AutoResponse(id: "ar003", guildId: "g002", trigger: "stream start", response: "🎤 Luna-chan is LIVE! Go check it out!",
                     matchType: .contains, enabled: true, cooldownSeconds: 60, channelIds: ["c008"]),
        AutoResponse(id: "ar004", guildId: "g001", trigger: "!rank", response: "Check your rank at <rank-site>! 📊",
                     matchType: .exact, enabled: false, cooldownSeconds: 10, channelIds: []),
        AutoResponse(id: "ar005", guildId: "g003", trigger: "(?i)help me", response: "Please open a ticket with /ticket! We'll help you ASAP.",
                     matchType: .regex, enabled: true, cooldownSeconds: 0, channelIds: []),
    ]

    nonisolated static let scheduledMessages: [ScheduledMessage] = [
        ScheduledMessage(id: "sm001", guildId: "g001", channelId: "c002", embedId: "e003",
                         title: "", scheduledFor: Calendar.current.date(byAdding: .day, value: 5, to: .now)!,
                         repeatRule: .none, status: .pending),
        ScheduledMessage(id: "sm002", guildId: "g002", channelId: "c008", embedId: "e002",
                         title: "", scheduledFor: Calendar.current.date(byAdding: .hour, value: 3, to: .now)!,
                         repeatRule: .none, status: .pending),
        ScheduledMessage(id: "sm003", guildId: "g001", channelId: "c001", embedId: "e006",
                         title: "週次お知らせ", scheduledFor: date(daysAgo: 1), repeatRule: .weekly, status: .sent),
        ScheduledMessage(id: "sm004", guildId: "g004", channelId: "c001", embedId: "e004",
                         title: "", scheduledFor: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
                         repeatRule: .none, status: .cancelled),
    ]

    nonisolated static let auditLogs: [AuditLog] = [
        AuditLog(id: "al001", guildId: "g001", userId: "m001", action: "member_ban",
                 target: "spammer_user", timestamp: date(hoursAgo: 1), details: "Reason: Spam"),
        AuditLog(id: "al002", guildId: "g001", userId: "u001", action: "embed_sent",
                 target: "#general", timestamp: date(hoursAgo: 2), details: "Embed: Welcome Message"),
        AuditLog(id: "al003", guildId: "g001", userId: "m003", action: "role_added",
                 target: "m006", timestamp: date(hoursAgo: 3), details: "Role: Moderator"),
        AuditLog(id: "al004", guildId: "g001", userId: "u001", action: "bot_restart",
                 target: "BotForge", timestamp: date(daysAgo: 1), details: nil),
        AuditLog(id: "al005", guildId: "g001", userId: "m001", action: "member_kick",
                 target: "troll_user", timestamp: date(daysAgo: 1), details: "Reason: Harassment"),
        AuditLog(id: "al006", guildId: "g001", userId: "u001", action: "command_toggle",
                 target: "/ban", timestamp: date(daysAgo: 2), details: "Enabled: true"),
    ]

    nonisolated static let notifications: [AppNotification] = [
        AppNotification(id: "n001", type: .ticket, title: "New Ticket", body: "ShadowX opened a ticket: \"Cannot add bot\"",
                        guildId: "g003", read: false, timestamp: date(hoursAgo: 1)),
        AppNotification(id: "n002", type: .mention, title: "You were mentioned", body: "@GoroGoro check this out in #general",
                        guildId: "g001", read: false, timestamp: date(hoursAgo: 2)),
        AppNotification(id: "n003", type: .memberJoin, title: "New member", body: "雪ゲーマー joined Valorant JP",
                        guildId: "g001", read: false, timestamp: date(hoursAgo: 3)),
        AppNotification(id: "n004", type: .scheduledSend, title: "Message Sent", body: "Tournament embed sent to #announcements",
                        guildId: "g001", read: true, timestamp: date(daysAgo: 1)),
        AppNotification(id: "n005", type: .system, title: "Bot Update", body: "BotForge v5.1.0 is now live!",
                        guildId: nil, read: true, timestamp: date(daysAgo: 1)),
        AppNotification(id: "n006", type: .botStatus, title: "Bot Back Online", body: "Maintenance complete. Latency: 38ms",
                        guildId: nil, read: true, timestamp: date(daysAgo: 2)),
    ]

    nonisolated static let botStatus = BotStatus(isOnline: true, latency: 42, uptime: 99.9, activeGuilds: 6, totalCommands: 892)

    nonisolated static let slashCommands: [SlashCommand] = [
        SlashCommand(id: "sc001", name: "help", description: "Show available commands", options: [], enabled: true, usageCount: 312),
        SlashCommand(id: "sc002", name: "ticket", description: "Open a support ticket", options: ["subject", "priority"], enabled: true, usageCount: 87),
        SlashCommand(id: "sc003", name: "rank", description: "Show your server rank", options: ["user"], enabled: true, usageCount: 245),
        SlashCommand(id: "sc004", name: "purge", description: "Delete multiple messages", options: ["amount", "channel"], enabled: true, usageCount: 43),
        SlashCommand(id: "sc005", name: "warn", description: "Warn a member", options: ["user", "reason"], enabled: true, usageCount: 19),
        SlashCommand(id: "sc006", name: "mute", description: "Timeout a member", options: ["user", "duration", "reason"], enabled: false, usageCount: 8),
        SlashCommand(id: "sc007", name: "ban", description: "Ban a member", options: ["user", "reason", "delete_messages"], enabled: true, usageCount: 5),
        SlashCommand(id: "sc008", name: "stats", description: "Show server statistics", options: ["period"], enabled: true, usageCount: 134),
    ]

    static func analyticsStats(guildId: String) -> AnalyticsStats {
        AnalyticsStats(
            guildId: guildId,
            totalMembers: 16_287,
            memberGrowthPercent: 12.3,
            messagesToday: 4_521,
            messageGrowthPercent: 5.1,
            commandsUsed: 892,
            commandGrowthPercent: -2.8,
            activeTickets: 7,
            voiceMinutes: 3_840,
            memberHistory: [14200, 14500, 14900, 15300, 15600, 15900, 16287],
            messageHistory: [3200, 3800, 4100, 3900, 4300, 4200, 4521]
        )
    }
}
