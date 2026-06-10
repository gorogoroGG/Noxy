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
    }

    // ── 基本 ──
    @State private var enabled = true
    @State private var disabledMessage = "この自販機は現在準備中です。もうしばらくお待ちください。"

    // ── パネルEmbed ──
    @State private var panelTitle = "自販機"
    @State private var panelDescription = "商品を選択し、支払い情報を送信してください。"
    @State private var panelColorHex: UInt32 = 0x10b981

    // ── チャンネル設定 ──
    @State private var supportRoleId = ""
    @State private var orderCategoryId = ""
    @State private var archiveCategoryId = ""

    // ── 支払い入力 ──
    @State private var paymentInputLabel = "PayPayの受け取りURLを入力してください"

    // ── 自動削除 ──
    @State private var autoDeleteEnabled = false
    @State private var autoDeleteDays: Int = 7

    // ── 取引Embed（ウェルカムメッセージ） ──
    @State private var welcomeDescription = "販売者が支払いを確認するのをお待ちください。確認でき次第、商品が引き渡されます。"
    @State private var welcomeColorHex: UInt32 = 0x10b981
    @State private var welcomeImageUrl = ""
    @State private var welcomeThumbnailUrl = ""
    @State private var welcomeFields: [EmbedFieldModel] = []
    @State private var welcomeShowTimestamp = true

    // ── 商品 ──
    @State private var products: [Product] = []
    @State private var showCreateProduct = false
    @State private var editingProduct: Product? = nil

    // ── Discord data ──
    @State private var roles: [DiscordRole] = []
    @State private var categories: [(id: String, name: String)] = []

    // ── UI state ──
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showDiscardAlert = false
    @State private var showPanelColorPicker = false
    @State private var showWelcomeColorPicker = false
    @State private var keyboardHeight: CGFloat = 0

    // ── Focus ──
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
                // ── ツールバー ──
                HStack {
                    Button("キャンセル") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }.foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(panelTitle.isEmpty ? Color.textTertiary : Color.accentGreen)
                        .disabled(panelTitle.isEmpty || isSaving)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(Divider(), alignment: .bottom)

                // ── タブ ──
                Picker("タブ", selection: $selectedTab) {
                    Text("パネル設定").tag(0)
                    Text("取引").tag(1)
                    Text("商品").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(Divider(), alignment: .bottom)

                TabView(selection: $selectedTab) {
                    panelTab.tag(0)
                    transactionTab.tag(1)
                    productsTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(isNew ? "自販機を作成" : "自販機を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }.foregroundStyle(Color.textSecondary)
                }
                keyboardToolbar
            }
            .background(Color(.systemGroupedBackground))
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
                .font(.captionRegular).fontWeight(.semibold)
        }
    }

    // MARK: - パネル設定タブ

    private var panelTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: .spacing16) {

                // 1. 有効・無効
                enabledSection

                // 2. パネルの見た目（Discord Embed 風インライン編集）
                panelEmbedEditor

                // 3. 通知チャンネルの設定
                channelSettingsCard

                // 4. 支払い入力設定（Discord モーダル風）
                paymentModalPreview

                // 5. 自動削除
                autoDeleteCard

                if let err = errorMessage {
                    Text(err)
                        .font(.captionRegular).foregroundStyle(.red)
                        .padding(.horizontal, .spacing16)
                }
            }
            .padding(.spacing16)
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 16 : 80)
        }
        .background(Color(.systemGroupedBackground))
    }

    // ── 有効・無効 ──

    private var enabledSection: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            sectionHeader("有効 / 無効")

            VStack(spacing: 0) {
                Toggle("自販機を有効にする", isOn: $enabled)
                    .padding(.spacing12)
                    .background(Color(.secondarySystemGroupedBackground))

                if !enabled {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("無効時メッセージ").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        TextEditor(text: $disabledMessage)
                            .frame(minHeight: 60).scrollContentBackground(.hidden)
                    }
                    .padding(.spacing12)
                    .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // ── パネルEmbed インライン編集 ──

    private var panelEmbedEditor: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            sectionHeader("パネルの見た目")

            // Discord メッセージ風コンテナ
            HStack(alignment: .top, spacing: 10) {
                // Bot アバター
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentGreen, Color.accentIndigo],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Bot 名
                    HStack(spacing: 6) {
                        Text("Noxy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentGreen)
                        Text("BOT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    // Embed ブロック
                    HStack(alignment: .top, spacing: 0) {
                        // カラーバー（タップで変更）
                        RoundedRectangle(cornerRadius: 2)
                            .fill(panelAccent)
                            .frame(width: 4)
                            .onTapGesture { showPanelColorPicker = true }
                            .accessibilityLabel("Embedカラーを変更")

                        VStack(alignment: .leading, spacing: .spacing8) {
                            // タイトル
                            TextField("タイトル", text: $panelTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(panelAccent)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .panelTitle)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .embedDashedBorder(focused: focusedField == .panelTitle)

                            // 説明
                            ZStack(alignment: .topLeading) {
                                if panelDescription.isEmpty {
                                    Text("説明")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textTertiary)
                                        .padding(.top, 8).padding(.leading, 6)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $panelDescription)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 60, maxHeight: .infinity)
                                    .focused($focusedField, equals: .panelDescription)
                            }
                            .padding(.horizontal, 2).padding(.vertical, 2)
                            .embedDashedBorder(focused: focusedField == .panelDescription)
                        }
                        .padding(.spacing10)
                    }
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.spacing12)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("左のカラーバーをタップするとカラーを変更できます")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    // ── 通知チャンネル ──

    private var channelSettingsCard: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            sectionHeader("通知チャンネルの設定")

            VStack(spacing: 0) {
                if isLoading {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                        .padding(.spacing16)
                        .background(Color(.secondarySystemGroupedBackground))
                } else {
                    Group {
                        pickerRow(
                            label: "サポートロール",
                            selection: $supportRoleId,
                            noneLabel: "なし",
                            options: roles.filter { !$0.managed && $0.name != "@everyone" }
                                .map { ($0.id, "@\($0.name)") }
                        )
                        Divider()
                        pickerRow(
                            label: "注文カテゴリ",
                            selection: $orderCategoryId,
                            noneLabel: "なし（デフォルト）",
                            options: categories.map { ($0.id, $0.name) }
                        )
                        Divider()
                        pickerRow(
                            label: "アーカイブカテゴリ",
                            selection: $archiveCategoryId,
                            noneLabel: "なし（そのまま）",
                            options: categories.map { ($0.id, $0.name) }
                        )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("注文チャンネルの作成・アーカイブ先カテゴリと、チャンネルに追加するサポートロールを設定します。")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    private func pickerRow(label: String, selection: Binding<String>, noneLabel: String, options: [(id: String, name: String)]) -> some View {
        Picker(label, selection: selection) {
            Text(noneLabel).tag("")
            ForEach(options, id: \.id) { Text($0.name).tag($0.id) }
        }
        .padding(.horizontal, .spacing12)
        .padding(.vertical, .spacing4)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // ── 支払い入力設定（Discord モーダル風） ──

    private var paymentModalPreview: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            sectionHeader("支払い入力設定")

            // Discord モーダル風プレビュー
            VStack(spacing: 0) {
                // モーダルヘッダー
                HStack {
                    Text("購入手続き")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, .spacing16)
                .padding(.top, .spacing16)
                .padding(.bottom, .spacing12)

                Divider()

                // 入力ラベル（直接編集可能）
                VStack(alignment: .leading, spacing: .spacing6) {
                    TextField("案内文を入力...", text: $paymentInputLabel, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .paymentLabel)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .embedDashedBorder(focused: focusedField == .paymentLabel)

                    // モック入力欄
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.bgElevated)
                        .frame(height: 40)
                        .overlay(
                            Text("入力してください...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, .spacing16)
                .padding(.vertical, .spacing12)

                Divider()

                // モックボタン行
                HStack(spacing: .spacing8) {
                    Spacer()
                    Text("キャンセル")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    Text("送信")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, .spacing16)
                .padding(.vertical, .spacing12)
            }
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.textTertiary.opacity(0.15), lineWidth: 1)
            )

            Text("購入者が商品を選択したときに表示されるモーダルです。案内文をタップして直接編集できます。")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    // ── 自動削除 ──

    private var autoDeleteCard: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            sectionHeader("チケットの自動削除")

            VStack(spacing: 0) {
                Toggle("取引完了後に自動削除する", isOn: $autoDeleteEnabled)
                    .padding(.spacing12)
                    .background(Color(.secondarySystemGroupedBackground))

                if autoDeleteEnabled {
                    Divider()
                    Picker("削除までの日数", selection: $autoDeleteDays) {
                        ForEach(autoDeleteOptions, id: \.days) { opt in
                            Text(opt.label).tag(opt.days)
                        }
                    }
                    .padding(.horizontal, .spacing12)
                    .padding(.vertical, .spacing4)
                    .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(autoDeleteEnabled
                 ? "取引完了から\(autoDeleteDays)日後にチケットチャンネルが自動削除されます。取引開始時・完了時にチケット内で通知されます。"
                 : "有効にすると、取引完了から指定した日数が経過した時点でチケットが自動的に削除されます。")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - 取引タブ

    private var transactionTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: .spacing16) {
                sectionLabel("チケット作成時に自動送信されるウェルカムメッセージです。タップして直接編集できます。")

                welcomeEmbedEditor

                if let err = errorMessage {
                    Text(err)
                        .font(.captionRegular).foregroundStyle(.red)
                        .padding(.horizontal, .spacing16)
                }
            }
            .padding(.spacing16)
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 16 : 80)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var welcomeEmbedEditor: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            // Discord メッセージ風コンテナ
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentGreen, Color.accentIndigo],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Noxy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentGreen)
                        Text("BOT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("今日 ") + Text(Date(), style: .time)
                    }
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)

                    // Embed ブロック
                    HStack(alignment: .top, spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(welcomeAccent)
                            .frame(width: 4)
                            .onTapGesture { showWelcomeColorPicker = true }
                            .accessibilityLabel("Embedカラーを変更")

                        VStack(alignment: .leading, spacing: .spacing8) {
                            // 説明（本文）
                            ZStack(alignment: .topLeading) {
                                if welcomeDescription.isEmpty {
                                    Text("メッセージを入力...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textTertiary)
                                        .padding(.top, 8).padding(.leading, 6)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $welcomeDescription)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 70, maxHeight: .infinity)
                                    .focused($focusedField, equals: .welcomeDescription)
                            }
                            .padding(.horizontal, 2).padding(.vertical, 2)
                            .embedDashedBorder(focused: focusedField == .welcomeDescription)

                            // フィールド
                            welcomeFieldsEditor
                        }
                        .padding(.spacing10)
                    }
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.spacing12)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("左のカラーバーをタップするとカラーを変更できます")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    private var welcomeFieldsEditor: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            ForEach(welcomeFields) { field in
                welcomeFieldEditor(for: field)
            }

            if welcomeFields.count < 25 {
                Button {
                    let f = EmbedFieldModel(id: UUID().uuidString, name: "", value: "", inline: false)
                    withAnimation { welcomeFields.append(f) }
                } label: {
                    HStack(spacing: .spacing6) {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("フィールドを追加").font(.captionRegular)
                    }
                    .foregroundStyle(welcomeAccent)
                    .padding(.vertical, .spacing6)
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

        return VStack(alignment: .leading, spacing: .spacing4) {
            HStack(spacing: .spacing6) {
                TextField("名前", text: nameBinding)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .welcomeFieldName(fieldId))
                    .padding(.horizontal, 4).padding(.vertical, 3)
                    .embedDashedBorder(focused: focusedField == .welcomeFieldName(fieldId))
                Spacer()
                Button {
                    withAnimation { welcomeFields.removeAll { $0.id == fieldId } }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16)).foregroundStyle(.red)
                }
            }
            TextField("値", text: valueBinding)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .welcomeFieldValue(fieldId))
                .padding(.horizontal, 4).padding(.vertical, 3)
                .embedDashedBorder(focused: focusedField == .welcomeFieldValue(fieldId))
        }
        .padding(.spacing8)
        .background(Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .id("wf-\(fieldId)")
    }

    // MARK: - 商品タブ

    private var productsTab: some View {
        ZStack(alignment: .bottom) {
            List {
                if isNew {
                    VStack(spacing: .spacing12) {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 40)).foregroundStyle(Color.textTertiary)
                        Text("自販機を先に保存してください")
                            .font(.titleMedium).foregroundStyle(Color.textPrimary)
                        Text("自販機を保存した後、再度編集画面を開いて商品を追加できます。")
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
                    ForEach(Array(products.enumerated()), id: \.element.id) { idx, product in
                        VendingProductCard(product: product, index: idx, onEdit: { editingProduct = product })
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
                    .background(Color.accentGreen).clipShape(Capsule())
                    .shadow(color: Color.accentGreen.opacity(0.4), radius: 8, y: 4)
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

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.captionSmall).fontWeight(.semibold)
            .foregroundStyle(Color.textTertiary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.captionSmall).foregroundStyle(Color.textTertiary)
            .padding(.horizontal, 4)
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
            welcomeDescription = s.welcomeFields.first(where: { $0.name == "__desc__" })?.value
                ?? s.description
            // 既存フィールドから __desc__ 以外を取得
            welcomeFields = s.welcomeFields.filter { $0.name != "__desc__" }
            welcomeImageUrl = s.welcomeImageUrl ?? ""
            welcomeThumbnailUrl = s.welcomeThumbnailUrl ?? ""
            welcomeShowTimestamp = s.welcomeShowTimestamp
            products = (try? await services.shops.fetchProducts(shopId: s.id)) ?? []
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

            // welcomeDescription を footerText に格納せず、welcomeFooterText で持つ
            // ウェルカムメッセージ本文を welcomeFooterText に格納（Bot側で参照）
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

    private func updatePositions() async {
        for (index, var product) in products.enumerated() {
            product.position = index
            _ = try? await services.shops.updateProduct(product)
        }
    }
}

// MARK: - VendingProductCard

private struct VendingProductCard: View {
    let product: Product
    let index: Int
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                ZStack {
                    Circle()
                        .fill(product.enabled ? Color.accentGreen.opacity(0.15) : Color.gray.opacity(0.45))
                        .frame(width: 36, height: 36)
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(product.enabled ? Color.accentGreen : Color.textTertiary)
                }
                .opacity(product.enabled ? 1 : 0.6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.name)
                            .font(.bodySmall).fontWeight(.semibold)
                            .foregroundStyle(product.enabled ? Color.textPrimary : Color.textTertiary)
                        if product.isSoldOut {
                            Text("売り切れ")
                                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.red)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.red.opacity(0.12)).clipShape(Capsule())
                        }
                    }
                    Label(product.priceDisplay, systemImage: "tag.fill")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                }

                Spacer()

                Label(product.rewardType.label, systemImage: product.rewardType.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(product.enabled ? Color.accentGreen : Color.textTertiary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(product.enabled ? Color.accentGreen.opacity(0.12) : Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
            .padding(.spacing12)

            Divider().padding(.horizontal, .spacing12)

            Button(action: onEdit) {
                Label("編集", systemImage: "pencil")
                    .font(.captionRegular).fontWeight(.medium)
                    .foregroundStyle(Color.accentGreen)
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
