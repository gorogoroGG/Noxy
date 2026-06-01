import SwiftUI

// MARK: - ShopsListView

struct ShopsListView: View {
    let guildId: String

    enum Tab { case shops, orders }
    @State private var selectedTab: Tab = .shops

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(title: "ショップ", icon: "cart.fill", tab: .shops)
                tabButton(title: "注文", icon: "list.bullet.clipboard", tab: .orders)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(Divider(), alignment: .bottom)

            switch selectedTab {
            case .shops:
                ShopPanelListView(guildId: guildId)
            case .orders:
                OrdersListView(guildId: guildId)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func tabButton(title: String, icon: String, tab: Tab) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab } } label: {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                    Text(title).font(.captionRegular).fontWeight(.semibold)
                }
                .foregroundStyle(selectedTab == tab ? Color.accentIndigo : Color.textTertiary)
                Capsule()
                    .fill(selectedTab == tab ? Color.accentIndigo : Color.clear)
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
    @Environment(\.services) private var services
    @State private var shops: [Shop] = []
    @State private var productCounts: [String: Int] = [:]
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var editingShop: Shop? = nil
    @State private var deployingId: String? = nil
    @State private var deployTargetShop: Shop? = nil
    @State private var selectedShopForProducts: Shop? = nil
    @State private var toast: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden).padding(.top, 40)
                } else if shops.isEmpty {
                    emptyState
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(shops) { shop in
                        let hasProducts = (productCounts[shop.id] ?? 0) > 0
                        ShopCard(
                            shop: shop,
                            isDeploying: deployingId == shop.id,
                            hasProducts: hasProducts,
                            onEdit: { editingShop = shop },
                            onProducts: { selectedShopForProducts = shop },
                            onDeploy: { deployTargetShop = shop }
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
                    Text("ショップを作成").font(.bodySmall).fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, .spacing20).padding(.vertical, .spacing12)
                .background(Color.accentIndigo).clipShape(Capsule())
                .shadow(color: Color.accentIndigo.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.bottom, 24)

            if let toast {
                Text(toast)
                    .font(.captionRegular).fontWeight(.medium).foregroundStyle(.white)
                    .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
                    .background(Color(.systemGray2)).clipShape(Capsule())
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showCreate) {
            ShopEditView(existingShop: nil, guildId: guildId) { shops.insert($0, at: 0) }
        }
        .sheet(item: $editingShop) { shop in
            ShopEditView(existingShop: shop, guildId: guildId) { updated in
                if let idx = shops.firstIndex(where: { $0.id == updated.id }) { shops[idx] = updated }
            }
        }
        .sheet(item: $deployTargetShop) { shop in
            ShopDeployChannelPickerSheet(shop: shop, guildId: guildId) { channelId in
                Task { await deploy(shop, channelId: channelId) }
            }
        }
        .sheet(item: $selectedShopForProducts) { shop in
            ProductManagementView(shop: shop, guildId: guildId)
        }
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 40)).foregroundStyle(Color.textTertiary)
            Text("ショップがありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text("「ショップを作成」ボタンからショップパネルを追加できます")
                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func load() async {
        isLoading = true
        shops = (try? await services.shops.fetchShops(guildId: guildId)) ?? []
        // 各ショップの商品数を並列取得
        var counts: [String: Int] = [:]
        await withTaskGroup(of: (String, Int).self) { group in
            for shop in shops {
                let shopId = shop.id
                group.addTask {
                    let products = (try? await services.shops.fetchProducts(shopId: shopId)) ?? []
                    return (shopId, products.count)
                }
            }
            for await (shopId, count) in group {
                counts[shopId] = count
            }
        }
        productCounts = counts
        isLoading = false
    }

    private func deploy(_ shop: Shop, channelId: String) async {
        deployingId = shop.id
        do {
            let updated = try await services.shops.deployShop(id: shop.id, channelId: channelId)
            if let idx = shops.firstIndex(where: { $0.id == shop.id }) { shops[idx] = updated }
            showToast("✅ Discordに送信しました")
        } catch {
            showToast("❌ 送信に失敗しました")
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

    var body: some View {
        NavigationStack {
            List {
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
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentIndigo)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("「\(shop.name)」の送信先チャンネル")
                    } footer: {
                        Text("選択したチャンネルにショップパネルが投稿されます。")
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
        if let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)"),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            if let chs = try? JSONDecoder().decode([RawCh].self, from: data) {
                channels = chs.filter { $0.type == 0 || $0.type == 5 }.map { ($0.id, $0.name) }
            }
        }
        isLoading = false
    }
}

// MARK: - ShopCard

private struct ShopCard: View {
    let shop: Shop
    let isDeploying: Bool
    let hasProducts: Bool
    let onEdit: () -> Void
    let onProducts: () -> Void
    let onDeploy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(shop.enabled ? Color(uiColor: UIColor(hex: UInt32(shop.color))) : Color(.systemGray4))
                        .frame(width: 42, height: 42)
                    Image(systemName: shop.enabled ? "cart.fill" : "cart.badge.xmark")
                        .font(.system(size: 18)).foregroundStyle(.white)
                }
                .opacity(shop.enabled ? 1 : 0.6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(shop.name)
                            .font(.bodySmall).fontWeight(.semibold)
                            .foregroundStyle(shop.enabled ? Color.textPrimary : Color.textTertiary)
                        if !shop.enabled {
                            Text("無効").font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 4) {
                        Text(shop.description)
                            .font(.captionSmall).foregroundStyle(Color.textTertiary).lineLimit(1)
                        Text("・").foregroundStyle(Color.textTertiary)
                        Label(shop.paymentFlow.label, systemImage: shop.paymentFlow.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentIndigo)
                    }
                }

                Spacer()

                if shop.isDeployed {
                    Label("デプロイ済", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentGreen)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.accentGreen.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Text("未デプロイ")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(.spacing12)
            .opacity(shop.enabled ? 1 : 0.7)

            Divider().padding(.horizontal, .spacing12)

            HStack(spacing: 0) {
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                        .font(.captionRegular).fontWeight(.medium)
                        .foregroundStyle(Color.accentIndigo)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                Button(action: onProducts) {
                    Label("商品管理", systemImage: "archivebox.fill")
                        .font(.captionRegular).fontWeight(.medium)
                        .foregroundStyle(Color.accentPurple)
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
                        Label(shop.isDeployed ? "再送信" : "送信", systemImage: "paperplane.fill")
                            .font(.captionRegular).fontWeight(.medium)
                            .foregroundStyle(shop.isDeployed ? Color.accentOrange : Color.accentGreen)
                            .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeploying || !hasProducts)
            }
            .background(Color(.tertiarySystemGroupedBackground))

            if !hasProducts {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle").font(.system(size: 9))
                    Text("送信するには商品を追加してください")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(Color.textTertiary)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemGroupedBackground))
            }
        }
        .background(shop.enabled ? Color(.secondarySystemGroupedBackground) : Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
