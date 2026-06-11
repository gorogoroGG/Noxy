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
        // チラツキ防止：既存ショップの enabled を初期値として使う
        _enabled = State(initialValue: existingShop?.enabled ?? true)
    }

    // ── 基本 ──
    @State private var enabled: Bool
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
    @State private var welcomeDescription = "支払いが確認できるまでお待ちください。確認でき次第、商品をお渡しします。"
    @State private var welcomeColorHex: UInt32 = 0x10b981
    @State private var welcomeImageUrl = ""
    @State private var welcomeThumbnailUrl = ""
    @State private var welcomeFields: [EmbedFieldModel] = []
    @State private var welcomeShowTimestamp = true

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
                // ── タブ ──
                Picker("タブ", selection: $selectedTab) {
                    Text("パネル設定").tag(0)
                    Text("取引").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(Divider(), alignment: .bottom)

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
                    }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(panelTitle.isEmpty ? Color.textTertiary : Color.accentGreen)
                        .disabled(panelTitle.isEmpty || isSaving)
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

            if !enabled {
                HStack(spacing: .spacing10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16)).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("この自販機は現在無効です")
                            .font(.bodySmall).fontWeight(.semibold).foregroundStyle(.orange)
                        Text("Discordのパネルで商品を選択できない状態です")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                }
                .padding(.spacing12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }

            VStack(spacing: 0) {
                Toggle("自販機を有効にする", isOn: $enabled.animation())
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

            // 画像URL入力
            VStack(spacing: 0) {
                HStack(spacing: .spacing10) {
                    Image(systemName: "photo").font(.system(size: 13)).foregroundStyle(Color.textTertiary)
                    TextField("画像URL（任意）", text: $welcomeImageUrl)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textPrimary)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                .padding(.spacing12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

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
                    // サポートロール
                    serverSettingRow(
                        icon: "shield.lefthalf.filled", iconColor: .accentIndigo,
                        title: "サポートロール", subtitle: "注文チャンネルに追加するロール"
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
                                accent: .accentIndigo, isEmpty: supportRoleId.isEmpty
                            )
                        }
                    }
                    Divider().padding(.leading, 56)
                    // 注文カテゴリ
                    serverSettingRow(
                        icon: "folder.badge.plus", iconColor: .accentGreen,
                        title: "注文カテゴリ", subtitle: "チケットチャンネルを作成する場所"
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
                                accent: .accentGreen, isEmpty: orderCategoryId.isEmpty
                            )
                        }
                    }
                    Divider().padding(.leading, 56)
                    // アーカイブカテゴリ
                    serverSettingRow(
                        icon: "archivebox.fill", iconColor: .accentOrange,
                        title: "アーカイブカテゴリ", subtitle: "完了後に移動する場所"
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
                                accent: .accentOrange, isEmpty: archiveCategoryId.isEmpty
                            )
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("注文チャンネルの作成・アーカイブ先カテゴリと、チャンネルに追加するサポートロールを設定します。")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func serverSettingRow<T: View>(
        icon: String, iconColor: Color, title: String, subtitle: String,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(iconColor.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, .spacing12)
        .padding(.horizontal, .spacing12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func menuLabel(_ text: String, accent: Color, isEmpty: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.captionRegular)
                .foregroundStyle(isEmpty ? Color.textTertiary : accent)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
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
                Toggle("取引完了後に自動削除する", isOn: $autoDeleteEnabled.animation())
                    .padding(.spacing12)
                    .background(Color(.secondarySystemGroupedBackground))

                if autoDeleteEnabled {
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("削除するまでの日数")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                            spacing: 8
                        ) {
                            ForEach(autoDeleteOptions, id: \.days) { opt in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) { autoDeleteDays = opt.days }
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(opt.days)").font(.system(size: 16, weight: .bold))
                                        Text("日").font(.system(size: 10))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(autoDeleteDays == opt.days ? Color.accentGreen : Color(.tertiarySystemGroupedBackground))
                                    .foregroundStyle(autoDeleteDays == opt.days ? .white : Color.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(autoDeleteDays == opt.days ? Color.accentGreen : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(.spacing12)
                    .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(autoDeleteEnabled
                 ? "取引完了から \(autoDeleteDays) 日後にチケットチャンネルが自動削除されます。取引開始時・完了時にチャンネル内へ削除予定日が通知されます。"
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
            let newDefault = "支払いが確認できるまでお待ちください。確認でき次第、商品をお渡しします。"
            let oldDefaults: Set<String> = [
                "商品を選択し、支払い情報を送信してください。",
                "商品を選択し、支払い情報を送信してください",
            ]
            let loaded = s.welcomeFields.first(where: { $0.name == "__desc__" })?.value
                ?? s.welcomeFooterText
            welcomeDescription = (loaded == nil || oldDefaults.contains(loaded!)) ? newDefault : loaded!
            // 既存フィールドから __desc__ 以外を取得
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

}
