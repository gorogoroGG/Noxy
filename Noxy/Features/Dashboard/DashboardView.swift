import SwiftUI

struct DashboardView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    // Bot status
    @State private var botStatus: BotStatus? = nil
    @State private var isBotStatusLoading = true
    @State private var isLoading = true

    // 通知フィード
    @State private var notifications: [HomeNotification] = []
    @State private var isNotifLoading = true
    @State private var showNotifSettings = false
    @State private var activeNotif: HomeNotification? = nil  // タップした通知

    // クイックアクション
    private let quickPrefs = HomeQuickActionsPrefs.shared
    @State private var showEditActions = false

    // アクション用の単一シート
    @State private var activeAction: QuickActionDef? = nil

    // サーバー選択
    @State private var showGuildPicker = false

    // サーバーの状況
    @State private var recentActivities: [ActivityItem_] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    VStack(alignment: .leading, spacing: .spacing20) {
                        headerSection
                        if isBotStatusLoading {
                            botStatusLoadingCard.transition(.opacity)
                        } else if let status = botStatus {
                            botStatusCard(status).transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .leading)),
                                removal: .opacity
                            ))
                        }
                        notifFeedSection
                        quickActionsSection
                        recentActivitySection
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isBotStatusLoading)
                    .padding(.vertical)
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showGuildPicker) {
                GuildPickerSheet(guilds: appState.guilds, selectedId: appState.selectedGuildId) { g in
                    Task { await appState.switchServer(to: g) }
                }
            }
            .sheet(isPresented: $showNotifSettings) {
                NotifSettingsSheet()
            }
            .sheet(isPresented: $showEditActions) {
                EditQuickActionsSheet()
            }
            .sheet(item: $activeAction) { action in
                actionSheet(for: action)
            }
            .sheet(item: $activeNotif) { notif in
                notifDetailSheet(for: notif)
            }
            .refreshable { await loadData() }
        }
        .task { await loadData() }
        // ギルド切り替え時に通知・状況を再取得
        .onChange(of: appState.selectedGuildId) { _, newId in
            guard !newId.isEmpty else { return }
            Task {
                async let notifsTask   = fetchNotifications(guildId: newId)
                async let activityTask = fetchRecentActivity(guildId: newId)
                async let statusTask   = services.bot.fetchStatus()
                let fetchedStatus = try? await statusTask
                let (notifs, activity) = await (notifsTask, activityTask)
                withAnimation {
                    botStatus        = fetchedStatus
                    isBotStatusLoading = false
                    notifications    = notifs
                    isNotifLoading   = false
                    recentActivities = activity
                }
            }
        }
    }

    // MARK: - Header

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 12 { return "おはようございます" }
        if h < 18 { return "こんにちは" }
        return "こんばんは"
    }

    /// selectedGuildId に対応するGuildオブジェクトを返す
    /// selectedGuild と selectedGuildId が一致しない場合は guilds リストから補完する
    private var currentGuild: Guild? {
        if let g = appState.selectedGuild, g.id == appState.selectedGuildId { return g }
        return appState.guilds.first { $0.id == appState.selectedGuildId }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Text(greeting + " 👋")
                .font(.bodySmall).foregroundStyle(Color.textSecondary)

            Button { showGuildPicker = true } label: {
                HStack(spacing: .spacing10) {
                    if let guild = currentGuild {
                        GuildIconView(guild: guild, size: 32)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentIndigo.opacity(0.15)).frame(width: 32, height: 32)
                            .overlay(Image(systemName: "server.rack").font(.captionRegular).foregroundStyle(Color.accentIndigo))
                    }
                    Text(currentGuild?.name ?? (appState.selectedGuildId.isEmpty ? "サーバーを選択" : "読込中..."))
                        .font(.bodySmall).fontWeight(.semibold).lineLimit(1).foregroundStyle(Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, .spacing12).padding(.vertical, .spacing10)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                .overlay(RoundedRectangle(cornerRadius: .cornerRadiusSmall).stroke(Color.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: - Bot Status

    private var botStatusLoadingCard: some View {
        HStack(spacing: .spacing16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentIndigo, Color.accentPurple],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Image("icon2").resizable().scaledToFit().frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: .spacing4) {
                Text("Noxy Bot").font(.titleMedium).foregroundStyle(Color.textPrimary)
                BotStatusScanIndicator()
            }
            Spacer()
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .padding(.horizontal)
    }

    private func botStatusCard(_ status: BotStatus) -> some View {
        HStack(spacing: .spacing16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentIndigo, Color.accentPurple],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Image("icon2").resizable().scaledToFit().frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: .spacing4) {
                Text("Noxy Bot").font(.titleMedium).foregroundStyle(Color.textPrimary)
                HStack(spacing: .spacing6) {
                    Circle().fill(status.isOnline ? Color.accentGreen : Color.accentPink).frame(width: 8, height: 8)
                    Text(status.isOnline ? "オンライン" : "オフライン")
                        .font(.captionRegular)
                        .foregroundStyle(status.isOnline ? Color.accentGreen : Color.accentPink)
                    if status.isOnline {
                        Text("· \(status.latency)ms").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .padding(.horizontal)
    }

    // MARK: - Notification Feed

    private var visibleNotifs: [HomeNotification] {
        let dismissed = DismissedNotifsStore.shared
        let settings  = HomeNotifSettings.shared
        let enabled   = Set(settings.enabledTypes.map(\.rawValue))
        return notifications.filter { !dismissed.isDismissed($0.id) && enabled.contains($0.type.rawValue) }
    }

    private var notifFeedSection: some View {
        VStack(alignment: .leading, spacing: .spacing10) {
            // ヘッダー
            HStack {
                Text("お知らせ")
                    .font(.captionRegular).fontWeight(.semibold).foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, .spacing16)

                if !visibleNotifs.isEmpty {
                    Text("\(visibleNotifs.count)件")
                        .font(.captionSmall).fontWeight(.bold).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.accentRed).clipShape(Capsule())
                }
                Spacer()
                Button { showNotifSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14)).foregroundStyle(Color.textTertiary)
                }
                .padding(.trailing, .spacing16)
            }

            if isNotifLoading {
                HStack { Spacer(); ProgressView().tint(Color.accentIndigo); Spacer() }
                    .frame(height: 60)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    .padding(.horizontal)
            } else if visibleNotifs.isEmpty {
                HStack(spacing: .spacing10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18)).foregroundStyle(Color.accentGreen)
                    Text("すべて確認済みです")
                        .font(.bodySmall).foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.spacing16)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleNotifs.prefix(10).enumerated()), id: \.element.id) { idx, notif in
                        NotifFeedRow(
                            notif: notif,
                            onTap: { activeNotif = notif },
                            onDismiss: {
                                withAnimation(.spring(duration: 0.3)) {
                                    DismissedNotifsStore.shared.dismiss(notif.id)
                                    notifications = notifications
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        )
                        if idx < min(visibleNotifs.count, 10) - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack {
                Text("クイックアクション")
                    .font(.captionRegular).fontWeight(.semibold).foregroundStyle(Color.textSecondary)
                    .padding(.leading, .spacing16)
                Spacer()
                Button { showEditActions = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.system(size: 11, weight: .semibold))
                        Text("編集").font(.captionRegular).fontWeight(.medium)
                    }
                    .foregroundStyle(Color.accentIndigo)
                }
                .padding(.trailing, .spacing16)
            }

            if quickPrefs.selected.isEmpty {
                Text("クイックアクションを追加してください")
                    .font(.bodySmall).foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, .spacing24)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    .padding(.horizontal)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: .spacing12),
                              GridItem(.flexible(), spacing: .spacing12)],
                    spacing: .spacing12
                ) {
                    ForEach(quickPrefs.selected) { action in
                        QuickActionCard(
                            icon: action.icon, title: action.title,
                            subtitle: action.subtitle, color: action.color,
                            isLocked: action.isLocked
                        ) {
                            guard !action.isLocked else { return }
                            activeAction = action
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Action Sheet Routing

    @ViewBuilder
    private func actionSheet(for action: QuickActionDef) -> some View {
        let guildId = appState.selectedGuildId
        NavigationStack {
            Group {
                switch action {
                case .embedCreate:
                    EmbedListView().navigationTitle("Embed")
                case .tickets:
                    TicketsCoordinatorView(guildId: guildId).navigationTitle("チケット一覧")
                case .members:
                    MembersListView(guildId: guildId).navigationTitle("メンバー")
                case .moderation:
                    ModerationCenterView()
                case .reactionRoles:
                    ReactionRolesView()
                case .welcomeMsg:
                    WelcomeMessageView()
                case .giveaways:
                    LockedFeaturePlaceholder(title: "ギブアウェイ", icon: "gift.fill", color: .accentPink)
                case .shop:
                    ShopsListView(guildId: guildId)
                case .analytics:
                    AnalyticsView(guildId: guildId)
                case .monitor:
                    MonitorView()
                case .tempVC:
                    TempVCListView(guildId: guildId)
                case .statChannels:
                    StatChannelsView(guildId: guildId)
                case .roles:
                    RolesListView(guildId: guildId).navigationTitle("ロール")
                case .auditLog:
                    AuditLogView(guildId: guildId)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { activeAction = nil }
                }
            }
        }
        .environment(appState)
        .environment(\.services, services)
    }

    // MARK: - Notification Detail Sheet

    @ViewBuilder
    private func notifDetailSheet(for notif: HomeNotification) -> some View {
        let guildId = appState.selectedGuildId
        switch notif.type {
        case .ticket:
            TicketDetailLoader(ticketId: notif.sourceId, guildId: guildId)
                .environment(appState)
                .environment(\.services, services)
        case .order:
            OrderDetailLoader(orderId: notif.sourceId, guildId: guildId)
                .environment(appState)
                .environment(\.services, services)
        case .moderation:
            NavigationStack {
                ModerationCenterView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完了") { activeNotif = nil }
                        }
                    }
            }
            .environment(appState)
            .environment(\.services, services)
        case .giveaway:
            NavigationStack {
                LockedFeaturePlaceholder(title: "ギブアウェイ", icon: "gift.fill", color: .accentPink)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完了") { activeNotif = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(spacing: 0) {
            Text("サーバーの状況")
                .font(.captionRegular).fontWeight(.semibold).foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, .spacing16)
            if recentActivities.isEmpty {
                VStack(spacing: .spacing8) {
                    Image(systemName: "chart.bar.fill").font(.system(size: 28)).foregroundStyle(Color.textTertiary)
                    Text("アクティビティはまだありません").font(.bodySmall).foregroundStyle(Color.textSecondary)
                    Text("Botの操作やイベントがここに表示されます").font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, .spacing24)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal).padding(.top, .spacing10)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentActivities.prefix(5).enumerated()), id: \.element.id) { idx, item in
                        ActivityRow(activity: item)
                        if idx < min(recentActivities.count, 5) - 1 {
                            Divider().background(Color.border).padding(.leading, 56)
                        }
                    }
                }
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal).padding(.top, .spacing10)
            }

            NavigationLink(destination: MonitorView()) {
                HStack {
                    Image(systemName: "waveform").font(.system(size: 14)).foregroundStyle(Color.accentGreen)
                    Text("モニターを開く").font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.accentGreen)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.textTertiary)
                }
                .padding(.spacing12)
            }
            .buttonStyle(.plain).padding(.top, .spacing8).padding(.horizontal)
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        isBotStatusLoading = true
        isNotifLoading = true
        botStatus = nil

        let fetchedGuilds = (try? await services.guilds.fetchAll()) ?? []
        let botGuilds     = (try? await DiscordService().fetchBotGuilds()) ?? []
        let botGuildIds   = Set(botGuilds.map(\.id))
        appState.guilds   = fetchedGuilds

        let storedId = appState.selectedGuildId
        var targetGuildId = storedId
        if !fetchedGuilds.isEmpty {
            // 前回選択したサーバーが有効（Botが入っている）ならそれを維持
            // 無効 or 未選択なら最初のBotサーバーにフォールバック
            // storedId が fetchedGuilds にあれば無条件に優先（Botが入っていなくても）
            // なければ Botが入っている最初のサーバー → それもなければ最初のサーバー
            let g = fetchedGuilds.first { $0.id == storedId }
                ?? fetchedGuilds.first { botGuildIds.contains($0.id) }
                ?? fetchedGuilds.first
            if let g {
                appState.selectedGuildId = g.id
                appState.selectedGuild   = g
                targetGuildId            = g.id
            }
        }
        isLoading = false

        async let statusTask   = services.bot.fetchStatus()
        async let notifsTask   = fetchNotifications(guildId: targetGuildId)
        async let activityTask = fetchRecentActivity(guildId: targetGuildId)

        let fetchedStatus = try? await statusTask
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            botStatus          = fetchedStatus
            isBotStatusLoading = false
        }
        let (notifs, activity) = await (notifsTask, activityTask)
        withAnimation {
            notifications     = notifs
            isNotifLoading    = false
            recentActivities  = activity
        }
    }

    // MARK: - Notification Fetching

    private func fetchNotifications(guildId: String) async -> [HomeNotification] {
        guard !guildId.isEmpty else { return [] }
        async let ticketsTask = fetchTicketNotifs(guildId: guildId)
        async let ordersTask  = fetchOrderNotifs(guildId: guildId)
        async let modTask     = fetchModerationNotifs(guildId: guildId)
        let tickets  = await ticketsTask
        let orders   = await ordersTask
        let mods     = await modTask
        return (tickets + orders + mods).sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchTicketNotifs(guildId: String) async -> [HomeNotification] {
        struct T: Decodable { let id: String; let subject: String; let openedAt: String }
        guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/tickets?guild_id=\(guildId)&status=open") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: DiscordConfig.makeWorkerRequest(url: url)),
              let items = try? JSONDecoder().decode([T].self, from: data) else { return [] }
        let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmt2 = ISO8601DateFormatter()
        return items.map { t in
            let date = fmt.date(from: t.openedAt) ?? fmt2.date(from: t.openedAt) ?? .now
            return HomeNotification(id: "ticket_\(t.id)", sourceId: t.id, type: .ticket,
                                    title: "新着チケット", detail: t.subject, createdAt: date)
        }
    }

    private func fetchOrderNotifs(guildId: String) async -> [HomeNotification] {
        struct O: Decodable { let id: String; let productName: String; let status: String; let createdAt: String
            enum CodingKeys: String, CodingKey { case id; case productName = "product_name"; case status; case createdAt = "created_at" }
        }
        guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/orders?guild_id=\(guildId)&status=pending") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: DiscordConfig.makeWorkerRequest(url: url)),
              let items = try? JSONDecoder().decode([O].self, from: data) else { return [] }
        let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmt2 = ISO8601DateFormatter()
        return items.map { o in
            let date = fmt.date(from: o.createdAt) ?? fmt2.date(from: o.createdAt) ?? .now
            return HomeNotification(id: "order_\(o.id)", sourceId: o.id, type: .order,
                                    title: "新規注文", detail: o.productName, createdAt: date)
        }
    }

    private func fetchModerationNotifs(guildId: String) async -> [HomeNotification] {
        let warnings = (try? await ModerationService().fetchWarnings(guildId: guildId)) ?? []
        return warnings.filter { !$0.isRevoked }.map { w in
            HomeNotification(id: "modwarn_\(w.id)", sourceId: w.id, type: .moderation,
                             title: "警告: \(w.displayName)", detail: w.reason, createdAt: w.createdAt)
        }
    }

    private func fetchRecentActivity(guildId: String) async -> [ActivityItem_] {
        guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/recent-activity?guild_id=\(guildId)") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: DiscordConfig.makeWorkerRequest(url: url)),
              let items = try? JSONDecoder().decode([ActivityItem_].self, from: data) else { return [] }
        return items
    }

    struct ActivityItem_: Identifiable, Codable {
        var id = UUID()
        var icon: String
        var text: String
        var timeAgo: String
        enum CodingKeys: String, CodingKey { case icon, text, timeAgo }
    }
}

// MARK: - NotifFeedRow

private struct NotifFeedRow: View {
    let notif: HomeNotification
    let onTap: () -> Void
    let onDismiss: () -> Void

    private var timeAgo: String {
        let diff = Int(Date.now.timeIntervalSince(notif.createdAt))
        if diff < 60  { return "たった今" }
        if diff < 3600 { return "\(diff / 60)分前" }
        if diff < 86400 { return "\(diff / 3600)時間前" }
        return "\(diff / 86400)日前"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: .spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(notif.type.color.opacity(0.14)).frame(width: 36, height: 36)
                    Image(systemName: notif.type.icon)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(notif.type.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: .spacing6) {
                        Text(notif.type.label)
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(notif.type.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(notif.type.color.opacity(0.12)).clipShape(Capsule())
                        Text(timeAgo).font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                    Text(notif.title)
                        .font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.textPrimary).lineLimit(1)
                    Text(notif.detail)
                        .font(.captionSmall).foregroundStyle(Color.textSecondary).lineLimit(1)
                }

                Spacer()

                // × ボタン（タップでこの通知のみ削除）
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Color.bgElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // タップ可能を示すシェブロン
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, .spacing16)
            .padding(.vertical, .spacing12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NotifSettingsSheet

private struct NotifSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = HomeNotifSettings.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    toggleRow("チケット", icon: "ticket.fill", color: .accentOrange,
                              binding: Binding(get: { settings.showTickets }, set: { settings.showTickets = $0 }))
                    toggleRow("ショップ注文", icon: "cart.fill", color: .accentGreen,
                              binding: Binding(get: { settings.showOrders }, set: { settings.showOrders = $0 }))
                    toggleRow("モデレーション", icon: "exclamationmark.triangle.fill", color: .accentRed,
                              binding: Binding(get: { settings.showModeration }, set: { settings.showModeration = $0 }))
                    toggleRow("ギブアウェイ", icon: "gift.fill", color: .accentPink,
                              binding: Binding(get: { settings.showGiveaways }, set: { settings.showGiveaways = $0 }))
                } header: {
                    Text("表示する通知の種類")
                } footer: {
                    Text("オフにした種類の通知は「要対応事項」に表示されません。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("通知の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() }.fontWeight(.semibold) }
            }
        }
    }

    private func toggleRow(_ label: String, icon: String, color: Color, binding: Binding<Bool>) -> some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon).font(.captionRegular).foregroundStyle(color)
                .frame(width: 28, height: 28).background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(label).font(.bodySmall).foregroundStyle(Color.textPrimary)
            Spacer()
            Toggle("", isOn: binding).labelsHidden().tint(Color.accentIndigo)
        }
    }
}

// MARK: - EditQuickActionsSheet

private struct EditQuickActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let prefs = HomeQuickActionsPrefs.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(QuickActionDef.allCases) { action in
                        let isLocked = action.isLocked
                        let isOn     = prefs.isSelected(action)
                        let canAdd   = prefs.canAdd(action)
                        Button {
                            guard !isLocked, isOn || canAdd else { return }
                            prefs.toggle(action)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: .spacing12) {
                                Image(systemName: action.icon)
                                    .font(.captionRegular)
                                    .foregroundStyle(isLocked ? Color.textTertiary : action.color)
                                    .frame(width: 28, height: 28)
                                    .background((isLocked ? Color.textTertiary : action.color).opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.title).font(.bodySmall)
                                        .foregroundStyle(isLocked ? Color.textTertiary : Color.textPrimary)
                                    Text(isLocked ? "近日公開" : action.subtitle)
                                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(Color.textTertiary).font(.system(size: 16))
                                } else if isOn {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentIndigo).font(.system(size: 20))
                                } else if !canAdd {
                                    Text("上限").font(.captionSmall).foregroundStyle(Color.textTertiary)
                                } else {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(Color.textTertiary).font(.system(size: 20))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(isLocked || (!isOn && !canAdd) ? 0.45 : 1)
                    }
                } header: {
                    Text("選択中: \(prefs.selected.count) / \(HomeQuickActionsPrefs.maxCount)")
                } footer: {
                    Text("最大\(HomeQuickActionsPrefs.maxCount)個まで選択できます。チェックを外すと削除されます。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("クイックアクションを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() }.fontWeight(.semibold) }
            }
        }
    }
}

// MARK: - Sub-components

private struct BotStatusScanIndicator: View {
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1
    @State private var pulseOpacity: Double = 0.55

    var body: some View {
        HStack(spacing: .spacing6) {
            ZStack {
                Circle().fill(Color.accentIndigo.opacity(pulseOpacity)).frame(width: 8, height: 8).scaleEffect(pulseScale)
                Circle().fill(Color.accentIndigo.opacity(0.55)).frame(width: 5, height: 5)
                Circle().trim(from: 0, to: 0.3)
                    .stroke(Color.accentIndigo, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 10, height: 10).rotationEffect(.degrees(rotation))
            }
            .frame(width: 14, height: 14)
            Text("スキャン中...").font(.captionRegular).foregroundStyle(Color.textTertiary)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { rotation = 360 }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulseScale = 2.2; pulseOpacity = 0 }
        }
    }
}

private struct ActivityRow: View {
    let activity: DashboardView.ActivityItem_
    var body: some View {
        HStack(spacing: .spacing12) {
            Text(activity.icon).font(.titleMedium).frame(width: 32, height: 32)
            Text(activity.text).font(.bodySmall).foregroundStyle(Color.textPrimary)
            Spacer()
            Text(activity.timeAgo).font(.captionSmall).foregroundStyle(Color.textTertiary)
        }
        .padding(.spacing12)
    }
}

private struct QuickActionCard: View {
    let icon: String; let title: String; let subtitle: String; let color: Color
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: .spacing8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon).font(.titleMedium)
                        .foregroundStyle(isLocked ? Color.textTertiary : color)
                        .frame(width: 44, height: 44)
                        .background((isLocked ? Color.textTertiary : color).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.textTertiary)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(isLocked ? Color.textTertiary : Color.textPrimary)
                    Text(isLocked ? "近日公開" : subtitle).font(.captionSmall)
                        .foregroundStyle(isLocked ? Color.textTertiary : Color.textSecondary)
                }
            }
            .padding(.spacing16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(Color.bgSurface.opacity(isLocked ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .overlay(
                isLocked
                    ? RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                        .stroke(Color.border, lineWidth: 1)
                    : nil
            )
        }
        .buttonStyle(isLocked ? AnyButtonStyle(.plain) : AnyButtonStyle(.scalePressStyle))
        .disabled(isLocked)
        .allowsHitTesting(!isLocked)
    }
}

private enum ButtonStyleKind { case plain, scalePressStyle }

private struct AnyButtonStyle: ButtonStyle {
    let kind: ButtonStyleKind
    init(_ kind: ButtonStyleKind) { self.kind = kind }
    func makeBody(configuration: Configuration) -> some View {
        switch kind {
        case .plain:
            configuration.label
        case .scalePressStyle:
            configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

// MARK: - Guild Picker Sheet

private struct GuildPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let guilds: [Guild]; let selectedId: String; let onSelect: (Guild) -> Void

    @State private var botGuildIds: Set<String> = []
    @State private var showInviteSheet = false
    @State private var isLoading = true
    private let discord = DiscordService()

    private var manageableGuilds: [Guild] { guilds.filter { $0.userRole == .owner && botGuildIds.contains($0.id) } }
    private var invitableGuilds:  [Guild] { guilds.filter { $0.userRole == .owner && !botGuildIds.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if showInviteSheet { InviteBotSheet(guilds: invitableGuilds, onBack: { showInviteSheet = false }) }
                else { mainList }
            }
            .background(Color(.systemGroupedBackground))
        }
        .task {
            botGuildIds = (try? await discord.fetchBotGuildIds()) ?? []
            isLoading = false
        }
    }

    private var mainList: some View {
        List {
            if manageableGuilds.isEmpty {
                Section {
                    VStack(spacing: .spacing16) {
                        Image(systemName: "server.rack").font(.system(size: 40)).foregroundStyle(Color.textTertiary)
                        Text("管理できるサーバーがありません").font(.bodyRegular).foregroundStyle(Color.textSecondary)
                        PrimaryButton("ボットをサーバーに追加", style: .filled, size: .medium) { showInviteSheet = true }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, .spacing32).listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(manageableGuilds) { guild in
                        Button { onSelect(guild); dismiss() } label: {
                            HStack(spacing: .spacing12) {
                                GuildIconView(guild: guild)
                                Text(guild.name).font(.bodyRegular).foregroundStyle(Color.textPrimary)
                                Spacer()
                                if guild.id == selectedId { Badge(text: "選択中", color: .accentIndigo) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: { Text("サーバーを選択") }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .navigationTitle("サーバー").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() } } }
        .safeAreaInset(edge: .bottom) {
            if !manageableGuilds.isEmpty {
                PrimaryButton("ボットを追加する", style: .outlined, size: .medium, icon: "plus") { showInviteSheet = true }
                    .padding().background(.regularMaterial)
            }
        }
    }
}

// MARK: - Guild Icon View

private struct GuildIconView: View {
    let guild: Guild; var size: CGFloat = 40

    var body: some View {
        Group {
            if let url = guild.iconUrl.flatMap(URL.init) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: fallbackIcon
                    }
                }
            } else { fallbackIcon }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22).fill(Color.accentIndigo.opacity(0.15))
            Text(String(guild.name.prefix(1))).font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(Color.accentIndigo)
        }
    }
}

// MARK: - Invite Bot Sheet

private struct InviteBotSheet: View {
    let guilds: [Guild]; let onBack: () -> Void

    var body: some View {
        List {
            if guilds.isEmpty {
                Section {
                    VStack(spacing: .spacing12) {
                        Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundStyle(Color.accentGreen)
                        Text("Botを追加できるサーバーはありません").font(.bodyRegular).foregroundStyle(Color.textSecondary)
                        Text("サーバーオーナー権限があるサーバーにのみ追加できます").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, .spacing24).listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(guilds) { guild in
                        HStack(spacing: .spacing12) {
                            GuildIconView(guild: guild)
                            Text(guild.name).font(.bodyRegular).foregroundStyle(Color.textPrimary)
                            Spacer()
                            Button {
                                Task {
                                    if let url = try? await DiscordService().inviteURL(guildId: guild.id) {
                                        await MainActor.run { UIApplication.shared.open(url) }
                                    }
                                }
                            } label: {
                                Text("追加").font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                                    .padding(.horizontal, .spacing16).padding(.vertical, .spacing6)
                                    .background(Color.accentIndigo).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: { Text("Bot を招待するサーバーを選択") }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .navigationTitle("ボットを追加").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { onBack() } label: {
                    HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("戻る") }
                }
            }
        }
    }
}

// MARK: - TicketDetailLoader（お知らせからのチケット詳細表示）

private struct TicketDetailLoader: View {
    let ticketId: String
    let guildId: String
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var ticket: Ticket? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("チケットを読込中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let ticket {
                    TicketDetailView(ticket: ticket, guildId: guildId, onUpdate: { _ in })
                } else {
                    VStack(spacing: .spacing16) {
                        Image(systemName: "exclamationmark.circle").font(.system(size: 40)).foregroundStyle(Color.textTertiary)
                        Text(errorMessage ?? "チケットが見つかりません").font(.bodySmall).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.bgPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
        .task {
            do {
                ticket = try await services.tickets.fetch(id: ticketId)
            } catch {
                errorMessage = "チケットの取得に失敗しました"
            }
            isLoading = false
        }
    }
}

// MARK: - OrderDetailLoader（お知らせからの注文詳細表示）

private struct OrderDetailLoader: View {
    let orderId: String
    let guildId: String
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var order: Order? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("注文を読込中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let order {
                    OrderDetailView(order: order, guildId: guildId, onUpdate: { _ in })
                } else {
                    VStack(spacing: .spacing16) {
                        Image(systemName: "exclamationmark.circle").font(.system(size: 40)).foregroundStyle(Color.textTertiary)
                        Text(errorMessage ?? "注文が見つかりません").font(.bodySmall).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.bgPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
        .task {
            do {
                order = try await services.shops.fetchOrder(id: orderId)
            } catch {
                errorMessage = "注文の取得に失敗しました"
            }
            isLoading = false
        }
    }
}

// MARK: - Locked Feature Placeholder

struct LockedFeaturePlaceholder: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: .spacing20) {
            ZStack {
                Circle().fill(color.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 32)).foregroundStyle(color.opacity(0.5))
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.textSecondary)
                    .clipShape(Circle())
                    .offset(x: 24, y: 24)
            }
            VStack(spacing: .spacing8) {
                Text(title)
                    .font(.titleMedium).foregroundStyle(Color.textPrimary)
                Text("近日公開予定の機能です")
                    .font(.bodySmall).foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
}
