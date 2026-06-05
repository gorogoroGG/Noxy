import SwiftUI

struct ManageTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                membersSection
                rolesSection
                moderationSection
                insightsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("管理")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - メンバー

    private var membersSection: some View {
        Section("メンバー") {
            NavigationLink {
                MembersListView(guildId: appState.selectedGuildId)
            } label: {
                ManageRow(icon: "person.3.fill", title: "メンバー一覧",
                          subtitle: "検索・権限の確認", color: .accentIndigo)
            }

            NavigationLink {
                RolesListView()
            } label: {
                ManageRow(icon: "tag.fill", title: "ロール管理",
                          subtitle: "ロールの確認・メンバー割り当て", color: .accentPurple)
            }
        }
    }

    // MARK: - モデレーション

    private var rolesSection: some View {
        Section("モデレーション") {
            NavigationLink {
                ModerationCenterView()
            } label: {
                ManageRow(icon: "shield.lefthalf.filled", title: "モデレーション",
                          subtitle: "BAN・タイムアウト・警告を一括管理", color: .accentRed)
            }

            NavigationLink {
                ModBanListView(guildId: appState.selectedGuildId)
            } label: {
                ManageRow(icon: "xmark.circle.fill", title: "BAN一覧",
                          subtitle: "BANされたメンバーの管理", color: .accentRed)
            }

            NavigationLink {
                AuditLogView(guildId: appState.selectedGuildId)
            } label: {
                ManageRow(icon: "doc.text.magnifyingglass", title: "監査ログ",
                          subtitle: "サーバー内の操作履歴", color: .accentOrange)
            }
        }
    }

    // MARK: - ロールブロック（入退室）

    private var moderationSection: some View {
        Section("自動化ルール") {
            NavigationLink {
                ReactionRolesView()
            } label: {
                ManageRow(icon: "heart.fill", title: "リアクションロール",
                          subtitle: "スタンプでロールを自動付与", color: .accentPink)
            }

            NavigationLink {
                WelcomeMessageView()
            } label: {
                ManageRow(icon: "hand.wave.fill", title: "入退室メッセージ",
                          subtitle: "参加・退出時に自動あいさつ", color: .accentGreen)
            }
        }
    }

    // MARK: - インサイト

    private var insightsSection: some View {
        Section("インサイト") {
            NavigationLink {
                AnalyticsView(guildId: appState.selectedGuildId)
            } label: {
                ManageRow(icon: "chart.bar.fill", title: "アナリティクス",
                          subtitle: "メンバーやメッセージの統計", color: .accentIndigo)
            }

            NavigationLink {
                MonitorView()
            } label: {
                ManageRow(icon: "waveform", title: "モニター",
                          subtitle: "Botのリアルタイム活動ログ", color: .accentGreen)
            }

            NavigationLink {
                SlashCommandsView()
            } label: {
                ManageRow(icon: "terminal.fill", title: "スラッシュコマンド",
                          subtitle: "利用可能なコマンド一覧", color: .accentPurple)
            }
        }
    }
}

// MARK: - ManageRow

private struct ManageRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))

            VStack(alignment: .leading, spacing: .spacing2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ManageTabView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
}
