import SwiftUI

struct CommunityTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("コミュニティ管理") {
                    NavigationLink {
                        MembersListView(guildId: appState.selectedGuildId)
                    } label: {
                        CommunityMenuRow(icon: "person.3.fill",
                                         title: "メンバー",
                                         subtitle: "メンバー一覧と管理",
                                         color: .accentIndigo)
                    }

                    NavigationLink {
                        TicketsListView(guildId: appState.selectedGuildId)
                    } label: {
                        CommunityMenuRow(icon: "ticket.fill",
                                         title: "チケット",
                                         subtitle: "サポート対応",
                                         color: .accentOrange)
                    }

                    NavigationLink {
                        TempChannelSettingsView(guildId: appState.selectedGuildId)
                    } label: {
                        CommunityMenuRow(icon: "waveform.and.mic",
                                         title: "一時チャンネル",
                                         subtitle: "VC参加時に自動作成されるプライベートチャンネル",
                                         color: .accentGreen)
                    }

//                    NavigationLink {
//                        ModerationToolsView()
//                    } label: {
//                        CommunityMenuRow(icon: "hammer.fill",
//                                         title: "モデレーション",
//                                         subtitle: "BAN・キック・タイムアウト・警告",
//                                         color: Color(uiColor: UIColor(hex: 0xEF4444)))
//                    }
                }

//                Section("エンゲージメント") {
//                    NavigationLink {
//                        LevelingView()
//                    } label: {
//                        CommunityMenuRow(icon: "chart.bar.fill",
//                                         title: "レベリング",
//                                         subtitle: "XP・リーダーボード・ロール報酬",
//                                         color: .accentGreen)
//                    }

//                    NavigationLink {
//                        PollsView()
//                    } label: {
//                        CommunityMenuRow(icon: "checkmark.circle.fill",
//                                     title: "投票",
//                                         subtitle: "アンケートと投票",
//                                         color: .accentPurple)
//                    }

//                    NavigationLink {
//                        GiveawaysView()
//                    } label: {
//                        CommunityMenuRow(icon: "gift.fill",
//                                         title: "ギブアウェイ",
//                                         subtitle: "景品プレゼント抽選",
//                                         color: .accentPink)
//                    }

//                    NavigationLink {
//                        StarboardView()
//                    } label: {
//                        CommunityMenuRow(icon: "star.fill",
//                                         title: "スターボード",
//                                         subtitle: "殿堂入りメッセージ",
//                                         color: .accentOrange)
//                    }
//                }

                Section("記録") {
                    NavigationLink {
                        AuditLogView(guildId: appState.selectedGuildId)
                    } label: {
                        CommunityMenuRow(icon: "doc.text.magnifyingglass",
                                         title: "監査ログ",
                                         subtitle: "サーバー操作の記録",
                                         color: .textSecondary)
                    }
                }
            }
            .navigationTitle("サーバー")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct CommunityMenuRow: View {
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

#Preview {
    CommunityTabView()
        .environment(AppState())
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}
