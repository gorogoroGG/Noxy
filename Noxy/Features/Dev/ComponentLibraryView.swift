// Available in DEBUG builds only
#if DEBUG

import SwiftUI
import PhotosUI
import UserNotifications

// MARK: - ComponentLibraryView（ナビゲーションリスト形式）

struct ComponentLibraryView: View {

    private struct CategoryItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
    }

    private let categories: [CategoryItem] = [
        CategoryItem(title: "セレクト系",  subtitle: "Picker / Chip / Radio / Dropdown",    icon: "checklist",                  color: .accentIndigo),
        CategoryItem(title: "Embed",       subtitle: "Discord風Embedプレビュー",             icon: "rectangle.on.rectangle",    color: .accentPurple),
        CategoryItem(title: "モーダル",    subtitle: "確認・入力・成功ダイアログ",            icon: "square.on.square.dashed",    color: .accentRed),
        CategoryItem(title: "タブ",        subtitle: "タブ切り替え・シート",                  icon: "rectangle.3.group",          color: .accentGreen),
        CategoryItem(title: "通知テスト",  subtitle: "各通知タイプを手動で送信",              icon: "bell.badge.fill",            color: .accentOrange),
    ]

    var body: some View {
        NavigationStack {
            List(categories) { cat in
                NavigationLink {
                    destinationView(for: cat.title)
                } label: {
                    HStack(spacing: .spacing12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(cat.color.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: cat.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(cat.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.title)
                                .font(.bodySmall).fontWeight(.semibold)
                                .foregroundStyle(Color.textPrimary)
                            Text(cat.subtitle)
                                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dev Components")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private func destinationView(for title: String) -> some View {
        switch title {
        case "セレクト系": SelectShowcase()
        case "Embed":      EmbedShowcase()
        case "モーダル":   ModalShowcase()
        case "タブ":       TabShowcase()
        case "通知テスト": NotificationTestView()
        default:           EmptyView()
        }
    }
}

// MARK: - ── 1. セレクト系 ──────────────────────────────────────────

private struct SelectShowcase: View {

    @State private var segSelected = 0
    @State private var chipSelected: Set<String> = ["音楽", "ゲーム"]
    private let chipOptions = ["音楽", "ゲーム", "アニメ", "スポーツ", "読書", "料理", "旅行", "映画"]
    @State private var radioSelected = "通知あり"
    private let radioOptions = ["通知あり", "通知なし", "重要のみ"]
    @State private var sheetValue = "未選択"
    @State private var showSheetPicker = false
    private let sheetOptions = ["ショップ", "自販機", "チケット", "ギブアウェイ", "ロール管理"]
    @State private var dropdownValue = "インディゴ"
    @State private var dropdownExpanded = false
    private let dropdownOptions: [(String, Color)] = [
        ("インディゴ", .accentIndigo), ("グリーン", .accentGreen),
        ("オレンジ", .accentOrange), ("パープル", .accentPurple),
        ("ピンク", .accentPink)
    ]

    @ViewBuilder
    private func radioRow(opt: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { radioSelected = opt } } label: {
            HStack(spacing: .spacing12) {
                ZStack {
                    Circle().stroke(radioSelected == opt ? Color.accentIndigo : Color.borderStrong, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if radioSelected == opt {
                        Circle().fill(Color.accentIndigo).frame(width: 10, height: 10)
                    }
                }
                Text(opt).font(.bodySmall).foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .padding(.spacing12)
            .background(radioSelected == opt ? Color.accentIndigo.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing24) {
                ShowcaseCard(title: "Segmented Picker", badge: "segmented") {
                    VStack(spacing: .spacing12) {
                        Picker("", selection: $segSelected) {
                            Text("ショップ").tag(0)
                            Text("自販機").tag(1)
                            Text("注文").tag(2)
                        }
                        .pickerStyle(.segmented)
                        Text("選択中: \(["ショップ","自販機","注文"][segSelected])")
                            .font(.captionRegular).foregroundStyle(Color.textTertiary)
                    }
                }

                ShowcaseCard(title: "Chip Multi Select", badge: "multi") {
                    VStack(alignment: .leading, spacing: .spacing12) {
                        FlowLayout(spacing: 8) {
                            ForEach(chipOptions, id: \.self) { opt in
                                ChipToggle(label: opt, isSelected: chipSelected.contains(opt)) {
                                    if chipSelected.contains(opt) { chipSelected.remove(opt) }
                                    else { chipSelected.insert(opt) }
                                }
                            }
                        }
                        if !chipSelected.isEmpty {
                            Text("選択中: \(chipSelected.sorted().joined(separator: "・"))")
                                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        }
                    }
                }

                ShowcaseCard(title: "Radio Single Select", badge: "single") {
                    VStack(spacing: 0) {
                        ForEach(Array(radioOptions.enumerated()), id: \.element) { idx, opt in
                            radioRow(opt: opt)
                            if idx < radioOptions.count - 1 { Divider().padding(.leading, 44) }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.border, lineWidth: 1))
                }

                ShowcaseCard(title: "Sheet Picker", badge: "sheet") {
                    Button { showSheetPicker = true } label: {
                        HStack {
                            Text(sheetValue)
                                .font(.bodySmall)
                                .foregroundStyle(sheetValue == "未選択" ? Color.textTertiary : Color.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
                        .background(Color.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .sheet(isPresented: $showSheetPicker) {
                    BottomSheetPickerContent(title: "機能を選択", options: sheetOptions, selected: sheetValue) { picked in
                        sheetValue = picked; showSheetPicker = false
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }

                ShowcaseCard(title: "Dropdown Select", badge: "dropdown") {
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dropdownExpanded.toggle() }
                        } label: {
                            HStack {
                                if let match = dropdownOptions.first(where: { $0.0 == dropdownValue }) {
                                    Circle().fill(match.1).frame(width: 10, height: 10)
                                }
                                Text(dropdownValue).font(.bodySmall).foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.textTertiary)
                                    .rotationEffect(.degrees(dropdownExpanded ? 180 : 0))
                            }
                            .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
                            .background(Color.bgElevated)
                            .clipShape(.rect(
                                topLeadingRadius: 12, bottomLeadingRadius: dropdownExpanded ? 0 : 12,
                                bottomTrailingRadius: dropdownExpanded ? 0 : 12, topTrailingRadius: 12))
                        }
                        .buttonStyle(.plain)

                        if dropdownExpanded {
                            VStack(spacing: 0) {
                                Divider()
                                ForEach(Array(dropdownOptions.enumerated()), id: \.element.0) { idx, opt in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            dropdownValue = opt.0; dropdownExpanded = false
                                        }
                                    } label: {
                                        HStack(spacing: .spacing10) {
                                            Circle().fill(opt.1).frame(width: 10, height: 10)
                                            Text(opt.0).font(.bodySmall).foregroundStyle(Color.textPrimary)
                                            Spacer()
                                            if dropdownValue == opt.0 {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.accentIndigo)
                                            }
                                        }
                                        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
                                        .background(dropdownValue == opt.0 ? Color.accentIndigo.opacity(0.06) : Color.bgElevated)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if idx < dropdownOptions.count - 1 { Divider().padding(.leading, 36) }
                                }
                            }
                            .clipShape(.rect(
                                topLeadingRadius: 0, bottomLeadingRadius: 12,
                                bottomTrailingRadius: 12, topTrailingRadius: 0))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .zIndex(1)
                }
            }
            .padding(.spacing16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("セレクト系")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ── 2. Embed 表示 ─────────────────────────────────────────

private struct EmbedShowcase: View {
    @State private var colorHex: UInt32 = 0x5856D6
    @State private var authorName = "Noxy"
    @State private var title = "Embedタイトル"
    @State private var description = "これはEmbedの説明文です。**太字**や*斜体*などのMarkdownが使えます。\n\n複数行にも対応しています。"
    @State private var fields: [EmbedFieldModel] = [
        EmbedFieldModel(id: "f1", name: "フィールド名 1", value: "フィールドの値です", inline: true),
        EmbedFieldModel(id: "f2", name: "フィールド名 2", value: "インラインフィールド", inline: true),
        EmbedFieldModel(id: "f3", name: "ブロックフィールド", value: "インラインをオフにすると縦に並びます", inline: false),
    ]
    @State private var footerText = "フッターテキスト"
    @State private var showTimestamp = true
    @State private var messageContent = "通常のメッセージ本文（Embed外）"
    @State private var showColorPicker = false

    private var accent: Color { Color(uiColor: UIColor(hex: colorHex)) }

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                ShowcaseCard(title: "Embed コントロール", badge: "controls") {
                    VStack(spacing: .spacing8) {
                        HStack {
                            Text("カラー").font(.captionRegular).foregroundStyle(Color.textSecondary)
                            Spacer()
                            Button { showColorPicker = true } label: {
                                HStack(spacing: 8) {
                                    Circle().fill(accent).frame(width: 22, height: 22)
                                        .overlay(Circle().stroke(Color.border, lineWidth: 1))
                                    Text(String(format: "#%06X", colorHex))
                                        .font(.mono).foregroundStyle(Color.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Divider()
                        Toggle("タイムスタンプ表示", isOn: $showTimestamp).font(.captionRegular)
                        Divider()
                        HStack {
                            Text("フィールド数").font(.captionRegular).foregroundStyle(Color.textSecondary)
                            Spacer()
                            Stepper("\(fields.count)", value: Binding(
                                get: { fields.count },
                                set: { count in
                                    while fields.count < count {
                                        fields.append(EmbedFieldModel(id: UUID().uuidString, name: "フィールド \(fields.count+1)", value: "値", inline: fields.count % 2 == 0))
                                    }
                                    while fields.count > count && !fields.isEmpty { fields.removeLast() }
                                }
                            ), in: 0...25)
                            .labelsHidden()
                        }
                    }
                }
                .sheet(isPresented: $showColorPicker) { ColorPickerSheet(selectedHex: $colorHex) }

                ShowcaseCard(title: "Embed プレビュー（全項目）", badge: "preview") {
                    FullEmbedPreview(
                        colorHex: colorHex, authorName: $authorName, title: $title,
                        description: $description, fields: $fields, footerText: $footerText,
                        showTimestamp: showTimestamp, messageContent: $messageContent
                    )
                }
            }
            .padding(.spacing16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Embed")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FullEmbedPreview

private struct FullEmbedPreview: View {
    let colorHex: UInt32
    @Binding var authorName: String
    @Binding var title: String
    @Binding var description: String
    @Binding var fields: [EmbedFieldModel]
    @Binding var footerText: String
    let showTimestamp: Bool
    @Binding var messageContent: String

    @FocusState private var focused: String?
    private var accent: Color { Color(uiColor: UIColor(hex: colorHex)) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentIndigo, Color.accentPink],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    TextField("Bot名", text: $authorName)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                        .textFieldStyle(.plain).fixedSize()
                        .focused($focused, equals: "author")
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .embedDashedBorder(focused: focused == "author")
                    Text("BOT").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.accentIndigo).clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("今日 ") + Text(Date(), style: .time)
                }
                .font(.captionSmall).foregroundStyle(Color.textTertiary)

                TextField("メッセージ本文（Embed外）", text: $messageContent, axis: .vertical)
                    .lineLimit(1...3).font(.system(size: 14)).foregroundStyle(Color.textPrimary)
                    .textFieldStyle(.plain).focused($focused, equals: "msgContent")
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .embedDashedBorder(focused: focused == "msgContent")

                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 4)

                    VStack(alignment: .leading, spacing: .spacing8) {
                        TextField("タイトル", text: $title)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(accent)
                            .textFieldStyle(.plain).focused($focused, equals: "title")
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .embedDashedBorder(focused: focused == "title")

                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("説明文...").font(.system(size: 14)).foregroundStyle(Color.textTertiary)
                                    .padding(.top, 7).padding(.leading, 7).allowsHitTesting(false)
                            }
                            TextEditor(text: $description)
                                .font(.system(size: 14)).foregroundStyle(Color.textSecondary)
                                .scrollContentBackground(.hidden).frame(minHeight: 60, maxHeight: .infinity)
                                .focused($focused, equals: "desc")
                        }
                        .padding(.horizontal, 2).padding(.vertical, 2)
                        .embedDashedBorder(focused: focused == "desc")

                        if !fields.isEmpty { embedFieldsGrid }

                        HStack(spacing: .spacing6) {
                            Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundStyle(Color.textTertiary)
                            TextField("フッターテキスト", text: $footerText)
                                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                                .textFieldStyle(.plain).focused($focused, equals: "footer")
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .embedDashedBorder(focused: focused == "footer")
                            if showTimestamp {
                                Text("・").foregroundStyle(Color.textTertiary)
                                Text(Date(), style: .date).font(.captionSmall).foregroundStyle(Color.textTertiary)
                            }
                        }
                    }
                    .padding(.spacing10)

                    RoundedRectangle(cornerRadius: 4).fill(Color.bgElevated).frame(width: 60, height: 60)
                        .overlay(Image(systemName: "photo").font(.system(size: 20)).foregroundStyle(Color.textTertiary))
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color.border))
                        .padding(.top, .spacing10).padding(.trailing, .spacing6)
                }
                .background(Color.bgSurface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    @ViewBuilder
    private var embedFieldsGrid: some View {
        let inlineFields = fields.filter(\.inline)
        let blockFields  = fields.filter { !$0.inline }
        VStack(alignment: .leading, spacing: .spacing6) {
            if !inlineFields.isEmpty {
                let rows = stride(from: 0, to: inlineFields.count, by: 2).map {
                    Array(inlineFields[$0..<min($0+2, inlineFields.count)])
                }
                ForEach(rows, id: \.first?.id) { row in
                    HStack(alignment: .top, spacing: .spacing8) { ForEach(row) { embedField($0) } }
                }
            }
            ForEach(blockFields) { embedField($0).frame(maxWidth: .infinity, alignment: .leading) }
        }
    }

    private func embedField(_ field: EmbedFieldModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(field.name.isEmpty ? "名前" : field.name)
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.textPrimary).lineLimit(1)
            Text(field.value.isEmpty ? "値" : field.value)
                .font(.captionSmall).foregroundStyle(Color.textSecondary).lineLimit(2)
        }
        .padding(.spacing8).background(Color.bgElevated).clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: field.inline ? .infinity : nil)
    }
}

// MARK: - ── 3. 確認モーダル ───────────────────────────────────────

private struct ModalShowcase: View {
    @State private var showDestructive = false
    @State private var showInfo        = false
    @State private var showCustom      = false
    @State private var showSuccess     = false
    @State private var lastResult: String? = nil

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: .spacing16) {
                    if let result = lastResult {
                        HStack(spacing: .spacing8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentGreen)
                            Text("操作: \(result)").font(.captionRegular).foregroundStyle(Color.textSecondary)
                            Spacer()
                            Button { lastResult = nil } label: {
                                Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Color.textTertiary)
                            }
                        }
                        .padding(.spacing12).background(Color.accentGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ShowcaseCard(title: "Destructive", badge: "danger") {
                        modalPreviewRow(icon: "trash.fill", iconColor: .accentRed, title: "削除の確認", desc: "この操作は元に戻せません") { showDestructive = true }
                    }
                    ShowcaseCard(title: "Info", badge: "info") {
                        modalPreviewRow(icon: "info.circle.fill", iconColor: .accentIndigo, title: "お知らせ", desc: "設定が変更されました") { showInfo = true }
                    }
                    ShowcaseCard(title: "Custom with Input", badge: "custom") {
                        modalPreviewRow(icon: "pencil.circle.fill", iconColor: .accentPurple, title: "理由を入力", desc: "テキスト入力欄つきモーダル") { showCustom = true }
                    }
                    ShowcaseCard(title: "Success", badge: "success") {
                        modalPreviewRow(icon: "checkmark.circle.fill", iconColor: .accentGreen, title: "完了", desc: "取引が正常に完了しました") { showSuccess = true }
                    }
                }
                .padding(.spacing16)
            }
            .background(Color(.systemGroupedBackground))

            if showDestructive {
                ConfirmModal(
                    icon: "trash.fill", iconColor: .accentRed,
                    title: "ショップを削除しますか？",
                    message: "「夏セールショップ」を削除すると、商品・注文履歴を含むすべてのデータが完全に削除されます。この操作は元に戻せません。",
                    primaryLabel: "削除する", primaryRole: .destructive,
                    onPrimary: { lastResult = "削除"; withAnimation { showDestructive = false } },
                    onCancel:  { withAnimation { showDestructive = false } }
                )
            }
            if showInfo {
                ConfirmModal(
                    icon: "info.circle.fill", iconColor: .accentIndigo,
                    title: "自動削除が設定されています",
                    message: "このチケットは取引完了から7日後に自動的に削除されます。必要な情報は事前に保存してください。",
                    primaryLabel: "了解", primaryRole: .cancel,
                    onPrimary: { lastResult = "了解"; withAnimation { showInfo = false } },
                    onCancel: nil
                )
            }
            if showCustom {
                CustomInputModal(
                    onSubmit: { reason in lastResult = "送信: \(reason)"; withAnimation { showCustom = false } },
                    onCancel: { withAnimation { showCustom = false } }
                )
            }
            if showSuccess {
                SuccessModal(
                    title: "取引完了！",
                    message: "商品が正常に届けられました。ご利用ありがとうございました。",
                    onDismiss: { lastResult = "チケットを閉じる"; withAnimation { showSuccess = false } }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showDestructive)
        .animation(.easeInOut(duration: 0.2), value: showInfo)
        .animation(.easeInOut(duration: 0.2), value: showCustom)
        .animation(.easeInOut(duration: 0.2), value: showSuccess)
        .animation(.easeInOut(duration: 0.2), value: lastResult)
        .navigationTitle("モーダル")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modalPreviewRow(icon: String, iconColor: Color, title: String, desc: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(iconColor.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                Text(desc).font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Button("表示") { action() }
                .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(iconColor).clipShape(Capsule())
        }
    }
}

// MARK: - ── 4. タブ ──────────────────────────────────────────────

private struct TabShowcase: View {

    // ── タブ切り替えデモ ──
    @State private var segTab = 0
    @State private var customTab = 0
    private let customTabs = ["概要", "注文", "設定"]

    // ── シートデモ ──
    @State private var showBasicSheet     = false
    @State private var showSaveSheet      = false
    @State private var showDestructSheet  = false
    @State private var sheetResult: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing24) {
                // ── 結果バナー ──
                if let result = sheetResult {
                    HStack(spacing: .spacing8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentGreen)
                        Text("操作: \(result)").font(.captionRegular).foregroundStyle(Color.textSecondary)
                        Spacer()
                        Button { sheetResult = nil } label: {
                            Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Color.textTertiary)
                        }
                    }
                    .padding(.spacing12).background(Color.accentGreen.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // ── Segmented Tab ──
                ShowcaseCard(title: "Segmented Tab", badge: "tab") {
                    VStack(spacing: .spacing12) {
                        Picker("", selection: $segTab) {
                            Text("パネル設定").tag(0)
                            Text("取引").tag(1)
                        }
                        .pickerStyle(.segmented)

                        Group {
                            switch segTab {
                            case 0:
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape.fill").foregroundStyle(Color.accentIndigo)
                                    Text("パネル設定タブのコンテンツです").font(.bodySmall).foregroundStyle(Color.textSecondary)
                                }
                            default:
                                HStack(spacing: 8) {
                                    Image(systemName: "cart.fill").foregroundStyle(Color.accentGreen)
                                    Text("取引タブのコンテンツです").font(.bodySmall).foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                        .padding(.spacing12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // ── カスタムタブバー ──
                ShowcaseCard(title: "カスタムタブバー", badge: "custom-tab") {
                    VStack(spacing: .spacing12) {
                        // タブバー
                        HStack(spacing: 0) {
                            ForEach(Array(customTabs.enumerated()), id: \.element) { idx, tab in
                                Button { withAnimation(.easeInOut(duration: 0.18)) { customTab = idx } } label: {
                                    VStack(spacing: 4) {
                                        Text(tab)
                                            .font(.captionRegular).fontWeight(.semibold)
                                            .foregroundStyle(customTab == idx ? Color.accentGreen : Color.textTertiary)
                                        Capsule()
                                            .fill(customTab == idx ? Color.accentGreen : Color.clear)
                                            .frame(height: 2)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, .spacing8).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Color.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.border, lineWidth: 1))

                        Text("「\(customTabs[customTab])」タブのコンテンツ")
                            .font(.bodySmall).foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.spacing16)
                            .background(Color.bgElevated).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // ── シート（基本：左右ボタンあり） ──
                ShowcaseCard(title: "シート（左右ボタン）", badge: "sheet") {
                    VStack(spacing: .spacing10) {
                        sheetDemoRow(
                            icon: "square.and.arrow.up", color: .accentIndigo,
                            title: "保存シート", desc: "左：閉じる　右：保存"
                        ) { showSaveSheet = true }

                        sheetDemoRow(
                            icon: "info.circle", color: .accentGreen,
                            title: "情報シート", desc: "左：キャンセル　右：完了"
                        ) { showBasicSheet = true }

                        sheetDemoRow(
                            icon: "trash", color: .accentRed,
                            title: "削除シート", desc: "左：キャンセル　右：削除（赤）"
                        ) { showDestructSheet = true }
                    }
                }
            }
            .padding(.spacing16)
        }
        .animation(.easeInOut(duration: 0.2), value: sheetResult)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("タブ")
        .navigationBarTitleDisplayMode(.inline)
        // ── 保存シート ──
        .sheet(isPresented: $showSaveSheet) {
            DemoSheet(
                title: "設定を編集",
                leftLabel: "閉じる", rightLabel: "保存",
                rightColor: .accentGreen, rightRole: nil
            ) { action in
                sheetResult = action
                showSaveSheet = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // ── 基本シート ──
        .sheet(isPresented: $showBasicSheet) {
            DemoSheet(
                title: "お知らせ",
                leftLabel: "キャンセル", rightLabel: "完了",
                rightColor: .accentIndigo, rightRole: nil
            ) { action in
                sheetResult = action
                showBasicSheet = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // ── 削除シート ──
        .sheet(isPresented: $showDestructSheet) {
            DemoSheet(
                title: "削除の確認",
                leftLabel: "キャンセル", rightLabel: "削除する",
                rightColor: .accentRed, rightRole: .destructive
            ) { action in
                sheetResult = action
                showDestructSheet = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func sheetDemoRow(icon: String, color: Color, title: String, desc: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                Text(desc).font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Button("表示") { action() }
                .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(color).clipShape(Capsule())
        }
    }
}

// MARK: - DemoSheet（左上・右上ボタン付き下から上シート）

private struct DemoSheet: View {
    let title: String
    let leftLabel: String
    let rightLabel: String
    let rightColor: Color
    let rightRole: ButtonRole?
    let onAction: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing16) {
                    ShowcaseCard(title: "シートコンテンツ", badge: "content") {
                        VStack(alignment: .leading, spacing: .spacing12) {
                            Text("これはシートの中身のサンプルです。")
                                .font(.bodySmall).foregroundStyle(Color.textSecondary)
                            HStack(spacing: .spacing8) {
                                ForEach(["項目A", "項目B", "項目C"], id: \.self) { item in
                                    Text(item).font(.captionRegular).foregroundStyle(Color.accentIndigo)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
                                }
                            }
                            Text("左上の「\(leftLabel)」で閉じるか、右上の「\(rightLabel)」でアクションを実行します。")
                                .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        }
                    }
                }
                .padding(.spacing16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(leftLabel) { onAction(leftLabel) }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(rightLabel, role: rightRole) { onAction(rightLabel) }
                        .fontWeight(.semibold)
                        .foregroundStyle(rightRole == .destructive ? Color.accentRed : rightColor)
                }
            }
        }
    }
}

// MARK: - CustomInputModal

private struct CustomInputModal: View {
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { onCancel() }

            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Color.accentPurple.opacity(0.12)).frame(width: 64, height: 64)
                    Image(systemName: "pencil.circle.fill").font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.accentPurple)
                }
                .padding(.top, .spacing24)

                VStack(spacing: .spacing8) {
                    Text("キャンセル理由を入力").font(.titleMedium).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                    Text("購入者に表示されます。できるだけ明確に記入してください。")
                        .font(.bodySmall).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal, .spacing24).padding(.top, .spacing16)

                TextField("例：在庫切れのため", text: $text, axis: .vertical)
                    .lineLimit(2...4).font(.bodySmall)
                    .padding(.spacing12).background(Color.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Color.accentPurple : Color.border, lineWidth: 1.5))
                    .focused($focused)
                    .padding(.horizontal, .spacing24).padding(.top, .spacing16).padding(.bottom, .spacing24)

                Divider()
                HStack(spacing: 0) {
                    Button("キャンセル") { onCancel() }
                        .font(.bodySmall).foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing16).contentShape(Rectangle())
                    Divider().frame(height: 50)
                    Button("送信") { onSubmit(text) }
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(text.isEmpty ? Color.textTertiary : Color.accentPurple).disabled(text.isEmpty)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing16).contentShape(Rectangle())
                }
            }
            .background(Color.bgSurface).clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.2), radius: 30, y: 10)
            .padding(.horizontal, .spacing32)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focused = true } }
    }
}

// MARK: - SuccessModal

private struct SuccessModal: View {
    let title: String
    let message: String
    let onDismiss: () -> Void
    @State private var checkScale: CGFloat = 0.3
    @State private var checkOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: .spacing16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.accentGreen.opacity(0.2), Color.accentGreen.opacity(0.05)],
                                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44)).foregroundStyle(Color.accentGreen)
                        .scaleEffect(checkScale).opacity(checkOpacity)
                }
                .padding(.top, .spacing24)

                VStack(spacing: .spacing8) {
                    Text(title).font(.titleMedium).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                    Text(message).font(.bodySmall).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal, .spacing24)

                Divider().padding(.top, .spacing8)
                Button(action: onDismiss) {
                    Text("チケットを閉じる").font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.accentGreen)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing16).contentShape(Rectangle())
                }
            }
            .background(Color.bgSurface).clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.2), radius: 30, y: 10)
            .padding(.horizontal, .spacing32)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                checkScale = 1.0; checkOpacity = 1.0
            }
        }
    }
}

// MARK: - ── Shared Components ─────────────────────────────────────

private struct ShowcaseCard<Content: View>: View {
    let title: String
    let badge: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack(spacing: .spacing8) {
                Text(title).font(.captionSmall).fontWeight(.bold).foregroundStyle(Color.textSecondary).textCase(.uppercase)
                Text(badge).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.accentIndigo)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
            }
            .padding(.horizontal, .spacing4)

            VStack(alignment: .leading, spacing: .spacing8) { content() }
                .padding(.spacing16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgSurface).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct ChipToggle: View {
    let label: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 5) {
                if isSelected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                Text(label).font(.captionRegular).fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected ? Color.accentIndigo : Color.bgElevated)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.border, lineWidth: 1))
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct BottomSheetPickerContent: View {
    let title: String
    let options: [String]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.borderStrong).frame(width: 36, height: 4)
                .padding(.top, .spacing8).padding(.bottom, .spacing16)
            Text(title).font(.titleMedium).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                .padding(.bottom, .spacing16)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element) { idx, opt in
                        Button { onSelect(opt) } label: {
                            HStack {
                                Text(opt).font(.bodySmall).foregroundStyle(Color.textPrimary)
                                Spacer()
                                if selected == opt {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentIndigo)
                                }
                            }
                            .padding(.horizontal, .spacing20).padding(.vertical, .spacing12)
                            .background(selected == opt ? Color.accentIndigo.opacity(0.05) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if idx < options.count - 1 { Divider().padding(.leading, .spacing20) }
                    }
                }
            }
        }
        .background(Color.bgSurface)
    }
}

// FlowLayout は Theme/Components/FlowLayout.swift で共通定義済み
private struct _DevFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var maxHeight: CGFloat = 0; var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            rowHeight = max(rowHeight, size.height); x += size.width + spacing; maxHeight = y + rowHeight
        }
        return CGSize(width: width, height: maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { y += rowHeight + spacing; x = bounds.minX; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height); x += size.width + spacing
        }
    }
}

// MARK: - ── 5. 通知テスト ──────────────────────────────────────

private struct NotificationTestView: View {

    // MARK: - 通知定義

    struct NotifItem: Identifiable {
        let id = UUID()
        let category: String
        let title: String
        let body: String
        let icon: String
        let color: Color
        let identifier: String  // UNNotification identifier prefix
    }

    private let items: [NotifItem] = [
        NotifItem(
            category: "チケット",
            title: "新規チケット",
            body: "サーバー「Noxy公式」で新しいチケットが開設されました。",
            icon: "ticket.fill",
            color: .accentIndigo,
            identifier: "test_ticket"
        ),
        NotifItem(
            category: "注文",
            title: "新規注文",
            body: "商品「プレミアムロール」の注文が届きました。",
            icon: "cart.fill",
            color: .accentGreen,
            identifier: "test_order"
        ),
        NotifItem(
            category: "モデレーション",
            title: "メンバーをミュートしました",
            body: "ユーザー「user#1234」が1時間ミュートされました。理由: スパム",
            icon: "mic.slash.fill",
            color: .accentRed,
            identifier: "test_moderation"
        ),
        NotifItem(
            category: "メンバー参加",
            title: "新規メンバーが参加",
            body: "「newuser#5678」がサーバー「Noxy公式」に参加しました。",
            icon: "person.badge.plus.fill",
            color: .accentPurple,
            identifier: "test_member_join"
        ),
        NotifItem(
            category: "ウェルカム",
            title: "ウェルカムメッセージ送信",
            body: "「user#9999」へのウェルカムメッセージが送信されました。",
            icon: "hands.sparkles.fill",
            color: .accentPink,
            identifier: "test_welcome"
        ),
        NotifItem(
            category: "認証",
            title: "認証完了",
            body: "「user#0001」がサーバーの認証を完了しました。",
            icon: "checkmark.shield.fill",
            color: .accentGreen,
            identifier: "test_verify"
        ),
        NotifItem(
            category: "リアクションロール",
            title: "ロール付与",
            body: "「user#2222」に「🎮 ゲーマー」ロールが付与されました。",
            icon: "star.circle.fill",
            color: .accentOrange,
            identifier: "test_reaction_role"
        ),
        NotifItem(
            category: "一時VC",
            title: "一時VCが作成されました",
            body: "「user#3333」が「🎤 user's channel」を作成しました。",
            icon: "waveform.circle.fill",
            color: .accentIndigo,
            identifier: "test_temp_vc"
        ),
        NotifItem(
            category: "自動応答",
            title: "自動応答が発動",
            body: "キーワード「help」にマッチし、自動応答を送信しました。",
            icon: "bolt.fill",
            color: .accentPurple,
            identifier: "test_auto_response"
        ),
        NotifItem(
            category: "Botステータス",
            title: "Botがオフラインになりました",
            body: "Noxy Bot の接続が切断されました。確認してください。",
            icon: "antenna.radiowaves.left.and.right.slash",
            color: .accentRed,
            identifier: "test_bot_status"
        ),
        NotifItem(
            category: "アップデート",
            title: "Noxyがアップデートされました",
            body: "バージョン 2.3.0 が利用可能です。新機能を確認しましょう！",
            icon: "arrow.down.circle.fill",
            color: .accentGreen,
            identifier: "test_update"
        ),
        NotifItem(
            category: "予約送信",
            title: "予約メッセージを送信しました",
            body: "「#announcements」への予約メッセージが正常に送信されました。",
            icon: "calendar.badge.clock",
            color: .accentOrange,
            identifier: "test_scheduled"
        ),
    ]

    // MARK: - State

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var sentIds: Set<String> = []
    @State private var sendingId: String? = nil

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {

                // ── 権限バナー ──
                permissionBanner

                // ── 全送信ボタン ──
                Button {
                    Task { await sendAll() }
                } label: {
                    HStack(spacing: .spacing8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("すべての通知を送信")
                            .font(.bodySmall).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(authStatus == .authorized ? Color.accentOrange : Color.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(authStatus != .authorized)

                // ── 個別通知 ──
                VStack(spacing: .spacing8) {
                    ForEach(items) { item in
                        notifRow(item)
                    }
                }
            }
            .padding(.spacing16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("通知テスト")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("既読リセット") { sentIds = [] }
                    .font(.captionRegular)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .task { await refreshAuthStatus() }
    }

    // MARK: - Permission Banner

    @ViewBuilder
    private var permissionBanner: some View {
        switch authStatus {
        case .authorized:
            HStack(spacing: .spacing8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentGreen)
                Text("通知が許可されています")
                    .font(.captionRegular).foregroundStyle(Color.textSecondary)
                Spacer()
            }
            .padding(.spacing12)
            .background(Color.accentGreen.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .denied:
            HStack(spacing: .spacing10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("通知が拒否されています")
                        .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.orange)
                    Text("設定アプリから通知を許可してください")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
                Spacer()
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.captionRegular).fontWeight(.semibold).foregroundStyle(Color.accentIndigo)
            }
            .padding(.spacing12)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))

        default:
            Button {
                Task { await requestPermission() }
            } label: {
                HStack(spacing: .spacing8) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 14))
                    Text("通知を許可する")
                        .font(.captionRegular).fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.accentIndigo)
                .padding(.spacing12)
                .background(Color.accentIndigo.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentIndigo.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Row

    private func notifRow(_ item: NotifItem) -> some View {
        HStack(spacing: .spacing12) {
            // アイコン
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: item.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(item.color)
            }

            // テキスト
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.category)
                        .font(.captionSmall).fontWeight(.bold).foregroundStyle(item.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(item.color.opacity(0.1)).clipShape(Capsule())
                    if sentIds.contains(item.identifier) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11)).foregroundStyle(Color.accentGreen)
                    }
                }
                Text(item.title)
                    .font(.captionRegular).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(item.body)
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
            }

            Spacer()

            // 送信ボタン
            Button {
                Task { await send(item) }
            } label: {
                Group {
                    if sendingId == item.identifier {
                        ProgressView().scaleEffect(0.7)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(authStatus == .authorized ? item.color : Color.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(authStatus == .authorized ? item.color.opacity(0.12) : Color.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
            .disabled(authStatus != .authorized || sendingId != nil)
            .buttonStyle(.plain)
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    @MainActor
    private func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthStatus()
    }

    @MainActor
    private func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }

    @MainActor
    private func send(_ item: NotifItem) async {
        guard authStatus == .authorized else { return }
        sendingId = item.identifier
        defer { sendingId = nil }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body  = item.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(item.identifier)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        sentIds.insert(item.identifier)

        // 少し待って UI フィードバック
        try? await Task.sleep(for: .milliseconds(300))
    }

    @MainActor
    private func sendAll() async {
        guard authStatus == .authorized else { return }
        for (i, item) in items.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body  = item.body
            content.sound = .default

            // 1秒ずつずらして送信（バラバラに届くように）
            let delay = TimeInterval(i) * 1.5 + 1.0
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(item.identifier)_all_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            sentIds.insert(item.identifier)
        }
    }
}

// MARK: - Preview

#Preview { ComponentLibraryView() }

#endif
