import SwiftUI

// MARK: - ShopEditView

struct ShopEditView: View {
    var existingShop: Shop?
    let guildId: String
    let initialTab: Int
    let onSave: (Shop) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var selectedTab: Int

    init(existingShop: Shop? = nil, guildId: String, initialTab: Int = 0, onSave: @escaping (Shop) -> Void) {
        self.existingShop = existingShop
        self.guildId = guildId
        self.initialTab = initialTab
        self.onSave = onSave
        _selectedTab = State(initialValue: initialTab)
    }
    @State private var name = "ショップ"
    @State private var description = "商品を選択して購入してください。"
    @State private var enabled = true
    @State private var disabledMessage = "このショップは現在準備中です。もうしばらくお待ちください。"
    @State private var supportRoleId = ""
    @State private var orderCategoryId = ""
    @State private var archiveCategoryId = ""
    @State private var timeoutHours: Int? = nil
    @State private var timeoutEnabled = false
    @State private var footerText = ""
    @State private var colorHex: UInt32 = 0x6366f1
    @State private var reviewEnabled = false
    @State private var reviewChannelId = ""

    // Welcome embed
    @State private var welcomeImageUrl = ""
    @State private var welcomeThumbnailUrl = ""
    @State private var welcomeFields: [EmbedFieldModel] = []
    @State private var welcomeFooterText = ""
    @State private var welcomeFooterIconUrl = ""
    @State private var welcomeShowTimestamp = true

    // Products (for 商品 tab)
    @State private var products: [Product] = []
    @State private var showCreateProduct = false
    @State private var editingProduct: Product? = nil

    @State private var roles: [DiscordRole] = []
    @State private var categories: [(id: String, name: String)] = []
    @State private var textChannels: [(id: String, name: String)] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showDiscardAlert = false

    private var isNew: Bool { existingShop == nil }
    private var previewColor: Color { Color(uiColor: UIColor(hex: colorHex)) }
    private let colorPresets: [UInt32] = [0x6366f1, 0x10b981, 0xf59e0b, 0xef4444, 0x8b5cf6, 0x3b82f6]

    private var hasChanges: Bool {
        guard let s = existingShop else { return true }
        return name != s.name || description != s.description || enabled != s.enabled ||
            disabledMessage != (s.disabledMessage ?? "このショップは現在準備中です。もうしばらくお待ちください。") ||
            supportRoleId != (s.supportRoleId ?? "") || orderCategoryId != (s.orderCategoryId ?? "") ||
            archiveCategoryId != (s.archiveCategoryId ?? "") || timeoutEnabled != (s.timeoutHours != nil) ||
            (timeoutEnabled && timeoutHours != s.timeoutHours) || footerText != s.footerText ||
            colorHex != UInt32(s.color) || reviewEnabled != s.reviewEnabled ||
            reviewChannelId != (s.reviewChannelId ?? "") ||
            welcomeImageUrl != (s.welcomeImageUrl ?? "") || welcomeThumbnailUrl != (s.welcomeThumbnailUrl ?? "") ||
            welcomeFields != s.welcomeFields || welcomeFooterText != (s.welcomeFooterText ?? "") ||
            welcomeFooterIconUrl != (s.welcomeFooterIconUrl ?? "") || welcomeShowTimestamp != s.welcomeShowTimestamp
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar buttons
                HStack {
                    Button("キャンセル") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }.foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.isEmpty ? Color.textTertiary : Color.accentIndigo)
                        .disabled(name.isEmpty || isSaving)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(Divider(), alignment: .bottom)

                // Tab bar
                tabPicker
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .overlay(Divider(), alignment: .bottom)

                // Content
                TabView(selection: $selectedTab) {
                    panelSettingsTab.tag(0)
                    transactionTab.tag(1)
                    productsTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(isNew ? "ショップを作成" : "ショップを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }.foregroundStyle(Color.textSecondary)
                }
            }
            .task { await loadData() }
            .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
                Button("破棄する", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("行った変更は保存されません。")
            }
        }
    }

    private var tabPicker: some View {
        Picker("タブ", selection: $selectedTab) {
            Text("パネル設定").tag(0)
            Text("取引").tag(1)
            Text("商品").tag(2)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - パネル設定

    private var panelSettingsTab: some View {
        Form {
            enabledToggleSection
            appearanceSection
            previewSection
            channelSettingsSection
            timeoutSection
            footerSection

            if let err = errorMessage {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.captionRegular)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private var enabledToggleSection: some View {
        Section {
            Toggle("ショップを有効にする", isOn: $enabled)
            if !enabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("無効時メッセージ").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    TextEditor(text: $disabledMessage)
                        .frame(minHeight: 60).scrollContentBackground(.hidden)
                }
            }
        } header: { Text("有効/無効") }
          footer: {
              if !enabled {
                  Text("無効の場合、参加者が商品を選択しようとするとこのメッセージが表示されます。")
              } else {
                  Text("無効にすると、パネルは表示されますが商品を選択できなくなります。")
              }
          }
    }

    private var appearanceSection: some View {
        Section {
            LabeledContent("名前") {
                TextField("ショップ", text: $name).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("説明").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextEditor(text: $description)
                    .frame(minHeight: 60).scrollContentBackground(.hidden)
            }
            HStack {
                Text("カラー")
                Spacer()
                HStack(spacing: 8) {
                    ForEach(colorPresets, id: \.self) { hex in
                        ZStack {
                            Circle().fill(Color(uiColor: UIColor(hex: hex))).frame(width: 26, height: 26)
                            if colorHex == hex {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { colorHex = hex } }
                    }
                }
            }
        } header: { Text("パネルの見た目") }
    }

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: .spacing12) {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2).fill(previewColor).frame(width: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if !name.isEmpty {
                            Text(name).font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                        }
                        if !description.isEmpty {
                            Text(description).font(.captionRegular).foregroundStyle(Color.textSecondary)
                        }
                        Divider().padding(.vertical, 4)
                        Text(footerText.isEmpty ? "フッターなし" : footerText).font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                    }
                    .padding(.leading, 10).padding(.vertical, 10).padding(.trailing, 10)
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 6) {
                    Text("🛒 商品を選択してください")
                        .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(previewColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Text("⚠️ 異議を申し立てる")
                        .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 5) {
                Image(systemName: "eye.fill").font(.captionSmall)
                Text("パネルのプレビュー")
            }
        } footer: {
            Text("Discordに投稿されるショップパネルのイメージです。")
        }
    }

    private var channelSettingsSection: some View {
        Section {
            if isLoading {
                HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
            } else {
                Picker("サポートロール", selection: $supportRoleId) {
                    Text("なし").tag("")
                    ForEach(roles.filter { !$0.managed && $0.name != "@everyone" }) {
                        Text("@\($0.name)").tag($0.id)
                    }
                }
                Picker("注文カテゴリ", selection: $orderCategoryId) {
                    Text("なし（デフォルト）").tag("")
                    ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                }
                Picker("アーカイブカテゴリ", selection: $archiveCategoryId) {
                    Text("なし（そのまま）").tag("")
                    ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                }
            }
        } header: { Text("チャンネル設定") }
          footer: {
              Text("サポートロール：注文チャンネルに追加されるロール。\n注文カテゴリ：注文チャンネルを作成するカテゴリ。\nアーカイブカテゴリ：完了・キャンセル後にチャンネルを移動するカテゴリ。")
          }
    }

    private var timeoutSection: some View {
        Section {
            Toggle("タイムアウトを有効にする", isOn: $timeoutEnabled)
            if timeoutEnabled {
                Stepper("タイムアウト：\(timeoutHours ?? 24)時間", value: Binding(
                    get: { timeoutHours ?? 24 },
                    set: { timeoutHours = max(1, $0) }
                ), in: 1...168)
            }
        } header: { Text("注文タイムアウト") }
          footer: {
              Text(timeoutEnabled
                   ? "指定時間以内に支払いが確認されない場合、注文は自動キャンセルされます。"
                   : "タイムアウトを無効にすると、注文は手動で処理されるまで残り続けます。")
          }
    }

    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("フッターテキスト").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextEditor(text: $footerText)
                    .frame(minHeight: 60).scrollContentBackground(.hidden)
            }
        } header: { Text("フッター") }
          footer: {
              Text("ショップパネルのフッターに表示されるテキストです。")
          }
    }

    // MARK: - 取引

    private var transactionTab: some View {
        Form {
            reviewSection
            welcomeEmbedSection
            welcomePreviewSection
            welcomeFieldsSection
            welcomeFooterSection

            if let err = errorMessage {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.captionRegular)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private var reviewSection: some View {
        Section {
            Toggle("レビュー機能を有効にする", isOn: $reviewEnabled)
            if reviewEnabled {
                Picker("レビュー投稿チャンネル", selection: $reviewChannelId) {
                    Text("未選択").tag("")
                    ForEach(textChannels, id: \.id) { Text("#\($0.name)").tag($0.id) }
                }
            }
        } header: { Text("レビュー設定") }
          footer: {
              Text(reviewEnabled
                   ? "取引完了後にレビューボタンが表示されます。評価・コメントは選択したチャンネルに投稿されます。"
                   : "有効にすると、取引完了後に購入者がレビューを投稿できます。")
          }
    }

    private var welcomeEmbedSection: some View {
        Section {
            LabeledContent("画像URL") {
                TextField("https://...", text: $welcomeImageUrl).multilineTextAlignment(.trailing)
            }
            LabeledContent("サムネイルURL") {
                TextField("https://...", text: $welcomeThumbnailUrl).multilineTextAlignment(.trailing)
            }
            Toggle("タイムスタンプを表示", isOn: $welcomeShowTimestamp)
        } header: { Text("ウェルカムメッセージ") }
          footer: { Text("注文チャンネル作成時に送信されるメッセージのembed設定です。") }
    }

    private var welcomePreviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: .spacing12) {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2).fill(previewColor).frame(width: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if !name.isEmpty {
                            Text(name).font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                        }
                        if !description.isEmpty {
                            Text(description).font(.captionRegular).foregroundStyle(Color.textSecondary)
                        }
                        if !welcomeFields.isEmpty {
                            Divider().padding(.vertical, 4)
                            ForEach(welcomeFields) { field in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(field.name).font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                                    Text(field.value).font(.captionSmall).foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                        Divider().padding(.vertical, 4)
                        Text(welcomeFooterText.isEmpty ? (footerText.isEmpty ? "フッターなし" : footerText) : welcomeFooterText)
                            .font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                    }
                    .padding(.leading, 10).padding(.vertical, 10).padding(.trailing, 10)
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 5) {
                Image(systemName: "eye.fill").font(.captionSmall)
                Text("ウェルカムメッセージのプレビュー")
            }
        }
    }

    private var welcomeFieldsSection: some View {
        Section {
            ForEach(Array(welcomeFields.enumerated()), id: \.element.id) { idx, field in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("フィールド \(idx + 1)").font(.captionSmall).fontWeight(.semibold)
                        Spacer()
                        Button("削除") {
                            var updated = welcomeFields
                            updated.remove(at: idx)
                            withAnimation { welcomeFields = updated }
                        }.font(.captionSmall).foregroundStyle(.red)
                    }
                    TextField("名前", text: Binding(
                        get: { field.name },
                        set: { welcomeFields[idx].name = $0 }
                    ))
                    TextField("値", text: Binding(
                        get: { field.value },
                        set: { welcomeFields[idx].value = $0 }
                    ))
                    Toggle("インライン", isOn: Binding(
                        get: { field.inline },
                        set: { welcomeFields[idx].inline = $0 }
                    ))
                }
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button(action: {
                let newField = EmbedFieldModel(id: UUID().uuidString, name: "", value: "", inline: false)
                withAnimation { welcomeFields.append(newField) }
            }) {
                Label("フィールドを追加", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
        } header: { Text("フィールド") }
    }

    private var welcomeFooterSection: some View {
        Section {
            LabeledContent("フッターテキスト") {
                TextField("パネルフッターと同じ", text: $welcomeFooterText).multilineTextAlignment(.trailing)
            }
            LabeledContent("フッターアイコンURL") {
                TextField("https://...", text: $welcomeFooterIconUrl).multilineTextAlignment(.trailing)
            }
        } header: { Text("ウェルカムフッター") }
          footer: { Text("空白の場合はパネルのフッターが使用されます。") }
    }

    // MARK: - 商品

    private var productsTab: some View {
        ZStack(alignment: .bottom) {
            List {
                if isNew {
                    VStack(spacing: .spacing12) {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 40)).foregroundStyle(Color.textTertiary)
                        Text("ショップを先に保存してください")
                            .font(.titleMedium).foregroundStyle(Color.textPrimary)
                        Text("ショップを保存した後、再度編集画面を開いて商品を追加できます。")
                            .font(.captionRegular).foregroundStyle(Color.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
                } else if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden).padding(.top, 40)
                } else if products.isEmpty {
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

            if !isNew {
                Button { showCreateProduct = true } label: {
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
            }
        }
        .sheet(isPresented: $showCreateProduct) {
            ProductEditView(shopId: existingShop?.id ?? "", guildId: guildId, existingProduct: nil) {
                products.insert($0, at: products.count)
            }
        }
        .sheet(item: $editingProduct) { product in
            ProductEditView(shopId: product.shopId, guildId: guildId, existingProduct: product) { updated in
                if let idx = products.firstIndex(where: { $0.id == updated.id }) { products[idx] = updated }
            }
        }
    }

    private func updatePositions() async {
        for (index, var product) in products.enumerated() {
            product.position = index
            _ = try? await services.shops.updateProduct(product)
        }
    }

    // MARK: - Load & Save

    private func loadData() async {
        isLoading = true

        if let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)"),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            if let chs = try? JSONDecoder().decode([RawCh].self, from: data) {
                categories = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
                textChannels = chs.filter { $0.type == 0 }.map { ($0.id, $0.name) }
            }
        }

        roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []

        if let s = existingShop {
            name = s.name
            description = s.description
            enabled = s.enabled
            disabledMessage = s.disabledMessage ?? "このショップは現在準備中です。もうしばらくお待ちください。"
            supportRoleId = s.supportRoleId ?? ""
            orderCategoryId = s.orderCategoryId ?? ""
            archiveCategoryId = s.archiveCategoryId ?? ""
            timeoutHours = s.timeoutHours
            timeoutEnabled = s.timeoutHours != nil
            footerText = s.footerText
            colorHex = UInt32(s.color)
            reviewEnabled = s.reviewEnabled
            reviewChannelId = s.reviewChannelId ?? ""
            welcomeImageUrl = s.welcomeImageUrl ?? ""
            welcomeThumbnailUrl = s.welcomeThumbnailUrl ?? ""
            welcomeFields = s.welcomeFields
            welcomeFooterText = s.welcomeFooterText ?? ""
            welcomeFooterIconUrl = s.welcomeFooterIconUrl ?? ""
            welcomeShowTimestamp = s.welcomeShowTimestamp

            // Load products
            products = (try? await services.shops.fetchProducts(shopId: s.id)) ?? []
        }

        isLoading = false
    }

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var shop = existingShop ?? Shop.blank(guildId: guildId)
            shop.name = name
            shop.description = description
            shop.enabled = enabled
            shop.disabledMessage = disabledMessage.isEmpty ? nil : disabledMessage
            shop.color = Int(colorHex)
            shop.supportRoleId = supportRoleId.isEmpty ? nil : supportRoleId
            shop.orderCategoryId = orderCategoryId.isEmpty ? nil : orderCategoryId
            shop.archiveCategoryId = archiveCategoryId.isEmpty ? nil : archiveCategoryId
            shop.timeoutHours = timeoutEnabled ? (timeoutHours ?? 24) : nil
            shop.footerText = footerText
            shop.reviewEnabled = reviewEnabled
            shop.reviewChannelId = reviewChannelId.isEmpty ? nil : reviewChannelId
            shop.welcomeImageUrl = welcomeImageUrl.isEmpty ? nil : welcomeImageUrl
            shop.welcomeThumbnailUrl = welcomeThumbnailUrl.isEmpty ? nil : welcomeThumbnailUrl
            shop.welcomeFields = welcomeFields
            shop.welcomeFooterText = welcomeFooterText.isEmpty ? nil : welcomeFooterText
            shop.welcomeFooterIconUrl = welcomeFooterIconUrl.isEmpty ? nil : welcomeFooterIconUrl
            shop.welcomeShowTimestamp = welcomeShowTimestamp

            #if DEBUG
            print("[ShopEditView] save: isNew=\(isNew), shop.id=\(shop.id), guildId=\(shop.guildId)")
            print("[ShopEditView] save: name=\(shop.name), color=\(shop.color), reviewEnabled=\(shop.reviewEnabled)")
            #endif

            let saved = isNew
                ? try await services.shops.createShop(shop)
                : try await services.shops.updateShop(shop)

            #if DEBUG
            print("[ShopEditView] save: success, returned id=\(saved.id)")
            #endif
            onSave(saved)
            dismiss()
        } catch {
            #if DEBUG
            print("[ShopEditView] save: error=\(error)")
            #endif
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

// MARK: - ProductCard (inline for products tab)

private struct ProductCard: View {
    let product: Product
    let index: Int
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                ZStack {
                    Circle().fill(product.enabled ? Color.accentPurple.opacity(0.15) : Color.gray.opacity(0.45))
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
