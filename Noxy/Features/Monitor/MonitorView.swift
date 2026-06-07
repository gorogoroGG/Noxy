import SwiftUI

struct MonitorView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedFilter: FilterType = .all
    @State private var activities: [BotActivityItem] = []
    @State private var isLoading = true

    enum FilterType: String, CaseIterable {
        case all        = "すべて"
        case errors     = "エラー"
        case commands   = "コマンド"
        case automation = "自動化"
    }

    private var filtered: [BotActivityItem] {
        switch selectedFilter {
        case .all:        return activities
        case .errors:     return activities.filter { $0.isError }
        case .commands:   return activities.filter { $0.type == .command }
        case .automation: return activities.filter { $0.type == .automation }
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
                .onChange(of: selectedFilter) { _, _ in
                    Task { await loadActivities() }
                }

                Divider().background(Color.border)

                // ── リスト / 空状態 ──
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filtered) { item in
                            ActivityLogRow(item: item)
                                .listRowBackground(
                                    item.isError
                                        ? Color.accentRed.opacity(0.06)
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
                    liveIndicator
                }
            }
            .refreshable { await loadActivities() }
            .task { await loadActivities() }
            .onChange(of: appState.selectedGuildId) { _, _ in
                Task { await loadActivities() }
            }
        }
    }

    // MARK: Live indicator

    private var liveIndicator: some View {
        HStack(spacing: .spacing4) {
            Circle()
                .fill(Color.accentGreen)
                .frame(width: 7, height: 7)
            Text("ライブ")
                .font(.captionRegular)
                .foregroundStyle(Color.accentGreen)
        }
        .padding(.horizontal, .spacing8)
        .padding(.vertical, .spacing4)
        .background(Capsule().fill(Color.accentGreen.opacity(0.15)))
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

    // MARK: Load data

    private func loadActivities() async {
        isLoading = true
        let guildId = appState.selectedGuildId
        guard !guildId.isEmpty else {
            activities = []
            isLoading = false
            return
        }
        let typeParam = selectedFilter == .all ? "all" : selectedFilter.rawValue
        guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/monitor-activity?guild_id=\(guildId)&type=\(typeParam)") else {
            isLoading = false
            return
        }
        let req = DiscordConfig.makeWorkerRequest(url: url)
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let items = try? JSONDecoder().decode([BotActivityItem].self, from: data) {
            activities = items
        } else {
            activities = []
        }
        isLoading = false
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
                Text(item.detail)
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
                .foregroundStyle(Color.accentRed)
                .frame(width: 34, height: 34)
                .background(Color.accentRed.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentRed)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                Text(item.timeAgo)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, .spacing8)
    }
}

// MARK: - Model

enum BotActivityType: String, Codable { case command, automation, moderation, system }

struct BotActivityItem: Identifiable, Codable {
    var id = UUID()
    var type: BotActivityType
    var icon: String
    var title: String
    var detail: String
    var guildName: String
    var timeAgo: String
    var isError: Bool = false

    // JSON に id フィールドがないため、デコード対象から除外
    enum CodingKeys: String, CodingKey {
        case type, icon, title, detail, guildName, timeAgo, isError
    }
}

#Preview {
    MonitorView()
        .environment(\.services, ServiceContainer.live())
}
