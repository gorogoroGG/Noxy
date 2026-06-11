import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self)   private var authManager
    @Environment(\.services)         private var services
    @Environment(\.scenePhase)       private var scenePhase
    @Environment(AppState.self)      private var appState

    @State private var selectedTab = 0

    var body: some View {
        Group {
            if !appState.isAppReady {
                AppLoadingOverlay()
            } else if appState.isBotNotInAnyGuild {
                BotNotInGuildView()
            } else if appState.isBotOffline {
                BotOfflineView {
                    await refreshBotStatus()
                }
                .transition(.opacity)
            } else {
                ZStack {
                    TabView(selection: $selectedTab) {
                        DashboardView()
                            .tabItem { Label("ホーム", systemImage: "house.fill") }
                            .tag(0)

                        ActionsTabView()
                            .tabItem { Label("アクション", systemImage: "bolt.fill") }
                            .tag(1)

                        ManageTabView()
                            .tabItem { Label("管理", systemImage: "person.3.fill") }
                            .tag(2)

                        MoreTabView()
                            .tabItem { Label("設定", systemImage: "gearshape.fill") }
                            .tag(3)

                        #if DEBUG
                        ComponentLibraryView()
                            .tabItem { Label("Dev", systemImage: "hammer.fill") }
                            .tag(4)
                        #endif
                    }
                    .tint(Color.accentIndigo)
                    .mockBanner()

                    // サーバー切り替え時の全画面ローディング
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
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if appState.selectedGuild == nil, !appState.selectedGuildId.isEmpty {
                Task { await restoreSelectedGuild() }
            }
            // フォアグラウンド復帰時に BotGuilds を再確認（招待後の自動検出）
            Task { await recheckBotGuildsOnForeground() }
        }
    }

    // MARK: - Initial Loading

    @MainActor
    private func loadInitialData() async {
        let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""

        // Bot guilds・ユーザーguilds・サブスク・Botステータスを並列取得
        async let botGuildsTask      = DiscordService().fetchBotGuilds()
        async let userGuildsTask     = services.guilds.fetchAll()
        async let subscriptionTask   = services.subscription.fetchStatus(discordUserId: userId)
        async let botStatusTask      = services.bot.fetchStatus()

        let botGuilds = (try? await botGuildsTask) ?? []
        appState.botGuilds = botGuilds

        // Bot がどのサーバーにも入っていない場合はここで早期リターン
        if botGuilds.isEmpty {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.isAppReady = true
            }
            return
        }

        // ユーザーが管理できるサーバー一覧（Discord OAuth）
        let fetchedGuilds = (try? await userGuildsTask) ?? []
        let botGuildIds = Set(botGuilds.map(\.id))
        appState.guilds = fetchedGuilds

        // サーバー選択: Bot が入っているサーバーの中から優先
        let storedId = appState.selectedGuildId
        let g = fetchedGuilds.first { $0.id == storedId && botGuildIds.contains($0.id) }
            ?? fetchedGuilds.first { botGuildIds.contains($0.id) }
            ?? botGuilds.first
        if let g {
            appState.selectedGuildId = g.id
            appState.selectedGuild = g
        }

        // サブスクリプション（並列取得済み）
        let status = (try? await subscriptionTask) ?? .inactive
        withAnimation { appState.subscriptionStatus = status }

        // Bot ステータス（並列取得済み）
        let botStatus = (try? await botStatusTask)
            ?? BotStatus(isOnline: false, latency: 0, uptime: 0, activeGuilds: 0, totalCommands: 0)
        withAnimation { appState.botStatus = botStatus }

        // 準備完了
        withAnimation(.easeInOut(duration: 0.3)) {
            appState.isAppReady = true
        }

        // Bot ポーリング開始
        await startBotPolling()
    }

    /// selectedGuild を DiscordAPI から取得して復元する
    private func restoreSelectedGuild() async {
        guard let guilds = try? await services.guilds.fetchAll(),
              let match = guilds.first(where: { $0.id == appState.selectedGuildId }) else { return }
        appState.guilds       = guilds
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

    /// フォアグラウンド復帰時に BotGuilds を再確認（招待後の自動検出・再ロード）
    @MainActor
    private func recheckBotGuildsOnForeground() async {
        // すでに guild が選択済みなら Bot ステータスのみ更新
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

// MARK: - Overlay

private struct ServerSwitchingOverlay: View {
    let guildName: String?

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: .spacing20) {
                // アプリアイコン（SplashView と同じデザイン）
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
                    .shadow(color: Color.accentIndigo.opacity(0.4), radius: 20, x: 0, y: 10)
                    .scaleEffect(scale)

                VStack(spacing: .spacing12) {
                    ProgressView()
                        .tint(Color.accentIndigo)

                    if let name = guildName {
                        Text(name)
                            .font(.titleMedium)
                            .foregroundStyle(Color.textPrimary)
                            .opacity(opacity)
                    }

                    Text("サーバーを切り替え中...")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textSecondary)
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

// MARK: - AppLoadingOverlay

private struct AppLoadingOverlay: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: .spacing20) {
                // アプリアイコン
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
                    .shadow(color: Color.accentIndigo.opacity(0.4), radius: 20, x: 0, y: 10)
                    .scaleEffect(scale)

                VStack(spacing: .spacing12) {
                    ProgressView()
                        .tint(Color.accentIndigo)

                    Text("読み込み中...")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textSecondary)
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

// MARK: - BotNotInGuildView

private struct BotNotInGuildView: View {
    @Environment(AppState.self) private var appState
    @State private var isChecking = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: .spacing24) {
                Spacer()

                // アプリアイコン
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
                    .shadow(color: Color.accentIndigo.opacity(0.4), radius: 30, x: 0, y: 15)

                VStack(spacing: .spacing12) {
                    Text("Botをサーバーに追加してください")
                        .font(.titleLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("このアプリを使うには、DiscordサーバーにNoxy Botを追加する必要があります。")
                        .font(.bodyRegular)
                        .foregroundStyle(Color.textSecondary)
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
                        .background(Color.accentIndigo)
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
                                .tint(Color.accentIndigo)
                            Text("サーバーを確認中...")
                                .font(.bodySmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .padding(.bottom, .spacing48)
            }
        }
        .task {
            // 30秒ごとに再確認（Botが追加されたかどうか）
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
                // フォールバック: Noxy Bot のクライアント ID を直接指定
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
}
