import SwiftUI

struct LevelingView: View {
    @State private var isEnabled = true
    @State private var selectedTab = 0
    @State private var toast: ToastMessage? = nil

    private let tabs = ["リーダーボード", "設定"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Toggle("レベリングを有効にする", isOn: $isEnabled.animation())
                    .tint(Color.accentGreen)
                    .padding()

                if isEnabled {
                    Picker("", selection: $selectedTab) {
                        ForEach(tabs.indices, id: \.self) { index in
                            Text(tabs[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch selectedTab {
                    case 0: LeaderboardView()
                    case 1: LevelingSettingsView()
                    default: EmptyView()
                    }
                } else {
                    Spacer()
                    EmptyStateView(
                        icon: "chart.bar.fill",
                        title: "レベリングは無効です",
                        description: "有効にするとメンバーのアクティビティに応じてXPが付与されます。"
                    )
                    Spacer()
                }
            }
            .navigationTitle("レベリング")
            .navigationBarTitleDisplayMode(.large)
        }
        .toast($toast)
    }
}

// MARK: - Leaderboard

private struct LeaderboardView: View {
    private let users = [
        LeaderboardUser(rank: 1, name: "GoroGoro", level: 42, xp: 15420, totalXp: 20000, isOnline: true),
        LeaderboardUser(rank: 2, name: "ShadowX", level: 38, xp: 12300, totalXp: 18000, isOnline: true),
        LeaderboardUser(rank: 3, name: "TaroYamada", level: 35, xp: 10800, totalXp: 16000, isOnline: false),
        LeaderboardUser(rank: 4, name: "NoobPlayer", level: 28, xp: 8200, totalXp: 12000, isOnline: true),
        LeaderboardUser(rank: 5, name: "ProGamer", level: 25, xp: 7100, totalXp: 10000, isOnline: false),
        LeaderboardUser(rank: 6, name: "CasualUser", level: 19, xp: 5400, totalXp: 8000, isOnline: false),
        LeaderboardUser(rank: 7, name: "NewMember", level: 12, xp: 3100, totalXp: 5000, isOnline: true),
        LeaderboardUser(rank: 8, name: "Lurker", level: 8, xp: 1800, totalXp: 3000, isOnline: false),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                ForEach(users) { user in
                    LeaderboardRow(user: user)
                }
            }
            .padding()
        }
    }
}

private struct LeaderboardUser: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let level: Int
    let xp: Int
    let totalXp: Int
    let isOnline: Bool
}

private struct LeaderboardRow: View {
    let user: LeaderboardUser

    private var rankColor: Color {
        switch user.rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return Color.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: .spacing12) {
            Text("\(user.rank)")
                .font(.titleMedium)
                .fontWeight(.bold)
                .foregroundStyle(rankColor)
                .frame(width: 28, alignment: .center)

            Avatar(name: user.name, size: 40, accentColor: .accentIndigo)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: .spacing6) {
                    Badge(text: "Lv.\(user.level)", color: .accentIndigo)
                    Text("\(user.xp.formatted()) / \(user.totalXp.formatted()) XP")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.bgElevated)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentIndigo, Color.accentPurple],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(user.xp) / CGFloat(user.totalXp), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer()
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

// MARK: - Settings

private struct LevelingSettingsView: View {
    @State private var xpPerMessage = 15
    @State private var cooldownSeconds = 60
    @State private var enableLevelUpMessage = true
    @State private var levelUpChannel = "general"
    @State private var autoRoleEnabled = true
    @State private var roleRewards: [(level: Int, role: String)] = [
        (5, "Active"), (10, "Regular"), (20, "Veteran"), (50, "Legend")
    ]

    private let channels = ["general", "level-up", "bot-commands"]

    var body: some View {
        List {
            Section("XP設定") {
                Stepper("メッセージあたり \(xpPerMessage) XP", value: $xpPerMessage, in: 1...100)
                Stepper("クールダウン \(cooldownSeconds) 秒", value: $cooldownSeconds, in: 10...600, step: 10)
            }

            Section("レベルアップ") {
                Toggle("レベルアップ通知", isOn: $enableLevelUpMessage)
                    .tint(Color.accentGreen)
                if enableLevelUpMessage {
                    Picker("通知チャンネル", selection: $levelUpChannel) {
                        ForEach(channels, id: \.self) { ch in
                            Text("#\(ch)").tag(ch)
                        }
                    }
                }
            }

            Section("ロール報酬") {
                Toggle("自動ロール付与", isOn: $autoRoleEnabled)
                    .tint(Color.accentGreen)

                if autoRoleEnabled {
                    ForEach(roleRewards.indices, id: \.self) { index in
                        HStack {
                            Text("Lv.\(roleRewards[index].level)")
                                .font(.bodySmall)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Badge(text: "@\(roleRewards[index].role)", color: .accentPurple, style: .outlined)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    NavigationStack { LevelingView() }
        .preferredColorScheme(.dark)
}
