import SwiftUI

struct MoreTabView: View {
    @Environment(AuthManager.self) private var authManager
//    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            List {
                Section("アカウント") {
                    NavigationLink { ProfileView() } label: {
                        HStack(spacing: .spacing12) {
                            Avatar(name: authManager.currentUser?.displayName ?? "User",
                                   size: 40, accentColor: .accentIndigo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.currentUser?.displayName ?? "User")
                                    .font(.titleMedium)
                                    .foregroundStyle(Color.textPrimary)
                                Text("@" + (authManager.currentUser?.username ?? ""))
                                    .font(.captionRegular)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .padding(.vertical, .spacing4)
                    }

                    NavigationLink { SubscriptionView() } label: {
                        HStack {
                            Label("サブスクリプション", systemImage: "star.fill")
                            Spacer()
                            Badge(text: "FREE", color: .accentOrange)
                        }
                    }
                }

                Section("設定") {
                    NavigationLink { AppearanceSettingsView() } label: {
                        Label("外観", systemImage: "paintbrush.fill")
                    }
//                    Label("言語", systemImage: "globe")
//                    NavigationLink { NotificationSettingsView() } label: {
//                        Label("通知", systemImage: "bell.fill")
//                    }
                }

                Section("Bot") {
                    NavigationLink { SupabaseSettingsView() } label: {
                        Label("設定", systemImage: "gearshape.fill")
                    }
                    Label("接続済みサーバー", systemImage: "server.rack")
                    Label("権限", systemImage: "lock.shield.fill")
                }

                Section("データ") {
                    Label("データをエクスポート", systemImage: "square.and.arrow.up")
                    Button {
                        // mock clear cache
                    } label: {
                        Label("キャッシュを削除", systemImage: "trash")
                            .foregroundStyle(Color.textPrimary)
                    }
                }

                Section("サポート") {
                    NavigationLink { HelpCenterView() } label: {
                        Label("ヘルプセンター", systemImage: "questionmark.circle.fill")
                    }
                    Label("お問い合わせ", systemImage: "envelope.fill")
                    Label("バグを報告", systemImage: "ant.fill")
                    Label("機能を提案", systemImage: "lightbulb.fill")
                }

                Section("このアプリについて") {
                    HStack {
                        Label("バージョン", systemImage: "info.circle.fill")
                        Spacer()
                        Text("1.0.0 (1)")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textTertiary)
                    }
                    Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                    Label("利用規約", systemImage: "doc.text.fill")
                    Label("オープンソースライセンス", systemImage: "curlybraces")
                }

                Section {
                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            // TODO: Coming Soon - 通知センター
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button {
//                        showNotifications = true
//                    } label: {
//                        Image(systemName: "bell.fill")
//                            .foregroundStyle(Color.textSecondary)
//                    }
//                }
//            }
//            .sheet(isPresented: $showNotifications) {
//                NotificationCenterView()
//            }
        }
    }
}

#Preview {
    MoreTabView()
        .environment(AuthManager(services: ServiceContainer.live()))
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}
