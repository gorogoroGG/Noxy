import SwiftUI

// MARK: - TicketPanelEditView

struct TicketPanelEditView: View {
    var existingPanel: TicketPanel?
    let guildId: String
    let onSave: (TicketPanel) -> Void

    @Environment(\.services)    private var services
    @Environment(\.dismiss)     private var dismiss
    @Environment(AppState.self) private var appState

    // ── フィールド ──
    @State private var title             = "サポートチケット"
    @State private var description       = "ボタンをクリックしてチケットを開きます。\nスタッフが迅速に対応します。"
    @State private var buttonLabel       = "チケットを作成"
    @State private var buttonEmoji       = "🎫"
    @State private var supportRoleId     = ""
    @State private var openCategoryId    = ""
    @State private var closedCategoryId  = ""
    @State private var ticketEmbedTitle  = "チケット"
    @State private var ticketMsgContent  = "{user.mention} さん、チケットを作成しました。\nスタッフが確認次第、対応いたします。\n\n**件名：** {subject}"
    @State private var maxOpenPerUser    = 1
    @State private var colorHex: UInt32  = 0x6366f1

    // ── データ ──
    @State private var roles: [DiscordRole] = []
    @State private var categories: [(id: String, name: String)] = []
    @State private var isLoading  = true
    @State private var isSaving   = false
    @State private var errorMessage: String? = nil

    private var isNew: Bool { existingPanel == nil }

    // ── プレビュー色 ──
    private var previewColor: Color { Color(uiColor: UIColor(hex: colorHex)) }

    // ── プリセットカラー ──
    private let colorPresets: [UInt32] = [0x6366f1, 0x10b981, 0xf59e0b, 0xef4444, 0x8b5cf6, 0x3b82f6]

    var body: some View {
        NavigationStack {
            Form {
                panelAppearanceSection
                panelPreviewSection      // ← パネルのプレビュー
                ticketSettingsSection
                welcomeMessageSection
                welcomeMessagePreviewSection // ← ウェルカムメッセージのプレビュー
                ticketEmbedSection

                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.captionRegular)
                    }
                }
            }
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
            .task { await loadData() }
        }
    }

    // MARK: - Sections

    // ── パネルの見た目 ──
    private var panelAppearanceSection: some View {
        Section {
            // タイトル（無料でも変更可）
            LabeledContent("タイトル") {
                TextField("サポートチケット", text: $title).multilineTextAlignment(.trailing)
            }

            // 説明・ボタン・カラー（Proのみ編集可）
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("説明").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    if !appState.isPro { Spacer(); Badge(text: "Pro", color: .accentOrange) }
                }
                TextEditor(text: $description)
                    .frame(minHeight: 60).scrollContentBackground(.hidden)
                    .disabled(!appState.isPro)
                    .foregroundStyle(appState.isPro ? Color.textPrimary : Color.textTertiary)
            }
            LabeledContent {
                TextField("チケットを作成", text: $buttonLabel).multilineTextAlignment(.trailing)
                    .disabled(!appState.isPro)
                    .foregroundStyle(appState.isPro ? Color.textPrimary : Color.textTertiary)
            } label: {
                HStack { Text("ボタンラベル"); if !appState.isPro { Badge(text: "Pro", color: .accentOrange) } }
            }
            LabeledContent {
                TextField("🎫", text: $buttonEmoji).multilineTextAlignment(.trailing)
                    .disabled(!appState.isPro)
                    .foregroundStyle(appState.isPro ? Color.textPrimary : Color.textTertiary)
            } label: {
                HStack { Text("ボタン絵文字"); if !appState.isPro { Badge(text: "Pro", color: .accentOrange) } }
            }
            HStack {
                Text("カラー")
                if !appState.isPro { Badge(text: "Pro", color: .accentOrange) }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(colorPresets, id: \.self) { hex in
                        ZStack {
                            Circle().fill(Color(uiColor: UIColor(hex: hex))).frame(width: 26, height: 26)
                                .opacity(appState.isPro ? 1 : 0.4)
                            if colorHex == hex {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            guard appState.isPro else { return }
                            withAnimation(.easeInOut(duration: 0.15)) { colorHex = hex }
                        }
                    }
                }
            }
        } header: { Text("パネルの見た目") }
          footer: { if !appState.isPro { Text("タイトル以外の変更はProプランで利用できます。") } }
    }

    // ── パネルプレビュー ──
    private var panelPreviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: .spacing12) {
                // Discord 風 embed プレビュー
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2).fill(previewColor).frame(width: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if !title.isEmpty {
                            Text(title).font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                        }
                        if !description.isEmpty {
                            Text(description).font(.captionRegular).foregroundStyle(Color.textSecondary)
                        }
                    }
                    .padding(.leading, 10).padding(.vertical, 10).padding(.trailing, 10)
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // ボタンプレビュー
                HStack(spacing: 6) {
                    Text("\(buttonEmoji) \(buttonLabel.isEmpty ? "ボタンラベル" : buttonLabel)")
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

    // ── チケット設定 ──
    private var ticketSettingsSection: some View {
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
                Picker("オープンカテゴリ", selection: $openCategoryId) {
                    Text("なし（デフォルト）").tag("")
                    ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                }
                Picker("クローズカテゴリ", selection: $closedCategoryId) {
                    Text("なし（そのまま）").tag("")
                    ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                }
            }
            Stepper("同時オープン上限：\(maxOpenPerUser)件", value: $maxOpenPerUser, in: 1...10)
        } header: { Text("チケット設定") }
          footer: {
              Text("サポートロール：チケットチャンネルに追加されるロール。\nオープン/クローズカテゴリ：チケット作成/クローズ時にチャンネルを移動するDiscordカテゴリ。")
          }
    }

    // ── ウェルカムメッセージ ──
    private var welcomeMessageSection: some View {
        Section {
            TextEditor(text: $ticketMsgContent)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
            // 変数チップ
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["{user.mention}", "{user.name}", "{subject}", "{ticket_id}"], id: \.self) { v in
                        Button { ticketMsgContent += v } label: {
                            Text(v).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentIndigo)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
        } header: { Text("チケット内ウェルカムメッセージ") }
          footer: { Text("チケットが作成されたとき、チャンネル内に表示されるメッセージ。変数を使うと実際の値に置き換えられます。") }
    }

    // ── ウェルカムメッセージ プレビュー（Discord風） ──
    private var welcomeMessagePreviewSection: some View {
        let msgPreview = ticketMsgContent
            .replacingOccurrences(of: "{user.mention}", with: "@SampleUser")
            .replacingOccurrences(of: "{user.name}",    with: "SampleUser")
            .replacingOccurrences(of: "{subject}",      with: "お問い合わせ内容")
            .replacingOccurrences(of: "{ticket_id}",    with: "abc123")
        let embedTitle = ticketEmbedTitle.isEmpty ? "チケット" : ticketEmbedTitle

        return Section {
            // Discord のチャット背景を模した暗めのコンテナ
            VStack(alignment: .leading, spacing: 0) {
                // チャンネルヘッダー
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                    Text("ticket-abc123")
                        .font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)

                Divider().opacity(0.3)

                // Bot メッセージ行
                HStack(alignment: .top, spacing: 10) {
                    // アバター
                    ZStack {
                        Circle().fill(previewColor).frame(width: 36, height: 36)
                        Text("🤖").font(.system(size: 16))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // ユーザー名 + 時刻
                        HStack(spacing: 6) {
                            Text("Noxy").font(.system(size: 13, weight: .semibold)).foregroundStyle(previewColor)
                            Text("BOT").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.accentIndigo).clipShape(RoundedRectangle(cornerRadius: 3))
                            Text("今日 12:00").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        }

                        // メッセージ本文
                        if !msgPreview.isEmpty {
                            Text(msgPreview)
                                .font(.captionRegular).foregroundStyle(Color.textPrimary)
                        }

                        // Embed カード
                        HStack(alignment: .top, spacing: 0) {
                            RoundedRectangle(cornerRadius: 2).fill(previewColor).frame(width: 3)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("🎫 \(embedTitle) #abc123")
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.textPrimary)
                                // フィールド
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("件名").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.textTertiary)
                                        Text("お問い合わせ内容").font(.captionSmall).foregroundStyle(Color.textPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("優先度").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.textTertiary)
                                        Text("medium").font(.captionSmall).foregroundStyle(Color.textPrimary)
                                    }
                                }
                            }
                            .padding(10)
                        }
                        .background(Color.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.border, lineWidth: 0.5))

                        // ボタン
                        HStack(spacing: 6) {
                            Text("🔒 チケットを閉じる")
                                .font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textSecondary)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.bgElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.border, lineWidth: 0.5))
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 5) {
                Image(systemName: "eye.fill").font(.captionSmall)
                Text("チケット内のプレビュー")
            }
        } footer: {
            Text("チケット作成時にチャンネル内に投稿されるメッセージのイメージです。変数はサンプル値で表示しています。")
        }
    }

    // ── チケット内埋め込み設定 ──
    private var ticketEmbedSection: some View {
        Section {
            LabeledContent("タイトル") {
                TextField("チケット", text: $ticketEmbedTitle).multilineTextAlignment(.trailing)
            }
        } header: { Text("チケット内埋め込みのタイトル") }
          footer: {
              Text("チケットチャンネルに投稿される埋め込みのタイトル接頭辞です。\n例：「チケット」→ 🎫 チケット #abc123")
          }
    }

    // MARK: - Load

    private func loadData() async {
        isLoading = true

        // カテゴリを含む全チャンネルを取得（Discord チャンネルタイプ 4 = カテゴリ）
        if let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)"),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            if let chs = try? JSONDecoder().decode([RawCh].self, from: data) {
                categories = chs.filter { $0.type == 4 }.map { ($0.id, $0.name) }
            }
        }

        roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []
        isLoading = false

        // 既存パネルの値をフォームに反映
        if let p = existingPanel {
            title            = p.title
            description      = p.description
            buttonLabel      = p.buttonLabel
            buttonEmoji      = p.buttonEmoji
            supportRoleId    = p.supportRoleId   ?? ""
            openCategoryId   = p.openCategoryId  ?? ""
            closedCategoryId = p.closedCategoryId ?? ""
            ticketMsgContent = p.ticketMsgContent ?? ""
            ticketEmbedTitle = p.ticketEmbedTitle
            maxOpenPerUser   = p.maxOpenPerUser
            colorHex         = UInt32(p.color)
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
            panel.color            = Int(colorHex)
            panel.supportRoleId    = supportRoleId.isEmpty    ? nil : supportRoleId
            panel.openCategoryId   = openCategoryId.isEmpty   ? nil : openCategoryId
            panel.closedCategoryId = closedCategoryId.isEmpty ? nil : closedCategoryId
            panel.ticketMsgContent = ticketMsgContent.isEmpty ? nil : ticketMsgContent
            panel.ticketEmbedTitle = ticketEmbedTitle
            panel.ticketEmbedColor = Int(colorHex)
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
