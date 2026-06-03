import SwiftUI

struct DashboardView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var botStatus: BotStatus? = nil
    @State private var isLoading = true
    @State private var botGuildCount = 0

    // Sheet states
//    @State private var showNotifications = false
    @State private var showGuildPicker = false
    @State private var showCreateEmbed = false
    @State private var showTickets = false
    @State private var showSchedule = false
    @State private var showMembers = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    VStack(alignment: .leading, spacing: .spacing24) {
                        headerSection
                        if let status = botStatus { botStatusCard(status) }
                        quickActionsSection
                        recentActivitySection
                    }
                    .padding(.vertical)
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.large)
            // TODO: Coming Soon - 通知センター
//            .toolbar { toolbarContent }
//            .sheet(isPresented: $showNotifications) { NotificationCenterView() }
            .sheet(isPresented: $showGuildPicker) {
                GuildPickerSheet(
                    guilds: appState.guilds,
                    selectedId: appState.selectedGuildId
                ) { guild in
                    Task { await appState.switchServer(to: guild) }
                }
            }
            .sheet(isPresented: $showCreateEmbed) {
                EmbedEditorView(embed: nil) { _ in }
            }
            .sheet(isPresented: $showTickets) {
                NavigationStack {
                    TicketsListView(guildId: appState.selectedGuildId)
                        .navigationTitle("チケット一覧")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完了") { showTickets = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showSchedule) {
                ScheduleMessageView { _ in } onCreateTemplate: { }
            }
            .sheet(isPresented: $showMembers) {
                NavigationStack {
                    MembersListView(guildId: appState.selectedGuildId)
                        .navigationTitle("メンバー")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完了") { showMembers = false }
                            }
                        }
                }
            }
            .refreshable { await loadData() }
        }
        .task { await loadData() }
    }

    // MARK: Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "おはようございます"
        case 12..<18: return "こんにちは"
        default:      return "こんばんは"
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: .spacing4) {
                    Text(greeting + " 👋")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                    Text("Noxy")
                        .font(.displayMedium)
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                Avatar(name: "Noxy", size: 44, accentColor: .accentIndigo)
            }

            // サーバー選択ボタン（大きく）
            Button {
                showGuildPicker = true
            } label: {
                HStack(spacing: .spacing8) {
                    Image(systemName: "server.rack")
                        .font(.captionRegular)
                    Text(appState.selectedGuild?.name ?? "サーバーを選択")
                        .font(.bodySmall)
                        .lineLimit(1)
                    Spacer()
                    Text("\(botGuildCount) サーバー稼働中")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    Image(systemName: "chevron.down")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
                .foregroundStyle(Color.accentIndigo)
                .padding(.horizontal, .spacing12)
                .padding(.vertical, .spacing10)
                .background(Color.accentIndigo.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: Bot Status

    private func botStatusCard(_ status: BotStatus) -> some View {
        HStack(spacing: .spacing16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.white)
                    .font(.titleMedium)
            }

            VStack(alignment: .leading, spacing: .spacing4) {
                Text("Noxy Bot")
                    .font(.titleMedium)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: .spacing6) {
                    Circle()
                        .fill(status.isOnline ? Color.accentGreen : Color.accentPink)
                        .frame(width: 8, height: 8)
                    Text(status.isOnline ? "オンライン" : "オフライン")
                        .font(.captionRegular)
                        .foregroundStyle(status.isOnline ? Color.accentGreen : Color.accentPink)
                    if status.isOnline {
                        Text("· \(status.latency)ms")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
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

    // MARK: Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            SectionHeader(title: "クイックアクション")
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: .spacing12),
                    GridItem(.flexible(), spacing: .spacing12)
                ],
                spacing: .spacing12
            ) {
                QuickActionCard(
                    icon: "rectangle.stack.badge.plus",
                    title: "Embed作成",
                    subtitle: "告知・お知らせ",
                    color: .accentIndigo
                ) { showCreateEmbed = true }

                QuickActionCard(
                    icon: "ticket.fill",
                    title: "チケット",
                    subtitle: "サポート対応",
                    color: .accentOrange
                ) { showTickets = true }

                QuickActionCard(
                    icon: "calendar.badge.plus",
                    title: "予約送信",
                    subtitle: "後で送る",
                    color: .accentGreen
                ) { showSchedule = true }

                QuickActionCard(
                    icon: "person.3.fill",
                    title: "メンバー",
                    subtitle: "メンバー管理",
                    color: .accentPink
                ) { showMembers = true }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Recent Activity

    @State private var recentActivities: [ActivityItem_] = []

    private var recentActivitySection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "サーバーの状況")
            if recentActivities.isEmpty {
                VStack(spacing: .spacing8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textTertiary)
                    Text("アクティビティはまだありません")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                    Text("Botの操作やイベントがここに表示されます")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacing24)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentActivities.prefix(5).enumerated()), id: \.element.id) { idx, activity in
                        ActivityRow(activity: activity)
                        if idx < min(recentActivities.count, 5) - 1 {
                            Divider()
                                .background(Color.border)
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal)
            }

            NavigationLink(destination: MonitorView()) {
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentGreen)
                    Text("モニターを開く")
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentGreen)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.spacing12)
            }
            .buttonStyle(.plain)
            .padding(.top, .spacing8)
            .padding(.horizontal)
        }
    }

    // MARK: Data

    private func loadData() async {
        isLoading = true
        let fetchedGuilds = (try? await services.guilds.fetchAll()) ?? []
        let botGuilds = (try? await DiscordService().fetchBotGuilds()) ?? []
        let botGuildIds = Set(botGuilds.map(\.id))

        botGuildCount = botGuildIds.count
        appState.guilds = fetchedGuilds

        if !fetchedGuilds.isEmpty {
            let botGuild = fetchedGuilds.first { botGuildIds.contains($0.id) }
                ?? fetchedGuilds.first
            if let g = botGuild {
                appState.selectedGuildId = g.id
                appState.selectedGuild = g
                await loadRecentActivity(guildId: g.id)
            }
        }

        botStatus = (try? await services.bot.fetchStatus())
        isLoading = false
    }

    private func loadRecentActivity(guildId: String) async {
        guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/recent-activity?guild_id=\(guildId)") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let items = try? JSONDecoder().decode([ActivityItem_].self, from: data) else {
            recentActivities = []
            return
        }
        recentActivities = items
    }

    struct ActivityItem_: Identifiable, Codable {
        var id = UUID()
        var icon: String
        var text: String
        var timeAgo: String
    }
}

// MARK: - Sub-components

private struct StatusDot: View {
    let isOnline: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(isOnline ? Color.accentGreen : Color.accentPink)
            .frame(width: 8, height: 8)
            .scaleEffect(pulse && isOnline ? 1.4 : 1.0)
            .animation(
                isOnline ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                value: pulse
            )
            .onAppear { pulse = true }
    }
}

private struct ActivityRow: View {
    let activity: DashboardView.ActivityItem_

    var body: some View {
        HStack(spacing: .spacing12) {
            Text(activity.icon)
                .font(.titleMedium)
                .frame(width: 32, height: 32)
            Text(activity.text)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(activity.timeAgo)
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.spacing12)
    }
}

private struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: .spacing8) {
                Image(systemName: icon)
                    .font(.titleMedium)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.captionSmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.spacing16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        }
        .buttonStyle(ScalePressButtonStyle())
    }
}

// MARK: - Guild Picker Sheet

private struct GuildPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let guilds: [Guild]
    let selectedId: String
    let onSelect: (Guild) -> Void

    @State private var botGuildIds: Set<String> = []
    @State private var showInviteSheet = false
    @State private var isLoading = true

    private let discord = DiscordService()

    /// Bot参加 + オーナー権限のあるサーバーのみ
    private var manageableGuilds: [Guild] {
        guilds.filter { $0.userRole == .owner && botGuildIds.contains($0.id) }
    }

    /// 招待可能サーバー（オーナーだがBot未参加）
    private var invitableGuilds: [Guild] {
        guilds.filter { $0.userRole == .owner && !botGuildIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if showInviteSheet {
                    InviteBotSheet(guilds: invitableGuilds, onBack: { showInviteSheet = false })
                } else {
                    mainList
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .task {
            botGuildIds = (try? await discord.fetchBotGuildIds()) ?? []
            isLoading = false
        }
    }

    // MARK: - メイン一覧

    private var mainList: some View {
        List {
            if manageableGuilds.isEmpty {
                Section {
                    VStack(spacing: .spacing16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.textTertiary)
                        Text("管理できるサーバーがありません")
                            .font(.bodyRegular)
                            .foregroundStyle(Color.textSecondary)
                        PrimaryButton("ボットをサーバーに追加", style: .filled, size: .medium) {
                            showInviteSheet = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spacing32)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(manageableGuilds) { guild in
                        Button {
                            onSelect(guild)
                            dismiss()
                        } label: {
                            HStack(spacing: .spacing12) {
                                GuildIconView(guild: guild)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(guild.name)
                                        .font(.bodyRegular)
                                        .foregroundStyle(Color.textPrimary)
                                }

                                Spacer()

                                if guild.id == selectedId {
                                    Badge(text: "選択中", color: .accentIndigo)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("サーバーを選択")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("サーバー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完了") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !manageableGuilds.isEmpty {
                PrimaryButton("ボットを追加する", style: .outlined, size: .medium, icon: "plus") {
                    showInviteSheet = true
                }
                .padding()
                .background(.regularMaterial)
            }
        }
    }
}

// MARK: - Guild Icon View

private struct GuildIconView: View {
    let guild: Guild

    var body: some View {
        Group {
            if let iconUrl = guild.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackIcon
                    default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                .fill(Color.accentIndigo.opacity(0.15))
            Text(String(guild.name.prefix(1)))
                .font(.titleMedium)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentIndigo)
        }
    }
}

// MARK: - Invite Bot Sheet

private struct InviteBotSheet: View {
    let guilds: [Guild]
    let onBack: () -> Void

    var body: some View {
        List {
            if guilds.isEmpty {
                Section {
                    VStack(spacing: .spacing12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentGreen)
                        Text("Botを追加できるサーバーはありません")
                            .font(.bodyRegular)
                            .foregroundStyle(Color.textSecondary)
                        Text("サーバーオーナー権限があるサーバーにのみ追加できます")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spacing24)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(guilds) { guild in
                        HStack(spacing: .spacing12) {
                            GuildIconView(guild: guild)

                            Text(guild.name)
                                .font(.bodyRegular)
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Button {
                                Task {
                                    if let url = try? await DiscordService().inviteURL(guildId: guild.id) {
                                        await MainActor.run { UIApplication.shared.open(url) }
                                    }
                                }
                            } label: {
                                Text("追加")
                                    .font(.captionRegular)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, .spacing16)
                                    .padding(.vertical, .spacing6)
                                    .background(Color.accentIndigo)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Bot を招待するサーバーを選択")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("ボットを追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { onBack() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
}
