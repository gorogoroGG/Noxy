import SwiftUI

// MARK: - Main View

struct InviteTrackerView: View {
    let guildId: String

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    @State private var leaderboard: [InviteStats] = []
    @State private var panels: [InvitePanel] = []
    @State private var period: InvitePeriod = .allTime
    @State private var isLoading = true
    @State private var showPanelSetup = false

    private var totalValid: Int { leaderboard.reduce(0) { $0 + $1.validInvites } }
    private var totalLeft: Int  { leaderboard.reduce(0) { $0 + $1.leftInvites } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.Color.bg.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    summarySection
                    leaderboardSection
                    panelSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.bottom, 80)
            }

            // FAB
            Button {
                showPanelSetup = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Color.accentInk)
                    .frame(width: 56, height: 56)
                    .background(Theme.Color.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .navigationTitle("招待トラッカー")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .onChange(of: period) { _, _ in Task { await loadLeaderboard() } }
        .sheet(isPresented: $showPanelSetup) {
            InvitePanelSetupView(guildId: guildId) { panel in
                panels.insert(panel, at: 0)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            SummaryCard(value: totalValid, label: "有効招待", color: Theme.Color.statusOK)
            SummaryCard(value: totalLeft,  label: "退出",     color: Theme.Color.statusWarn)
            SummaryCard(value: panels.count, label: "パネル",  color: Theme.Color.accent)
        }
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader(icon: "trophy.fill", title: "ランキング")

            Picker("期間", selection: $period) {
                ForEach(InvitePeriod.allCases, id: \.self) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)

            Card(padding: 0) {
                if isLoading {
                    ForEach(0..<5, id: \.self) { i in
                        LeaderboardRowSkeleton()
                        if i < 4 { Divider().background(Theme.Color.line).padding(.leading, Theme.Spacing.md) }
                    }
                } else if leaderboard.isEmpty {
                    EmptyStateInline(icon: "person.2.slash", title: "招待データなし",
                                     subtitle: "メンバーが招待リンクで参加すると記録されます")
                } else {
                    ForEach(Array(leaderboard.enumerated()), id: \.element.id) { idx, stats in
                        NavigationLink {
                            InviteMemberDetailView(guildId: guildId, stats: stats)
                        } label: {
                            InviteLeaderboardRow(stats: stats, rank: idx + 1)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                        }
                        if idx < leaderboard.count - 1 {
                            Divider().background(Theme.Color.line).padding(.leading, Theme.Spacing.md)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Panels

    private var panelSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                sectionHeader(icon: "rectangle.and.hand.point.up.left.fill", title: "招待パネル")
                Spacer()
                NavigationLink {
                    PersonalInviteLinksView(guildId: guildId)
                } label: {
                    Text("リンク一覧")
                        .font(Theme.Font.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Color.accent)
                }
            }

            if panels.isEmpty && !isLoading {
                Card {
                    EmptyStateInline(
                        icon: "rectangle.and.hand.point.up.left",
                        title: "招待パネルが未設置",
                        subtitle: "右下のボタンからパネルを設置すると\nメンバーが専用リンクを取得できます"
                    )
                }
            } else {
                Card(padding: 0) {
                    ForEach(Array(panels.enumerated()), id: \.element.id) { idx, panel in
                        PanelRow(panel: panel)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deletePanel(panel) }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        if idx < panels.count - 1 {
                            Divider().background(Theme.Color.line).padding(.leading, Theme.Spacing.md)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
            Text(title)
                .font(Theme.Font.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.textTertiary)
                .textCase(.uppercase)
        }
    }

    // MARK: - Data

    private func load() async {
        if let cached: [InviteStats] = appState.guildData(.inviteLeaderboard, guild: guildId) {
            leaderboard = cached; isLoading = false
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadLeaderboard() }
            group.addTask { await loadPanels() }
        }
        isLoading = false
    }

    private func loadLeaderboard() async {
        if let result = try? await services.inviteTracker.fetchLeaderboard(guildId: guildId, period: period) {
            leaderboard = result
            appState.setGuildData(result, .inviteLeaderboard, guild: guildId)
        }
    }

    private func loadPanels() async {
        if let result = try? await services.inviteTracker.fetchInvitePanels(guildId: guildId) {
            panels = result
        }
    }

    private func deletePanel(_ panel: InvitePanel) async {
        try? await services.inviteTracker.deleteInvitePanel(id: panel.id)
        withAnimation { panels.removeAll { $0.id == panel.id } }
    }
}

// MARK: - Panel Row

private struct PanelRow: View {
    let panel: InvitePanel

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.chip)
                    .fill(Theme.Color.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "rectangle.and.hand.point.up.left.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Color.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(panel.channelName.map { "#\($0)" } ?? "#チャンネル")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(panel.createdAt.formatted(date: .abbreviated, time: .omitted) + "に設置")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Color.statusOK)
        }
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

// MARK: - Leaderboard Row

struct InviteLeaderboardRow: View {
    let stats: InviteStats
    let rank: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(rank <= 3 ? rankEmoji : "#\(rank)")
                .font(rank <= 3 ? .system(size: 20) : .system(size: 12, weight: .bold))
                .foregroundStyle(rank <= 3 ? .primary : Theme.Color.textTertiary)
                .frame(width: 28, alignment: .center)

            AvatarCircle(displayName: stats.displayName, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(stats.displayName)
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Color.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    InviteBadge(count: stats.validInvites, color: Theme.Color.statusOK, label: "有効")
                    InviteBadge(count: stats.leftInvites,  color: Theme.Color.statusWarn, label: "退出")
                    if stats.fakeInvites > 0 {
                        InviteBadge(count: stats.fakeInvites, color: Theme.Color.statusBad.opacity(0.7), label: "偽")
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stats.influenceScore)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.accent)
                Text("影響力")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
    }

    private var rankEmoji: String {
        switch rank { case 1: return "🥇"; case 2: return "🥈"; default: return "🥉" }
    }
}

private struct InviteBadge: View {
    let count: Int
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
        }
    }
}

// MARK: - Skeleton / Empty

private struct LeaderboardRowSkeleton: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 4).fill(Theme.Color.textTertiary.opacity(0.1)).frame(width: 28, height: 16)
            Circle().fill(Theme.Color.textTertiary.opacity(0.1)).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Theme.Color.textTertiary.opacity(0.1)).frame(width: 100, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Theme.Color.textTertiary.opacity(0.1)).frame(width: 140, height: 10)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .redacted(reason: .placeholder)
    }
}

private struct EmptyStateInline: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Theme.Color.textTertiary)
            Text(title)
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Color.textSecondary)
            Text(subtitle)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }
}

// MARK: - Shared Components

struct AvatarCircle: View {
    let displayName: String
    let size: CGFloat
    var avatarUrl: String? = nil

    private var initial: String { String(displayName.prefix(1)).uppercased() }
    private var bg: Color {
        let colors: [Color] = [Theme.Color.accent, .orange, .pink, Theme.Color.statusOK, .blue]
        let idx = abs(displayName.hashValue) % colors.count
        return colors[idx]
    }

    var body: some View {
        Circle()
            .fill(bg.opacity(0.18))
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(bg)
            }
            .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InviteTrackerView(guildId: "g001")
    }
    .environment(AppState())
    .environment(\.services, ServiceContainer.mock())
}
