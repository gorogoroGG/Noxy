import SwiftUI

// MARK: - Main View

struct InviteTrackerView: View {
    let guildId: String

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    @State private var leaderboard: [InviteStats] = []
    @State private var campaigns: [InviteCampaign] = []
    @State private var panels: [InvitePanel] = []
    @State private var period: InvitePeriod = .allTime
    @State private var isLoading = true
    @State private var showCreateCampaign = false
    @State private var showPanelSetup = false

    var body: some View {
        List {
            summarySection
            leaderboardSection
            campaignSection
            panelSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("招待トラッカー")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .onChange(of: period) { _, _ in Task { await loadLeaderboard() } }
        .sheet(isPresented: $showCreateCampaign) {
            CreateCampaignSheet(guildId: guildId) { campaign in
                campaigns.insert(campaign, at: 0)
            }
        }
        .sheet(isPresented: $showPanelSetup) {
            InvitePanelSetupView(guildId: guildId) { panel in
                panels.insert(panel, at: 0)
            }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            HStack(spacing: .spacing12) {
                SummaryCard(
                    value: leaderboard.reduce(0) { $0 + $1.validInvites },
                    label: "総招待数",
                    color: .accentGreen
                )
                SummaryCard(
                    value: leaderboard.reduce(0) { $0 + $1.leftInvites },
                    label: "退出数",
                    color: Color.orange
                )
                SummaryCard(
                    value: campaigns.filter(\.isActive).count,
                    label: "実施中",
                    color: .accentPurple
                )
            }
            .listRowInsets(EdgeInsets(top: .spacing8, leading: .spacing16, bottom: .spacing8, trailing: .spacing16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var leaderboardSection: some View {
        Section {
            // Period picker
            Picker("期間", selection: $period) {
                ForEach(InvitePeriod.allCases, id: \.self) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: .spacing16, bottom: .spacing4, trailing: .spacing16))

            if isLoading {
                ForEach(0..<5, id: \.self) { _ in
                    LeaderboardRowSkeleton()
                }
            } else if leaderboard.isEmpty {
                EmptyStateRow(
                    icon: "person.2.slash",
                    title: "招待データなし",
                    subtitle: "メンバーが招待リンクで参加すると記録されます"
                )
            } else {
                ForEach(Array(leaderboard.enumerated()), id: \.element.id) { idx, stats in
                    NavigationLink {
                        InviteMemberDetailView(guildId: guildId, stats: stats)
                    } label: {
                        InviteLeaderboardRow(stats: stats, rank: idx + 1)
                    }
                }
            }
        } header: {
            Text("ランキング")
        }
    }

    private var campaignSection: some View {
        Section {
            if campaigns.isEmpty && !isLoading {
                EmptyStateRow(
                    icon: "flag.slash",
                    title: "キャンペーンなし",
                    subtitle: "招待キャンペーンを作成して盛り上げよう"
                )
            } else {
                ForEach(campaigns) { campaign in
                    CampaignRow(campaign: campaign)
                }
                .onDelete { offsets in
                    Task { await deleteCampaigns(at: offsets) }
                }
            }

            Button {
                showCreateCampaign = true
            } label: {
                Label("キャンペーンを作成", systemImage: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
        } header: {
            Text("キャンペーン")
        }
    }

    private var panelSection: some View {
        Section {
            if panels.isEmpty && !isLoading {
                VStack(spacing: .spacing8) {
                    Image(systemName: "rectangle.and.hand.point.up.left")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.textTertiary)
                    Text("招待パネルが未設置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                    Text("パネルをチャンネルに設置すると、メンバーが専用リンクを取得できます")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacing20)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(panels) { panel in
                    PanelRow(panel: panel)
                }
                .onDelete { offsets in Task { await deletePanels(at: offsets) } }
            }

            Button {
                showPanelSetup = true
            } label: {
                Label("招待パネルを設置する", systemImage: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
        } header: {
            HStack {
                Text("招待パネル")
                Spacer()
                NavigationLink {
                    PersonalInviteLinksView(guildId: guildId)
                } label: {
                    Text("リンク一覧")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentPurple)
                }
            }
        }
    }

    // MARK: - Data

    private func load() async {
        if let cached: [InviteStats] = appState.guildData(.inviteLeaderboard, guild: guildId) {
            leaderboard = cached; isLoading = false
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadLeaderboard() }
            group.addTask { await loadCampaigns() }
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

    private func loadCampaigns() async {
        if let result = try? await services.inviteTracker.fetchCampaigns(guildId: guildId) {
            campaigns = result
            appState.setGuildData(result, .inviteCampaigns, guild: guildId)
        }
    }

    private func deleteCampaigns(at offsets: IndexSet) async {
        for idx in offsets {
            try? await services.inviteTracker.deleteCampaign(id: campaigns[idx].id)
        }
        withAnimation { campaigns.remove(atOffsets: offsets) }
    }

    private func loadPanels() async {
        if let result = try? await services.inviteTracker.fetchInvitePanels(guildId: guildId) {
            panels = result
        }
    }

    private func deletePanels(at offsets: IndexSet) async {
        for idx in offsets {
            try? await services.inviteTracker.deleteInvitePanel(id: panels[idx].id)
        }
        withAnimation { panels.remove(atOffsets: offsets) }
    }
}

// MARK: - Panel Row

private struct PanelRow: View {
    let panel: InvitePanel

    var body: some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentPurple.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "rectangle.and.hand.point.up.left.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentPurple)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(panel.channelName.map { "#\($0)" } ?? "#チャンネル")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(panel.createdAt.formatted(date: .abbreviated, time: .omitted) + "に設置")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentGreen)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: .spacing4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacing12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
    }
}

// MARK: - Leaderboard Row

struct InviteLeaderboardRow: View {
    let stats: InviteStats
    let rank: Int

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1, green: 0.84, blue: 0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return Color.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: .spacing12) {
            // Rank
            Text(rank <= 3 ? rankEmoji : "#\(rank)")
                .font(rank <= 3 ? .system(size: 20) : .system(size: 12, weight: .bold))
                .foregroundStyle(rank <= 3 ? .primary : rankColor)
                .frame(width: 28, alignment: .center)

            // Avatar
            AvatarCircle(displayName: stats.displayName, size: 36)

            // Name + stats
            VStack(alignment: .leading, spacing: 3) {
                Text(stats.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: .spacing8) {
                    InviteBadge(count: stats.validInvites, color: .accentGreen,   label: "有効")
                    InviteBadge(count: stats.leftInvites,  color: Color.orange,   label: "退出")
                    if stats.fakeInvites > 0 {
                        InviteBadge(count: stats.fakeInvites, color: Color.red.opacity(0.7), label: "偽")
                    }
                }
            }

            Spacer()

            // Influence score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stats.influenceScore)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentPurple)
                Text("影響力")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.vertical, .spacing4)
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
                .font(.system(size: 9))
                .foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - Campaign Row

private struct CampaignRow: View {
    let campaign: InviteCampaign

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: .spacing6) {
                        Text(campaign.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        if !campaign.isActive || campaign.isExpired {
                            Text(campaign.isExpired ? "終了" : "停止")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.textTertiary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    if let desc = campaign.description {
                        Text(desc)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(campaign.currentCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentPurple)
                    if let target = campaign.targetCount {
                        Text("/ \(target)人")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            // Progress bar
            if let target = campaign.targetCount, target > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.textTertiary.opacity(0.1))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [.accentOrange, .accentPink],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * campaign.progressRatio)
                    }
                    .frame(height: 5)
                }
                .frame(height: 5)
            }

            // Dates
            HStack(spacing: .spacing12) {
                if let code = campaign.inviteCode {
                    Label(code, systemImage: "link")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
                if let end = campaign.endsAt {
                    Label(end.formatted(date: .abbreviated, time: .omitted) + "まで",
                          systemImage: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(campaign.isExpired ? Color.red.opacity(0.6) : Color.textTertiary)
                }
            }
        }
        .padding(.vertical, .spacing4)
    }
}

// MARK: - Create Campaign Sheet

private struct CreateCampaignSheet: View {
    let guildId: String
    let onCreate: (InviteCampaign) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var inviteCode = ""
    @State private var targetCount = ""
    @State private var hasEndDate = false
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 14)
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("キャンペーン名", text: $name)
                    TextField("説明（任意）", text: $description)
                }
                Section("設定") {
                    TextField("招待コード（任意）", text: $inviteCode)
                    TextField("目標人数（任意）", text: $targetCount)
                        .keyboardType(.numberPad)
                    Toggle("終了日を設定", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("キャンペーンを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") { Task { await save() } }
                        .disabled(name.isEmpty || isSaving)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        let target = Int(targetCount)
        let end: Date? = hasEndDate ? endDate : nil
        if let campaign = try? await services.inviteTracker.createCampaign(
            guildId: guildId, name: name,
            description: description.isEmpty ? nil : description,
            inviteCode: inviteCode.isEmpty ? nil : inviteCode,
            targetCount: target, endsAt: end
        ) {
            onCreate(campaign)
            dismiss()
        }
        isSaving = false
    }
}

// MARK: - Skeletons / Empty

private struct LeaderboardRowSkeleton: View {
    var body: some View {
        HStack(spacing: .spacing12) {
            RoundedRectangle(cornerRadius: 4).fill(Color.textTertiary.opacity(0.1)).frame(width: 28, height: 16)
            Circle().fill(Color.textTertiary.opacity(0.1)).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.textTertiary.opacity(0.1)).frame(width: 100, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color.textTertiary.opacity(0.1)).frame(width: 140, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, .spacing4)
        .redacted(reason: .placeholder)
    }
}

private struct EmptyStateRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: .spacing8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color.textTertiary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacing24)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Shared Components

struct AvatarCircle: View {
    let displayName: String
    let size: CGFloat
    var avatarUrl: String? = nil

    private var initial: String { String(displayName.prefix(1)).uppercased() }
    private var bg: Color {
        let colors: [Color] = [.accentOrange, .accentPink, .accentPurple, .accentGreen, .blue]
        let idx = abs(displayName.hashValue) % colors.count
        return colors[idx]
    }

    var body: some View {
        Circle()
            .fill(bg.opacity(0.2))
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
