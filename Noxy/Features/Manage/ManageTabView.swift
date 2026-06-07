import SwiftUI

struct ManageTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                membersSection
                rolesSection
                insightsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("管理")
            .navigationBarTitleDisplayMode(.large)
        }
        .id(appState.selectedGuildId)
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
                RolesListView(guildId: appState.selectedGuildId)
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
                AuditLogView(guildId: appState.selectedGuildId)
            } label: {
                ManageRow(icon: "doc.text.magnifyingglass", title: "監査ログ",
                          subtitle: "サーバー内の操作履歴", color: .accentOrange)
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
