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
            .listStyle(.insetGrouped)
            .navigationTitle("サーバーを切替")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
    }
}
