import SwiftUI

// MARK: - ServerActivationView
// 有料ユーザー向けのサーバー有効化管理画面。
// 所有するサーバー一覧を表示し、スロットを使って有効化/無効化できる。

struct ServerActivationView: View {
    @Environment(\.services) private var services

    @State private var subStatus:    SubscriptionStatus = .inactive
    @State private var ownerGuilds:  [Guild]            = []
    @State private var isLoading     = true
    @State private var processingId: String?             = nil  // 処理中のサーバーID
    @State private var errorMessage: String?             = nil
    @State private var toast:        String?             = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else {
                mainContent
            }
        }
        .navigationTitle("サーバーの有効化")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let toast {
                toastView(toast)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { self.toast = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        List {
            // スロット使用状況
            slotSection

            // エラー表示
            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.captionRegular)
                        .foregroundStyle(Color.accentRed)
                }
            }

            // サーバー一覧
            serverListSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - スロットセクション

    private var slotSection: some View {
        Section {
            VStack(spacing: .spacing12) {
                // スロットカウンター
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("使用中スロット")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(subStatus.usedSlots)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            Text("/ \(subStatus.purchasedSlots)")
                                .font(.titleMedium)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("残り")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textSecondary)
                        Text("\(subStatus.availableSlots)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(
                                subStatus.availableSlots > 0 ? Color.accentGreen : Color.accentOrange
                            )
                    }
                }

                // プログレスバー
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.bgSurface)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                subStatus.availableSlots > 0
                                    ? Color.accentIndigo
                                    : Color.accentOrange
                            )
                            .frame(
                                width: geo.size.width * CGFloat(subStatus.usedSlots) / CGFloat(max(subStatus.purchasedSlots, 1)),
                                height: 8
                            )
                            .animation(.easeInOut, value: subStatus.usedSlots)
                    }
                }
                .frame(height: 8)

                if subStatus.availableSlots == 0 {
                    HStack(spacing: .spacing6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.accentOrange)
                        Text("スロットが満杯です。不要なサーバーを無効化するかプランをアップグレードしてください")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .padding(.vertical, .spacing8)
        } header: {
            Text("スロット使用状況")
        }
    }

    // MARK: - サーバー一覧セクション

    private var serverListSection: some View {
        Section {
            if ownerGuilds.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: .spacing8) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.textTertiary)
                        Text("オーナーのサーバーがありません")
                            .font(.bodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, .spacing16)
            } else {
                ForEach(ownerGuilds) { guild in
                    ActivationRow(
                        guild: guild,
                        isActivated: subStatus.activatedGuildIds.contains(guild.id),
                        canActivate: subStatus.availableSlots > 0,
                        isProcessing: processingId == guild.id
                    ) { activate in
                        await toggle(guild: guild, activate: activate)
                    }
                }
            }
        } header: {
            Text("所有サーバー（\(ownerGuilds.count)件）")
        } footer: {
            Text("有効化すると1スロットを消費します。無効化するとスロットが戻ります。")
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        async let statusTask = services.subscription.fetchStatus(discordUserId: userId)
        async let guildsTask = services.guilds.fetchAll()
        subStatus   = (try? await statusTask) ?? .inactive
        let all     = (try? await guildsTask) ?? []
        ownerGuilds = all.filter { $0.userRole == .owner }
        isLoading   = false
    }

    private func toggle(guild: Guild, activate: Bool) async {
        processingId  = guild.id
        errorMessage  = nil
        do {
            if activate {
                try await services.subscription.activateServer(guildId: guild.id)
                withAnimation { toast = "「\(guild.name)」を有効化しました" }
            } else {
                try await services.subscription.deactivateServer(guildId: guild.id)
                withAnimation { toast = "「\(guild.name)」の有効化を解除しました" }
            }
            // ステータスを再取得してスロット数を更新
            let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
            subStatus = (try? await services.subscription.fetchStatus(discordUserId: userId)) ?? subStatus
        } catch {
            errorMessage = error.localizedDescription
        }
        processingId = nil
    }

    private func toastView(_ message: String) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text(message).font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
        }
        .padding(.horizontal, .spacing20).frame(height: 44)
        .background(Color.accentGreen).clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - ActivationRow

private struct ActivationRow: View {
    let guild: Guild
    let isActivated: Bool
    let canActivate: Bool
    let isProcessing: Bool
    let onToggle: (Bool) async -> Void

    var body: some View {
        HStack(spacing: .spacing12) {
            // サーバーアイコン（イニシャル）
            ZStack {
                RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                    .fill(isActivated ? Color.accentIndigo.opacity(0.15) : Color.bgSurface)
                    .frame(width: 40, height: 40)
                Text(String(guild.name.prefix(1)).uppercased())
                    .font(.titleMedium)
                    .foregroundStyle(isActivated ? Color.accentIndigo : Color.textTertiary)
            }

            // サーバー情報
            VStack(alignment: .leading, spacing: 2) {
                Text(guild.name)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(isActivated ? Color.accentGreen : Color.textTertiary)
                        .frame(width: 6, height: 6)
                    Text(isActivated ? "有効化済み • スロット使用中"
                         : canActivate ? "無効"
                         : "無効（スロット不足）")
                        .font(.captionRegular)
                        .foregroundStyle(isActivated ? Color.accentGreen : Color.textTertiary)
                }
            }

            Spacer()

            // トグル or ローディング
            if isProcessing {
                ProgressView().scaleEffect(0.8)
                    .frame(width: 51, height: 31)
            } else {
                Toggle("", isOn: Binding(
                    get: { isActivated },
                    set: { newVal in Task { await onToggle(newVal) } }
                ))
                .tint(Color.accentIndigo)
                .labelsHidden()
                .disabled(!canActivate && !isActivated)
            }
        }
        .padding(.vertical, .spacing4)
        .opacity(!canActivate && !isActivated ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServerActivationView()
            .environment(\.services, ServiceContainer.live())
    }
}
