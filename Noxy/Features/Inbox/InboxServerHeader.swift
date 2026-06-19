import SwiftUI

// MARK: - InboxServerHeader
// 受信箱上部のサーバーヘッダー（旧ホーム画面の serverHeader を移植）

struct InboxServerHeader: View {
    @Environment(AppState.self) private var appState
    let onSwitch: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Server icon
            ServerIconView(
                imageUrl: appState.selectedGuild?.iconUrl,
                name: appState.selectedGuild?.name ?? "",
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.selectedGuild?.name ?? "サーバーを選択")
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(1)

                if let status = appState.botStatus {
                    HStack(spacing: 4) {
                        StatusDot(color: status.isOnline ? Theme.Color.statusOK : Theme.Color.statusBad)
                        Text(status.isOnline ? "稼働中" : "オフライン")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(status.isOnline ? Theme.Color.statusOK : Theme.Color.statusBad)
                        if status.isOnline {
                            Text("·")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                            MonoText(
                                value: "\(status.latency)ms",
                                font: Theme.Font.monoCap,
                                color: Theme.Color.textTertiary
                            )
                        }
                    }
                } else {
                    Text("確認中...")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }

            Spacer()

            Button {
                onSwitch()
            } label: {
                HStack(spacing: 3) {
                    Text("切替")
                        .font(Theme.Font.caption)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 5)
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Theme.Color.lineStrong, lineWidth: 1)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Color.line, lineWidth: 1)
        }
    }
}

// MARK: - GuildPickerSheet (simplified guild switcher)

struct GuildPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.services) private var services

    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                let botIds = Set(appState.botGuilds.map(\.id))
                let available = appState.guilds.filter { botIds.contains($0.id) }

                if available.isEmpty {
                    ContentUnavailableView(
                        "サーバーがありません",
                        systemImage: "server.rack",
                        description: Text("BotをDiscordサーバーに追加してください")
                    )
                } else {
                    Section {
                        ForEach(available) { guild in
                            Button {
                                Task { await appState.switchServer(to: guild) }
                                dismiss()
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    ServerIconView(imageUrl: guild.iconUrl, name: guild.name, size: 40)
                                    Text(guild.name)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Spacer()
                                    if guild.id == appState.selectedGuildId {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.Color.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button {
                        openBotInviteURL()
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.Color.accent)
                                .frame(width: 28)
                            Text("Botをサーバーに追加")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("サーバーを切替")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isRefreshing {
                        ProgressView()
                            .tint(Theme.Color.accent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: PlatformHelper.willEnterForegroundNotification)) { _ in
            Task { await refreshGuilds() }
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
    private func refreshGuilds() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let previousBotGuildIds = Set(appState.botGuilds.map(\.id))
        let botGuilds = (try? await DiscordService().fetchBotGuilds()) ?? []
        let fetchedGuilds = (try? await DiscordService().fetchAll()) ?? []
        appState.botGuilds = botGuilds
        if !fetchedGuilds.isEmpty { appState.guilds = fetchedGuilds }
        let newBotGuildIds = Set(botGuilds.map(\.id))
        if newBotGuildIds != previousBotGuildIds {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.needsReload.toggle()
            }
        }
    }
}
