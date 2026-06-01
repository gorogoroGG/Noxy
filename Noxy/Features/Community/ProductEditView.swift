import SwiftUI

// MARK: - ProductManagementView

struct ProductManagementView: View {
    let shop: Shop
    let guildId: String

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var editingProduct: Product? = nil
    @State private var toast: String? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .listRowBackground(Color(.systemGroupedBackground))
                            .listRowSeparator(.hidden).padding(.top, 40)
                    } else if products.isEmpty {
                        emptyState
                            .listRowBackground(Color(.systemGroupedBackground))
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                            ProductCard(product: product, index: index, onEdit: { editingProduct = product })
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color(.systemGroupedBackground))
                                .listRowSeparator(.hidden)
                        }
                        .onMove { indices, newOffset in
                            products.move(fromOffsets: indices, toOffset: newOffset)
                            Task { await updatePositions() }
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
                        Text("商品を追加").font(.bodySmall).fontWeight(.semibold)
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
            .navigationTitle("商品管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完了") { dismiss() }.foregroundStyle(Color.accentIndigo)
                }
            }
            .sheet(isPresented: $showCreate) {
                ProductEditView(shopId: shop.id, guildId: guildId, existingProduct: nil) {
                    products.insert($0, at: products.count)
                }
            }
            .sheet(item: $editingProduct) { product in
                ProductEditView(shopId: shop.id, guildId: guildId, existingProduct: product) { updated in
                    if let idx = products.firstIndex(where: { $0.id == updated.id }) { products[idx] = updated }
                }
            }
            .task { await load() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 40)).foregroundStyle(Color.textTertiary)
            Text("商品がありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text("「商品を追加」ボタンから販売する商品を作成できます")
                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func load() async {
        isLoading = true
        products = (try? await services.shops.fetchProducts(shopId: shop.id)) ?? []
        isLoading = false
    }

    private func updatePositions() async {
        for (index, var product) in products.enumerated() {
            product.position = index
            _ = try? await services.shops.updateProduct(product)
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

// MARK: - ProductCard

private struct ProductCard: View {
    let product: Product
    let index: Int
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                ZStack {
                    Circle().fill(product.enabled ? Color.accentPurple.opacity(0.15) : Color(.systemGray4))
                        .frame(width: 36, height: 36)
                    Text("\(index + 1)").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(product.enabled ? Color.accentPurple : Color.textTertiary)
                }
                .opacity(product.enabled ? 1 : 0.6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.name)
                            .font(.bodySmall).fontWeight(.semibold)
                            .foregroundStyle(product.enabled ? Color.textPrimary : Color.textTertiary)
                        if product.isSoldOut {
                            Text("売り切れ")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.red.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        if !product.enabled {
                            Text("無効")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
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
        .background(product.enabled ? Color(.secondarySystemGroupedBackground) : Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - ProductEditView

struct ProductEditView: View {
    let shopId: String
    let guildId: String
    var existingProduct: Product?
    let onSave: (Product) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var priceDisplay = "要相談"
    @State private var imageUrl = ""
    @State private var stockEnabled = false
    @State private var stockValue: Int = 1
    @State private var rewardType: RewardType = .text
    @State private var rewardContent = ""
    @State private var rewardRoleId = ""
    @State private var rewardDmContent = ""
    @State private var enabled = true

    @State private var roles: [DiscordRole] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var isNew: Bool { existingProduct == nil }

    var body: some View {
        NavigationStack {
            Form {
                enabledSection
                basicInfoSection
                stockSection
                rewardSection

                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.captionRegular)
                    }
                }
            }
            .navigationTitle(isNew ? "商品を作成" : "商品を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.isEmpty ? Color.textTertiary : Color.accentIndigo)
                        .disabled(name.isEmpty || isSaving)
                }
            }
            .task { await loadData() }
        }
    }

    private var enabledSection: some View {
        Section {
            Toggle("商品を有効にする", isOn: $enabled)
        } header: { Text("有効/無効") }
          footer: { Text("無効にすると、ショップパネルに表示されなくなります。") }
    }

    private var basicInfoSection: some View {
        Section {
            LabeledContent("商品名") {
                TextField("商品名", text: $name).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("説明").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextEditor(text: $description)
                    .frame(minHeight: 60).scrollContentBackground(.hidden)
            }
            LabeledContent("価格表示") {
                TextField("要相談", text: $priceDisplay).multilineTextAlignment(.trailing)
            }
            LabeledContent("画像URL（任意）") {
                TextField("https://...", text: $imageUrl).multilineTextAlignment(.trailing)
            }
        } header: { Text("基本情報") }
    }

    private var stockSection: some View {
        Section {
            Toggle("在庫管理を有効にする", isOn: $stockEnabled)
            if stockEnabled {
                Stepper("在庫数：\(stockValue)", value: $stockValue, in: 0...9999)
            }
        } header: { Text("在庫設定") }
          footer: {
              Text(stockEnabled ? "在庫が0になると「売り切れ」として表示され、購入できなくなります。" : "在庫無制限として販売されます。")
          }
    }

    private var rewardSection: some View {
        Section {
            Picker("対価タイプ", selection: $rewardType) {
                ForEach(RewardType.allCases, id: \.self) { type in
                    Label(type.label, systemImage: type.icon).tag(type)
                }
            }

            switch rewardType {
            case .text, .url:
                VStack(alignment: .leading, spacing: 6) {
                    Text(rewardType == .url ? "URL" : "テキスト内容").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    TextEditor(text: $rewardContent)
                        .frame(minHeight: 80).scrollContentBackground(.hidden)
                }
            case .role:
                if isLoading {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                } else {
                    Picker("付与するロール", selection: $rewardRoleId) {
                        Text("選択してください").tag("")
                        ForEach(roles.filter { !$0.managed && $0.name != "@everyone" }) {
                            Text("@\($0.name)").tag($0.id)
                        }
                    }
                }
            case .dm:
                VStack(alignment: .leading, spacing: 6) {
                    Text("DM送信内容").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    TextEditor(text: $rewardDmContent)
                        .frame(minHeight: 80).scrollContentBackground(.hidden)
                }
            }
        } header: { Text("対価設定") }
          footer: {
              Text("支払い確認後に自動的に送信される内容です。")
          }
    }

    private var optionsSection: some View {
        Section {
            Toggle("有効", isOn: $enabled)
        } header: { Text("オプション") }
    }

    private func loadData() async {
        isLoading = true
        roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []

        if let p = existingProduct {
            name = p.name
            description = p.description
            priceDisplay = p.priceDisplay
            imageUrl = p.imageUrl ?? ""
            stockEnabled = p.stock != nil
            stockValue = p.stock ?? 1
            rewardType = p.rewardType
            rewardContent = p.rewardContent ?? ""
            rewardRoleId = p.rewardRoleId ?? ""
            rewardDmContent = p.rewardDmContent ?? ""
            enabled = p.enabled
        }
        isLoading = false
    }

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var product = existingProduct ?? Product(
                id: UUID().uuidString, shopId: shopId, name: name, description: description,
                priceDisplay: priceDisplay, imageUrl: nil, stock: nil, rewardType: .text,
                rewardContent: nil, rewardRoleId: nil, rewardDmContent: nil,
                position: 0, enabled: true, createdAt: .now
            )
            product.name = name
            product.description = description
            product.priceDisplay = priceDisplay
            product.imageUrl = imageUrl.isEmpty ? nil : imageUrl
            product.stock = stockEnabled ? stockValue : nil
            product.rewardType = rewardType
            product.rewardContent = rewardContent.isEmpty ? nil : rewardContent
            product.rewardRoleId = rewardRoleId.isEmpty ? nil : rewardRoleId
            product.rewardDmContent = rewardDmContent.isEmpty ? nil : rewardDmContent
            product.enabled = enabled

            let saved = isNew
                ? try await services.shops.createProduct(product)
                : try await services.shops.updateProduct(product)

            onSave(saved)
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました"
        }
        isSaving = false
    }
}
