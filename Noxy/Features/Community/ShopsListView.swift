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
        .navigationBarTitleDisplayMode(.large)
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
    @State private var editingShop: Shop? = nil
    @State private var editingShopInitialTab: Int = 0
    @State private var deployingId: String? = nil
    @State private var deployTargetShop: Shop? = nil
    @State private var pendingRedeployShop: Shop? = nil
    @State private var showRedeployConfirm = false
    @State private var toast: String? = nil

    private var accentColor: Color { shopType.accentColor }
    private var createButtonLabel: String {
        shopType == .vendingMachine ? "自販機を作成" : "ショップを作成"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                if isLoading {
                    ForEach(0..<3) { _ in
                        VStack(alignment: .leading, spacing: .spacing8) {
                            HStack(spacing: .spacing8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.textTertiary.opacity(0.2))
                                    .frame(width: 100, height: 18)
                                Spacer()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.textTertiary.opacity(0.15))
                                    .frame(width: 50, height: 14)
                            }
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.textTertiary.opacity(0.1))
                                .frame(width: 180, height: 12)
                        }
                        .padding(.spacing12)
                        .background(Color.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                        .padding(.top, 8)
                    }
                    .transition(.opacity)
                } else if shops.isEmpty {
                    emptyState
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                        .transition(.opacity)
                } else {
                    ForEach(shops) { shop in
                        let count = productCounts[shop.id] ?? 0
                        ShopCard(
                            shop: shop,
                            productCount: count,
                            isDeploying: deployingId == shop.id,
                            onTap: {
                                editingShopInitialTab = count > 0 ? 0 : 2
                                editingShop = shop
                            },
                            onSettings: {
                                editingShopInitialTab = 0
                                editingShop = shop
                            },
                            onManageProducts: {
                                editingShopInitialTab = 2
                                editingShop = shop
                            },
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
                    Text(createButtonLabel).font(.bodySmall).fontWeight(.semibold)
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
                VendingMachineEditView(existingShop: nil, guildId: guildId) { shops.insert($0, at: 0) }
            } else {
                ShopEditView(existingShop: nil, guildId: guildId, shopType: .shop) { shops.insert($0, at: 0) }
            }
        }
        .sheet(item: $editingShop) { shop in
            if shopType == .vendingMachine {
                VendingMachineEditView(existingShop: shop, guildId: guildId, initialTab: editingShopInitialTab) { updated in
                    if let idx = shops.firstIndex(where: { $0.id == updated.id }) { shops[idx] = updated }
                    Task { await loadProductCounts() }
                }
            } else {
                ShopEditView(existingShop: shop, guildId: guildId, shopType: .shop, initialTab: editingShopInitialTab) { updated in
                    if let idx = shops.firstIndex(where: { $0.id == updated.id }) { shops[idx] = updated }
                    Task { await loadProductCounts() }
                }
            }
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

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: shopType == .vendingMachine ? "storefront" : "cart.badge.plus")
                .font(.system(size: 40)).foregroundStyle(Color.textTertiary)
            Text(shopType == .vendingMachine ? "自販機がありません" : "ショップがありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text("「\(createButtonLabel)」ボタンからパネルを追加できます")
                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
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

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }
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
                                    Image(systemName: "number")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textTertiary)
                                    Text(ch.name)
                                        .font(.bodySmall).foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    if shop.channelId == ch.id {
                                        Text("現在設定中")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color.accentOrange)
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color.accentOrange.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("「\(shop.name)」の送信先チャンネル")
                    } footer: {
                        Text("選択したチャンネルに新しいパネルが投稿されます。")
                    }
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

// MARK: - ShopCard

private struct ShopCard: View {
    let shop: Shop
    let productCount: Int
    let isDeploying: Bool
    let onTap: () -> Void
    let onSettings: () -> Void
    let onManageProducts: () -> Void
    let onDeploy: () -> Void

    private var accentColor: Color {
        shop.enabled
            ? Color(uiColor: UIColor(hex: UInt32(shop.color)))
            : Color.gray.opacity(0.6)
    }
    private var hasProducts: Bool { productCount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: .spacing12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor)
                            .frame(width: 44, height: 44)
                        Image(systemName: shop.enabled ? shop.shopType.icon : "cart.badge.xmark")
                            .font(.system(size: 18)).foregroundStyle(.white)
                    }
                    .opacity(shop.enabled ? 1 : 0.7)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: .spacing6) {
                            Text(shop.name)
                                .font(.bodySmall).fontWeight(.semibold)
                                .foregroundStyle(shop.enabled ? Color.textPrimary : Color.textTertiary)
                            if !shop.enabled {
                                Text("無効")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                            if shop.autoDeleteEnabled, let days = shop.autoDeleteDays {
                                Label("\(days)日で削除", systemImage: "timer")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.accentOrange)
                            }
                        }
                        HStack(spacing: .spacing8) {
                            if !shop.description.isEmpty {
                                Text(shop.description)
                                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                                    .lineLimit(1)
                            }
                            if shop.reviewEnabled {
                                Label("レビュー有効", systemImage: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.accentIndigo)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if shop.isDeployed {
                            Label("設置済み", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.accentGreen)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.accentGreen.opacity(0.1))
                                .clipShape(Capsule())
                        } else {
                            Text("未設置")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "archivebox.fill").font(.system(size: 8))
                            Text(hasProducts ? "\(productCount)商品" : "商品なし")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(hasProducts ? Color.accentPurple : Color.accentOrange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(
                            (hasProducts ? Color.accentPurple : Color.accentOrange).opacity(0.1)
                        )
                        .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.spacing12)
            }
            .buttonStyle(.plain)
            .opacity(shop.enabled ? 1 : 0.8)

            Divider().padding(.horizontal, .spacing12)

            if !hasProducts {
                Button(action: onManageProducts) {
                    HStack(spacing: .spacing6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                        Text("商品を追加して設置を有効にする")
                            .font(.captionRegular).fontWeight(.semibold)
                    }
                    .foregroundStyle(shop.shopType.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain)
                .background(shop.shopType.accentColor.opacity(0.04))
            } else {
                HStack(spacing: 0) {
                    Button(action: onSettings) {
                        Label("設定", systemImage: "gearshape")
                            .font(.captionRegular).fontWeight(.medium)
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, .spacing10)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 20)

                    Button(action: onManageProducts) {
                        Label("商品", systemImage: "archivebox.fill")
                            .font(.captionRegular).fontWeight(.medium)
                            .foregroundStyle(Color.accentPurple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, .spacing10)
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
                                .foregroundStyle(shop.isDeployed ? Color.accentOrange : Color.accentGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, .spacing10)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeploying)
                }
                .background(Color(.tertiarySystemGroupedBackground))
            }
        }
        .background(shop.enabled
            ? Color(.secondarySystemGroupedBackground)
            : Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
