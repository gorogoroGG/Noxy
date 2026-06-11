import SwiftUI

// MARK: - ShopEditView

struct ShopEditView: View {
    var existingShop: Shop?
    let guildId: String
    let shopType: ShopType
    let initialTab: Int
    let onSave: (Shop) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var selectedTab: Int

    init(existingShop: Shop? = nil, guildId: String, shopType: ShopType = .shop, initialTab: Int = 0, onSave: @escaping (Shop) -> Void) {
        self.existingShop = existingShop
        self.guildId = guildId
        self.shopType = shopType
        // 商品タブ(2)は使わないので 0 or 1 に丸める
        self.initialTab = min(initialTab, 1)
        self.onSave = onSave
        _selectedTab = State(initialValue: min(initialTab, 1))
    }

    @State private var name = ""
    @State private var description = ""
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

    // 自販機固有
    @State private var paymentInputLabel = ""

    // 自動削除
    @State private var autoDeleteEnabled = false
    @State private var autoDeleteDays: Int = 7

    // Welcome embed
    @State private var welcomeImageUrl = ""
    @State private var welcomeThumbnailUrl = ""
    @State private var welcomeFields: [EmbedFieldModel] = []
    @State private var welcomeFooterText = ""
    @State private var welcomeFooterIconUrl = ""
    @State private var welcomeShowTimestamp = true

    @State private var roles: [DiscordRole] = []
    @State private var categories: [(id: String, name: String)] = []
    @State private var textChannels: [(id: String, name: String)] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showDiscardAlert = false

    private let autoDeleteDayOptions: [Int] = [1, 2, 3, 5, 7, 14, 30]

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
            welcomeFooterIconUrl != (s.welcomeFooterIconUrl ?? "") || welcomeShowTimestamp != s.welcomeShowTimestamp ||
            paymentInputLabel != (s.paymentInputLabel ?? "") ||
            autoDeleteEnabled != s.autoDeleteEnabled || (autoDeleteEnabled && autoDeleteDays != (s.autoDeleteDays ?? 7))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button("キャンセル") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }.foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.isEmpty ? Color.textTertiary : shopType.accentColor)
                        .disabled(name.isEmpty || isSaving)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(Divider(), alignment: .bottom)

                tabPicker
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .overlay(Divider(), alignment: .bottom)

                TabView(selection: $selectedTab) {
                    panelSettingsTab.tag(0)
                    transactionTab.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(isNew ? "\(shopType.label)を作成" : "\(shopType.label)を編集")
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
        }
        .pickerStyle(.segmented)
    }

    // MARK: - パネル設定

    private var panelSettingsTab: some View {
        Form {
            enabledToggleSection
            appearanceSection
            previewSection
            serverSettingsSection
            if shopType == .vendingMachine {
                paymentInputLabelSection
            }
            autoDeleteSection
            if shopType == .shop {
                timeoutSection
            }
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
            Toggle("\(shopType.label)を有効にする", isOn: $enabled)
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
                TextField(shopType.label, text: $name).multilineTextAlignment(.trailing)
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
                    let buttonLabel = shopType == .vendingMachine ? "🏪 商品を選択してください" : "🛒 商品を選択してください"
                    Text(buttonLabel)
                        .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(previewColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 5) {
                Image(systemName: "eye.fill").font(.captionSmall)
                Text("パネルのプレビュー")
            }
        } footer: {
            Text("Discordに投稿されるパネルのイメージです。")
        }
    }

    // MARK: - サーバー設定（リデザイン）

    private var serverSettingsSection: some View {
        Section {
            if isLoading {
                HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
            } else {
                // サポートロール
                serverSettingRow(
                    icon: "shield.lefthalf.filled",
                    iconColor: .accentIndigo,
                    title: "サポートロール",
                    subtitle: "注文チャンネルに追加するロール"
                ) {
                    Menu {
                        Button("なし") { supportRoleId = "" }
                        Divider()
                        ForEach(roles.filter { !$0.managed && $0.name != "@everyone" }) { role in
                            Button("@\(role.name)") { supportRoleId = role.id }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(roles.first(where: { $0.id == supportRoleId })
                                    .map { "@\($0.name)" } ?? "なし")
                                .font(.captionRegular)
                                .foregroundStyle(supportRoleId.isEmpty ? Color.textTertiary : .accentIndigo)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }

                // オープンカテゴリ
                serverSettingRow(
                    icon: "folder.badge.plus",
                    iconColor: .accentGreen,
                    title: "オープンカテゴリ",
                    subtitle: "注文チャンネルを作成する場所"
                ) {
                    Menu {
                        Button("なし（デフォルト）") { orderCategoryId = "" }
                        Divider()
                        ForEach(categories, id: \.id) { cat in
                            Button(cat.name) { orderCategoryId = cat.id }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(categories.first(where: { $0.id == orderCategoryId })?.name ?? "なし")
                                .font(.captionRegular)
                                .foregroundStyle(orderCategoryId.isEmpty ? Color.textTertiary : .accentGreen)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }

                // クローズカテゴリ
                serverSettingRow(
                    icon: "archivebox.fill",
                    iconColor: .accentOrange,
                    title: "クローズカテゴリ",
                    subtitle: "完了・キャンセル後に移動する場所"
                ) {
                    Menu {
                        Button("なし（そのまま）") { archiveCategoryId = "" }
                        Divider()
                        ForEach(categories, id: \.id) { cat in
                            Button(cat.name) { archiveCategoryId = cat.id }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(categories.first(where: { $0.id == archiveCategoryId })?.name ?? "なし")
                                .font(.captionRegular)
                                .foregroundStyle(archiveCategoryId.isEmpty ? Color.textTertiary : .accentOrange)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }
            }
        } header: { Text("Discord サーバー設定") }
          footer: {
              Text("オープンカテゴリに注文チャンネルが作成され、取引完了後はクローズカテゴリに移動します。")
          }
    }

    @ViewBuilder
    private func serverSettingRow<T: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 2)
    }

    private var paymentInputLabelSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("支払い入力欄の案内文").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextEditor(text: $paymentInputLabel)
                    .frame(minHeight: 60).scrollContentBackground(.hidden)
            }
        } header: { Text("支払い入力設定") }
          footer: {
              Text("購入者が商品を選択したとき、モーダルに表示される案内文です。例：「PayPayの受け取りURLを入力してください」「ギフトコードを入力してください」")
          }
    }

    // MARK: - 自動削除（チップセレクター）

    private var autoDeleteSection: some View {
        Section {
            Toggle("取引完了後に自動削除する", isOn: $autoDeleteEnabled.animation())
            if autoDeleteEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("削除するまでの日数").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(autoDeleteDayOptions, id: \.self) { days in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { autoDeleteDays = days }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(days)")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("日")
                                        .font(.system(size: 10))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    autoDeleteDays == days
                                        ? shopType.accentColor
                                        : Color(.tertiarySystemGroupedBackground)
                                )
                                .foregroundStyle(autoDeleteDays == days ? .white : Color.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(autoDeleteDays == days ? shopType.accentColor : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        } header: { Text("チケットの自動削除") }
          footer: {
              if autoDeleteEnabled {
                  Text("取引完了から \(autoDeleteDays) 日後にチケットチャンネルが自動削除されます。取引開始時・完了時にチャンネル内へ削除予定日が通知されます。")
              } else {
                  Text("有効にすると、取引完了から指定した日数が経過した時点でチケットチャンネルが自動的に削除されます。")
              }
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
              Text("パネルのフッターに表示されるテキストです。")
          }
    }

    // MARK: - 取引

    private var transactionTab: some View {
        Form {
            if shopType == .shop {
                reviewSection
            }
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

    // MARK: - レビュー設定（通知チャンネル含む）

    private var reviewSection: some View {
        Section {
            Toggle("レビュー機能を有効にする", isOn: $reviewEnabled.animation())
            if reviewEnabled {
                if isLoading {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                } else {
                    serverSettingRow(
                        icon: "bell.fill",
                        iconColor: .accentIndigo,
                        title: "通知チャンネル",
                        subtitle: "レビューを投稿するチャンネル"
                    ) {
                        Menu {
                            Button("未選択") { reviewChannelId = "" }
                            Divider()
                            ForEach(textChannels, id: \.id) { ch in
                                Button("#\(ch.name)") { reviewChannelId = ch.id }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(textChannels.first(where: { $0.id == reviewChannelId })
                                        .map { "#\($0.name)" } ?? "未選択")
                                    .font(.captionRegular)
                                    .foregroundStyle(reviewChannelId.isEmpty ? Color.textTertiary : .accentIndigo)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                    }
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
          footer: { Text("チケット作成時に送信されるメッセージのembed設定です。") }
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

    // MARK: - Load & Save

    private func loadData() async {
        isLoading = true

        struct RawCh: Decodable { let id: String; let name: String; let type: Int }
        if let chs = try? await WorkerClient().get("/bot/channels?guild_id=\(guildId)") as [RawCh] {
            categories   = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
            textChannels = chs.filter { $0.type == 0 }.map { ($0.id, $0.name) }
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
            paymentInputLabel = s.paymentInputLabel ?? ""
            autoDeleteEnabled = s.autoDeleteEnabled
            autoDeleteDays = s.autoDeleteDays ?? 7
        } else {
            let blank = Shop.blank(guildId: guildId, shopType: shopType)
            name = blank.name
            description = blank.description
            colorHex = UInt32(blank.color)
            paymentInputLabel = blank.paymentInputLabel ?? ""
        }

        isLoading = false
    }

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var shop = existingShop ?? Shop.blank(guildId: guildId, shopType: shopType)
            shop.name = name
            shop.description = description
            shop.enabled = enabled
            shop.disabledMessage = disabledMessage.isEmpty ? nil : disabledMessage
            shop.color = Int(colorHex)
            shop.supportRoleId = supportRoleId.isEmpty ? nil : supportRoleId
            shop.orderCategoryId = orderCategoryId.isEmpty ? nil : orderCategoryId
            shop.archiveCategoryId = archiveCategoryId.isEmpty ? nil : archiveCategoryId
            shop.timeoutHours = (shopType == .shop && timeoutEnabled) ? (timeoutHours ?? 24) : nil
            shop.footerText = footerText
            shop.reviewEnabled = shopType == .shop ? reviewEnabled : false
            shop.reviewChannelId = reviewChannelId.isEmpty ? nil : reviewChannelId
            shop.welcomeImageUrl = welcomeImageUrl.isEmpty ? nil : welcomeImageUrl
            shop.welcomeThumbnailUrl = welcomeThumbnailUrl.isEmpty ? nil : welcomeThumbnailUrl
            shop.welcomeFields = welcomeFields
            shop.welcomeFooterText = welcomeFooterText.isEmpty ? nil : welcomeFooterText
            shop.welcomeFooterIconUrl = welcomeFooterIconUrl.isEmpty ? nil : welcomeFooterIconUrl
            shop.welcomeShowTimestamp = welcomeShowTimestamp
            shop.paymentInputLabel = (shopType == .vendingMachine && !paymentInputLabel.isEmpty)
                ? paymentInputLabel : nil
            shop.autoDeleteEnabled = autoDeleteEnabled
            shop.autoDeleteDays = autoDeleteEnabled ? autoDeleteDays : nil

            let saved = isNew
                ? try await services.shops.createShop(shop)
                : try await services.shops.updateShop(shop)

            onSave(saved)
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

