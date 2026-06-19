import SwiftUI
import StoreKit

private enum BillingPeriod: String, CaseIterable {
    case monthly = "月額"
    case annual  = "年額"
}

struct SubscriptionView: View {
    @Environment(\.services)    private var services
    @Environment(AppState.self) private var appState

    @State private var storeProducts: [StoreKit.Product] = []
    @State private var ownerGuilds: [Guild]  = []
    @State private var botGuildIds: Set<String> = []
    @State private var isLoading    = true
    @State private var isPurchasing = false
    @State private var isActivating: String? = nil
    @State private var errorMessage: String? = nil
    @State private var toast: ToastMessage?  = nil
    @State private var billingPeriod: BillingPeriod = .monthly
    @State private var splashMessage: String? = nil

    private var status: SubscriptionStatus { appState.subscriptionStatus }

    private var currentCatalog: [SubscriptionProduct] {
        billingPeriod == .monthly ? SubscriptionProduct.monthly : SubscriptionProduct.annual
    }

    private var currentStoreProducts: [StoreKit.Product] {
        storeProducts.filter { sp in currentCatalog.contains(where: { $0.id == sp.id }) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    header
                    if status.isActive {
                        slotsBar
                        serverSection
                    } else {
                        plansSection
                        featureComparison
                    }
                    footerLinks
                }
            }
            .padding(.vertical)
        }
        .background(Theme.Color.bg)
        .navigationTitle("Noxy Pro")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .toast($toast)
        .overlay {
            if let splashMessage {
                splashView(message: splashMessage)
            }
        }
    }

    private func splashView(message: String) -> some View {
        ZStack {
            Theme.Color.bg.opacity(0.92)
                .ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(Theme.Color.accent)
                Text(message)
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Color.surface)
                    .frame(width: 80, height: 80)
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.Color.accent)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Noxy Pro")
                    .font(Theme.Font.title3)
                    .foregroundStyle(Theme.Color.textPrimary)

                if status.isActive {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.statusOK)
                        Text("有効中")
                            .font(Theme.Font.bodySmall)
                            .foregroundStyle(Theme.Color.statusOK)
                        if let exp = status.expiresAt {
                            Text("· \(exp.formatted(date: .abbreviated, time: .omitted))まで")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                } else {
                    Text("全Pro機能つき · いつでも解約可能")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.statusBad)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Active: slots bar

    private var slotsBar: some View {
        Card {
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("サーバースロット")
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    if status.isUnlimited {
                        Label("無制限", systemImage: "infinity")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.accent)
                    } else {
                        Text("\(status.usedSlots) / \(status.purchasedSlots) 使用中")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .monospaced()
                    }
                }
                if !status.isUnlimited {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Color.surfaceRaised)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    status.availableSlots > 0 ? Theme.Color.accent : Theme.Color.statusWarn
                                )
                                .frame(
                                    width: geo.size.width * CGFloat(status.usedSlots) / CGFloat(max(status.purchasedSlots, 1)),
                                    height: 8
                                )
                                .animation(.easeInOut, value: status.usedSlots)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Active: server list

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                SectionLabel(title: "サーバーを有効化")
                Spacer()
                NavigationLink(destination: ServerActivationView()) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("すべて管理")
                            .font(Theme.Font.caption)
                        Image(systemName: "chevron.right")
                            .font(Theme.Font.caption)
                    }
                    .foregroundStyle(Theme.Color.accent)
                }
            }
            .padding(.horizontal)

            if ownerGuilds.isEmpty {
                Text("条件に合うサーバーがありません")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.horizontal)
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(ownerGuilds) { guild in
                            ServerActivationRow(
                                guild: guild,
                                isActivated: status.activatedGuildIds.contains(guild.id),
                                isLoading: isActivating == guild.id,
                                canActivate: status.availableSlots > 0 || status.activatedGuildIds.contains(guild.id)
                            ) { activate in await toggleActivation(guild: guild, activate: activate) }
                            if guild.id != ownerGuilds.last?.id { Divider().padding(.leading, 60) }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    PlatformHelper.openURL(url)
                }
            } label: {
                Text("App Storeでサブスクを管理")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Picker("", selection: $billingPeriod) {
                ForEach(BillingPeriod.allCases, id: \.self) { period in
                    Text(period == .annual ? "年額（最大38%オフ）" : period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            ForEach(currentStoreProducts.isEmpty ? [] : currentStoreProducts.compactMap({ sp in
                currentCatalog.first(where: { $0.id == sp.id })
            }), id: \.id) { plan in
                if let sp = currentStoreProducts.first(where: { $0.id == plan.id }) {
                    PlanCard(
                        plan: plan,
                        displayPrice: sp.displayPrice + plan.periodSuffix,
                        isPurchasing: isPurchasing
                    ) { await purchase(productId: plan.id) }
                }
            }

            // StoreKit未取得時のフォールバック
            if currentStoreProducts.isEmpty {
                ForEach(currentCatalog) { plan in
                    PlanCard(plan: plan, displayPrice: plan.priceLabel, isPurchasing: isPurchasing) {
                        await purchase(productId: plan.id)
                    }
                }
            }

            Button { Task { await restore() } } label: {
                Text("購入を復元")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Feature comparison

    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("プラン比較")
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Color.textPrimary)
                .padding(.horizontal)

            Card {
                VStack(spacing: 0) {
                    HStack {
                        Text("機能")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                        Spacer()
                        Text("Free")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .frame(width: 48)
                        Text("Pro")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .frame(width: 48)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    Divider()

                    ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                        HStack {
                            Text(row.feature)
                                .font(Theme.Font.bodySmall)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Spacer()
                            Image(systemName: row.free ? "checkmark" : "minus")
                                .font(Theme.Font.caption)
                                .foregroundStyle(row.free ? Theme.Color.statusOK : Theme.Color.textTertiary)
                                .frame(width: 48)
                            Image(systemName: "checkmark")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.statusOK)
                                .frame(width: 48)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        if i < rows.count - 1 { Divider() }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private let rows: [(feature: String, free: Bool)] = [
        ("メンバー管理",         true),
        ("基本モデレーション",   true),
        ("入退室メッセージ",     true),
        ("Embedメッセージ",      true),
        ("リアクションロール",   false),
        ("チケット",             false),
        ("認証パネル",           false),
        ("一時チャンネル",       false),
        ("ステータスチャンネル", false),
        ("ギブアウェイ",         false),
        ("レベリング",           false),
        ("ショップ",             false),
    ]

    // MARK: - Footer

    private var footerLinks: some View {
        Text("利用規約 · プライバシー · サブスク管理")
            .font(Theme.Font.caption2)
            .foregroundStyle(Theme.Color.textTertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    // サブスクリプション管理はアカウント全体に影響するため、選択サーバーの Pro 状態に
    // 関わらず常にライブサービスを直接使用する（isDemoMode の影響を受けない）
    private let liveSubscription = WorkerSubscriptionService()
    private let liveGuilds       = DiscordService()

    private func load() async {
        isLoading = true
        errorMessage = nil
        let userId  = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        async let statusTask   = liveSubscription.fetchStatus(discordUserId: userId)
        async let guildsTask   = liveGuilds.fetchAll()
        async let botIdsTask   = liveGuilds.fetchBotGuildIds()
        async let productsTask = StoreKit.Product.products(for: SubscriptionProduct.catalog.map(\.id))

        let newStatus   = (try? await statusTask)   ?? .inactive
        let allGuilds   = (try? await guildsTask)   ?? []
        botGuildIds     = (try? await botIdsTask)   ?? []
        storeProducts   = ((try? await productsTask) ?? []).sorted { a, b in
            let ai = SubscriptionProduct.catalog.firstIndex(where: { $0.id == a.id }) ?? 99
            let bi = SubscriptionProduct.catalog.firstIndex(where: { $0.id == b.id }) ?? 99
            return ai < bi
        }
        ownerGuilds = allGuilds.filter { botGuildIds.contains($0.id) && ($0.userRole == .owner || $0.userRole == .admin) }
        appState.subscriptionStatus = newStatus
        isLoading = false
    }

    private func purchase(productId: String) async {
        isPurchasing = true; errorMessage = nil
        do {
            let s = try await liveSubscription.purchase(productId: productId)
            appState.subscriptionStatus = s
            toast = ToastMessage(type: .success, message: "購入完了")
        } catch SubscriptionError.cancelled { }
        catch SubscriptionError.pending { errorMessage = "購入の承認待ちです" }
        catch { errorMessage = "購入に失敗しました: \(error.localizedDescription)" }
        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true; errorMessage = nil
        do {
            let s = try await liveSubscription.restore()
            appState.subscriptionStatus = s
            toast = ToastMessage(type: .success, message: "購入を復元しました")
        } catch { errorMessage = "復元に失敗しました" }
        isPurchasing = false
    }

    private func toggleActivation(guild: Guild, activate: Bool) async {
        isActivating = guild.id
        errorMessage = nil
        splashMessage = activate ? "「\(guild.name)」を有効化しています..." : "「\(guild.name)」の有効化を解除しています..."
        do {
            if activate {
                try await liveSubscription.activateServer(guildId: guild.id)
            } else {
                try await liveSubscription.deactivateServer(guildId: guild.id)
            }
            await load()
            toast = ToastMessage(type: .success, message: activate ? "\(guild.name) を有効化しました" : "\(guild.name) の有効化を解除しました")
        } catch {
            errorMessage = error.localizedDescription
        }
        isActivating = nil
        splashMessage = nil
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: SubscriptionProduct
    let displayPrice: String
    let isPurchasing: Bool
    let onPurchase: () async -> Void

    var body: some View {
        Button { Task { await onPurchase() } } label: {
            HStack(spacing: Theme.Spacing.md) {
                // Slot count badge
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip)
                        .fill(plan.isRecommended ? Theme.Color.accent : Theme.Color.surfaceRaised)
                        .frame(width: 48, height: 48)
                    if plan.slots >= 99 {
                        Image(systemName: "infinity")
                            .font(Theme.Font.title3)
                            .foregroundStyle(plan.isRecommended ? Theme.Color.accentInk : Theme.Color.accent)
                    } else {
                        Text("\(plan.slots)")
                            .font(Theme.Font.title2)
                            .foregroundStyle(plan.isRecommended ? Theme.Color.accentInk : Theme.Color.accent)
                            .monospaced()
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(plan.planName)
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Color.textPrimary)
                        if plan.isRecommended {
                            Text("人気 No.1")
                                .font(Theme.Font.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.Color.accentInk)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Color.accent)
                                .clipShape(Capsule())
                        }
                        if let savings = plan.savingsLabel {
                            Text(savings)
                                .font(Theme.Font.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.Color.statusOK)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Color.statusOK.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(plan.slotsLabel)サーバー · 全Pro機能")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    if let equiv = plan.monthlyEquivalentLabel {
                        Text(equiv)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }

                Spacer()

                if isPurchasing {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text(displayPrice)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.accent)
                        .monospaced()
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        plan.isRecommended ? Theme.Color.accent : Theme.Color.line,
                        lineWidth: plan.isRecommended ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}

// MARK: - Server Activation Row

private struct ServerActivationRow: View {
    let guild: Guild
    let isActivated: Bool
    let isLoading: Bool
    let canActivate: Bool
    let onToggle: (Bool) async -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ServerIconView(name: guild.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(guild.name).font(Theme.Font.body).foregroundStyle(Theme.Color.textPrimary)
                HStack(spacing: 4) {
                    StatusDot(color: isActivated ? Theme.Color.statusOK : Theme.Color.textTertiary)
                    Text(isActivated ? "有効" : canActivate ? "タップして有効化" : "スロット不足")
                        .font(Theme.Font.caption)
                        .foregroundStyle(isActivated ? Theme.Color.statusOK : canActivate ? Theme.Color.textSecondary : Theme.Color.textTertiary)
                }
            }
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.8)
            } else {
                Toggle("", isOn: Binding(
                    get: { isActivated },
                    set: { v in Task { await onToggle(v) } }
                ))
                .tint(Theme.Color.accent)
                .labelsHidden()
                .disabled(!canActivate && !isActivated)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SubscriptionView()
            .environment(AppState())
            .environment(\.services, ServiceContainer.live())
    }
}

#Preview("Dark") {
    NavigationStack {
        SubscriptionView()
            .environment(AppState())
            .environment(\.services, ServiceContainer.live())
    }
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack {
        SubscriptionView()
            .environment(AppState())
            .environment(\.services, ServiceContainer.live())
    }
    .preferredColorScheme(.light)
}
