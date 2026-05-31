import SwiftUI

struct MonitorView: View {
    @State private var selectedFilter: FilterType = .all
    @State private var isLive = true
    @State private var pulse = false

    enum FilterType: String, CaseIterable {
        case all        = "すべて"
        case errors     = "エラー"
        case commands   = "コマンド"
        case automation = "自動化"
    }

    private var filtered: [BotActivityItem] {
        switch selectedFilter {
        case .all:        return mockActivities
        case .errors:     return mockActivities.filter { $0.isError }
        case .commands:   return mockActivities.filter { $0.type == .command }
        case .automation: return mockActivities.filter { $0.type == .automation }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── フィルター ──
                Picker("", selection: $selectedFilter) {
                    ForEach(FilterType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, .spacing8)
                .background(Color.bgSurface)

                Divider().background(Color.border)

                // ── リスト / 空状態 ──
                if filtered.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filtered) { item in
                            ActivityLogRow(item: item)
                                .listRowBackground(
                                    item.isError
                                        ? Color(uiColor: UIColor(hex: 0xEF4444)).opacity(0.06)
                                        : Color.bgSurface
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparatorTint(Color.border)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("モニター")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    liveToggle
                }
            }
            .refreshable {
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
        .onAppear { pulse = true }
    }

    // MARK: Live toggle

    private var liveToggle: some View {
        Button {
            withAnimation { isLive.toggle() }
        } label: {
            HStack(spacing: .spacing4) {
                Circle()
                    .fill(isLive ? Color.accentGreen : Color.textTertiary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulse && isLive ? 1.4 : 1.0)
                    .animation(
                        isLive
                            ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                            : .default,
                        value: pulse
                    )
                Text(isLive ? "ライブ" : "停止中")
                    .font(.captionRegular)
                    .foregroundStyle(isLive ? Color.accentGreen : Color.textTertiary)
            }
            .padding(.horizontal, .spacing8)
            .padding(.vertical, .spacing4)
            .background(
                Capsule().fill(isLive ? Color.accentGreen.opacity(0.15) : Color.bgElevated)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: .spacing16) {
            Spacer()
            Image(systemName: selectedFilter == .errors ? "checkmark.circle.fill" : "tray")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(selectedFilter == .errors ? Color.accentGreen : Color.textTertiary)
            Text(selectedFilter == .errors ? "エラーはありません" : "ログがありません")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text(selectedFilter == .errors ? "Botは正常に動作しています。" : "まだ記録がありません。")
                .font(.bodySmall)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Row

private struct ActivityLogRow: View {
    let item: BotActivityItem

    private var typeColor: Color {
        switch item.type {
        case .command:    return .accentIndigo
        case .automation: return .accentGreen
        case .moderation: return .accentOrange
        case .system:     return .accentPurple
        }
    }

    var body: some View {
        if item.isError {
            errorRow
        } else {
            normalRow
        }
    }

    // 通常ログ: コンパクト1行
    private var normalRow: some View {
        HStack(spacing: .spacing8) {
            Image(systemName: item.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(typeColor)
                .frame(width: 26, height: 26)
                .background(typeColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(item.detail + " · " + item.guildName)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.timeAgo)
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, .spacing8)
    }

    // エラーログ: 目立つ3行
    private var errorRow: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(uiColor: UIColor(hex: 0xEF4444)))
                .frame(width: 34, height: 34)
                .background(Color(uiColor: UIColor(hex: 0xEF4444)).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0xEF4444)))
                    .lineLimit(1)
                Text(item.detail)
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                Text(item.guildName + " · " + item.timeAgo)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, .spacing8)
    }
}

// MARK: - Model

enum BotActivityType { case command, automation, moderation, system }

struct BotActivityItem: Identifiable {
    let id = UUID()
    let type: BotActivityType
    let icon: String
    let title: String
    let detail: String
    let guildName: String
    let timeAgo: String
    var isError: Bool = false
}

// MARK: - Mock data

extension MonitorView {
    var mockActivities: [BotActivityItem] { [
        BotActivityItem(type: .command,    icon: "terminal.fill",
                        title: "/ticket create",
                        detail: "@ShadowX がチケットを作成",
                        guildName: "Valorant JP",  timeAgo: "たった今"),
        BotActivityItem(type: .automation, icon: "bubble.left.fill",
                        title: "自動返信トリガー",
                        detail: "\"ルール\" → ルール一覧を送信",
                        guildName: "Valorant JP",  timeAgo: "1分前"),
        BotActivityItem(type: .moderation, icon: "shield.fill",
                        title: "スパム検知 — メッセージ削除",
                        detail: "@NoobPlayer — 5秒で6件のメッセージ",
                        guildName: "Gaming Hub",   timeAgo: "3分前"),
        BotActivityItem(type: .command,    icon: "terminal.fill",
                        title: "/embed send",
                        detail: "#announcements に送信完了",
                        guildName: "Valorant JP",  timeAgo: "8分前"),
        BotActivityItem(type: .system,     icon: "calendar.badge.clock",
                        title: "予約送信 — 完了",
                        detail: "週次アナウンスを #general に送信",
                        guildName: "Gaming Hub",   timeAgo: "15分前"),
        BotActivityItem(type: .automation, icon: "heart.fill",
                        title: "リアクションロール付与",
                        detail: "🎮 → @Gamer ロールを付与",
                        guildName: "Valorant JP",  timeAgo: "18分前"),
        BotActivityItem(type: .command,    icon: "terminal.fill",
                        title: "/help",
                        detail: "@NewMember が実行",
                        guildName: "Esports Club", timeAgo: "22分前"),
        BotActivityItem(type: .automation, icon: "hand.wave.fill",
                        title: "ウェルカムメッセージ送信",
                        detail: "@TaroYamada が Valorant JP に参加",
                        guildName: "Valorant JP",  timeAgo: "45分前"),
        BotActivityItem(type: .system,     icon: "exclamationmark.triangle.fill",
                        title: "接続エラー",
                        detail: "WebSocket が切断 — 自動再接続中",
                        guildName: "システム",      timeAgo: "1時間前",  isError: true),
        BotActivityItem(type: .command,    icon: "terminal.fill",
                        title: "/stats",
                        detail: "@GoroGoro が実行",
                        guildName: "Esports Club", timeAgo: "1時間前"),
        BotActivityItem(type: .system,     icon: "arrow.clockwise",
                        title: "再接続完了",
                        detail: "WebSocket 接続を復元",
                        guildName: "システム",      timeAgo: "1時間前"),
        BotActivityItem(type: .automation, icon: "calendar.badge.plus",
                        title: "予約メッセージ登録",
                        detail: "@GoroGoro が週次アナウンスを設定",
                        guildName: "Gaming Hub",   timeAgo: "2時間前"),
        BotActivityItem(type: .moderation, icon: "at",
                        title: "メンションスパム検知",
                        detail: "@SpamBot — 1メッセージで8件@メンション",
                        guildName: "Esports Club", timeAgo: "3時間前",  isError: true),
    ]}
}

#Preview {
    MonitorView()
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}
