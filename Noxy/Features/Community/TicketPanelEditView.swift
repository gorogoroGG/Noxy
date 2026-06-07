import SwiftUI

// MARK: - TicketPanelEditView

struct TicketPanelEditView: View {
    var existingPanel: TicketPanel?
    let guildId: String
    let onSave: (TicketPanel) -> Void

    @Environment(\.services)    private var services
    @Environment(\.dismiss)     private var dismiss
    @Environment(AppState.self) private var appState

    // ── タブ ──
    enum EditTab: String, CaseIterable {
        case panel  = "パネルの設定"
        case ticket = "チケットの設定"
    }
    @State private var selectedTab: EditTab = .panel

    // ── パネルフィールド ──
    @State private var title             = "サポートチケット"
    @State private var description       = "ボタンをクリックしてチケットを開きます。\nスタッフが迅速に対応します。"
    @State private var buttonLabel       = "チケットを作成"
    @State private var buttonEmoji       = "🎫"
    @State private var embedColorHex: UInt32  = 0x6366f1
    @State private var buttonColorHex: UInt32 = 0x6366f1

    // ── チケットフィールド ──
    @State private var supportRoleId     = ""
    @State private var openCategoryId    = ""
    @State private var closedCategoryId  = ""
    @State private var ticketEmbedTitle  = "チケット"
    @State private var ticketMsgContent  = "{user.mention} さん、チケットを作成しました。\nスタッフが確認次第、対応いたします。\n\n**件名：** {subject}"
    @State private var maxOpenPerUser    = 1

    // ── データ ──
    @State private var roles: [DiscordRole] = []
    @State private var categories: [(id: String, name: String)] = []
    @State private var isLoading  = true
    @State private var isSaving   = false
    @State private var errorMessage: String? = nil

    // ── キーボード高さ ──
    @State private var keyboardHeight: CGFloat = 0

    // ── カラーピッカー ──
    @State private var showEmbedColorPicker  = false
    @State private var showButtonColorPicker = false

    // ── Focus ──
    @FocusState private var focusedField: FieldFocus?

    private var isNew: Bool { existingPanel == nil }

    private var embedColor:  Color { Color(uiColor: UIColor(hex: embedColorHex)) }
    private var buttonColor: Color { Color(uiColor: UIColor(hex: buttonColorHex)) }

    enum FieldFocus: Hashable {
        case title, description, buttonLabel, buttonEmoji
        case ticketMsg
        case ticketEmbedTitle
    }

    // ── 変数チップ ──
    private let variableChips: [(label: String, value: String)] = [
        ("{user.mention}", "{user.mention}"),
        ("{user.name}",    "{user.name}"),
        ("{guild.name}",   "{guild.name}"),
        ("{subject}",      "{subject}"),
        ("{ticket.id}",    "{ticket.id}"),
        ("{channel.name}", "{channel.name}"),
        ("{ticket.number}","{ticket.number}"),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .spacing16) {
                    Picker("", selection: $selectedTab) {
                        ForEach(EditTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, .spacing16)

                    if selectedTab == .panel {
                        panelPreviewEditor
                    } else {
                        ticketSettingsForm
                    }

                    if let err = errorMessage {
                        Card {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.captionRegular)
                        }
                    }
                }
                .padding(.spacing16)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.never)
            .background(Color.bgPrimary)
            .navigationTitle(isNew ? "パネルを作成" : "パネルを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(title.isEmpty ? Color.textTertiary : Color.accentIndigo)
                        .disabled(title.isEmpty || isSaving)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if focusedField != nil {
                    chipBar
                }
            }
            .task { await loadData() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
                if let rect = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = rect.height }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
            }
            .sheet(isPresented: $showEmbedColorPicker) {
                ColorPickerSheet(selectedHex: $embedColorHex)
            }
            .sheet(isPresented: $showButtonColorPicker) {
                ColorPickerSheet(selectedHex: $buttonColorHex)
            }
        }
    }

    // MARK: - Chip Bar（safeAreaInset で表示）
    // UIKit ベースの HorizontalChipBar を使用。SwiftUI の ScrollView(.horizontal) では
    // sheet+NavigationStack コンテキストで縦ジェスチャーが伝播する問題を完全回避。

    private var chipBar: some View {
        HorizontalChipBar(
            chips: variableChips,
            accentColor: Color.accentIndigo,
            doneTitle: "完了",
            onChipTap: { insertVariable($0) },
            onDone:    { focusedField = nil }
        )
        .frame(height: 46)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private func insertVariable(_ v: String) {
        switch focusedField {
        case .title:       title            += v
        case .description: description      += v
        case .buttonLabel: buttonLabel      += v
        case .ticketMsg:   ticketMsgContent += v
        default: break
        }
    }

    // MARK: - Panel Preview Editor

    private var panelPreviewEditor: some View {
        VStack(spacing: .spacing12) {
            // Discord スタイルのプレビュー
            HStack(alignment: .top, spacing: .spacing12) {
                // Bot アバター
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentIndigo, Color.accentPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: .spacing4) {
                    HStack(spacing: .spacing6) {
                        Text("Noxy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentIndigo)
                        Text("BOT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.accentIndigo)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        (Text("今日 ") + Text(Date(), style: .time))
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                    }

                    // Embed ブロック
                    HStack(alignment: .top, spacing: 0) {
                        // 左カラーバー（タップでEmbedカラー変更）
                        RoundedRectangle(cornerRadius: 2)
                            .fill(embedColor)
                            .frame(width: 4)
                            .onTapGesture { showEmbedColorPicker = true }

                        VStack(alignment: .leading, spacing: .spacing8) {
                            // タイトル
                            TextField("タイトル", text: $title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(embedColor)
                                .textFieldStyle(.plain)
                                .background(.clear)
                                .focused($focusedField, equals: .title)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .embedDashedBorder(focused: focusedField == .title)

                            // 説明
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("説明")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textTertiary)
                                        .padding(.top, 8).padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $description)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                                    .frame(minHeight: 60, maxHeight: 120)
                                    .focused($focusedField, equals: .description)
                            }
                            .padding(2)
                            .embedDashedBorder(focused: focusedField == .description)

                            // ボタン（絵文字 + ラベル）
                            HStack(spacing: .spacing6) {
                                TextField("🎫", text: $buttonEmoji)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .textFieldStyle(.plain)
                                    .background(.clear)
                                    .frame(width: 30)
                                    .multilineTextAlignment(.center)
                                    .focused($focusedField, equals: .buttonEmoji)

                                TextField("チケットを作成", text: $buttonLabel)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .textFieldStyle(.plain)
                                    .background(.clear)
                                    .focused($focusedField, equals: .buttonLabel)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(buttonColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(.spacing10)
                    }
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // カラー設定行
            HStack(spacing: .spacing20) {
                ColorSwatch(label: "Embedカラー", color: embedColor) {
                    showEmbedColorPicker = true
                }
                ColorSwatch(label: "ボタンカラー", color: buttonColor) {
                    showButtonColorPicker = true
                }
                Spacer()
            }
            .padding(.horizontal, .spacing4)
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Ticket Settings Form

    private var ticketSettingsForm: some View {
        VStack(spacing: .spacing16) {
            // ── チケット内メッセージ ──
            HStack(alignment: .top, spacing: .spacing10) {
                ZStack {
                    Circle().fill(embedColor).frame(width: 36, height: 36)
                    Text("🤖").font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: .spacing4) {
                    HStack(spacing: .spacing6) {
                        Text("Noxy")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(embedColor)
                        Text("BOT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.accentIndigo)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        (Text("今日 ") + Text(Date(), style: .time))
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                    }
                    ZStack(alignment: .topLeading) {
                        if ticketMsgContent.isEmpty {
                            Text("チケット内メッセージを入力...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)
                                .padding(.top, 8).padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $ticketMsgContent)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .frame(minHeight: 60, maxHeight: 120)
                            .focused($focusedField, equals: .ticketMsg)
                    }
                }
            }
            .padding(.spacing12)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // ── チケット設定 ──
            Card {
                VStack(spacing: 0) {
                    settingRow(label: "接頭辞", icon: "textformat.prefix", detail: ticketEmbedTitle.isEmpty ? "ticket" : ticketEmbedTitle) {
                        TextField("ticket", text: $ticketEmbedTitle)
                            .font(.bodySmall)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color.textSecondary)
                    }

                    Divider().padding(.leading, 44)

                    if isLoading {
                        HStack { Spacer(); ProgressView().scaleEffect(0.8).padding(.vertical, .spacing12); Spacer() }
                    } else {
                        pickerRow(label: "サポートロール", icon: "person.badge.shield.checkmark", selection: $supportRoleId) {
                            Text("なし").tag("")
                            ForEach(roles.filter { !$0.managed && $0.name != "@everyone" }) {
                                Text("@\($0.name)").tag($0.id)
                            }
                        }

                        Divider().padding(.leading, 44)

                        pickerRow(label: "オープンカテゴリ", icon: "folder.badge.plus", selection: $openCategoryId) {
                            Text("なし").tag("")
                            ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                        }

                        Divider().padding(.leading, 44)

                        pickerRow(label: "クローズカテゴリ", icon: "folder.badge.minus", selection: $closedCategoryId) {
                            Text("なし").tag("")
                            ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                        }

                        Divider().padding(.leading, 44)

                        HStack(spacing: .spacing12) {
                            Image(systemName: "number.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.accentIndigo)
                                .frame(width: 28)
                            Text("同時オープン上限")
                                .font(.bodySmall)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Stepper("\(maxOpenPerUser)件", value: $maxOpenPerUser, in: 1...10)
                                .font(.bodySmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.horizontal, .spacing12)
                        .padding(.vertical, .spacing10)
                    }
                }
            }
        }
    }

    private func settingRow<Content: View>(label: String, icon: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentIndigo)
                .frame(width: 28)
            Text(label)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            content()
        }
        .padding(.horizontal, .spacing12)
        .padding(.vertical, .spacing10)
    }

    private func pickerRow<SelectionValue: Hashable, Content: View>(
        label: String,
        icon: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View where Content: View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentIndigo)
                .frame(width: 28)
            Text(label)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Picker("", selection: selection) {
                content()
            }
            .font(.captionRegular)
            .pickerStyle(.menu)
            .tint(Color.textSecondary)
        }
        .padding(.horizontal, .spacing12)
        .padding(.vertical, .spacing10)
    }

    // MARK: - Load

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

        if let p = existingPanel {
            title            = p.title
            description      = p.description
            buttonLabel      = p.buttonLabel
            buttonEmoji      = p.buttonEmoji
            supportRoleId    = p.supportRoleId    ?? ""
            openCategoryId   = p.openCategoryId   ?? ""
            closedCategoryId = p.closedCategoryId ?? ""
            ticketMsgContent = p.ticketMsgContent ?? ""
            ticketEmbedTitle = p.ticketEmbedTitle
            maxOpenPerUser   = p.maxOpenPerUser
            embedColorHex    = UInt32(p.color)
            buttonColorHex   = UInt32(p.buttonColor)
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var panel = existingPanel ?? TicketPanel.blank(guildId: guildId)
            panel.title            = title
            panel.description      = description
            panel.buttonLabel      = buttonLabel
            panel.buttonEmoji      = buttonEmoji
            panel.color            = Int(embedColorHex)
            panel.buttonColor      = Int(buttonColorHex)
            panel.ticketEmbedColor = Int(embedColorHex)
            panel.supportRoleId    = supportRoleId.isEmpty    ? nil : supportRoleId
            panel.openCategoryId   = openCategoryId.isEmpty   ? nil : openCategoryId
            panel.closedCategoryId = closedCategoryId.isEmpty ? nil : closedCategoryId
            panel.ticketMsgContent = ticketMsgContent.isEmpty ? nil : ticketMsgContent
            panel.ticketEmbedTitle = ticketEmbedTitle
            panel.maxOpenPerUser   = maxOpenPerUser

            let saved = isNew
                ? try await services.tickets.createPanel(panel)
                : try await services.tickets.updatePanel(panel)

            onSave(saved)
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました"
        }
        isSaving = false
    }
}

// MARK: - ColorSwatch

private struct ColorSwatch: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: .spacing6) {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.border, lineWidth: 1))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, .spacing8).padding(.vertical, .spacing6)
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
