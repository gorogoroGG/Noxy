import SwiftUI
import StoreKit

// MARK: - SubscriptionView

struct SubscriptionView: View {
    @Environment(\.services) private var services
    @Environment(AuthManager.self)  private var authManager

    @State private var status: SubscriptionStatus = .inactive
    @State private var storeProducts: [StoreKit.Product] = []
    @State private var ownerGuilds: [Guild] = []
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var isActivating: String? = nil   // guildId
    @State private var errorMessage: String? = nil
    @State private var toast: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing24) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    headerSection
                    if status.isActive {
                        slotsSection
                        serverListSection
                    } else {
                        plansSection
                    }
                    footerLinks
                }
            }
            .padding(.vertical)
        }
        .background(Color.bgPrimary)
        .navigationTitle("Noxy Pro")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let toast {
                toastBanner(toast)
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: .spacing12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentOrange, Color.accentPink],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            VStack(spacing: .spacing6) {
                Text("Noxy Pro")
                    .font(.displayMedium)
                    .foregroundStyle(Color.textPrimary)

                if status.isActive {
                    HStack(spacing: .spacing6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.accentGreen)
                        Text("有効中")
                            .font(.bodySmall)
                            .foregroundStyle(Color.accentGreen)
                        if let expires = status.expiresAt {
                            Text("・\(expires.formatted(date: .abbreviated, time: .omitted))まで")
                                .font(.captionRegular)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                } else {
                    Text("有効なサブスクリプションなし")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.captionRegular)
                    .foregroundStyle(Color.accentRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Active: Slots

    private var slotsSection: some View {
        VStack(spacing: .spacing8) {
            HStack {
                Text("サーバースロット")
                    .font(.titleMedium).foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(status.usedSlots) / \(status.purchasedSlots) 使用中")
                    .font(.captionRegular).foregroundStyle(Color.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.bgSurface)
                        .frame(height: 8)
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
        .padding(.horizontal)
    }

    // MARK: - Active: Server List

    private var serverListSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            SectionHeader(title: "サーバーを有効化")
                .padding(.horizontal)

            if ownerGuilds.isEmpty {
                Text("オーナー権限を持つサーバーがありません")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(ownerGuilds) { guild in
                        ServerActivationRow(
                            guild: guild,
                            isActivated: status.activatedGuildIds.contains(guild.id),
                            isLoading: isActivating == guild.id,
                            canActivate: status.availableSlots > 0 || status.activatedGuildIds.contains(guild.id)
                        ) { activate in
                            await toggleActivation(guild: guild, activate: activate)
                        }
                        if guild.id != ownerGuilds.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Not Subscribed: Plans

    private var plansSection: some View {
        VStack(spacing: .spacing16) {
            Text("サーバー1台から始められます")
                .font(.bodySmall)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: .spacing10) {
                ForEach(storeProducts, id: \.id) { product in
                    PlanRow(product: product, isPurchasing: isPurchasing) {
                        await purchase(productId: product.id)
                    }
                }

                if storeProducts.isEmpty {
                    // フォールバック: StoreKit 製品未取得時はカタログから表示
                    ForEach(SubscriptionProduct.catalog) { catalog in
                        PlanRow(
                            productId: catalog.id,
                            slots: catalog.slots,
                            priceLabel: catalog.priceLabel,
                            isPurchasing: isPurchasing
                        ) {
                            await purchase(productId: catalog.id)
                        }
                    }
                }
            }
            .padding(.horizontal)

            Button {
                Task { await restorePurchases() }
            } label: {
                Text("購入を復元")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        Text("利用規約 · プライバシー · サブスク管理")
            .font(.captionSmall)
            .foregroundStyle(Color.textTertiary)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let discordUserId = KeychainHelper.load(forKey: "discord_user_id") ?? ""

            // 並列取得
            async let statusTask  = services.subscription.fetchStatus(discordUserId: discordUserId)
            async let guildsTask  = services.guilds.fetchAll()
            async let productsTask = StoreKit.Product.products(for: SubscriptionProduct.catalog.map(\.id))

            status      = (try? await statusTask)  ?? .inactive
            let allGuilds = (try? await guildsTask)  ?? []
            ownerGuilds = allGuilds.filter { $0.userRole == .owner }

            let fetched: [StoreKit.Product] = (try? await productsTask) ?? []
            storeProducts = fetched.sorted { a, b in
                // slots 順でソート
                let aSlots = SubscriptionProduct.catalog.first(where: { $0.id == a.id })?.slots ?? 0
                let bSlots = SubscriptionProduct.catalog.first(where: { $0.id == b.id })?.slots ?? 0
                return aSlots < bSlots
            }
        }
        isLoading = false
    }

    private func purchase(productId: String) async {
        isPurchasing = true
        errorMessage = nil
        do {
            status = try await services.subscription.purchase(productId: productId)
            withAnimation { toast = "購入が完了しました 🎉" }
        } catch SubscriptionError.cancelled {
            // キャンセルは何もしない
        } catch SubscriptionError.pending {
            errorMessage = "購入の承認が保留中です"
        } catch {
            errorMessage = "購入に失敗しました: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    private func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        do {
            status = try await services.subscription.restore()
            withAnimation { toast = "購入が復元されました" }
        } catch {
            errorMessage = "復元に失敗しました"
        }
        isPurchasing = false
    }

    private func toggleActivation(guild: Guild, activate: Bool) async {
        isActivating = guild.id
        errorMessage = nil
        do {
            if activate {
                try await services.subscription.activateServer(guildId: guild.id)
                withAnimation { toast = "\(guild.name) を有効化しました" }
            } else {
                try await services.subscription.deactivateServer(guildId: guild.id)
                withAnimation { toast = "\(guild.name) の有効化を解除しました" }
            }
            // ステータスを再取得
            let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
            status = try await services.subscription.fetchStatus(discordUserId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isActivating = nil
    }

    // MARK: - Toast

    private func toastBanner(_ message: String) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text(message).font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
        }
        .padding(.horizontal, .spacing20).frame(height: 44)
        .background(Color.accentGreen)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - ServerActivationRow

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
                Text(guild.name)
                    .font(.body).foregroundStyle(Color.textPrimary)
                Text(isActivated ? "有効化済み" : canActivate ? "タップして有効化" : "スロットが満杯です")
                    .font(.captionRegular)
                    .foregroundStyle(isActivated ? Color.accentGreen :
                                     canActivate ? Color.textSecondary : Color.textTertiary)
            }

            Spacer()

            if isLoading {
                ProgressView().scaleEffect(0.8)
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
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
    }
}

// MARK: - PlanRow (StoreKit Product)

private struct PlanRow: View {
    let productId: String
    let slots: Int
    let priceLabel: String
    let isPurchasing: Bool
    let onPurchase: () async -> Void

    init(product: StoreKit.Product, isPurchasing: Bool, onPurchase: @escaping () async -> Void) {
        self.productId   = product.id
        self.slots       = SubscriptionProduct.catalog.first(where: { $0.id == product.id })?.slots ?? 0
        self.priceLabel  = product.displayPrice + "/月"
        self.isPurchasing = isPurchasing
        self.onPurchase  = onPurchase
    }

    init(productId: String, slots: Int, priceLabel: String, isPurchasing: Bool, onPurchase: @escaping () async -> Void) {
        self.productId   = productId
        self.slots       = slots
        self.priceLabel  = priceLabel
        self.isPurchasing = isPurchasing
        self.onPurchase  = onPurchase
    }

    var body: some View {
        Button {
            Task { await onPurchase() }
        } label: {
            HStack(spacing: .spacing16) {
                ZStack {
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                        .fill(Color.accentIndigo.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text("\(slots)")
                        .font(.titleLarge)
                        .foregroundStyle(Color.accentIndigo)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("サーバー \(slots)台")
                        .font(.titleMedium).foregroundStyle(Color.textPrimary)
                    Text("ステータスチャンネルを\(slots)つのサーバーで利用可能")
                        .font(.captionRegular).foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if isPurchasing {
                    ProgressView().scaleEffect(0.8)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(priceLabel)
                            .font(.titleMedium)
                            .foregroundStyle(Color.accentIndigo)
                    }
                }
            }
            .padding(.spacing16)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .strokeBorder(Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(ScalePressButtonStyle())
        .disabled(isPurchasing)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SubscriptionView()
            .environment(\.services, ServiceContainer.live())
            .environment(AuthManager(services: ServiceContainer.live()))
    }
}
