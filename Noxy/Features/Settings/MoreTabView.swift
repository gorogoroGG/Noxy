import SwiftUI

struct MoreTabView: View {
    @Environment(AuthManager.self)  private var authManager
    @Environment(AppState.self)     private var appState
    @Environment(\.services)        private var services

    @State private var subStatus: SubscriptionStatus = .inactive

    var body: some View {
        NavigationStack {
            List {
                profileSection
                settingsSection
                botSection
                dataSection
                supportSection
                aboutSection
                signOutSection
                #if DEBUG
                debugSection
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadSubStatus() }
        .onReceive(NotificationCenter.default.publisher(for: PlatformHelper.willEnterForegroundNotification)) { _ in
            Task { await loadSubStatus() }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            NavigationLink {
                ProfileView()
            } label: {
                HStack(spacing: .spacing12) {
                    Avatar(
                        name: authManager.currentUser?.displayName ?? "User",
                        size: 48,
                        accentColor: .accentIndigo
                    )

                    VStack(alignment: .leading, spacing: .spacing2) {
                        Text(authManager.currentUser?.displayName ?? "User")
                            .font(.body)
                            .foregroundStyle(Color.textPrimary)

                        Text("@" + (authManager.currentUser?.username ?? ""))
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()
                }
                .padding(.vertical, .spacing4)
            }

            NavigationLink {
                SubscriptionView()
            } label: {
                HStack(spacing: .spacing12) {
                    Image(systemName: subStatus.isActive ? "crown.fill" : "star.fill")
                        .foregroundStyle(subStatus.isActive ? Color.accentOrange : Color.accentIndigo)
                        .frame(width: 28)

                    Text("サブスクリプション")
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    if subStatus.isActive {
                        Badge(text: "PRO", color: .accentOrange)
                    } else {
                        Badge(text: "FREE", color: .accentOrange)
                    }
                }
            }

            // 有料ユーザーのみ表示
            if subStatus.isActive {
                NavigationLink {
                    ServerActivationView()
                } label: {
                    HStack(spacing: .spacing12) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(Color.accentIndigo)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("サーバーの有効化")
                                .font(.body)
                                .foregroundStyle(Color.textPrimary)
                            Text("スロット: \(subStatus.usedSlots) / \(subStatus.purchasedSlots) 使用中")
                                .font(.captionRegular)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func loadSubStatus() async {
        let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        guard !userId.isEmpty else { return }
        subStatus = (try? await services.subscription.fetchStatus(discordUserId: userId)) ?? .inactive
    }

    private var settingsSection: some View {
        Section("設定") {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                SettingsRow(icon: "paintbrush.fill", title: "外観")
            }
        }
    }

    private var botSection: some View {
        Section("Bot") {
            NavigationLink {
                SupabaseSettingsView()
            } label: {
                SettingsRow(icon: "gearshape.fill", title: "設定")
            }

            SettingsRow(icon: "server.rack", title: "接続済みサーバー")
                .opacity(0.5)
                .disabled(true)

            SettingsRow(icon: "lock.shield.fill", title: "権限")
                .opacity(0.5)
                .disabled(true)
        }
    }

    private var dataSection: some View {
        Section("データ") {
            SettingsRow(icon: "square.and.arrow.up", title: "データをエクスポート")
                .opacity(0.5)
                .disabled(true)

            Button {
                // TODO: キャッシュ削除
            } label: {
                SettingsRow(icon: "trash", title: "キャッシュを削除", tint: .accentRed)
            }
        }
    }

    private var supportSection: some View {
        Section("サポート") {
            NavigationLink {
                HelpCenterView()
            } label: {
                SettingsRow(icon: "questionmark.circle.fill", title: "ヘルプセンター")
            }

            SettingsRow(icon: "envelope.fill", title: "お問い合わせ")
                .opacity(0.5)
                .disabled(true)

            SettingsRow(icon: "ant.fill", title: "バグを報告")
                .opacity(0.5)
                .disabled(true)

            SettingsRow(icon: "lightbulb.fill", title: "機能を提案")
                .opacity(0.5)
                .disabled(true)
        }
    }

    private var aboutSection: some View {
        Section("このアプリについて") {
            HStack(spacing: .spacing12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.accentIndigo)
                    .frame(width: 28)

                Text("バージョン")
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("1.0.0 (1)")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            SettingsRow(icon: "hand.raised.fill", title: "プライバシーポリシー")
                .opacity(0.5)
                .disabled(true)

            SettingsRow(icon: "doc.text.fill", title: "利用規約")
                .opacity(0.5)
                .disabled(true)

            SettingsRow(icon: "curlybraces", title: "オープンソースライセンス")
                .opacity(0.5)
                .disabled(true)
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                authManager.logout()
            } label: {
                HStack {
                    Spacer()
                    Text("サインアウト")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Debug（DEBUG ビルドのみ表示）

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        let debug = DebugSettings.shared

        Section {
            // Pro / Free 切り替え（実際に DB を操作する）
            HStack(spacing: .spacing12) {
                if debug.isWorking {
                    ProgressView().frame(width: 28)
                } else {
                    Image(systemName: debug.isProMode ? "crown.fill" : "crown")
                        .foregroundStyle(debug.isProMode ? Color.accentOrange : Color.textTertiary)
                        .frame(width: 28)
                }
                Toggle(
                    debug.isProMode ? "Pro モード ON（3スロット）" : "Pro モード OFF",
                    isOn: Binding(
                        get: { debug.isProMode },
                        set: { newVal in
                            Task { await debug.setProMode(newVal) }
                        }
                    )
                )
                .tint(Color.accentOrange)
                .disabled(debug.isWorking)
            }

            if let err = debug.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.captionRegular)
                    .foregroundStyle(Color.accentRed)
            }

            // 全リセット
            Button(role: .destructive) {
                debug.resetAll()
            } label: {
                HStack(spacing: .spacing12) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(Color.accentRed)
                        .frame(width: 28)
                    Text("Pro状態をリセット（DB + ローカル）")
                        .foregroundStyle(Color.accentRed)
                }
            }
            .disabled(debug.isWorking)
        } header: {
            Label("デバッグ", systemImage: "ant.fill")
        } footer: {
            if debug.isProMode {
                Text("✅ DB に user_profiles（3スロット）が存在します\nサーバーの有効化はサブスクリプション画面から行えます")
            } else {
                Text("このセクションは DEBUG ビルドでのみ表示されます")
            }
        }
    }
    #endif
}

// MARK: - SettingsRow

private struct SettingsRow: View {
    let icon: String
    let title: String
    var tint: Color = .accentIndigo

    var body: some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundStyle(tint == .accentRed ? .accentRed : Color.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    MoreTabView()
        .environment(AuthManager(services: ServiceContainer.live()))
        .environment(\.services, ServiceContainer.live())
}