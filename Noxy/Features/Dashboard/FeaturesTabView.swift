import SwiftUI

struct FeaturesTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                contentSection
                communitySection
                automationSection
                moderationSection
                toolsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("機能")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if appState.isDemoMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        DemoBadge()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var contentSection: some View {
        Section("コンテンツ") {
            NavigationLink {
                EmbedListView()
            } label: {
                FeatureRow(icon: "rectangle.stack.fill", title: "埋め込みメッセージ", subtitle: "Embedテンプレートの作成・送信")
            }
        }
    }

    private var communitySection: some View {
        Section("コミュニティ") {
            NavigationLink {
                MembersListView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(icon: "person.3.fill", title: "メンバー", subtitle: "メンバー一覧と管理")
            }

            NavigationLink {
                VerifyPanelListView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(
                    icon: "checkmark.shield.fill",
                    title: "認証",
                    subtitle: "CAPTCHA認証でロールを自動付与",
                    accentColor: Theme.Color.statusOK
                )
            }

            NavigationLink {
                TicketsCoordinatorView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(icon: "ticket.fill", title: "チケット", subtitle: "サポートチケットの管理")
            }

            NavigationLink {
                TempVCListView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(icon: "waveform.and.mic", title: "一時チャンネル", subtitle: "参加すると自動でVCを作成")
            }

            NavigationLink {
                InviteTrackerView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(
                    icon: "person.badge.plus",
                    title: "招待トラッカー",
                    subtitle: "招待数・樹形図・キャンペーン管理",
                    accentColor: Color.accentPurple
                )
            }

            FeatureRow(icon: "chart.bar.fill", title: "レベリング", subtitle: "XP・リーダーボード・ロール報酬", isComingSoon: true).disabled(true)
            FeatureRow(icon: "checkmark.circle.fill", title: "投票", subtitle: "アンケートと投票", isComingSoon: true).disabled(true)
            FeatureRow(icon: "gift.fill", title: "ギブアウェイ", subtitle: "景品プレゼント抽選", accentColor: Color.accentPink, isComingSoon: true).disabled(true)
            FeatureRow(icon: "star.fill", title: "スターボード", subtitle: "殿堂入りメッセージ", isComingSoon: true).disabled(true)
        }
    }

    private var automationSection: some View {
        Section("自動化・通知") {
            NavigationLink {
                ReactionRolesView()
            } label: {
                FeatureRow(icon: "heart.fill", title: "リアクションロール", subtitle: "リアクションでロールを自動付与")
            }

            NavigationLink { WelcomeMessageView() } label: {
                FeatureRow(icon: "hand.wave.fill", title: "入退室メッセージ", subtitle: "入室・退室時の自動メッセージ")
            }

            NavigationLink { VCNotificationSettingsView() } label: {
                FeatureRow(icon: "speaker.wave.2.circle.fill", title: "VC参加通知", subtitle: "VCの入退室をチャンネルに通知")
            }

            FeatureRow(icon: "bubble.left.and.text.bubble.right.fill", title: "自動応答", subtitle: "キーワード → 返信の自動化", isComingSoon: true).disabled(true)
            FeatureRow(icon: "person.badge.plus.fill", title: "自動ロール", subtitle: "入室時にロールを自動付与", isComingSoon: true).disabled(true)
            FeatureRow(icon: "star.fill", title: "ブースト通知", subtitle: "サーバーブーストをお祝い", isComingSoon: true).disabled(true)
            FeatureRow(icon: "antenna.radiowaves.left.and.right", title: "SNS通知", subtitle: "YouTube・Twitch・Xの新着通知", isComingSoon: true).disabled(true)
        }
    }

    private var moderationSection: some View {
        Section("モデレーション") {
            NavigationLink { ModerationCenterView() } label: {
                FeatureRow(
                    icon: "shield.lefthalf.filled",
                    title: "モデレーション",
                    subtitle: "BAN・タイムアウト・警告・AutoMod を一括管理",
                    accentColor: Theme.Color.statusBad
                )
            }
            FeatureRow(icon: "shield.fill", title: "自動モデレーション", subtitle: "スパム・大文字・メンション制限", accentColor: Theme.Color.statusBad, isComingSoon: true).disabled(true)
            FeatureRow(icon: "xmark.seal.fill", title: "スパムフィルター", subtitle: "メッセージレート制限", isComingSoon: true).disabled(true)
            FeatureRow(icon: "nosign", title: "ワードフィルター", subtitle: "特定ワードをブロック", accentColor: Theme.Color.statusBad, isComingSoon: true).disabled(true)
        }
    }

    private var toolsSection: some View {
        Section("ツール") {
            NavigationLink {
                ShopsListView(guildId: appState.selectedGuildId, shopType: .shop)
            } label: {
                FeatureRow(icon: "cart.fill", title: "ショップ", subtitle: "商品販売・チケット交渉")
            }

            NavigationLink {
                ShopsListView(guildId: appState.selectedGuildId, shopType: .vendingMachine)
            } label: {
                FeatureRow(
                    icon: "storefront.fill",
                    title: "自販機",
                    subtitle: "即時購入・スムーズな取引",
                    accentColor: Theme.Color.statusOK
                )
            }

            NavigationLink {
                ServerRecoveryView()
            } label: {
                FeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "サーバー復旧",
                    subtitle: "OAuth2認証メンバーを自動参加",
                    accentColor: Theme.Color.statusOK
                )
            }

            NavigationLink {
                StatChannelsView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(
                    icon: "chart.bar.xaxis",
                    title: "ステータスチャンネル",
                    subtitle: "メンバー数・Boost数などをVC名に表示",
                    accentColor: .accentPurple
                )
            }
        }
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var accentColor: Color = Theme.Color.accent
    var isComingSoon: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Theme.Color.surfaceRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(Theme.Color.lineStrong, lineWidth: 1)
                    }
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)

                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isComingSoon {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .padding(.vertical, 2)
        .opacity(isComingSoon ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    FeaturesTabView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
}
