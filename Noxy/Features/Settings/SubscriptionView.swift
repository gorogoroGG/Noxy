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

    private var status: SubscriptionStatus { appState.subscriptionStatus }

    private var currentCatalog: [SubscriptionProduct] {
        billingPeriod == .monthly ? SubscriptionProduct.monthly : SubscriptionProduct.annual
    }

    private var currentStoreProducts: [StoreKit.Product] {
        storeProducts.filter { sp in currentCatalog.contains(where: { $0.id == sp.id }) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing24) {
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
        .background(Color.bgPrimary)
        .navigationTitle("Noxy Pro")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .toast($toast)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: .spacing16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentOrange.opacity(0.18), Color.accentPink.opacity(0.18)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.accentOrange, Color.accentPink],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: .spacing6) {
                Text("Noxy Pro")
                    .font(.displayMedium)
                    .foregroundStyle(Color.textPrimary)

                if status.isActive {
                    HStack(spacing: .spacing6) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.accentGreen)
                        Text("有効中").font(.bodySmall).foregroundStyle(Color.accentGreen)
                        if let exp = status.expiresAt {
                            Text("· \(exp.formatted(date: .abbreviated, time: .omitted))まで")
                                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                        }
                    }
                } else {
                    Text("全Pro機能つき · いつでも解約可能")
                        .font(.bodySmall).foregroundStyle(Color.textSecondary)
                }
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.captionRegular).foregroundStyle(Color.accentPink)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Active: slots bar

    private var slotsBar: some View {
        VStack(spacing: .spacing8) {
            HStack {
                Text("サーバースロット")
                    .font(.titleMedium).foregroundStyle(Color.textPrimary)
                Spacer()
                if status.isUnlimited {
                    Label("無制限", systemImage: "infinity")
                        .font(.captionRegular).foregroundStyle(Color.accentIndigo)
                } else {
                    Text("\(status.usedSlots) / \(status.purchasedSlots) 使用中")
                        .font(.captionRegular).foregroundStyle(Color.textSecondary)
                }
            }
            if !status.isUnlimited {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.bgSurface).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(status.availableSlots > 0 ? Color.accentIndigo : Color.accentOrange)
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
        .padding(.horizontal)
    }

    // MARK: - Active: server list

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack {
                SectionHeader(title: "サーバーを有効化")
                Spacer()
                NavigationLink(destination: ServerActivationView()) {
                    HStack(spacing: .spacing4) {
                        Text("すべて管理").font(.captionRegular)
                        Image(systemName: "chevron.right").font(.captionRegular)
                    }
                    .foregroundStyle(Color.accentIndigo)
                }
            }
            .padding(.horizontal)

            if ownerGuilds.isEmpty {
                Text("条件に合うサーバーがありません")
                    .font(.bodySmall).foregroundStyle(Color.textSecondary)
                    .padding(.horizontal)
            } else {
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
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal)
            }

            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    PlatformHelper.openURL(url)
                }
            } label: {
                Text("App Storeでサブスクを管理")
                    .font(.bodySmall).foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: .spacing12) {
            Picker("", selection: $billingPeriod) {
                ForEach(BillingPeriod.allCases, id: \.self) { period in
                    Text(period == .annual ? "年額（最大38%オフ）" : period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

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
                    .font(.captionRegular).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Feature comparison

    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Text("プラン比較")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                HStack {
                    Text("機能").font(.captionRegular).foregroundStyle(Color.textTertiary)
                    Spacer()
                    Text("Free").font(.captionRegular).foregroundStyle(Color.textTertiary).frame(width: 48)
                    Text("Pro").font(.captionRegular).foregroundStyle(Color.accentOrange).frame(width: 48)
                }
                .padding(.horizontal, .spacing16).padding(.vertical, .spacing8)
                Divider()

                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(row.feature).font(.bodySmall).foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: row.free ? "checkmark" : "minus")
                            .font(.captionRegular)
                            .foregroundStyle(row.free ? Color.accentGreen : Color.textTertiary)
                            .frame(width: 48)
                        Image(systemName: "checkmark")
                            .font(.captionRegular).foregroundStyle(Color.accentGreen)
                            .frame(width: 48)
                    }
                    .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
                    if i < rows.count - 1 { Divider() }
                }
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
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
            .font(.captionSmall).foregroundStyle(Color.textTertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        let userId  = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        async let statusTask   = services.subscription.fetchStatus(discordUserId: userId)
        async let guildsTask   = services.guilds.fetchAll()
        async let botIdsTask   = services.guilds.fetchBotGuildIds()
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
            let s = try await services.subscription.purchase(productId: productId)
            appState.subscriptionStatus = s
            toast = ToastMessage(type: .success, message: "購入完了 🎉")
        } catch SubscriptionError.cancelled { }
        catch SubscriptionError.pending { errorMessage = "購入の承認待ちです" }
        catch { errorMessage = "購入に失敗しました: \(error.localizedDescription)" }
        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true; errorMessage = nil
        do {
            let s = try await services.subscription.restore()
            appState.subscriptionStatus = s
            toast = ToastMessage(type: .success, message: "購入を復元しました")
        } catch { errorMessage = "復元に失敗しました" }
        isPurchasing = false
    }

    private func toggleActivation(guild: Guild, activate: Bool) async {
        isActivating = guild.id; errorMessage = nil
        do {
            if activate {
                try await services.subscription.activateServer(guildId: guild.id)
                toast = ToastMessage(type: .success, message: "\(guild.name) を有効化しました")
            } else {
                try await services.subscription.deactivateServer(guildId: guild.id)
                toast = ToastMessage(type: .info, message: "\(guild.name) の有効化を解除しました")
            }
            let s = try await services.subscription.fetchStatus(discordUserId: KeychainHelper.load(forKey: "discord_user_id") ?? "")
            appState.subscriptionStatus = s
        } catch { errorMessage = error.localizedDescription }
        isActivating = nil
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
            HStack(spacing: .spacing16) {
                // Slot count badge
                ZStack {
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                        .fill(plan.isRecommended ? Color.accentIndigo : Color.accentIndigo.opacity(0.1))
                        .frame(width: 48, height: 48)
                    if plan.slots >= 99 {
                        Image(systemName: "infinity")
                            .font(.titleMedium)
                            .foregroundStyle(plan.isRecommended ? Color.white : Color.accentIndigo)
                    } else {
                        Text("\(plan.slots)")
                            .font(.titleLarge)
                            .foregroundStyle(plan.isRecommended ? Color.white : Color.accentIndigo)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: .spacing6) {
                        Text(plan.planName)
                            .font(.titleMedium).foregroundStyle(Color.textPrimary)
                        if plan.isRecommended {
                            Text("人気 No.1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(LinearGradient(
                                    colors: [Color.accentOrange, Color.accentPink],
                                    startPoint: .leading, endPoint: .trailing))
                                .clipShape(Capsule())
                        }
                        if let savings = plan.savingsLabel {
                            Text(savings)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.accentGreen)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentGreen.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(plan.slotsLabel)サーバー · 全Pro機能")
                        .font(.captionRegular).foregroundStyle(Color.textSecondary)
                    if let equiv = plan.monthlyEquivalentLabel {
                        Text(equiv)
                            .font(.captionRegular).foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                if isPurchasing {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text(displayPrice)
                        .font(.titleMedium).foregroundStyle(Color.accentIndigo)
                }
            }
            .padding(.spacing16)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .strokeBorder(
                        plan.isRecommended ? Color.accentIndigo.opacity(0.5) : Color.border,
                        lineWidth: plan.isRecommended ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(ScalePressButtonStyle())
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
        HStack(spacing: .spacing12) {
            ServerIconView(name: guild.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(guild.name).font(.body).foregroundStyle(Color.textPrimary)
                Text(isActivated ? "有効" : canActivate ? "タップして有効化" : "スロット不足")
                    .font(.captionRegular)
                    .foregroundStyle(isActivated ? Color.accentGreen : canActivate ? Color.textSecondary : Color.textTertiary)
            }
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.8)
            } else {
                Toggle("", isOn: Binding(
                    get: { isActivated },
                    set: { v in Task { await onToggle(v) } }
                ))
                .tint(Color.accentIndigo).labelsHidden()
                .disabled(!canActivate && !isActivated)
            }
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
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
