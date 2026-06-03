import SwiftUI

struct AutomationTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("自動化") {
                    NavigationLink {
                        AutoResponsesListView(guildId: appState.selectedGuildId)
                    } label: {
                        AutomationMenuRow(icon: "bubble.left.and.text.bubble.right.fill",
                                          title: "自動返信",
                                          subtitle: "キーワード → 返信の自動化",
                                          color: .accentIndigo)
                    }

                    NavigationLink {
                        ReactionRolesView()
                    } label: {
                        AutomationMenuRow(icon: "heart.fill",
                                          title: "リアクションロール",
                                          subtitle: "リアクションでロールを付与",
                                          color: .accentPink)
                    }

                    NavigationLink {
                        WelcomeMessageView()
                    } label: {
                        AutomationMenuRow(icon: "arrow.left.arrow.right.circle.fill",
                                          title: "入退室メッセージ",
                                          subtitle: "参加・退室時の自動メッセージ",
                                          color: .accentGreen)
                    }

//                    NavigationLink {
//                        AutoRoleView()
//                    } label: {
//                        AutomationMenuRow(icon: "person.badge.plus.fill",
//                                          title: "自動ロール",
//                                          subtitle: "入室時にロールを自動付与",
//                                          color: .accentPurple)
//                    }

//                    NavigationLink {
//                        PlaceholderView(title: "ブースト通知")
//                    } label: {
//                        AutomationMenuRow(icon: "star.fill",
//                                          title: "ブースト通知",
//                                          subtitle: "サーバーブーストをお祝い",
//                                          color: .accentOrange)
//                    }
                }

                Section("スケジュール") {
                    NavigationLink {
                        ScheduledMessagesListView()
                    } label: {
                        AutomationMenuRow(icon: "calendar.badge.clock",
                                          title: "予約送信",
                                          subtitle: "指定時刻に送信",
                                          color: .accentPurple)
                    }

                    NavigationLink {
                        PlaceholderView(title: "定期アナウンス")
                    } label: {
                        AutomationMenuRow(icon: "repeat.circle.fill",
                                          title: "定期アナウンス",
                                          subtitle: "日次・週次投稿",
                                          color: .accentIndigo)
                    }
                }

//                Section("連携") {
//                    NavigationLink {
//                        SocialFeedsView()
//                    } label: {
//                        AutomationMenuRow(icon: "antenna.radiowaves.left.and.right",
//                                          title: "SNS通知",
//                                          subtitle: "YouTube・Twitch・Xの新着通知",
//                                          color: .accentIndigo)
//                    }
//                }

                Section("モデレーション") {
                    // TODO: Coming Soon - AutoMod
//                    NavigationLink {
//                        AutoModRulesView()
//                    } label: {
//                        AutomationMenuRow(icon: "shield.fill",
//                                          title: "自動モデレーション",
//                                          subtitle: "スパム・大文字・メンション制限",
//                                          color: .accentRed)
//                    }

//                    NavigationLink {
//                        PlaceholderView(title: "スパムフィルター")
//                    } label: {
//                        AutomationMenuRow(icon: "xmark.seal.fill",
//                                          title: "スパムフィルター",
//                                          subtitle: "メッセージレート制限",
//                                          color: .accentOrange)
//                    }

//                    NavigationLink {
//                        WordFilterView()
//                    } label: {
//                        AutomationMenuRow(icon: "nosign",
//                                          title: "ワードフィルター",
//                                          subtitle: "特定ワードをブロック",
//                                          color: .accentRed)
//                    }
                }
            }
            .navigationTitle("機能")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct AutomationMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .font(.titleMedium)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.titleMedium).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.captionRegular).foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.vertical, .spacing4)
    }
}

struct PlaceholderView: View {
    let title: String
    var body: some View {
        Text(title).navigationTitle(title).foregroundStyle(Color.textSecondary)
    }
}

#Preview {
    AutomationTabView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
}
