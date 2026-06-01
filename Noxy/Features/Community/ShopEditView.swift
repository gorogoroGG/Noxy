import SwiftUI

// MARK: - ShopEditView

struct ShopEditView: View {
    var existingShop: Shop?
    let guildId: String
    let onSave: (Shop) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var selectedTab = 0
    @State private var name = "ショップ"
    @State private var description = "商品を選択して購入してください。"
    @State private var enabled = true
    @State private var supportRoleId = ""
    @State private var orderCategoryId = ""
    @State private var archiveCategoryId = ""
    @State private var timeoutHours: Int? = nil
    @State private var timeoutEnabled = false
    @State private var footerText = ""
    @State private var colorHex: UInt32 = 0x6366f1
    @State private var paymentFlow: PaymentFlow = .manual
    @State private var autoDeliver = true

    // Welcome embed
    @State private var welcomeImageUrl = ""
    @State private var welcomeThumbnailUrl = ""
    @State private var welcomeFields: [EmbedFieldModel] = []
    @State private var welcomeFooterText = ""
    @State private var welcomeFooterIconUrl = ""
    @State private var welcomeShowTimestamp = true

    @State private var roles: [DiscordRole] = []
    @State private var categories: [(id: String, name: String)] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var isNew: Bool { existingShop == nil }
    private var previewColor: Color { Color(uiColor: UIColor(hex: colorHex)) }
    private let colorPresets: [UInt32] = [0x6366f1, 0x10b981, 0xf59e0b, 0xef4444, 0x8b5cf6, 0x3b82f6]

    var body: some View {
        NavigationStack {
            Form {
                if selectedTab == 0 {
                    enabledToggleSection
                    appearanceSection
                    previewSection
                    channelSettingsSection
                    timeoutSection
                    paymentFlowSection
                    footerSection
                } else {
                    welcomeEmbedSection
                    welcomePreviewSection
                    welcomeFieldsSection
                    welcomeFooterSection
                }

                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.captionRegular)
                    }
                }
            }
            .navigationTitle(isNew ? "ショップを作成" : "ショップを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Picker("タブ", selection: $selectedTab) {
                        Text("基本設定").tag(0)
                        Text("ウェルカム").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
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

    private var enabledToggleSection: some View {
        Section {
            Toggle("ショップを有効にする", isOn: $enabled)
        } header: { Text("有効/無効") }
          footer: { Text("無効にすると、パネルは表示されますが商品を選択できなくなります。") }
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

    private var paymentFlowSection: some View {
        Section {
            Picker("支払いフロー", selection: $paymentFlow) {
                ForEach(PaymentFlow.allCases, id: \.self) {
                    Label($0.label, systemImage: $0.icon).tag($0)
                }
            }
            .pickerStyle(.inline)
            Text(paymentFlow.description).font(.captionSmall).foregroundStyle(Color.textTertiary)

            Toggle("自動で対価を送信", isOn: $autoDeliver)
        } header: { Text("支払い・配送") }
          footer: {
              Text(autoDeliver
                   ? "支払い確認後、自動で商品（対価）を送信します。"
                   : "支払い確認後、手動で対価を送信します。")
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

    // MARK: - Welcome Embed

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

    private func loadData() async {
        isLoading = true

        if let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)"),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            if let chs = try? JSONDecoder().decode([RawCh].self, from: data) {
                categories = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
            }
        }

        roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []
        isLoading = false

        if let s = existingShop {
            name = s.name
            description = s.description
            enabled = s.enabled
            supportRoleId = s.supportRoleId ?? ""
            orderCategoryId = s.orderCategoryId ?? ""
            archiveCategoryId = s.archiveCategoryId ?? ""
            timeoutHours = s.timeoutHours
            timeoutEnabled = s.timeoutHours != nil
            footerText = s.footerText
            colorHex = UInt32(s.color)
            paymentFlow = s.paymentFlow
            autoDeliver = s.autoDeliver
            welcomeImageUrl = s.welcomeImageUrl ?? ""
            welcomeThumbnailUrl = s.welcomeThumbnailUrl ?? ""
            welcomeFields = s.welcomeFields
            welcomeFooterText = s.welcomeFooterText ?? ""
            welcomeFooterIconUrl = s.welcomeFooterIconUrl ?? ""
            welcomeShowTimestamp = s.welcomeShowTimestamp
        }
    }

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var shop = existingShop ?? Shop.blank(guildId: guildId)
            shop.name = name
            shop.description = description
            shop.enabled = enabled
            shop.color = Int(colorHex)
            shop.supportRoleId = supportRoleId.isEmpty ? nil : supportRoleId
            shop.orderCategoryId = orderCategoryId.isEmpty ? nil : orderCategoryId
            shop.archiveCategoryId = archiveCategoryId.isEmpty ? nil : archiveCategoryId
            shop.timeoutHours = timeoutEnabled ? (timeoutHours ?? 24) : nil
            shop.footerText = footerText
            shop.paymentFlow = paymentFlow
            shop.autoDeliver = autoDeliver
            shop.welcomeImageUrl = welcomeImageUrl.isEmpty ? nil : welcomeImageUrl
            shop.welcomeThumbnailUrl = welcomeThumbnailUrl.isEmpty ? nil : welcomeThumbnailUrl
            shop.welcomeFields = welcomeFields
            shop.welcomeFooterText = welcomeFooterText.isEmpty ? nil : welcomeFooterText
            shop.welcomeFooterIconUrl = welcomeFooterIconUrl.isEmpty ? nil : welcomeFooterIconUrl
            shop.welcomeShowTimestamp = welcomeShowTimestamp

            print("[ShopEditView] save: isNew=\(isNew), shop.id=\(shop.id), guildId=\(shop.guildId)")
            print("[ShopEditView] save: name=\(shop.name), color=\(shop.color), paymentFlow=\(shop.paymentFlow)")

            let saved = isNew
                ? try await services.shops.createShop(shop)
                : try await services.shops.updateShop(shop)

            print("[ShopEditView] save: success, returned id=\(saved.id)")
            onSave(saved)
            dismiss()
        } catch {
            print("[ShopEditView] save: error=\(error)")
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
        isSaving = false
    }
}
