import SwiftUI

struct ActionsTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing32) {
                    createSendGroup
                    communityGroup
                    automationGroup
                    toolsGroup
                }
                .padding(.bottom, .spacing32)
            }
            .background(Color.bgPrimary)
            .navigationTitle("アクション")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 送る・作る

    private var createSendGroup: some View {
        ActionGroup(title: "送る・作る", icon: "paperplane.fill") {
            navCard(icon: "rectangle.stack.badge.plus", title: "Embedメッセージ",
                    description: "画像・装飾付きのお知らせ作成", color: .accentIndigo) {
                EmbedListView()
            }
        }
    }

    // MARK: - コミュニティ

    private var communityGroup: some View {
        ActionGroup(title: "コミュニティ", icon: "person.3.fill") {
            navCard(icon: "ticket.fill", title: "チケット",
                    description: "サポート・お問い合わせ対応", color: .accentOrange) {
                TicketsCoordinatorView(guildId: appState.selectedGuildId)
            }
            navCard(icon: "waveform.and.mic", title: "一時VC",
                    description: "入室すると自動でVCを作成", color: .accentIndigo) {
                TempVCListView(guildId: appState.selectedGuildId)
            }
            navCard(icon: "gift.fill", title: "ギブアウェイ",
                    description: "景品プレゼント抽選", color: .accentPink) {
                GiveawaysView()
            }
            comingSoonCard(icon: "checkmark.circle.fill", title: "投票",
                           description: "アンケートと投票", color: .accentGreen)
            comingSoonCard(icon: "star.fill", title: "スターボード",
                           description: "神投稿をピックアップ", color: .accentOrange)
        }
    }

    // MARK: - 自動化

    private var automationGroup: some View {
        ActionGroup(title: "自動化", icon: "sparkles") {
            navCard(icon: "hand.wave.fill", title: "入退室メッセージ",
                    description: "参加・退出時に自動あいさつ", color: .accentGreen) {
                WelcomeMessageView()
            }
            navCard(icon: "heart.fill", title: "リアクションロール",
                    description: "スタンプでロールを自動付与", color: .accentPink) {
                ReactionRolesView()
            }
            comingSoonCard(icon: "bubble.left.and.text.bubble.right.fill", title: "自動応答",
                           description: "キーワードに自動返信", color: .accentIndigo)
            comingSoonCard(icon: "person.badge.plus.fill", title: "自動ロール",
                           description: "入室時にロールを自動付与", color: .accentPurple)
            comingSoonCard(icon: "antenna.radiowaves.left.and.right", title: "SNS通知",
                           description: "YouTube・Twitch・X新着通知", color: .accentOrange)
        }
    }

    // MARK: - ツール

    private var toolsGroup: some View {
        ActionGroup(title: "ツール", icon: "wrench.and.screwdriver.fill") {
            if appState.isPro {
                navCard(icon: "cart.fill", title: "ショップ",
                        description: "サーバー内で商品を販売", color: .accentOrange) {
                    ShopsListView(guildId: appState.selectedGuildId)
                }
            } else {
                proNavCard(icon: "cart.fill", title: "ショップ",
                           description: "サーバー内で商品を販売", color: .accentOrange) {
                    ProUpgradeView(featureIcon: "cart.fill", featureTitle: "ショップ",
                                   description: "Discordサーバーで商品を販売できます",
                                   proFeatures: [("🛍","商品ページの作成・管理"),("📦","注文の受付・履歴管理"),("💳","売上レポート")])
                }
            }
            navCard(icon: "chart.bar.xaxis", title: "ステータスチャンネル",
                    description: "メンバー数などをVC名に表示", color: .accentPurple) {
                StatChannelsView(guildId: appState.selectedGuildId)
            }
        }
    }

    // MARK: - Card builders

    @ViewBuilder
    private func navCard<D: View>(icon: String, title: String, description: String,
                                  color: Color, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            ActionCardFace(icon: icon, title: title, description: description,
                           color: color, badgeText: nil, locked: false)
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    @ViewBuilder
    private func proNavCard<D: View>(icon: String, title: String, description: String,
                                     color: Color, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            ActionCardFace(icon: icon, title: title, description: description,
                           color: color, badgeText: "Pro", locked: false)
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    @ViewBuilder
    private func comingSoonCard(icon: String, title: String, description: String, color: Color) -> some View {
        ActionCardFace(icon: icon, title: title, description: description,
                       color: color, badgeText: nil, locked: true)
    }
}

// MARK: - ActionGroup

private struct ActionGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack(spacing: .spacing6) {
                Image(systemName: icon)
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
                Text(title)
                    .font(.captionRegular)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, .spacing16)
            .textCase(nil)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: .spacing12),
                    GridItem(.flexible(), spacing: .spacing12),
                ],
                spacing: .spacing12
            ) {
                content()
            }
            .padding(.horizontal, .spacing16)
        }
    }
}

// MARK: - ActionCardFace

private struct ActionCardFace: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let badgeText: String?
    let locked: Bool

    private var opacity: Double { locked ? 0.38 : 1.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.titleMedium)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    .opacity(opacity)

                Spacer()

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                } else if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(
                                colors: [Color.accentOrange, Color.accentPink],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: .spacing2) {
                Text(title)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .opacity(locked ? 0.4 : 1.0)
                Text(description)
                    .font(.captionSmall)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(locked ? 0.4 : 1.0)
            }
        }
        .padding(.spacing12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(Color.bgSurface.opacity(locked ? 0.6 : 1.0))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

// MARK: - Preview

#Preview {
    ActionsTabView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
}
