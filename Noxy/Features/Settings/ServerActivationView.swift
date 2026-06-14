import SwiftUI

// MARK: - ServerActivationView
// 有料ユーザー向けのサーバー有効化管理画面。
// 所有するサーバー一覧を表示し、スロットを使って有効化/無効化できる。

struct ServerActivationView: View {
    @Environment(\.services) private var services

    @State private var subStatus:    SubscriptionStatus = .inactive
    @State private var ownerGuilds:  [Guild]            = []
    @State private var botGuildIds:  Set<String>        = []
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
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                slotSection
                if let error = errorMessage {
                    FormSection("エラー", icon: "exclamationmark.triangle") {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                }
                serverListSection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Color.bg)
    }

    // MARK: - スロットセクション

    private var slotSection: some View {
        FormSection("スロット使用状況", icon: "server.rack") {
            VStack(spacing: Theme.Spacing.sm) {
                // スロットカウンター
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("使用中スロット")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(subStatus.usedSlots)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Theme.Color.textPrimary)
                                .monospaced()
                            Text("/ \(subStatus.purchasedSlots)")
                                .font(Theme.Font.title3)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .monospaced()
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("残り")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                        Text("\(subStatus.availableSlots)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(
                                subStatus.availableSlots > 0 ? Theme.Color.statusOK : Theme.Color.statusWarn
                            )
                            .monospaced()
                    }
                }

                // プログレスバー
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Color.surfaceRaised)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                subStatus.availableSlots > 0
                                    ? Theme.Color.accent
                                    : Theme.Color.statusWarn
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
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.statusWarn)
                        Text("スロットが満杯です。不要なサーバーを無効化するかプランをアップグレードしてください")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    // MARK: - サーバー一覧セクション

    private var serverListSection: some View {
        FormSection("管理サーバー", icon: "list.bullet", footer: "\(ownerGuilds.count) 件") {
            if ownerGuilds.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.Color.textTertiary)
                        Text("条件に合うサーバーがありません")
                            .font(Theme.Font.bodySmall)
                            .foregroundStyle(Theme.Color.textSecondary)
                        Text("ボットが導入されていて、あなたが管理者権限を持つサーバーが表示されます")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(ownerGuilds) { guild in
                        ActivationRow(
                            guild: guild,
                            isActivated: subStatus.activatedGuildIds.contains(guild.id),
                            canActivate: subStatus.availableSlots > 0,
                            isProcessing: processingId == guild.id
                        ) { activate in
                            await toggle(guild: guild, activate: activate)
                        }
                        if guild.id != ownerGuilds.last?.id {
                            Divider().background(Theme.Color.line)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        async let statusTask = services.subscription.fetchStatus(discordUserId: userId)
        async let guildsTask = services.guilds.fetchAll()
        async let botIdsTask = services.guilds.fetchBotGuildIds()
        subStatus   = (try? await statusTask) ?? .inactive
        let all     = (try? await guildsTask)  ?? []
        botGuildIds = (try? await botIdsTask)  ?? []
        // ボット導入済み + オーナーまたは管理者権限を持つサーバーのみ
        ownerGuilds = all.filter {
            botGuildIds.contains($0.id) && ($0.userRole == .owner || $0.userRole == .admin)
        }
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
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.statusOK)
            Text(message)
                .font(Theme.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(height: 44)
        .background(Theme.Color.surfaceRaised)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.Color.line, lineWidth: 1)
        )
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
        HStack(spacing: Theme.Spacing.sm) {
            // サーバーアイコン（イニシャル）
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.chip)
                    .fill(Theme.Color.surfaceRaised)
                    .frame(width: 40, height: 40)
                Text(String(guild.name.prefix(1)).uppercased())
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            // サーバー情報
            VStack(alignment: .leading, spacing: 2) {
                Text(guild.name)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    StatusDot(color: isActivated ? Theme.Color.statusOK : Theme.Color.textTertiary)
                    Text(isActivated ? "有効化済み • スロット使用中"
                         : canActivate ? "無効"
                         : "無効（スロット不足）")
                        .font(Theme.Font.caption)
                        .foregroundStyle(isActivated ? Theme.Color.statusOK : Theme.Color.textTertiary)
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
                .tint(Theme.Color.accent)
                .labelsHidden()
                .disabled(!canActivate && !isActivated)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .opacity(!canActivate && !isActivated ? 0.5 : 1.0)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServerActivationView()
            .environment(\.services, ServiceContainer.live())
    }
}

#Preview("Dark") {
    NavigationStack {
        ServerActivationView()
            .environment(\.services, ServiceContainer.live())
    }
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack {
        ServerActivationView()
            .environment(\.services, ServiceContainer.live())
    }
    .preferredColorScheme(.light)
}
