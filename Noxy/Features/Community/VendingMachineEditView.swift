import SwiftUI
import PhotosUI

// MARK: - VendingMachineEditView

struct VendingMachineEditView: View {
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
        _enabled = State(initialValue: existingShop?.enabled ?? true)
    }

    // 基本
    @State private var enabled: Bool
    @State private var disabledMessage = "この自販機は現在準備中です。もうしばらくお待ちください。"

    // パネルEmbed
    @State private var panelTitle = "自販機"
    @State private var panelDescription = "商品を選択し、支払い情報を送信してください。"
    @State private var panelColorHex: UInt32 = 0x10b981

    // チャンネル設定
    @State private var supportRoleId = ""
    @State private var orderCategoryId = ""
    @State private var archiveCategoryId = ""

    // 支払い入力
    @State private var paymentInputLabel = "PayPayの受け取りURLを入力してください"

    // 自動削除
    @State private var autoDeleteEnabled = false
    @State private var autoDeleteDays: Int = 7

    // 取引Embed（ウェルカムメッセージ）
    @State private var welcomeDescription = "支払いが確認できるまでお待ちください。確認でき次第、商品をお渡しします。"
    @State private var welcomeColorHex: UInt32 = 0x10b981
    @State private var welcomeImageUrl = ""
    @State private var welcomeThumbnailUrl = ""
    @State private var welcomeFields: [EmbedFieldModel] = []
    @State private var welcomeShowTimestamp = true

    // Discord data
    @State private var roles: [DiscordRole] = []
    @State private var categories: [(id: String, name: String)] = []

    // UI state
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showDiscardAlert = false
    @State private var showPanelColorPicker = false
    @State private var showWelcomeColorPicker = false
    @State private var keyboardHeight: CGFloat = 0

    // Focus
    @FocusState private var focusedField: FieldFocus?

    enum FieldFocus: Hashable {
        case panelTitle, panelDescription
        case paymentLabel
        case welcomeDescription
        case welcomeFieldName(String), welcomeFieldValue(String)
    }

    private let autoDeleteOptions: [(label: String, days: Int)] = [
        ("1日", 1), ("2日", 2), ("3日", 3), ("5日", 5),
        ("7日（1週間）", 7), ("14日（2週間）", 14), ("30日（1か月）", 30)
    ]

    private var isNew: Bool { existingShop == nil }
    private var panelAccent: Color { Color(uiColor: UIColor(hex: panelColorHex)) }
    private var welcomeAccent: Color { Color(uiColor: UIColor(hex: welcomeColorHex)) }

    private var hasChanges: Bool { true }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("タブ", selection: $selectedTab) {
                    Text("パネル設定").tag(0)
                    Text("取引").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Color.surface)
                .overlay(Divider().background(Theme.Color.line), alignment: .bottom)

                TabView(selection: $selectedTab) {
                    panelTab.tag(0)
                    transactionTab.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(isNew ? "自販機を作成" : "自販機を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }
                    .foregroundStyle(Theme.Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(panelTitle.isEmpty ? Theme.Color.textTertiary : Theme.Color.accent)
                        .disabled(panelTitle.isEmpty || isSaving)
                }
                keyboardToolbar
            }
            .background(Theme.Color.bg)
            .task { await loadData() }
            .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
                Button("破棄する", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("行った変更は保存されません。")
            }
            .sheet(isPresented: $showPanelColorPicker) {
                ColorPickerSheet(selectedHex: $panelColorHex)
            }
            .sheet(isPresented: $showWelcomeColorPicker) {
                ColorPickerSheet(selectedHex: $welcomeColorHex)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
                if let rect = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = rect.height }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
            }
        }
    }

    // MARK: - Keyboard Toolbar

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("完了") { focusedField = nil }
                .font(Theme.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.accent)
        }
    }

    // MARK: - パネル設定タブ

    private var panelTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.md) {
                enabledSection
                panelEmbedEditor
                channelSettingsCard
                paymentModalPreview
                autoDeleteCard

                if let err = errorMessage {
                    FormSection("エラー", icon: "exclamationmark.triangle") {
                        Text(err)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                }

                bottomPad
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 16 : 80)
        }
        .background(Theme.Color.bg)
    }

    // MARK: - 有効・無効

    private var enabledSection: some View {
        FormSection("有効 / 無効", icon: "power") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if !enabled {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Color.statusWarn)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("この自販機は現在無効です")
                                .font(Theme.Font.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Color.statusWarn)
                            Text("Discordのパネルで商品を選択できない状態です")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Color.statusWarn.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }

                HStack {
                    Text("自販機を有効にする")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Toggle("", isOn: $enabled.animation())
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                }

                if !enabled {
                    Divider()
                        .background(Theme.Color.line)
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

    // MARK: - パネルEmbed インライン編集

    private var panelEmbedEditor: some View {
        FormSection("パネルの見た目", icon: "paintbrush") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.Color.accentDim)
                            .frame(width: 38, height: 38)
                        Image(systemName: "storefront")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Color.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Noxy")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.Color.accent)
                            Text("BOT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.Color.accentInk)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Theme.Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        HStack(alignment: .top, spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(panelAccent)
                                .frame(width: 4)
                                .onTapGesture { showPanelColorPicker = true }
                                .accessibilityLabel("Embedカラーを変更")

                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                TextField("タイトル", text: $panelTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(panelAccent)
                                    .textFieldStyle(.plain)
                                    .focused($focusedField, equals: .panelTitle)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .embedDashedBorder(focused: focusedField == .panelTitle)

                                ZStack(alignment: .topLeading) {
                                    if panelDescription.isEmpty {
                                        Text("説明")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.Color.textTertiary)
                                            .padding(.top, 8)
                                            .padding(.leading, 6)
                                            .allowsHitTesting(false)
                                    }
                                    TextEditor(text: $panelDescription)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.Color.textSecondary)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 60, maxHeight: .infinity)
                                        .focused($focusedField, equals: .panelDescription)
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 2)
                                .embedDashedBorder(focused: focusedField == .panelDescription)
                            }
                            .padding(Theme.Spacing.sm)
                        }
                        .background(Theme.Color.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "photo")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Color.textTertiary)
                    TextField("画像URL（任意）", text: $welcomeImageUrl)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.Color.line, lineWidth: 1)
                )

                Text("左のカラーバーをタップするとカラーを変更できます")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .padding(.horizontal, 4)

                HStack(spacing: 3) {
                    Text("*")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Color.statusBad)
                    Text("タイトルは必須項目です")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 通知チャンネル

    private var channelSettingsCard: some View {
        FormSection("通知チャンネルの設定", icon: "server.rack") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if isLoading {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                        .padding(Theme.Spacing.md)
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
                            menuLabel(
                                roles.first(where: { $0.id == supportRoleId }).map { "@\($0.name)" } ?? "なし",
                                isEmpty: supportRoleId.isEmpty
                            )
                        }
                    }
                    Divider()
                        .background(Theme.Color.line)
                        .padding(.leading, 56)
                    serverSettingRow(
                        icon: "folder.badge.plus",
                        title: "注文カテゴリ",
                        subtitle: "チケットチャンネルを作成する場所"
                    ) {
                        Menu {
                            Button("なし（デフォルト）") { orderCategoryId = "" }
                            Divider()
                            ForEach(categories, id: \.id) { cat in
                                Button(cat.name) { orderCategoryId = cat.id }
                            }
                        } label: {
                            menuLabel(
                                categories.first(where: { $0.id == orderCategoryId })?.name ?? "なし",
                                isEmpty: orderCategoryId.isEmpty
                            )
                        }
                    }
                    Divider()
                        .background(Theme.Color.line)
                        .padding(.leading, 56)
                    serverSettingRow(
                        icon: "archivebox",
                        title: "アーカイブカテゴリ",
                        subtitle: "完了後に移動する場所"
                    ) {
                        Menu {
                            Button("なし（そのまま）") { archiveCategoryId = "" }
                            Divider()
                            ForEach(categories, id: \.id) { cat in
                                Button(cat.name) { archiveCategoryId = cat.id }
                            }
                        } label: {
                            menuLabel(
                                categories.first(where: { $0.id == archiveCategoryId })?.name ?? "なし",
                                isEmpty: archiveCategoryId.isEmpty
                            )
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
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.sm)
    }

    private func menuLabel(_ text: String, isEmpty: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(Theme.Font.caption)
                .foregroundStyle(isEmpty ? Theme.Color.textTertiary : Theme.Color.textSecondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Color.textTertiary)
        }
    }

    // MARK: - 支払い入力設定

    private var paymentModalPreview: some View {
        FormSection("支払い入力設定", icon: "creditcard") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(spacing: 0) {
                    HStack {
                        Text("購入手続き")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Color.textPrimary)
                        Spacer()
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)

                    Divider()
                        .background(Theme.Color.line)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        TextField("案内文を入力...", text: $paymentInputLabel, axis: .vertical)
                            .lineLimit(1...3)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Color.textPrimary)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .paymentLabel)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .embedDashedBorder(focused: focusedField == .paymentLabel)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Color.surfaceRaised)
                            .frame(height: 40)
                            .overlay(
                                Text("入力してください...")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Color.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Theme.Color.line, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)

                    Divider()
                        .background(Theme.Color.line)

                    HStack(spacing: Theme.Spacing.xs) {
                        Spacer()
                        Text("キャンセル")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        Text("送信")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Color.accentInk)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.Color.line, lineWidth: 1)
                )

                Text("購入者が商品を選択したときに表示されるモーダルです。案内文をタップして直接編集できます。")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 自動削除

    private var autoDeleteCard: some View {
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
                    Divider()
                        .background(Theme.Color.line)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("削除するまでの日数")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                            spacing: 8
                        ) {
                            ForEach(autoDeleteOptions, id: \.days) { opt in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) { autoDeleteDays = opt.days }
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(opt.days)")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("日")
                                            .font(.system(size: 10))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(autoDeleteDays == opt.days ? Theme.Color.accent : Theme.Color.surfaceRaised)
                                    .foregroundStyle(autoDeleteDays == opt.days ? Theme.Color.accentInk : Theme.Color.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.button)
                                            .stroke(autoDeleteDays == opt.days ? Theme.Color.accent : Color.clear, lineWidth: 1.5)
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

    // MARK: - 取引タブ

    private var transactionTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.md) {
                SectionLabel(title: "ウェルカムメッセージ")
                    .padding(.horizontal, 4)

                welcomeEmbedEditor

                if let err = errorMessage {
                    FormSection("エラー", icon: "exclamationmark.triangle") {
                        Text(err)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                }

                bottomPad
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 16 : 80)
        }
        .background(Theme.Color.bg)
    }

    private var welcomeEmbedEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.Color.accentDim)
                        .frame(width: 38, height: 38)
                    Image(systemName: "storefront")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Noxy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Color.accent)
                        Text("BOT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.Color.accentInk)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("今日 ") + Text(Date(), style: .time)
                    }
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)

                    HStack(alignment: .top, spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(welcomeAccent)
                            .frame(width: 4)
                            .onTapGesture { showWelcomeColorPicker = true }
                            .accessibilityLabel("Embedカラーを変更")

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            ZStack(alignment: .topLeading) {
                                if welcomeDescription.isEmpty {
                                    Text("メッセージを入力...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.Color.textTertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 6)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $welcomeDescription)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Color.textSecondary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 70, maxHeight: .infinity)
                                    .focused($focusedField, equals: .welcomeDescription)
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                            .embedDashedBorder(focused: focusedField == .welcomeDescription)

                            welcomeFieldsEditor
                        }
                        .padding(Theme.Spacing.sm)
                    }
                    .background(Theme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))

            Text("左のカラーバーをタップするとカラーを変更できます")
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    private var welcomeFieldsEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(welcomeFields) { field in
                welcomeFieldEditor(for: field)
            }

            if welcomeFields.count < 25 {
                Button {
                    let f = EmbedFieldModel(id: UUID().uuidString, name: "", value: "", inline: false)
                    withAnimation { welcomeFields.append(f) }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("フィールドを追加").font(Theme.Font.caption)
                    }
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func welcomeFieldEditor(for field: EmbedFieldModel) -> some View {
        let fieldId = field.id
        let nameBinding = Binding<String>(
            get: { welcomeFields.first(where: { $0.id == fieldId })?.name ?? "" },
            set: { v in if let i = welcomeFields.firstIndex(where: { $0.id == fieldId }) { welcomeFields[i].name = v } }
        )
        let valueBinding = Binding<String>(
            get: { welcomeFields.first(where: { $0.id == fieldId })?.value ?? "" },
            set: { v in if let i = welcomeFields.firstIndex(where: { $0.id == fieldId }) { welcomeFields[i].value = v } }
        )

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                TextField("名前", text: nameBinding)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Color.textTertiary)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .welcomeFieldName(fieldId))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .embedDashedBorder(focused: focusedField == .welcomeFieldName(fieldId))
                Spacer()
                Button {
                    withAnimation { welcomeFields.removeAll { $0.id == fieldId } }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Color.statusBad)
                }
            }
            TextField("値", text: valueBinding)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .welcomeFieldValue(fieldId))
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .embedDashedBorder(focused: focusedField == .welcomeFieldValue(fieldId))
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .id("wf-\(fieldId)")
    }

    // MARK: - Load & Save

    private func loadData() async {
        isLoading = true

        struct RawCh: Decodable { let id: String; let name: String; let type: Int }
        if let chs = try? await WorkerClient().get("/bot/channels?guild_id=\(guildId)") as [RawCh] {
            categories = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
        }
        roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []

        if let s = existingShop {
            enabled = s.enabled
            disabledMessage = s.disabledMessage ?? "この自販機は現在準備中です。もうしばらくお待ちください。"
            panelTitle = s.name
            panelDescription = s.description
            panelColorHex = UInt32(s.color)
            supportRoleId = s.supportRoleId ?? ""
            orderCategoryId = s.orderCategoryId ?? ""
            archiveCategoryId = s.archiveCategoryId ?? ""
            paymentInputLabel = s.paymentInputLabel ?? "PayPayの受け取りURLを入力してください"
            autoDeleteEnabled = s.autoDeleteEnabled
            autoDeleteDays = s.autoDeleteDays ?? 7
            welcomeColorHex = UInt32(s.color)
            let newDefault = "支払いが確認できるまでお待ちください。確認でき次第、商品をお渡しします。"
            let oldDefaults: Set<String> = [
                "商品を選択し、支払い情報を送信してください。",
                "商品を選択し、支払い情報を送信してください",
            ]
            let loaded = s.welcomeFields.first(where: { $0.name == "__desc__" })?.value
                ?? s.welcomeFooterText
            welcomeDescription = (loaded == nil || oldDefaults.contains(loaded!)) ? newDefault : loaded!
            welcomeFields = s.welcomeFields.filter { $0.name != "__desc__" }
            welcomeImageUrl = s.welcomeImageUrl ?? ""
            welcomeThumbnailUrl = s.welcomeThumbnailUrl ?? ""
            welcomeShowTimestamp = s.welcomeShowTimestamp
        }

        isLoading = false
    }

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var shop = existingShop ?? Shop.blank(guildId: guildId, shopType: .vendingMachine)
            shop.enabled = enabled
            shop.disabledMessage = disabledMessage.isEmpty ? nil : disabledMessage
            shop.name = panelTitle
            shop.description = panelDescription
            shop.color = Int(panelColorHex)
            shop.supportRoleId = supportRoleId.isEmpty ? nil : supportRoleId
            shop.orderCategoryId = orderCategoryId.isEmpty ? nil : orderCategoryId
            shop.archiveCategoryId = archiveCategoryId.isEmpty ? nil : archiveCategoryId
            shop.paymentInputLabel = paymentInputLabel.isEmpty ? nil : paymentInputLabel
            shop.autoDeleteEnabled = autoDeleteEnabled
            shop.autoDeleteDays = autoDeleteEnabled ? autoDeleteDays : nil
            shop.footerText = ""
            shop.reviewEnabled = false
            shop.welcomeImageUrl = welcomeImageUrl.isEmpty ? nil : welcomeImageUrl
            shop.welcomeThumbnailUrl = welcomeThumbnailUrl.isEmpty ? nil : welcomeThumbnailUrl
            shop.welcomeFields = welcomeFields
            shop.welcomeShowTimestamp = welcomeShowTimestamp
            shop.welcomeFooterText = welcomeDescription.isEmpty ? nil : welcomeDescription
            shop.welcomeFooterIconUrl = nil

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
    NavigationStack { VendingMachineEditView(guildId: "") { _ in } }
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { VendingMachineEditView(guildId: "") { _ in } }
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.light)
}
