import SwiftUI

// MARK: - Tab definition

private enum AppTab: Int, CaseIterable {
    case inbox    = 0
    case features = 1
    case members  = 2
    case settings = 3

    var label: String {
        switch self {
        case .inbox:    "ホーム"
        case .features: "機能"
        case .members:  "メンバー"
        case .settings: "設定"
        }
    }

    var icon: String {
        switch self {
        case .inbox:    "house.fill"
        case .features: "square.grid.2x2.fill"
        case .members:  "person.2.fill"
        case .settings: "gearshape.fill"
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @Environment(AuthManager.self)   private var authManager
    @Environment(\.services)         private var services
    @Environment(\.scenePhase)       private var scenePhase
    @Environment(AppState.self)      private var appState

    @State private var selectedTab: AppTab = .inbox
    @State private var inboxState = InboxState.shared

    var body: some View {
        Group {
            if !appState.isAppReady {
                Theme.Color.bg.ignoresSafeArea()
            } else if appState.isBotNotInAnyGuild {
                BotNotInGuildView()
            } else if appState.isBotOffline {
                BotOfflineView {
                    await refreshBotStatus()
                }
                .transition(.opacity)
            } else {
                ZStack {
                    tabContentView
                        .mockBanner()

                    if appState.isSwitchingServer {
                        ServerSwitchingOverlay(guildName: appState.switchingToName)
                            .transition(.opacity)
                            .zIndex(999)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: appState.isSwitchingServer)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isAppReady)
        .animation(.easeInOut(duration: 0.3), value: appState.isBotNotInAnyGuild)
        .animation(.easeInOut(duration: 0.3), value: appState.isBotOffline)
        .task(id: appState.needsReload) { await loadInitialData() }
        // 選択サーバーが決まる/切り替わるたびに、全データをスプラッシュ裏で先読みする
        .task(id: appState.selectedGuildId) { await prefetchGuildData(appState.selectedGuildId) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if appState.selectedGuild == nil, !appState.selectedGuildId.isEmpty {
                Task { await restoreSelectedGuild() }
            }
            Task { await recheckBotGuildsOnForeground() }
            Task { await inboxState.refresh(using: services.notifications) }
        }
        // ディープリンク受け口: noxy://inbox
        .onOpenURL { url in
            guard url.host == "inbox" || url.path == "/inbox" else { return }
            selectedTab = .inbox
        }
        // プロセス内通知経由（プッシュ通知デリゲートから送信可能）
        .onReceive(NotificationCenter.default.publisher(for: .openInboxTab)) { _ in
            selectedTab = .inbox
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContentView: some View {
        TabView(selection: $selectedTab) {
            InboxTabView()
                .tag(AppTab.inbox)

            FeaturesTabView()
                .tag(AppTab.features)

            membersTab
                .tag(AppTab.members)

            MoreTabView()
                .tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(.keyboard)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(
                selected: $selectedTab,
                inboxBadge: inboxState.unreadCount
            )
        }
    }

    private var membersTab: some View {
        NavigationStack {
            MembersListView(guildId: appState.selectedGuildId)
        }
        .id(appState.selectedGuildId)
    }

    // MARK: - Initial Loading

    @MainActor
    private func loadInitialData() async {
        let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""

        async let botGuildsTask      = DiscordService().fetchBotGuilds()
        async let userGuildsTask     = services.guilds.fetchAll()
        async let subscriptionTask   = services.subscription.fetchStatus(discordUserId: userId)
        async let botStatusTask      = services.bot.fetchStatus()

        let botGuilds = (try? await botGuildsTask) ?? []
        appState.botGuilds = botGuilds

        if botGuilds.isEmpty {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.isAppReady = true
            }
            return
        }

        let fetchedGuilds = (try? await userGuildsTask) ?? []
        let botGuildIds = Set(botGuilds.map(\.id))
        appState.guilds = fetchedGuilds

        let storedId = appState.selectedGuildId
        let g = fetchedGuilds.first { $0.id == storedId && botGuildIds.contains($0.id) }
            ?? fetchedGuilds.first { botGuildIds.contains($0.id) }
            ?? botGuilds.first
        if let g {
            appState.selectedGuildId = g.id
            appState.selectedGuild = g
        }

        let status = (try? await subscriptionTask) ?? .inactive
        withAnimation { appState.subscriptionStatus = status }

        let botStatus = (try? await botStatusTask)
            ?? BotStatus(isOnline: false, latency: 0, uptime: 0, activeGuilds: 0, totalCommands: 0)
        withAnimation { appState.botStatus = botStatus }

        withAnimation(.easeInOut(duration: 0.3)) {
            appState.isAppReady = true
        }

        await startBotPolling()
        await inboxState.refresh(using: services.notifications)
    }

    // MARK: - Prefetch（スプラッシュ中に選択サーバーの全データを先読み）
    //
    // 各画面は cache-first（AppState のキャッシュを即表示 → 裏で最新化）で実装されているため、
    // ここで全ギルドスコープのデータを並列に pull してキャッシュを温めておくと、
    // スプラッシュ明けに各画面を開いた瞬間から最新データが表示される。
    // isAppReady はブロックしない（スプラッシュ演出の残り時間で完了する想定）。
    @MainActor
    private func prefetchGuildData(_ guildId: String) async {
        guard !guildId.isEmpty else { return }

        // すべて並列で発火（失敗は握りつぶしてキャッシュは前回値を維持）
        async let embedsT         = services.embeds.fetchByGuild(guildId)
        async let ticketsT        = services.tickets.fetchAll(guildId: guildId)
        async let ticketPanelsT   = services.tickets.fetchPanels(guildId: guildId)
        async let shopsT          = services.shops.fetchShops(guildId: guildId)
        async let reactionRolesT  = services.reactionRoles.fetchAll(guildId: guildId)
        async let membersT        = services.members.fetchMembers(guildId: guildId)
        async let rolesT          = DiscordService().fetchRoles(guildId: guildId)
        async let channelsT       = services.guilds.fetchChannels(guildId: guildId)
        async let analyticsT      = services.analytics.fetchStats(guildId: guildId)
        async let autoRespT       = services.autoResponses.fetchAll(guildId: guildId)
        async let statChannelsT   = services.statChannels.fetchAll(guildId: guildId)
        async let verifyPanelsT   = services.verify.fetchPanels(guildId: guildId)
        async let verifyReqsT     = services.verify.fetchRequests(guildId: guildId, status: .pending)
        async let greetingT       = services.greeting.fetch(guildId: guildId)
        async let tempSettingsT   = services.tempChannel.fetchSettings(guildId: guildId)
        async let tempActiveT     = services.tempChannel.fetchActiveChannels(guildId: guildId)
        async let tempVCT         = services.tempVCSource.fetchSources(guildId: guildId)
        async let ordersT         = services.shops.fetchOrders(guildId: guildId, status: nil)
        async let slashT          = services.bot.fetchCommands()

        // 専用キャッシュ
        if let v = try? await embedsT        { appState.cacheEmbeds(v, for: guildId) }
        if let v = try? await ticketsT       { appState.cacheTickets(v, for: guildId) }
        if let v = try? await ticketPanelsT  { appState.cacheTicketPanels(v, for: guildId) }
        if let v = try? await shopsT         { appState.cacheShops(v, for: guildId) }
        if let v = try? await reactionRolesT { appState.cacheReactionRoles(v, for: guildId) }
        // 汎用キャッシュ
        if let v = try? await membersT       { appState.setGuildData(v, .members, guild: guildId) }
        if let v = try? await rolesT         { appState.setGuildData(v, .roles, guild: guildId) }
        if let v = try? await channelsT      { appState.setGuildData(v, .channels, guild: guildId) }
        if let v = try? await analyticsT     { appState.setGuildData(v, .analytics, guild: guildId) }
        if let v = try? await autoRespT      { appState.setGuildData(v, .autoResponses, guild: guildId) }
        if let v = try? await statChannelsT  { appState.setGuildData(v, .statChannels, guild: guildId) }
        if let v = try? await verifyPanelsT  { appState.setGuildData(v, .verifyPanels, guild: guildId) }
        if let v = try? await verifyReqsT    { appState.setGuildData(v, .verifyRequests, guild: guildId) }
        if let v = try? await greetingT      { appState.setGuildData(v, .greeting, guild: guildId) }
        if let v = try? await tempSettingsT  { appState.setGuildData(v, .tempChannelSettings, guild: guildId) }
        if let v = try? await tempActiveT    { appState.setGuildData(v, .tempChannelActive, guild: guildId) }
        if let v = try? await tempVCT        { appState.setGuildData(v, .tempVCSources, guild: guildId) }
        if let v = try? await ordersT        { appState.setGuildData(v, .orders, guild: guildId) }
        if let v = try? await slashT         { appState.setGuildData(v, .slashCommands, guild: guildId) }
    }

    private func restoreSelectedGuild() async {
        guard let guilds = try? await services.guilds.fetchAll(),
              let match = guilds.first(where: { $0.id == appState.selectedGuildId }) else { return }
        appState.guilds        = guilds
        appState.selectedGuild = match
    }

    private func startBotPolling() async {
        await refreshBotStatus()
        while true {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            await refreshBotStatus()
        }
    }

    @MainActor
    private func refreshBotStatus() async {
        guard let status = try? await services.bot.fetchStatus() else { return }
        withAnimation { appState.botStatus = status }
    }

    @MainActor
    private func recheckBotGuildsOnForeground() async {
        guard appState.selectedGuild == nil else {
            await refreshBotStatus()
            return
        }
        let botGuilds = (try? await DiscordService().fetchBotGuilds()) ?? []
        if !botGuilds.isEmpty {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.botGuilds = botGuilds
                appState.needsReload.toggle()
            }
        } else {
            await refreshBotStatus()
        }
    }
}

// MARK: - Custom Tab Bar

private struct AppTabBar: View {
    @Binding var selected: AppTab
    let inboxBadge: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .background {
            Theme.Color.surface
                .overlay(alignment: .top) {
                    Theme.Color.line.frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selected == tab

        return Button {
            selected = tab
        } label: {
            VStack(spacing: 0) {
                // Accent underline indicator
                Rectangle()
                    .fill(isSelected ? Theme.Color.accent : Color.clear)
                    .frame(height: 2)

                Spacer().frame(height: Theme.Spacing.xs)

                // Icon + badge
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textTertiary)

                    if tab == .inbox, inboxBadge > 0 {
                        Text(inboxBadge > 99 ? "99+" : "\(inboxBadge)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.Color.accentInk)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.Color.accent, in: Capsule())
                            .offset(x: 10, y: -6)
                    }
                }

                Spacer().frame(height: 4)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textTertiary)

                Spacer().frame(height: Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

// MARK: - Overlays (unchanged)

private struct ServerSwitchingOverlay: View {
    let guildName: String?

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            VStack(spacing: .spacing20) {
                RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }
                                        .scaleEffect(scale)

                VStack(spacing: .spacing12) {
                    ProgressView()
                        .tint(Theme.Color.accent)

                    if let name = guildName {
                        Text(name)
                            .font(.titleMedium)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .opacity(opacity)
                    }

                    Text("サーバーを切り替え中...")
                        .font(.bodySmall)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.4)) {
                scale   = 1.0
                opacity = 1.0
            }
        }
    }
}

private struct AppLoadingOverlay: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            VStack(spacing: .spacing20) {
                RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }
                                        .scaleEffect(scale)

                VStack(spacing: .spacing12) {
                    ProgressView()
                        .tint(Theme.Color.accent)

                    Text("読み込み中...")
                        .font(.bodySmall)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.4)) {
                scale   = 1.0
                opacity = 1.0
            }
        }
    }
}

private struct BotNotInGuildView: View {
    @Environment(AppState.self) private var appState
    @State private var isChecking = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            VStack(spacing: .spacing24) {
                Spacer()

                RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                VStack(spacing: .spacing12) {
                    Text("Botをサーバーに追加してください")
                        .font(.titleLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("このアプリを使うには、DiscordサーバーにNoxy Botを追加する必要があります。")
                        .font(.bodyRegular)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, .spacing32)
                }

                Spacer()

                VStack(spacing: .spacing16) {
                    Button {
                        openBotInviteURL()
                    } label: {
                        HStack(spacing: .spacing12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                            Text("Botをサーバーに追加")
                                .font(.titleMedium)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    }
                    .buttonStyle(ScalePressButtonStyle())
                    .padding(.horizontal, .spacing24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.captionRegular)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, .spacing24)
                    }

                    if isChecking {
                        HStack(spacing: .spacing8) {
                            ProgressView()
                                .tint(Theme.Color.accent)
                            Text("サーバーを確認中...")
                                .font(.bodySmall)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                }
                .padding(.bottom, .spacing48)
            }
        }
        .task {
            while true {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await recheckBotGuilds()
            }
        }
    }

    private func openBotInviteURL() {
        Task {
            if let url = try? await DiscordService().generalInviteURL() {
                PlatformHelper.openURL(url)
            } else if let fallback = URL(string: "https://discord.com/oauth2/authorize?client_id=1257646175054245918&scope=bot&permissions=8") {
                PlatformHelper.openURL(fallback)
            }
        }
    }

    @MainActor
    private func recheckBotGuilds() async {
        isChecking = true
        defer { isChecking = false }
        let botGuilds = (try? await DiscordService().fetchBotGuilds()) ?? []
        if !botGuilds.isEmpty {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.botGuilds = botGuilds
                appState.needsReload.toggle()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager(services: ServiceContainer.live()))
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
}
