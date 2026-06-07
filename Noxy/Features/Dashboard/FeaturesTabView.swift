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
                if appState.isPro {
                    VerifyPanelListView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "checkmark.shield.fill",
                        featureTitle: "認証パネル",
                        description: "CAPTCHA認証でBOT・荒らしをブロック。安全なコミュニティを維持できます。",
                        proFeatures: [
                            ("🛡", "CAPTCHA認証でロール自動付与"),
                            ("🎨", "カスタムメッセージ・デザイン"),
                            ("📊", "認証ログ・統計"),
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "checkmark.shield.fill",
                    title: "認証",
                    subtitle: "CAPTCHA認証でロールを自動付与",
                    accentColor: .accentGreen,
                    badge: appState.isPro ? nil : "Pro"
                )
            }

            NavigationLink {
                if appState.isPro {
                    TicketsCoordinatorView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "ticket.fill",
                        featureTitle: "チケット",
                        description: "サポートチケットシステムを導入。メンバーの問い合わせを効率的に管理。",
                        proFeatures: [
                            ("🎫", "チケットの作成・クローズ"),
                            ("👥", "担当者アサイン"),
                            ("📁", "トランスクリプト保存"),
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "ticket.fill",
                    title: "チケット",
                    subtitle: "サポートチケットの管理",
                    badge: appState.isPro ? nil : "Pro"
                )
            }

            NavigationLink {
                if appState.isPro {
                    TempVCListView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "waveform.and.mic",
                        featureTitle: "一時チャンネル",
                        description: "参加すると自動でVCを作成し、退出時に自動削除。常にすっきりとしたサーバーを維持。",
                        proFeatures: [
                            ("🔊", "参加で自動作成・退出で自動削除"),
                            ("⚙️", "チャンネル名・人数制限を設定"),
                            ("🎮", "ゲームセッション用途に最適"),
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "waveform.and.mic",
                    title: "一時チャンネル",
                    subtitle: "参加すると自動でVCを作成",
                    badge: appState.isPro ? nil : "Pro"
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

            FeatureRow(
                icon: "gift.fill",
                title: "ギブアウェイ",
                subtitle: "景品プレゼント抽選",
                accentColor: .accentPink,
                isComingSoon: true
            )
            .disabled(true)

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
                if appState.isPro {
                    ReactionRolesView()
                } else {
                    ProUpgradeView(
                        featureIcon: "heart.fill",
                        featureTitle: "リアクションロール",
                        description: "リアクションを押すだけでロールを自動付与。サーバー運営に欠かせない定番機能。",
                        proFeatures: [
                            ("💜", "絵文字1つでロール付与・解除"),
                            ("📋", "複数パネル・複数ロール設定"),
                            ("⚡", "リアルタイム同期"),
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "heart.fill",
                    title: "リアクションロール",
                    subtitle: "リアクションでロールを自動付与",
                    badge: appState.isPro ? nil : "Pro"
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
                if appState.isPro {
                    StatChannelsView(guildId: appState.selectedGuildId)
                } else {
                    ProUpgradeView(
                        featureIcon: "chart.bar.xaxis",
                        featureTitle: "ステータスチャンネル",
                        description: "メンバー数やBoost数をVCチャンネル名にリアルタイム表示。サーバーの今がひと目でわかる。",
                        proFeatures: [
                            ("📊", "メンバー数・Boost数をリアルタイム表示"),
                            ("🔧", "表示フォーマットを自由にカスタマイズ"),
                            ("♾️", "複数チャンネルの同時設定"),
                        ]
                    )
                }
            } label: {
                FeatureRow(
                    icon: "chart.bar.xaxis",
                    title: "ステータスチャンネル",
                    subtitle: "メンバー数・Boost数などをVC名に表示",
                    accentColor: .accentPurple,
                    badge: appState.isPro ? nil : "Pro"
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