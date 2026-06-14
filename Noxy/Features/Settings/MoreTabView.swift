import SwiftUI

struct MoreTabView: View {
    @Environment(AuthManager.self)  private var authManager
    @Environment(AppState.self)     private var appState
    @Environment(\.services)        private var services

    @State private var subStatus: SubscriptionStatus = .inactive
    @State private var showSignOutConfirm = false
    @State private var showDebugResetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
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
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.Color.bg)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadSubStatus() }
        .onReceive(NotificationCenter.default.publisher(for: PlatformHelper.willEnterForegroundNotification)) { _ in
            Task { await loadSubStatus() }
        }
        .overlay {
            if showSignOutConfirm {
                ConfirmModal(
                    icon: "arrow.right.square.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "サインアウトしますか？",
                    message: "再度ログインする必要があります。",
                    primaryLabel: "サインアウト",
                    primaryRole: .destructive,
                    onPrimary: {
                        authManager.logout()
                        showSignOutConfirm = false
                    },
                    onCancel: { showSignOutConfirm = false }
                )
            }
        }
        #if DEBUG
        .overlay {
            if showDebugResetConfirm {
                ConfirmModal(
                    icon: "arrow.counterclockwise",
                    iconColor: Theme.Color.statusBad,
                    title: "Pro状態をリセットしますか？",
                    message: "DBとローカルのPro状態が削除されます。サーバーの有効化も解除されます。",
                    primaryLabel: "リセットする",
                    primaryRole: .destructive,
                    onPrimary: {
                        DebugSettings.shared.resetAll()
                        showDebugResetConfirm = false
                    },
                    onCancel: { showDebugResetConfirm = false }
                )
            }
        }
        #endif
    }

    // MARK: - Sections

    private var profileSection: some View {
        Card {
            VStack(spacing: 0) {
                NavigationLink {
                    ProfileView()
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Avatar(
                            name: authManager.currentUser?.displayName ?? "User",
                            size: 48,
                            accentColor: Theme.Color.accent
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(authManager.currentUser?.displayName ?? "User")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textPrimary)

                            Text("@" + (authManager.currentUser?.username ?? ""))
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .monospaced()
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().background(Theme.Color.line)

                NavigationLink {
                    SubscriptionView()
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: subStatus.isActive ? "crown.fill" : "star.fill")
                            .foregroundStyle(Theme.Color.textSecondary)
                            .frame(width: 28)

                        Text("サブスクリプション")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)

                        Spacer()

                        if subStatus.isActive {
                            Text("PRO")
                                .font(Theme.Font.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.Color.statusOK)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Color.statusOK.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Text("FREE")
                                .font(Theme.Font.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.Color.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Color.surfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Image(systemName: "chevron.right")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // 有料ユーザーのみ表示
                if subStatus.isActive {
                    Divider().background(Theme.Color.line)

                    NavigationLink {
                        ServerActivationView()
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "server.rack")
                                .foregroundStyle(Theme.Color.textSecondary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("サーバーの有効化")
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                Text("スロット: \(subStatus.usedSlots) / \(subStatus.purchasedSlots) 使用中")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textSecondary)
                                    .monospaced()
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        .padding(.vertical, Theme.Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
        FormSection("設定", icon: "gear") {
            VStack(spacing: 0) {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    SettingsRow(icon: "bell.badge.fill", title: "通知設定")
                }
                .buttonStyle(.plain)
                Divider().background(Theme.Color.line)
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    SettingsRow(icon: "paintbrush.fill", title: "外観")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var botSection: some View {
        FormSection("Bot", icon: "cpu") {
            VStack(spacing: 0) {
                NavigationLink {
                    SupabaseSettingsView()
                } label: {
                    SettingsRow(icon: "gearshape.fill", title: "設定")
                }
                .buttonStyle(.plain)
                Divider().background(Theme.Color.line)
                SettingsRow(icon: "server.rack", title: "接続済みサーバー")
                    .opacity(0.5)
                Divider().background(Theme.Color.line)
                SettingsRow(icon: "lock.shield.fill", title: "権限")
                    .opacity(0.5)
            }
        }
    }

    private var dataSection: some View {
        FormSection("データ", icon: "externaldrive") {
            VStack(spacing: 0) {
                SettingsRow(icon: "square.and.arrow.up", title: "データをエクスポート")
                    .opacity(0.5)
                Divider().background(Theme.Color.line)
                Button {
                    // TODO: キャッシュ削除
                } label: {
                    SettingsRow(icon: "trash", title: "キャッシュを削除", tint: Theme.Color.statusBad)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var supportSection: some View {
        FormSection("サポート", icon: "lifepreserver") {
            VStack(spacing: 0) {
                NavigationLink {
                    HelpCenterView()
                } label: {
                    SettingsRow(icon: "questionmark.circle.fill", title: "ヘルプセンター")
                }
                .buttonStyle(.plain)
                Divider().background(Theme.Color.line)
                SettingsRow(icon: "envelope.fill", title: "お問い合わせ")
                    .opacity(0.5)
                Divider().background(Theme.Color.line)
                SettingsRow(icon: "ant.fill", title: "バグを報告")
                    .opacity(0.5)
                Divider().background(Theme.Color.line)
                SettingsRow(icon: "lightbulb.fill", title: "機能を提案")
                    .opacity(0.5)
            }
        }
    }

    private var aboutSection: some View {
        FormSection("このアプリについて", icon: "info.circle") {
            VStack(spacing: 0) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(width: 28)

                    Text("バージョン")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)

                    Spacer()

                    Text("1.0.0 (1)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .monospaced()
                }
                .padding(.vertical, Theme.Spacing.sm)
                Divider().background(Theme.Color.line)
                SettingsRow(icon: "hand.raised.fill", title: "プライバシーポリシー")
                    .opacity(0.5)
                Divider().background(Theme.Color.line)
                SettingsRow(icon: "doc.text.fill", title: "利用規約")
                    .opacity(0.5)
                Divider().background(Theme.Color.line)
                SettingsRow(icon: "curlybraces", title: "オープンソースライセンス")
                    .opacity(0.5)
            }
        }
    }

    private var signOutSection: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            HStack {
                Spacer()
                Text("サインアウト")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.statusBad)
                Spacer()
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Debug（DEBUG ビルドのみ表示）

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        let debug = DebugSettings.shared

        FormSection("開発者ツール", icon: "hammer") {
            VStack(spacing: 0) {
                NavigationLink {
                    ComponentLibraryView()
                } label: {
                    SettingsRow(icon: "paintpalette.fill", title: "コンポーネントライブラリ")
                }
                .buttonStyle(.plain)
                Divider().background(Theme.Color.line)

                // Pro / Free 切り替え（実際に DB を操作する）
                HStack(spacing: Theme.Spacing.sm) {
                    if debug.isWorking {
                        ProgressView().frame(width: 28)
                    } else {
                        Image(systemName: debug.isProMode ? "crown.fill" : "crown")
                            .foregroundStyle(Theme.Color.textSecondary)
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
                    .tint(Theme.Color.accent)
                    .disabled(debug.isWorking)
                }
                .padding(.vertical, Theme.Spacing.sm)

                if let err = debug.lastError {
                    Divider().background(Theme.Color.line)
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.statusBad)
                        .padding(.vertical, Theme.Spacing.sm)
                }

                Divider().background(Theme.Color.line)

                // 全リセット
                Button {
                    showDebugResetConfirm = true
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(Theme.Color.statusBad)
                            .frame(width: 28)
                        Text("Pro状態をリセット（DB + ローカル）")
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                }
                .buttonStyle(.plain)
                .disabled(debug.isWorking)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
    }
    #endif
}

// MARK: - SettingsRow

private struct SettingsRow: View {
    let icon: String
    let title: String
    var tint: Color = Theme.Color.textSecondary

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 28)

            Text(title)
                .font(Theme.Font.body)
                .foregroundStyle(tint == Theme.Color.statusBad ? Theme.Color.statusBad : Theme.Color.textPrimary)

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    MoreTabView()
        .environment(AuthManager(services: ServiceContainer.live()))
        .environment(\.services, ServiceContainer.live())
}

#Preview("Dark") {
    MoreTabView()
        .environment(AuthManager(services: ServiceContainer.live()))
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    MoreTabView()
        .environment(AuthManager(services: ServiceContainer.live()))
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.light)
}
