import SwiftUI

// MARK: - ShopsListView

struct ShopsListView: View {
    let guildId: String
    let shopType: ShopType

    enum Tab { case panels, orders }
    @State private var selectedTab: Tab = .panels

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(title: shopType.label, icon: shopType.icon,           tab: .panels)
                tabButton(title: "注文",          icon: "list.bullet.clipboard",  tab: .orders)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(Divider(), alignment: .bottom)

            switch selectedTab {
            case .panels: ShopPanelListView(guildId: guildId, shopType: shopType)
            case .orders: OrdersListView(guildId: guildId)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(shopType.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tabButton(title: String, icon: String, tab: Tab) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab } } label: {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                    Text(title).font(.captionRegular).fontWeight(.semibold)
                }
                .foregroundStyle(selectedTab == tab ? shopType.accentColor : Color.textTertiary)
                Capsule()
                    .fill(selectedTab == tab ? shopType.accentColor : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spacing8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ShopPanelListView

private struct ShopPanelListView: View {
    let guildId: String
    let shopType: ShopType

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var shops: [Shop] = []
    @State private var productCounts: [String: Int] = [:]
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var settingsShop: Shop? = nil
    @State private var productsShop: Shop? = nil
    @State private var statusShop: Shop? = nil
    @State private var deployTargetShop: Shop? = nil
    @State private var pendingRedeployShop: Shop? = nil
    @State private var showRedeployConfirm = false
    @State private var deployingId: String? = nil
    @State private var toast: String? = nil

    private var accentColor: Color { shopType.accentColor }

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                if isLoading {
                    ForEach(0..<3) { _ in skeletonCard }
                        .transition(.opacity)
                } else if shops.isEmpty {
                    emptyState
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                        .transition(.opacity)
                } else {
                    ForEach(shops) { shop in
                        ShopCard(
                            shop: shop,
                            productCount: productCounts[shop.id] ?? 0,
                            isDeploying: deployingId == shop.id,
                            onStatusTap: { statusShop = shop },
                            onSettings:  { settingsShop = shop },
                            onProducts:  { productsShop = shop },
                            onDeploy: {
                                if shop.isDeployed {
                                    pendingRedeployShop = shop
                                    showRedeployConfirm = true
                                } else {
                                    deployTargetShop = shop
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { shops[$0] }
                        Task {
                            for s in toDelete { try? await services.shops.deleteShop(id: s.id) }
                            shops.remove(atOffsets: offsets)
                        }
                    }
                }
                Color.clear.frame(height: 80)
                    .listRowBackground(Color(.systemGroupedBackground)).listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .refreshable { await load() }

            Button { showCreate = true } label: {
                HStack(spacing: .spacing8) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text(shopType == .vendingMachine ? "自販機を作成" : "ショップを作成")
                        .font(.bodySmall).fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, .spacing20).padding(.vertical, .spacing12)
                .background(accentColor).clipShape(Capsule())
                .shadow(color: accentColor.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.bottom, 24)

            if let toast {
                Text(toast)
                    .font(.captionRegular).fontWeight(.medium).foregroundStyle(.white)
                    .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
                    .background(Color.gray.opacity(0.25)).clipShape(Capsule())
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showCreate) {
            if shopType == .vendingMachine {
                VendingMachineEditView(existingShop: nil, guildId: guildId) { saved in
                    shops.insert(saved, at: 0)
                    productCounts[saved.id] = 0
                    updateCache(with: saved)
                }
            } else {
                ShopEditView(existingShop: nil, guildId: guildId, shopType: shopType) { saved in
                    shops.insert(saved, at: 0)
                    productCounts[saved.id] = 0
                    updateCache(with: saved)
                }
            }
        }
        .sheet(item: $settingsShop) { shop in
            if shopType == .vendingMachine {
                VendingMachineEditView(existingShop: shop, guildId: guildId) { updated in
                    if let idx = shops.firstIndex(where: { $0.id == updated.id }) { shops[idx] = updated }
                    updateCache(with: updated)
                }
            } else {
                ShopEditView(existingShop: shop, guildId: guildId, shopType: shopType) { updated in
                    if let idx = shops.firstIndex(where: { $0.id == updated.id }) { shops[idx] = updated }
                    updateCache(with: updated)
                }
            }
        }
        .fullScreenCover(item: $productsShop) { shop in
            ProductsManageView(shop: shop, guildId: guildId) { count in
                productCounts[shop.id] = count
            }
        }
        .sheet(item: $statusShop) { shop in
            ShopQuickStatusSheet(shop: shop, guildId: guildId, productCount: productCounts[shop.id] ?? 0)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $deployTargetShop) { shop in
            ShopDeployChannelPickerSheet(shop: shop, guildId: guildId) { channelId in
                Task { await deploy(shop, channelId: channelId) }
            }
        }
        .confirmationDialog(
            "\(shopType.label)を再送信しますか？",
            isPresented: $showRedeployConfirm,
            titleVisibility: .visible
        ) {
            Button("再送信する") {
                if let shop = pendingRedeployShop { deployTargetShop = shop }
                pendingRedeployShop = nil
            }
            Button("キャンセル", role: .cancel) { pendingRedeployShop = nil }
        } message: {
            Text("新しいメッセージとしてDiscordに投稿されます。既存のパネルは更新されません。")
        }
        .task { await load() }
        .onChange(of: guildId) { _, _ in
            isLoading = true
            Task { await load() }
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack(spacing: .spacing8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.textTertiary.opacity(0.2)).frame(width: 100, height: 18)
                Spacer()
                RoundedRectangle(cornerRadius: 4).fill(Color.textTertiary.opacity(0.15)).frame(width: 50, height: 14)
            }
            RoundedRectangle(cornerRadius: 4).fill(Color.textTertiary.opacity(0.1)).frame(width: 180, height: 12)
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .listRowBackground(Color(.systemGroupedBackground))
        .listRowSeparator(.hidden)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: shopType == .vendingMachine ? "storefront" : "cart.badge.plus")
                .font(.system(size: 40)).foregroundStyle(Color.textTertiary)
            Text(shopType == .vendingMachine ? "自販機がありません" : "ショップがありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text("ボタンからパネルを追加できます")
                .font(.captionRegular).foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func load() async {
        isLoading = true
        if let cached = appState.cachedShops[guildId] {
            shops = cached.filter { $0.shopType == shopType }
            isLoading = false
        }
        do {
            let fetched = try await services.shops.fetchShops(guildId: guildId)
            appState.cacheShops(fetched, for: guildId)
            shops = fetched.filter { $0.shopType == shopType }
        } catch {
            if appState.cachedShops[guildId] == nil { shops = [] }
        }
        await loadProductCounts()
        isLoading = false
    }

    private func loadProductCounts() async {
        var counts: [String: Int] = [:]
        await withTaskGroup(of: (String, Int).self) { group in
            for shop in shops {
                let shopId = shop.id
                group.addTask {
                    let products = (try? await services.shops.fetchProducts(shopId: shopId)) ?? []
                    return (shopId, products.count)
                }
            }
            for await (shopId, count) in group { counts[shopId] = count }
        }
        productCounts = counts
    }

    private func deploy(_ shop: Shop, channelId: String) async {
        deployingId = shop.id
        do {
            let updated = try await services.shops.deployShop(id: shop.id, channelId: channelId)
            if let idx = shops.firstIndex(where: { $0.id == shop.id }) { shops[idx] = updated }
            showToast("✅ Discordに送信しました")
        } catch ServiceError.workerError(let status, let msg) {
            showToast("❌ 送信失敗(\(status)): \(msg.prefix(80))")
        } catch {
            showToast("❌ 送信に失敗: \(error.localizedDescription)")
        }
        deployingId = nil
    }

    /// 保存後にAppStateキャッシュを即時更新する（再ロード時の古いデータ表示を防ぐ）
    private func updateCache(with shop: Shop) {
        var cached = appState.cachedShops[guildId] ?? []
        if let idx = cached.firstIndex(where: { $0.id == shop.id }) {
            cached[idx] = shop
        } else {
            cached.insert(shop, at: 0)
        }
        appState.cacheShops(cached, for: guildId)
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }
        }
    }
}

// MARK: - ShopCard

private struct ShopCard: View {
    let shop: Shop
    let productCount: Int
    let isDeploying: Bool
    let onStatusTap: () -> Void
    let onSettings: () -> Void
    let onProducts: () -> Void
    let onDeploy: () -> Void

    private var accentColor: Color {
        shop.enabled ? Color(uiColor: UIColor(hex: UInt32(shop.color))) : Color.gray.opacity(0.6)
    }
    private var hasProducts: Bool { productCount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            // ── 無効バナー ──
            if !shop.enabled {
                HStack(spacing: .spacing6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                    Text("この自販機は現在無効です")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.horizontal, .spacing12).padding(.vertical, .spacing8)
                .background(Color.orange.opacity(0.12))
            }

            // ── メイン情報エリア（タップ → ステータスシート）──
            Button(action: onStatusTap) {
                HStack(spacing: .spacing12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: .spacing6) {
                            Text(shop.name)
                                .font(.bodySmall).fontWeight(.semibold)
                                .foregroundStyle(shop.enabled ? Color.textPrimary : Color.textTertiary)
                            if !shop.enabled {
                                Text("無効")
                                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.orange)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15)).clipShape(Capsule())
                            }
                        }
                        if !shop.description.isEmpty {
                            Text(shop.description)
                                .font(.captionSmall).foregroundStyle(Color.textTertiary).lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if shop.isDeployed {
                            Label("設置済み", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.accentGreen)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.accentGreen.opacity(0.1)).clipShape(Capsule())
                        } else {
                            Text("未設置")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(.tertiarySystemGroupedBackground)).clipShape(Capsule())
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "archivebox.fill").font(.system(size: 8))
                            Text(hasProducts ? "\(productCount)商品" : "商品なし")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(hasProducts ? Color.accentPurple : Color.accentOrange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((hasProducts ? Color.accentPurple : Color.accentOrange).opacity(0.1))
                        .clipShape(Capsule())
                    }

                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary.opacity(0.4))
                }
                .padding(.spacing12)
            }
            .buttonStyle(.plain)
            .opacity(shop.enabled ? 1 : 0.8)

            Divider().padding(.horizontal, .spacing12)

            // ── 商品管理ボタン（目立つアクセントカラー）──
            Button(action: onProducts) {
                HStack(spacing: .spacing8) {
                    Image(systemName: "archivebox.fill").font(.system(size: 13))
                    Text("商品を管理").font(.captionRegular).fontWeight(.semibold)
                    Spacer()
                    if hasProducts {
                        Text("\(productCount)件")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(.white.opacity(0.2)).clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
                .background(shop.shopType.accentColor)
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal, .spacing12)

            // ── 設定 / 設置 ──
            HStack(spacing: 0) {
                Button(action: onSettings) {
                    Label("設定", systemImage: "gearshape")
                        .font(.captionRegular).fontWeight(.medium)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                Button(action: onDeploy) {
                    if isDeploying {
                        HStack(spacing: 5) {
                            ProgressView().scaleEffect(0.7)
                            Text("送信中").font(.captionRegular).foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                    } else {
                        Label(shop.isDeployed ? "再設置" : "設置する", systemImage: "paperplane.fill")
                            .font(.captionRegular).fontWeight(.semibold)
                            .foregroundStyle(
                                !hasProducts ? Color.textTertiary :
                                    (shop.isDeployed ? Color.accentOrange : Color.accentGreen)
                            )
                            .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeploying || !hasProducts)
            }
            .background(Color(.tertiarySystemGroupedBackground))
        }
        .background(shop.enabled
            ? Color(.secondarySystemGroupedBackground)
            : Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - ShopQuickStatusSheet

struct ShopQuickStatusSheet: View {
    let shop: Shop
    let guildId: String
    let productCount: Int

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var orders: [Order] = []
    @State private var products: [Product] = []
    @State private var isLoading = true

    private var accentColor: Color { Color(uiColor: UIColor(hex: UInt32(shop.color))) }

    private var todayOrders: [Order] {
        let start = Calendar.current.startOfDay(for: .now)
        return orders.filter { $0.createdAt >= start }
    }
    private var weekOrders: [Order] {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return orders.filter { $0.createdAt >= start }
    }
    private var lowStockProducts: [Product] {
        products.filter { p in
            guard let stock = p.stock else { return false }
            return stock <= 3 && p.enabled
        }.sorted { ($0.stock ?? 0) < ($1.stock ?? 0) }
    }
    private var topProducts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for o in orders { counts[o.productName, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { (name: $0.key, count: $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: .spacing12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(accentColor).frame(width: 52, height: 52)
                            Image(systemName: shop.shopType.icon).font(.system(size: 22)).foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shop.name).font(.titleMedium).fontWeight(.bold)
                            HStack(spacing: .spacing8) {
                                Label(shop.isDeployed ? "設置済み" : "未設置",
                                      systemImage: shop.isDeployed ? "checkmark.circle.fill" : "circle")
                                    .font(.captionSmall)
                                    .foregroundStyle(shop.isDeployed ? Color.accentGreen : Color.textTertiary)
                                Text("·").foregroundStyle(Color.textTertiary)
                                Label("\(productCount)商品", systemImage: "archivebox.fill")
                                    .font(.captionSmall).foregroundStyle(Color.accentPurple)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        HStack(spacing: .spacing12) {
                            statCell(label: "本日", value: "\(todayOrders.count)",
                                     icon: "sun.max.fill", color: .accentOrange)
                            Divider().frame(height: 44)
                            statCell(label: "7日間", value: "\(weekOrders.count)",
                                     icon: "calendar", color: .accentIndigo)
                            Divider().frame(height: 44)
                            statCell(label: "累計", value: "\(orders.count)",
                                     icon: "infinity", color: accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                } header: { Text("注文件数") }

                if !isLoading && !lowStockProducts.isEmpty {
                    Section {
                        ForEach(lowStockProducts) { product in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(product.stock == 0 ? .red : .orange)
                                    .font(.system(size: 14))
                                Text(product.name).font(.bodySmall)
                                Spacer()
                                Text(product.stock == 0 ? "売り切れ" : "残り\(product.stock!)個")
                                    .font(.captionSmall).fontWeight(.semibold)
                                    .foregroundStyle(product.stock == 0 ? .red : .accentOrange)
                            }
                        }
                    } header: {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("在庫アラート")
                        }
                    }
                }

                if !isLoading && !topProducts.isEmpty {
                    Section {
                        ForEach(Array(topProducts.enumerated()), id: \.offset) { idx, item in
                            HStack {
                                Text(["🥇", "🥈", "🥉"][safe: idx] ?? "·").font(.system(size: 16))
                                Text(item.name).font(.bodySmall)
                                Spacer()
                                Text("\(item.count)件").font(.captionSmall).foregroundStyle(Color.textTertiary)
                            }
                        }
                    } header: { Text("売れ筋ランキング") }
                }

                if !isLoading && orders.isEmpty {
                    Section {
                        VStack(spacing: .spacing8) {
                            Image(systemName: "cart").font(.system(size: 32)).foregroundStyle(Color.textTertiary)
                            Text("まだ注文がありません").font(.bodySmall).foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing16)
                        .listRowBackground(Color(.systemGroupedBackground))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ステータス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
            .task { await load() }
        }
    }

    private func statCell(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(Color.textPrimary)
            Text(label).font(.captionSmall).foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        isLoading = true
        async let ordersResult = (try? await services.shops.fetchOrders(guildId: guildId, status: nil)) ?? []
        async let productsResult = (try? await services.shops.fetchProducts(shopId: shop.id)) ?? []
        let (fetchedOrders, fetchedProducts) = await (ordersResult, productsResult)
        orders = fetchedOrders.filter { $0.shopId == shop.id }
        products = fetchedProducts
        isLoading = false
    }
}

// MARK: - ProductsManageView

struct ProductsManageView: View {
    let shop: Shop
    let guildId: String
    let onCountChange: (Int) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var editingProduct: Product? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .listRowBackground(Color(.systemGroupedBackground))
                            .listRowSeparator(.hidden).padding(.top, 40)
                    } else if products.isEmpty {
                        VStack(spacing: .spacing12) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 40)).foregroundStyle(Color.textTertiary)
                            Text("商品がありません").font(.titleMedium).foregroundStyle(Color.textPrimary)
                            Text("「商品を追加」ボタンから販売する商品を作成できます")
                                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                        .listRowBackground(Color(.systemGroupedBackground)).listRowSeparator(.hidden)
                    } else {
                        ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                            ShopProductCard(product: product, index: index, onEdit: { editingProduct = product })
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color(.systemGroupedBackground))
                                .listRowSeparator(.hidden)
                        }
                        .onMove { indices, newOffset in
                            products.move(fromOffsets: indices, toOffset: newOffset)
                            Task { await updatePositions() }
                        }
                        .onDelete { offsets in
                            let toDelete = offsets.map { products[$0] }
                            Task {
                                for p in toDelete { try? await services.shops.deleteProduct(id: p.id) }
                                products.remove(atOffsets: offsets)
                                onCountChange(products.count)
                            }
                        }
                    }
                    Color.clear.frame(height: 80)
                        .listRowBackground(Color(.systemGroupedBackground)).listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .background(Color(.systemGroupedBackground))

                Button { showCreate = true } label: {
                    HStack(spacing: .spacing8) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("商品を追加").font(.bodySmall).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacing20).padding(.vertical, .spacing12)
                    .background(shop.shopType.accentColor).clipShape(Capsule())
                    .shadow(color: shop.shopType.accentColor.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("\(shop.name)の商品")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .task { await load() }
            .sheet(isPresented: $showCreate) {
                ProductEditView(shopId: shop.id, guildId: guildId, shopType: shop.shopType, existingProduct: nil) { saved in
                    products.append(saved)
                    onCountChange(products.count)
                }
            }
            .sheet(item: $editingProduct) { product in
                ProductEditView(shopId: product.shopId, guildId: guildId, shopType: shop.shopType, existingProduct: product) { updated in
                    if let idx = products.firstIndex(where: { $0.id == updated.id }) { products[idx] = updated }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        products = (try? await services.shops.fetchProducts(shopId: shop.id)) ?? []
        onCountChange(products.count)
        isLoading = false
    }

    private func updatePositions() async {
        for (index, var product) in products.enumerated() {
            product.position = index
            _ = try? await services.shops.updateProduct(product)
        }
    }
}

// MARK: - ShopProductCard

struct ShopProductCard: View {
    let product: Product
    let index: Int
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                ZStack {
                    Circle()
                        .fill(product.enabled ? Color.accentPurple.opacity(0.15) : Color.gray.opacity(0.45))
                        .frame(width: 36, height: 36)
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(product.enabled ? Color.accentPurple : Color.textTertiary)
                }
                .opacity(product.enabled ? 1 : 0.6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.name).font(.bodySmall).fontWeight(.semibold)
                            .foregroundStyle(product.enabled ? Color.textPrimary : Color.textTertiary)
                        if product.isSoldOut {
                            Text("売り切れ")
                                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.red)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.red.opacity(0.12)).clipShape(Capsule())
                        }
                        if !product.enabled {
                            Text("無効")
                                .font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.tertiarySystemGroupedBackground)).clipShape(Capsule())
                        }
                    }
                    HStack(spacing: .spacing12) {
                        Label(product.priceDisplay, systemImage: "tag.fill")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        if let stock = product.stock {
                            Label("残り\(stock)個", systemImage: "cube.box.fill")
                                .font(.captionSmall).foregroundStyle(stock > 0 ? Color.accentGreen : .red)
                        } else {
                            Label("無制限", systemImage: "infinity")
                                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        }
                    }
                }

                Spacer()

                Label(product.rewardType.label, systemImage: product.rewardType.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(product.enabled ? Color.accentPurple : Color.textTertiary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(product.enabled ? Color.accentPurple.opacity(0.12) : Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
            .padding(.spacing12)
            .opacity(product.enabled ? 1 : 0.7)

            Divider().padding(.horizontal, .spacing12)

            Button(action: onEdit) {
                Label("編集", systemImage: "pencil")
                    .font(.captionRegular).fontWeight(.medium)
                    .foregroundStyle(Color.accentIndigo)
                    .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
            }
            .buttonStyle(.plain)
            .background(Color(.tertiarySystemGroupedBackground))
        }
        .background(product.enabled
            ? Color(.secondarySystemGroupedBackground)
            : Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - ShopDeployChannelPickerSheet

private struct ShopDeployChannelPickerSheet: View {
    let shop: Shop
    let guildId: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var channels: [(id: String, name: String)] = []
    @State private var isLoading = true

    private var shopEmbedPreview: EmbedData {
        EmbedData(
            color: Color(uiColor: UIColor(hex: UInt32(shop.color))),
            botName: "Noxy",
            messageContent: nil,
            title: "\(shop.shopType == .vendingMachine ? "🏪" : "🛒") \(shop.name)",
            description: shop.description.isEmpty ? nil : shop.description,
            fields: [],
            footerText: shop.shopType == .vendingMachine
                ? "商品を選択して支払い情報を送信してください"
                : "商品を選択して注文してください"
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DiscordMessagePreview(embed: shopEmbedPreview, isCompact: true)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill").font(.captionSmall)
                        Text("送信されるEmbedのプレビュー")
                    }
                } footer: {
                    Text("Discordに投稿されるパネルのイメージです。実際の商品一覧はBot側で自動的に追加されます。")
                }

                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color(.systemGroupedBackground))
                } else if channels.isEmpty {
                    Text("テキストチャンネルが見つかりません")
                        .font(.bodySmall).foregroundStyle(Color.textTertiary)
                } else {
                    Section {
                        ForEach(channels, id: \.id) { ch in
                            Button {
                                onSelect(ch.id)
                                dismiss()
                            } label: {
                                HStack(spacing: .spacing12) {
                                    Image(systemName: "number").font(.system(size: 14)).foregroundStyle(Color.textTertiary)
                                    Text(ch.name).font(.bodySmall).foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    if shop.channelId == ch.id {
                                        Text("現在設定中")
                                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.accentOrange)
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color.accentOrange.opacity(0.1)).clipShape(Capsule())
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: { Text("「\(shop.name)」の送信先チャンネル") }
                    footer: { Text("選択したチャンネルに新しいパネルが投稿されます。") }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("送信先を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        struct RawCh: Decodable { let id: String; let name: String; let type: Int }
        if let chs = try? await WorkerClient().get("/bot/channels?guild_id=\(guildId)") as [RawCh] {
            channels = chs.filter { $0.type == 0 || $0.type == 5 }.map { ($0.id, $0.name) }
        }
        isLoading = false
    }
}

// MARK: - Collection safe subscript

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
