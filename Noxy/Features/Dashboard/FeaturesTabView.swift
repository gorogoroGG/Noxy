import SwiftUI

// ウェブのサイドバーと同じ順番・名称でフラットに並べる

struct FeaturesTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                ForEach(FeatureItem.all) { item in
                    if let dest = item.destination(appState.selectedGuildId) {
                        NavigationLink(destination: dest) {
                            FeatureRow(item: item)
                        }
                    } else {
                        FeatureRow(item: item)
                            .overlay(alignment: .trailing) {
                                Text("準備中")
                                    .font(.captionSmall)
                                    .foregroundStyle(Color.textTertiary)
                                    .padding(.trailing, .spacing4)
                            }
                    }
                }
                .listRowBackground(Color.bgSurface)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            }
            .listStyle(.plain)
            .listRowSpacing(.spacing4)
            .background(Color.bgPrimary)
            .scrollContentBackground(.hidden)
            .navigationTitle("機能")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Feature Items

struct FeatureItem: Identifiable {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let destination: (String) -> AnyView?

    static let all: [FeatureItem] = [
        FeatureItem(
            id: "embeds",
            icon: "rectangle.stack.fill",
            color: .accentIndigo,
            title: "埋め込みメッセージ",
            subtitle: "Embedテンプレートの作成・送信"
        ) { _ in AnyView(EmbedListView()) },

        FeatureItem(
            id: "scheduled",
            icon: "clock.fill",
            color: .accentPurple,
            title: "予約投稿",
            subtitle: "指定時刻にメッセージを送信"
        ) { _ in AnyView(ScheduledMessagesListView()) },

        FeatureItem(
            id: "recurring",
            icon: "repeat.circle.fill",
            color: .accentIndigo,
            title: "定期投稿",
            subtitle: "日次・週次・月次の自動投稿"
        ) { _ in AnyView(RecurringPostsListView()) },

        FeatureItem(
            id: "reaction-roles",
            icon: "heart.fill",
            color: .accentPink,
            title: "リアクションロール",
            subtitle: "リアクションでロールを自動付与"
        ) { _ in AnyView(ReactionRolesView()) },

        FeatureItem(
            id: "greetings",
            icon: "hand.wave.fill",
            color: .accentGreen,
            title: "入退室メッセージ",
            subtitle: "入室・退室時の自動メッセージ"
        ) { _ in AnyView(WelcomeMessageView()) },

        FeatureItem(
            id: "members",
            icon: "person.3.fill",
            color: .accentIndigo,
            title: "メンバー",
            subtitle: "メンバー一覧と管理"
        ) { id in AnyView(MembersListView(guildId: id)) },

        FeatureItem(
            id: "tickets",
            icon: "ticket.fill",
            color: .accentOrange,
            title: "チケット",
            subtitle: "サポートチケットの管理"
        ) { id in AnyView(TicketsListView(guildId: id)) },

        FeatureItem(
            id: "shops",
            icon: "cart.fill",
            color: .accentPurple,
            title: "ショップ",
            subtitle: "商品販売・注文管理"
        ) { id in AnyView(ShopsListView(guildId: id)) },

        FeatureItem(
            id: "roles",
            icon: "shield.fill",
            color: .accentPurple,
            title: "ロール",
            subtitle: "権限の確認・編集・ロールの作成"
        ) { _ in AnyView(RolesListView()) },

        FeatureItem(
            id: "moderation",
            icon: "shield.lefthalf.filled",
            color: Color(uiColor: UIColor(hex: 0xEF4444)),
            title: "モデレーション",
            subtitle: "BAN・タイムアウト・警告・AutoMod を一括管理"
        ) { _ in AnyView(ModerationCenterView()) },

        FeatureItem(
            id: "notifications",
            icon: "bell.fill",
            color: .accentOrange,
            title: "通知設定",
            subtitle: "通知チャンネルの設定"
        ) { _ in AnyView(NotificationSettingsView()) },
    ]
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let item: FeatureItem

    var body: some View {
        HStack(spacing: .spacing16) {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(item.color)
                .frame(width: 38, height: 38)
                .background(item.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.bodyRegular)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                Text(item.subtitle)
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, .spacing6)
    }
}

#Preview {
    FeaturesTabView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}
