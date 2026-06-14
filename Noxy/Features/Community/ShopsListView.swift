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
                tabButton(title: shopType.label, icon: shopType.icon, tab: .panels)
                tabButton(title: "注文", icon: "list.bullet.clipboard", tab: .orders)
            }
            .background(Theme.Color.surface)
            .overlay(Divider().background(Theme.Color.line), alignment: .bottom)

            switch selectedTab {
            case .panels: ShopPanelListView(guildId: guildId, shopType: shopType)
            case .orders: OrdersListView(guildId: guildId)
            }
        }
        .background(Theme.Color.bg)
        .navigationTitle(shopType.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tabButton(title: String, icon: String, tab: Tab) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab } } label: {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                    Text(title).font(Theme.Font.caption).fontWeight(.semibold)
                }
                .foregroundStyle(selectedTab == tab ? Theme.Color.accent : Theme.Color.textTertiary)
                Capsule()
                    .fill(selectedTab == tab ? Theme.Color.accent : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
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
    enum ShopFilter: String, CaseIterable {
        case all     = "すべて"
        case deployed = "設置済み"
        case pending  = "未設置"
        case disabled = "無効"
    }

    @State private var shops: [Shop] = []
    @State private var productCounts: [String: Int] = [:]
    @State private var isLoading = true
    @State private var selectedFilter: ShopFilter = .all
    @State private var showCreate = false
    @State private var settingsShop: Shop? = nil
    @State private var productsShop: Shop? = nil
    @State private var statusShop: Shop? = nil
    @State private var deployTargetShop: Shop? = nil
    @State private var pendingRedeployShop: Shop? = nil
    @State private var showRedeployConfirm = false
    @State private var deployingId: String? = nil
    @State private var toast: String? = nil
    @State private var deletingShop: Shop? = nil
    @State private var showDeleteConfirm = false

    private var filteredShops: [Shop] {
        let sorted = shops.sorted {
            // 設置済み → 未設置 → 無効
            if $0.isDeployed != $1.isDeployed { return $0.isDeployed }
            if $0.enabled != $1.enabled { return $0.enabled }
            return false
        }
        switch selectedFilter {
        case .all:      return sorted
        case .deployed: return sorted.filter { $0.isDeployed && $0.enabled }
        case .pending:  return sorted.filter { !$0.isDeployed && $0.enabled }
        case .disabled: return sorted.filter { !$0.enabled }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // サブタブ（フィルター）
                if !isLoading && !shops.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(ShopFilter.allCases, id: \.self) { filter in
                                let count = countForFilter(filter)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) { selectedFilter = filter }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(filter.rawValue)
                                            .font(Theme.Font.caption)
                                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                            .foregroundStyle(selectedFilter == filter ? Theme.Color.accent : Theme.Color.textTertiary)
                                        if filter != .all {
                                            Text("\(count)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(selectedFilter == filter ? Theme.Color.accent : Theme.Color.textTertiary)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(selectedFilter == filter ? Theme.Color.accentDim : Theme.Color.surfaceRaised)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .padding(.vertical, Theme.Spacing.xs)
                                    .overlay(alignment: .bottom) {
                                        if selectedFilter == filter {
                                            Capsule().fill(Theme.Color.accent).frame(height: 2)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                    }
                    .background(Theme.Color.surface)
                    .overlay(Divider().background(Theme.Color.line), alignment: .bottom)
                }

                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        if isLoading {
                            ForEach(0..<3) { _ in skeletonCard }
                                .transition(.opacity)
                        } else if filteredShops.isEmpty {
                            emptyState
                                .transition(.opacity)
                        } else {
                            SectionLabel(title: "\(shopType.label)リスト")
                                .padding(.horizontal, Theme.Spacing.md)

                            VStack(spacing: Theme.Spacing.sm) {
                                ForEach(filteredShops) { shop in
                                    ShopRow(
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
                                        },
                                        onDelete: {
                                            deletingShop = shop
                                            showDeleteConfirm = true
                                        }
                                    )
                                    .background(Theme.Color.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)

                            bottomPad
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                }
            }

            Button { showCreate = true } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text(shopType == .vendingMachine ? "自販機を作成" : "ショップを作成")
                        .font(Theme.Font.bodySmall).fontWeight(.semibold)
                }
                .foregroundStyle(Theme.Color.accentInk)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Color.accent)
                .clipShape(Capsule())
            }
            .padding(.bottom, Theme.Spacing.xl)

            if let toast {
                Text(toast)
                    .font(Theme.Font.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.Color.lineStrong, lineWidth: 1))
                    .padding(.bottom, Theme.Spacing.xxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toast != nil)
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
        .overlay {
            if showDeleteConfirm, let shop = deletingShop {
                ConfirmModal(
                    icon: "trash.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "削除しますか？",
                    message: "「\(shop.name)」を削除します。この操作は元に戻せません。",
                    primaryLabel: "削除する",
                    primaryRole: .destructive,
                    onPrimary: {
                        Task {
                            try? await services.shops.deleteShop(id: shop.id)
                            shops.removeAll { $0.id == shop.id }
                            deletingShop = nil
                            showDeleteConfirm = false
                        }
                    },
                    onCancel: {
                        deletingShop = nil
                        showDeleteConfirm = false
                    }
                )
            }
        }
        .task { await load() }
        .onChange(of: guildId) { _, _ in
            isLoading = true
            Task { await load() }
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Color.textTertiary.opacity(0.2))
                    .frame(width: 100, height: 18)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Color.textTertiary.opacity(0.15))
                    .frame(width: 50, height: 14)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.Color.textTertiary.opacity(0.1))
                .frame(width: 180, height: 12)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: shopType == .vendingMachine ? "storefront" : "cart.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Color.textTertiary)
            Text(shopType == .vendingMachine ? "自販機がありません" : "ショップがありません")
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("ボタンからパネルを追加できます")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xxl)
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
            showToast("Discordに送信しました")
        } catch ServiceError.workerError(let status, let msg) {
            showToast("送信失敗(\(status)): \(msg.prefix(80))")
        } catch {
            showToast("送信に失敗: \(error.localizedDescription)")
        }
        deployingId = nil
    }

    private func updateCache(with shop: Shop) {
        var cached = appState.cachedShops[guildId] ?? []
        if let idx = cached.firstIndex(where: { $0.id == shop.id }) {
            cached[idx] = shop
        } else {
            cached.insert(shop, at: 0)
        }
        appState.cacheShops(cached, for: guildId)
    }

    private func countForFilter(_ filter: ShopFilter) -> Int {
        switch filter {
        case .all:      return shops.count
        case .deployed: return shops.filter { $0.isDeployed && $0.enabled }.count
        case .pending:  return shops.filter { !$0.isDeployed && $0.enabled }.count
        case .disabled: return shops.filter { !$0.enabled }.count
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }
        }
    }
}

// MARK: - ShopRow

private struct ShopRow: View {
    let shop: Shop
    let productCount: Int
    let isDeploying: Bool
    let onStatusTap: () -> Void
    let onSettings: () -> Void
    let onProducts: () -> Void
    let onDeploy: () -> Void
    let onDelete: () -> Void

    private var accentColor: Color {
        shop.enabled ? Color(uiColor: UIColor(hex: UInt32(shop.color))) : Theme.Color.textTertiary
    }
    private var hasProducts: Bool { productCount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            // メイン情報
            Button(action: onStatusTap) {
                HStack(spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(shop.name)
                                .font(Theme.Font.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundStyle(shop.enabled ? Theme.Color.textPrimary : Theme.Color.textTertiary)
                            if !shop.enabled {
                                Badge(text: "無効", color: Theme.Color.statusWarn)
                            }
                        }
                        if !shop.description.isEmpty {
                            Text(shop.description)
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if shop.isDeployed {
                            HStack(spacing: 4) {
                                StatusDot(color: Theme.Color.statusOK)
                                Text("設置済み")
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        } else {
                            Text("未設置")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.accent)
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "archivebox").font(.system(size: 8))
                            Text(hasProducts ? "\(productCount)商品" : "商品なし")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(hasProducts ? Theme.Color.textSecondary : Theme.Color.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Color.surfaceRaised)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.plain)
            .opacity(shop.enabled ? 1 : 0.8)

            Divider()
                .background(Theme.Color.line)
                .padding(.horizontal, Theme.Spacing.sm)

            // 商品管理
            Button(action: onProducts) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "archivebox").font(.system(size: 13))
                    Text("商品を管理")
                        .font(Theme.Font.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    if hasProducts {
                        Text("\(productCount)件")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Color.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.Color.surfaceRaised)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.Color.accent)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.plain)

            Divider()
                .background(Theme.Color.line)
                .padding(.horizontal, Theme.Spacing.sm)

            // 設定 / 設置
            HStack(spacing: 0) {
                Button(action: onSettings) {
                    Label("設定", systemImage: "gearshape")
                        .font(Theme.Font.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(Theme.Color.line)
                    .frame(height: 20)

                Button(action: onDeploy) {
                    if isDeploying {
                        HStack(spacing: 5) {
                            ProgressView().scaleEffect(0.7)
                            Text("送信中")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                    } else {
                        Label(shop.isDeployed ? "再設置" : "設置する", systemImage: "paperplane")
                            .font(Theme.Font.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                !hasProducts ? Theme.Color.textTertiary : Theme.Color.accent
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeploying || !hasProducts)
            }
            .background(Theme.Color.surfaceRaised)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
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
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // ヘッダー
                    HStack(spacing: Theme.Spacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(accentColor)
                                .frame(width: 52, height: 52)
                            Image(systemName: shop.shopType.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Color.accentInk)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shop.name)
                                .font(Theme.Font.title3)
                                .fontWeight(.bold)
                            HStack(spacing: Theme.Spacing.xs) {
                                Label(shop.isDeployed ? "設置済み" : "未設置",
                                      systemImage: shop.isDeployed ? "checkmark.circle.fill" : "circle")
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(shop.isDeployed ? Theme.Color.statusOK : Theme.Color.textTertiary)
                                Text("·")
                                    .foregroundStyle(Theme.Color.textTertiary)
                                Label("\(productCount)商品", systemImage: "archivebox")
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .padding(.horizontal, Theme.Spacing.md)

                    // 注文件数
                    FormSection("注文件数", icon: "chart.bar") {
                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else {
                            HStack(spacing: Theme.Spacing.sm) {
                                statCell(label: "本日", value: "\(todayOrders.count)",
                                         icon: "sun.max", color: Theme.Color.statusWarn)
                                Divider()
                                    .background(Theme.Color.line)
                                    .frame(height: 44)
                                statCell(label: "7日間", value: "\(weekOrders.count)",
                                         icon: "calendar", color: Theme.Color.accent)
                                Divider()
                                    .background(Theme.Color.line)
                                    .frame(height: 44)
                                statCell(label: "累計", value: "\(orders.count)",
                                         icon: "infinity", color: accentColor)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    // 在庫アラート
                    if !isLoading && !lowStockProducts.isEmpty {
                        FormSection("在庫アラート", icon: "exclamationmark.triangle") {
                            VStack(spacing: 0) {
                                ForEach(Array(lowStockProducts.enumerated()), id: \.element.id) { idx, product in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(product.stock == 0 ? Theme.Color.statusBad : Theme.Color.statusWarn)
                                            .font(.system(size: 14))
                                        Text(product.name)
                                            .font(Theme.Font.body)
                                        Spacer()
                                        Text(product.stock == 0 ? "売り切れ" : "残り\(product.stock!)個")
                                            .font(Theme.Font.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(product.stock == 0 ? Theme.Color.statusBad : Theme.Color.statusWarn)
                                    }
                                    .padding(.vertical, Theme.Spacing.xs)
                                    if idx < lowStockProducts.count - 1 {
                                        Divider()
                                            .background(Theme.Color.line)
                                            .padding(.leading, 28)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    // 売れ筋ランキング
                    if !isLoading && !topProducts.isEmpty {
                        FormSection("売れ筋ランキング", icon: "trophy") {
                            VStack(spacing: 0) {
                                ForEach(Array(topProducts.enumerated()), id: \.offset) { idx, item in
                                    HStack {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(idx == 0 ? Theme.Color.accent : Theme.Color.textTertiary)
                                            .frame(width: 24)
                                        Text(item.name)
                                            .font(Theme.Font.body)
                                        Spacer()
                                        Text("\(item.count)件")
                                            .font(Theme.Font.caption2)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                            .monospaced()
                                    }
                                    .padding(.vertical, Theme.Spacing.xs)
                                    if idx < topProducts.count - 1 {
                                        Divider()
                                            .background(Theme.Color.line)
                                            .padding(.leading, 28)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    if !isLoading && orders.isEmpty {
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "cart")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.Color.textTertiary)
                            Text("まだ注文がありません")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                    }

                    bottomPad
                }
                .padding(.top, Theme.Spacing.md)
            }
            .background(Theme.Color.bg)
            .navigationTitle("ステータス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .task { await load() }
        }
    }

    private func statCell(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Color.textPrimary)
                .monospaced()
            Text(label)
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
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
    @State private var deletingProduct: Product? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.top, Theme.Spacing.xxl)
                        } else if products.isEmpty {
                            VStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Theme.Color.textTertiary)
                                Text("商品がありません")
                                    .font(Theme.Font.title3)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                Text("「商品を追加」ボタンから販売する商品を作成できます")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xxl)
                        } else {
                            SectionLabel(title: "商品一覧")
                                .padding(.horizontal, Theme.Spacing.md)

                            VStack(spacing: 0) {
                                ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                                    ShopProductRow(
                                        product: product,
                                        index: index,
                                        onEdit: { editingProduct = product },
                                        onDelete: {
                                            deletingProduct = product
                                            showDeleteConfirm = true
                                        }
                                    )
                                    if index < products.count - 1 {
                                        Divider()
                                            .background(Theme.Color.line)
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Theme.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                            .padding(.horizontal, Theme.Spacing.md)

                            bottomPad
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                }

                Button { showCreate = true } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("商品を追加").font(Theme.Font.bodySmall).fontWeight(.semibold)
                    }
                    .foregroundStyle(Theme.Color.accentInk)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.accent)
                    .clipShape(Capsule())
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Color.bg)
            .navigationTitle("\(shop.name)の商品")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Theme.Color.textSecondary)
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
            .overlay {
                if showDeleteConfirm, let product = deletingProduct {
                    ConfirmModal(
                        icon: "trash.fill",
                        iconColor: Theme.Color.statusBad,
                        title: "削除しますか？",
                        message: "「\(product.name)」を削除します。この操作は元に戻せません。",
                        primaryLabel: "削除する",
                        primaryRole: .destructive,
                        onPrimary: {
                            Task {
                                try? await services.shops.deleteProduct(id: product.id)
                                products.removeAll { $0.id == product.id }
                                onCountChange(products.count)
                                deletingProduct = nil
                                showDeleteConfirm = false
                            }
                        },
                        onCancel: {
                            deletingProduct = nil
                            showDeleteConfirm = false
                        }
                    )
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

// MARK: - ShopProductRow

struct ShopProductRow: View {
    let product: Product
    let index: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(product.enabled ? Theme.Color.accentDim : Theme.Color.surfaceRaised)
                        .frame(width: 36, height: 36)
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(product.enabled ? Theme.Color.accent : Theme.Color.textTertiary)
                }
                .opacity(product.enabled ? 1 : 0.6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.name)
                            .font(Theme.Font.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(product.enabled ? Theme.Color.textPrimary : Theme.Color.textTertiary)
                        if product.isSoldOut {
                            Badge(text: "売り切れ", color: Theme.Color.statusBad)
                        }
                        if !product.enabled {
                            Badge(text: "無効", color: Theme.Color.textTertiary)
                        }
                    }
                    HStack(spacing: Theme.Spacing.sm) {
                        Label(product.priceDisplay, systemImage: "tag")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                        if let stock = product.stock {
                            Label("残り\(stock)個", systemImage: "cube.box")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(stock > 0 ? Theme.Color.textSecondary : Theme.Color.statusBad)
                        } else {
                            Label("無制限", systemImage: "infinity")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                }

                Spacer()

                Label(product.rewardType.label, systemImage: product.rewardType.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(product.enabled ? Theme.Color.textSecondary : Theme.Color.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(product.enabled ? Theme.Color.surfaceRaised : Theme.Color.surface)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .opacity(product.enabled ? 1 : 0.7)

            Divider()
                .background(Theme.Color.line)
                .padding(.horizontal, Theme.Spacing.sm)

            Button(action: onEdit) {
                Label("編集", systemImage: "pencil")
                    .font(Theme.Font.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.plain)
            .background(Theme.Color.surfaceRaised)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
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
            title: shop.name,
            description: shop.description.isEmpty ? nil : shop.description,
            fields: [],
            footerText: shop.shopType == .vendingMachine
                ? "商品を選択して支払い情報を送信してください"
                : "商品を選択して注文してください"
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    FormSection("プレビュー", icon: "eye") {
                        DiscordMessagePreview(embed: shopEmbedPreview, isCompact: true)
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(Theme.Spacing.md)
                    } else if channels.isEmpty {
                        Text("テキストチャンネルが見つかりません")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .padding(Theme.Spacing.md)
                    } else {
                        FormSection("送信先チャンネル", icon: "number") {
                            VStack(spacing: 0) {
                                ForEach(Array(channels.enumerated()), id: \.element.id) { idx, ch in
                                    Button {
                                        onSelect(ch.id)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: Theme.Spacing.sm) {
                                            Image(systemName: "number")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Theme.Color.textTertiary)
                                            Text(ch.name)
                                                .font(Theme.Font.body)
                                                .foregroundStyle(Theme.Color.textPrimary)
                                            Spacer()
                                            if shop.channelId == ch.id {
                                                Text("現在設定中")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(Theme.Color.statusWarn)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Theme.Color.statusWarn.opacity(0.1))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if idx < channels.count - 1 {
                                        Divider()
                                            .background(Theme.Color.line)
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
                .padding(.top, Theme.Spacing.md)
            }
            .background(Theme.Color.bg)
            .navigationTitle("送信先を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Theme.Color.textSecondary)
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

// MARK: - Preview

#Preview("Dark") {
    NavigationStack { ShopsListView(guildId: "", shopType: .shop) }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { ShopsListView(guildId: "", shopType: .shop) }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.light)
}
