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
        }
    }

    // MARK: - Sections

    private var contentSection: some View {
        Section("コンテンツ") {
            NavigationLink {
                EmbedListView()
            } label: {
                FeatureRow(
                    icon: "rectangle.stack.fill",
                    title: "埋め込みメッセージ",
                    subtitle: "Embedテンプレートの作成・送信"
                )
            }

            NavigationLink {
                if appState.isPro {
                    ScheduledMessagesListView()
                } else {
                    ProUpgradeView(
                        featureIcon: "clock.fill",
                        featureTitle: "予約投稿",
                        description: "指定時刻に自動でメッセージを送信できます",
                        proFeatures: [
                            ("📅", "日時指定で自動送信"),
                            ("🔁", "繰り返し投稿"),
                            ("📝", "Embedテンプレート使用"),
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "clock.fill",
                    title: "予約投稿",
                    subtitle: "指定時刻にメッセージを送信",
                    badge: appState.isPro ? nil : "Pro"
                )
            }

            NavigationLink {
                if appState.isPro {
                    RecurringPostsListView()
                } else {
                    ProUpgradeView(
                        featureIcon: "repeat.circle.fill",
                        featureTitle: "定期投稿",
                        description: "日次・週次・月次で自動投稿できます",
                        proFeatures: [
                            ("🗓", "日次・週次・月次スケジュール"),
                            ("📝", "Embedテンプレート使用"),
                            ("⏱", "好きな時刻に配信"),
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "repeat.circle.fill",
                    title: "定期投稿",
                    subtitle: "日次・週次・月次の自動投稿",
                    badge: appState.isPro ? nil : "Pro"
                )
            }
        }
    }

    private var communitySection: some View {
        Section("コミュニティ") {
            NavigationLink {
                MembersListView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(
                    icon: "person.3.fill",
                    title: "メンバー",
                    subtitle: "メンバー一覧と管理"
                )
            }

            NavigationLink {
                TicketsListView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(
                    icon: "ticket.fill",
                    title: "チケット",
                    subtitle: "サポートチケットの管理"
                )
            }

            NavigationLink {
                TempVCListView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(
                    icon: "waveform.and.mic",
                    title: "一時チャンネル",
                    subtitle: "参加すると自動でVCを作成"
                )
            }

            FeatureRow(
                icon: "chart.bar.fill",
                title: "レベリング",
                subtitle: "XP・リーダーボード・ロール報酬",
                isComingSoon: true
            )
            .disabled(true)

            FeatureRow(
                icon: "checkmark.circle.fill",
                title: "投票",
                subtitle: "アンケートと投票",
                isComingSoon: true
            )
            .disabled(true)

            NavigationLink {
                GiveawaysView()
            } label: {
                FeatureRow(
                    icon: "gift.fill",
                    title: "ギブアウェイ",
                    subtitle: "景品プレゼント抽選",
                    accentColor: .accentPink,
                    badge: "Pro"
                )
            }

            FeatureRow(
                icon: "star.fill",
                title: "スターボード",
                subtitle: "殿堂入りメッセージ",
                isComingSoon: true
            )
            .disabled(true)
        }
    }

    private var automationSection: some View {
        Section("自動化・通知") {
            NavigationLink {
                ReactionRolesView()
            } label: {
                FeatureRow(
                    icon: "heart.fill",
                    title: "リアクションロール",
                    subtitle: "リアクションでロールを自動付与"
                )
            }

            NavigationLink {
                WelcomeMessageView()
            } label: {
                FeatureRow(
                    icon: "hand.wave.fill",
                    title: "入退室メッセージ",
                    subtitle: "入室・退室時の自動メッセージ"
                )
            }

            FeatureRow(
                icon: "bubble.left.and.text.bubble.right.fill",
                title: "自動応答",
                subtitle: "キーワード → 返信の自動化",
                isComingSoon: true
            )
            .disabled(true)

            FeatureRow(
                icon: "person.badge.plus.fill",
                title: "自動ロール",
                subtitle: "入室時にロールを自動付与",
                isComingSoon: true
            )
            .disabled(true)

            FeatureRow(
                icon: "star.fill",
                title: "ブースト通知",
                subtitle: "サーバーブーストをお祝い",
                isComingSoon: true
            )
            .disabled(true)

            FeatureRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "SNS通知",
                subtitle: "YouTube・Twitch・Xの新着通知",
                isComingSoon: true
            )
            .disabled(true)
        }
    }

    private var moderationSection: some View {
        Section("モデレーション") {
            NavigationLink {
                ModerationCenterView()
            } label: {
                FeatureRow(
                    icon: "shield.lefthalf.filled",
                    title: "モデレーション",
                    subtitle: "BAN・タイムアウト・警告・AutoMod を一括管理",
                    accentColor: .accentRed
                )
            }

            FeatureRow(
                icon: "shield.fill",
                title: "自動モデレーション",
                subtitle: "スパム・大文字・メンション制限",
                accentColor: .accentRed,
                isComingSoon: true
            )
            .disabled(true)

            FeatureRow(
                icon: "xmark.seal.fill",
                title: "スパムフィルター",
                subtitle: "メッセージレート制限",
                isComingSoon: true
            )
            .disabled(true)

            FeatureRow(
                icon: "nosign",
                title: "ワードフィルター",
                subtitle: "特定ワードをブロック",
                accentColor: .accentRed,
                isComingSoon: true
            )
            .disabled(true)
        }
    }

    private var toolsSection: some View {
        Section("ツール") {
            NavigationLink {
                if appState.isPro {
                    ShopsListView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "cart.fill",
                        featureTitle: "ショップ",
                        description: "Discordサーバーで商品を販売できます",
                        proFeatures: [
                            ("🛍", "商品ページの作成・管理"),
                            ("📦", "注文の受付・履歴管理"),
                            ("💳", "売上レポート"),
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "cart.fill",
                    title: "ショップ",
                    subtitle: "商品販売・注文管理",
                    badge: appState.isPro ? nil : "Pro"
                )
            }

            NavigationLink {
                StatChannelsView(guildId: appState.selectedGuildId)
            } label: {
                FeatureRow(
                    icon: "chart.bar.xaxis",
                    title: "ステータスチャンネル",
                    subtitle: "メンバー数・Boost数などをVC名に表示",
                    accentColor: .accentPurple,
                    badge: "Pro"
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
    var accentColor: Color = .accentIndigo
    var isComingSoon: Bool = false
    var badge: String?     = nil  // "Pro" などのバッジテキスト

    var body: some View {
        HStack(spacing: .spacing12) {
            // Icon
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(accentColor)
                .frame(width: 32, height: 32)
                .background(accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))

            // Text
            VStack(alignment: .leading, spacing: .spacing2) {
                HStack(spacing: .spacing6) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(colors: [Color.accentOrange, Color.accentPink],
                                               startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Coming Soon indicator
            if isComingSoon {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .opacity(isComingSoon ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    FeaturesTabView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
}