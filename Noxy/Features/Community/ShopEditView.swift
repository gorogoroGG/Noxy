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
                    }
                    .foregroundStyle(Theme.Color.textSecondary)
                    Spacer()
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.isEmpty ? Theme.Color.textTertiary : Theme.Color.accent)
                        .disabled(name.isEmpty || isSaving)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Color.surface)
                .overlay(Divider().background(Theme.Color.line), alignment: .bottom)

                tabPicker
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.surface)
                    .overlay(Divider().background(Theme.Color.line), alignment: .bottom)

                TabView(selection: $selectedTab) {
                    panelSettingsTab.tag(0)
                    transactionTab.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Theme.Color.bg)
            .navigationTitle(isNew ? "\(shopType.label)を作成" : "\(shopType.label)を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }
                    .foregroundStyle(Theme.Color.textSecondary)
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
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
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
                    FormSection("エラー", icon: "exclamationmark.triangle") {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Color.statusWarn)
                            .font(Theme.Font.caption)
                    }
                }

                bottomPad
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Color.bg)
    }

    private var enabledToggleSection: some View {
        FormSection("有効/無効", icon: "power") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("\(shopType.label)を有効にする")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Toggle("", isOn: $enabled)
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                }
                if !enabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("無効時メッセージ")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                        TextEditor(text: $disabledMessage)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                    }
                }
            }
        }
    }

    private var appearanceSection: some View {
        FormSection("パネルの見た目", icon: "paintbrush") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    HStack(spacing: 3) {
                        Text("名前")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("*")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                    Spacer()
                    TextField(shopType.label, text: $name)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                    .background(Theme.Color.line)
                VStack(alignment: .leading, spacing: 6) {
                    Text("説明")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                    TextEditor(text: $description)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                }
                Divider()
                    .background(Theme.Color.line)
                HStack {
                    Text("カラー")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(colorPresets, id: \.self) { hex in
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: UIColor(hex: hex)))
                                    .frame(width: 26, height: 26)
                                if colorHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.Color.accentInk)
                                }
                            }
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { colorHex = hex } }
                        }
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        FormSection("プレビュー", icon: "eye") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(previewColor)
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if !name.isEmpty {
                            Text(name)
                                .font(Theme.Font.body)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.Color.textPrimary)
                        }
                        if !description.isEmpty {
                            Text(description)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        Divider()
                            .padding(.vertical, 4)
                        Text(footerText.isEmpty ? "フッターなし" : footerText)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    .padding(.leading, 10)
                    .padding(.vertical, 10)
                    .padding(.trailing, 10)
                }
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))

                HStack(spacing: 6) {
                    Text("商品を選択してください")
                        .font(Theme.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Color.accentInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(previewColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - サーバー設定

    private var serverSettingsSection: some View {
        FormSection("Discordサーバー設定", icon: "server.rack") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if isLoading {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                } else {
                    serverSettingRow(
                        icon: "shield.lefthalf.filled",
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
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(supportRoleId.isEmpty ? Theme.Color.textTertiary : Theme.Color.textSecondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.Color.textTertiary)
                            }
                        }
                    }
                    Divider()
                        .background(Theme.Color.line)

                    serverSettingRow(
                        icon: "folder.badge.plus",
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
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(orderCategoryId.isEmpty ? Theme.Color.textTertiary : Theme.Color.textSecondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.Color.textTertiary)
                            }
                        }
                    }
                    Divider()
                        .background(Theme.Color.line)

                    serverSettingRow(
                        icon: "archivebox",
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
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(archiveCategoryId.isEmpty ? Theme.Color.textTertiary : Theme.Color.textSecondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.Color.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func serverSettingRow<T: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Theme.Color.accentDim)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Color.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(subtitle)
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 2)
    }

    private var paymentInputLabelSection: some View {
        FormSection("支払い入力設定", icon: "creditcard") {
            VStack(alignment: .leading, spacing: 6) {
                Text("支払い入力欄の案内文")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                TextEditor(text: $paymentInputLabel)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - 自動削除

    private var autoDeleteSection: some View {
        FormSection("チケットの自動削除", icon: "trash") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("取引完了後に自動削除する")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Toggle("", isOn: $autoDeleteEnabled.animation())
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                }
                if autoDeleteEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("削除するまでの日数")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
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
                                            ? Theme.Color.accent
                                            : Theme.Color.surfaceRaised
                                    )
                                    .foregroundStyle(autoDeleteDays == days ? Theme.Color.accentInk : Theme.Color.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.button)
                                            .stroke(autoDeleteDays == days ? Theme.Color.accent : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var timeoutSection: some View {
        FormSection("注文タイムアウト", icon: "timer") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("タイムアウトを有効にする")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Toggle("", isOn: $timeoutEnabled)
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                }
                if timeoutEnabled {
                    Stepper("タイムアウト：\(timeoutHours ?? 24)時間", value: Binding(
                        get: { timeoutHours ?? 24 },
                        set: { timeoutHours = max(1, $0) }
                    ), in: 1...168)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                }
            }
        }
    }

    private var footerSection: some View {
        FormSection("フッター", icon: "text.bubble") {
            VStack(alignment: .leading, spacing: 6) {
                Text("フッターテキスト")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                TextEditor(text: $footerText)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - 取引

    private var transactionTab: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if shopType == .shop {
                    reviewSection
                }
                welcomeEmbedSection
                welcomePreviewSection
                welcomeFieldsSection
                welcomeFooterSection

                if let err = errorMessage {
                    FormSection("エラー", icon: "exclamationmark.triangle") {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Color.statusWarn)
                            .font(Theme.Font.caption)
                    }
                }

                bottomPad
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Color.bg)
    }

    // MARK: - レビュー設定

    private var reviewSection: some View {
        FormSection("レビュー設定", icon: "star") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("レビュー機能を有効にする")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Toggle("", isOn: $reviewEnabled.animation())
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                }
                if reviewEnabled {
                    if isLoading {
                        HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                    } else {
                        serverSettingRow(
                            icon: "bell",
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
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(reviewChannelId.isEmpty ? Theme.Color.textTertiary : Theme.Color.textSecondary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Theme.Color.textTertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var welcomeEmbedSection: some View {
        FormSection("ウェルカムメッセージ", icon: "envelope") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("画像URL")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    TextField("https://...", text: $welcomeImageUrl)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                    .background(Theme.Color.line)
                HStack {
                    Text("サムネイルURL")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    TextField("https://...", text: $welcomeThumbnailUrl)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                    .background(Theme.Color.line)
                HStack {
                    Text("タイムスタンプを表示")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Toggle("", isOn: $welcomeShowTimestamp)
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                }
            }
        }
    }

    private var welcomePreviewSection: some View {
        FormSection("プレビュー", icon: "eye") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(previewColor)
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if !name.isEmpty {
                            Text(name)
                                .font(Theme.Font.body)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.Color.textPrimary)
                        }
                        if !description.isEmpty {
                            Text(description)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        if !welcomeFields.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                            ForEach(welcomeFields) { field in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(field.name)
                                        .font(Theme.Font.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Text(field.value)
                                        .font(Theme.Font.caption2)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                }
                            }
                        }
                        Divider()
                            .padding(.vertical, 4)
                        Text(welcomeFooterText.isEmpty ? (footerText.isEmpty ? "フッターなし" : footerText) : welcomeFooterText)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    .padding(.leading, 10)
                    .padding(.vertical, 10)
                    .padding(.trailing, 10)
                }
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .padding(.vertical, 4)
        }
    }

    private var welcomeFieldsSection: some View {
        FormSection("フィールド", icon: "list.bullet") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(welcomeFields.enumerated()), id: \.element.id) { idx, field in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("フィールド \(idx + 1)")
                                .font(Theme.Font.caption2)
                                .fontWeight(.semibold)
                            Spacer()
                            Button("削除") {
                                var updated = welcomeFields
                                updated.remove(at: idx)
                                withAnimation { welcomeFields = updated }
                            }
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.statusBad)
                        }
                        TextField("名前", text: Binding(
                            get: { field.name },
                            set: { welcomeFields[idx].name = $0 }
                        ))
                        .font(Theme.Font.body)
                        TextField("値", text: Binding(
                            get: { field.value },
                            set: { welcomeFields[idx].value = $0 }
                        ))
                        .font(Theme.Font.body)
                        HStack {
                            Text("インライン")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { field.inline },
                                set: { welcomeFields[idx].inline = $0 }
                            ))
                            .tint(Theme.Color.accent)
                            .labelsHidden()
                        }
                    }
                    .padding(Theme.Spacing.xs)
                    .background(Theme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                Button(action: {
                    let newField = EmbedFieldModel(id: UUID().uuidString, name: "", value: "", inline: false)
                    withAnimation { welcomeFields.append(newField) }
                }) {
                    Label("フィールドを追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
    }

    private var welcomeFooterSection: some View {
        FormSection("ウェルカムフッター", icon: "text.bubble") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("フッターテキスト")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    TextField("パネルフッターと同じ", text: $welcomeFooterText)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                    .background(Theme.Color.line)
                HStack {
                    Text("フッターアイコンURL")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    TextField("https://...", text: $welcomeFooterIconUrl)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
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

#Preview("Dark") {
    NavigationStack { ShopEditView(guildId: "", shopType: .shop) { _ in } }
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { ShopEditView(guildId: "", shopType: .shop) { _ in } }
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.light)
}
