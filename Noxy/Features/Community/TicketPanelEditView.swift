import SwiftUI

// MARK: - TicketPanelEditView

struct TicketPanelEditView: View {
    /// nil = 新規作成、non-nil = 編集
    var existingPanel: TicketPanel?
    let guildId: String
    let onSave: (TicketPanel) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    // ── フィールド ──
    @State private var title          = "サポートチケット"
    @State private var description    = "ボタンをクリックしてチケットを開きます。\nスタッフが迅速に対応します。"
    @State private var buttonLabel    = "チケットを作成"
    @State private var buttonEmoji    = "🎫"
    @State private var selectedChannelId    = ""
    @State private var selectedChannelName  = ""
    @State private var supportRoleId        = ""
    @State private var openCategoryId       = ""
    @State private var closedCategoryId     = ""
    @State private var ticketEmbedTitle     = "チケット"
    @State private var ticketMsgContent     = "{user.mention} さん、チケットを作成しました。\nスタッフが確認次第、対応いたします。\n\n**件名：**{subject}"
    @State private var maxOpenPerUser       = 1
    @State private var colorHex: UInt32     = 0x6366f1

    // ── ロード状態 ──
    @State private var channels: [Channel] = []
    @State private var roles: [DiscordRole] = []
    @State private var isLoading  = true
    @State private var isSaving   = false
    @State private var errorMessage: String? = nil

    private var isNew: Bool { existingPanel == nil }

    // カテゴリ（type == 4 は Discord のカテゴリチャンネル）
    // DiscordService.fetchChannels は type 4 を除外するため、Worker の /bot/channels から直接取る
    @State private var rawChannels: [(id: String, name: String, type: Int)] = []
    private var textChannels:   [(id: String, name: String)] { rawChannels.filter { $0.type == 0 || $0.type == 5 }.map { ($0.id, $0.name) } }
    private var categories:     [(id: String, name: String)] { rawChannels.filter { $0.type == 4 }.map { ($0.id, $0.name) } }
    private var selectableRoles: [DiscordRole] { roles.filter { $0.name != "@everyone" && !$0.managed } }

    var body: some View {
        NavigationStack {
            Form {
                // ── パネルの見た目 ──
                Section {
                    LabeledContent("タイトル") {
                        TextField("サポートチケット", text: $title)
                            .multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("説明").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        TextEditor(text: $description)
                            .frame(minHeight: 70)
                            .scrollContentBackground(.hidden)
                    }
                    LabeledContent("ボタンラベル") {
                        TextField("チケットを作成", text: $buttonLabel)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("ボタン絵文字") {
                        TextField("🎫", text: $buttonEmoji)
                            .multilineTextAlignment(.trailing)
                    }
                    colorRow
                } header: { Text("パネルの見た目") }

                // ── 投稿先チャンネル ──
                Section {
                    if isLoading {
                        HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                    } else {
                        Picker("投稿チャンネル", selection: $selectedChannelId) {
                            Text("未設定").tag("")
                            ForEach(textChannels, id: \.id) { Text("#\($0.name)").tag($0.id) }
                        }
                    }
                } header: { Text("投稿先") }
                  footer: { Text("このチャンネルにパネルメッセージが投稿されます。") }

                // ── チケット設定 ──
                Section {
                    if isLoading {
                        HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                    } else {
                        Picker("サポートロール", selection: $supportRoleId) {
                            Text("なし").tag("")
                            ForEach(selectableRoles) { Text("@\($0.name)").tag($0.id) }
                        }
                        Picker("オープンカテゴリ", selection: $openCategoryId) {
                            Text("なし").tag("")
                            ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                        }
                        Picker("クローズカテゴリ", selection: $closedCategoryId) {
                            Text("なし").tag("")
                            ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                        }
                    }
                    Stepper("同時オープン上限: \(maxOpenPerUser)件", value: $maxOpenPerUser, in: 1...10)
                } header: { Text("チケット設定") }

                // ── ウェルカムメッセージ ──
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        TextEditor(text: $ticketMsgContent)
                            .frame(minHeight: 90)
                            .scrollContentBackground(.hidden)
                        variableChips
                    }
                } header: { Text("チケット内ウェルカムメッセージ") }
                  footer: { Text("変数: {user.mention} {user.name} {subject} {ticket_id}") }

                // ── チケット内埋め込み ──
                Section {
                    LabeledContent("タイトル") {
                        TextField("チケット", text: $ticketEmbedTitle)
                            .multilineTextAlignment(.trailing)
                    }
                } header: { Text("チケット内埋め込み") }

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
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(title.isEmpty ? Color.textTertiary : Color.accentIndigo)
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .task { await loadData() }
        }
    }

    // MARK: - Color Row

    private var colorRow: some View {
        HStack {
            Text("カラー")
            Spacer()
            HStack(spacing: 8) {
                ForEach([0x6366f1, 0x10b981, 0xf59e0b, 0xef4444, 0x8b5cf6, 0x3b82f6] as [UInt32], id: \.self) { hex in
                    Circle()
                        .fill(Color(uiColor: UIColor(hex: hex)))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(colorHex == hex ? .white : .clear, lineWidth: 2.5))
                        .onTapGesture { colorHex = hex }
                }
            }
        }
    }

    // MARK: - Variable Chips

    private let panelVars = ["{user.mention}", "{user.name}", "{subject}", "{ticket_id}"]

    private var variableChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(panelVars, id: \.self) { v in
                    Button { ticketMsgContent += v } label: {
                        Text(v).font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentIndigo)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentIndigo.opacity(0.1))
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Load

    private func loadData() async {
        isLoading = true
        // rawChannels（カテゴリを含む全チャンネル）
        if let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)"),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            if let chs = try? JSONDecoder().decode([RawCh].self, from: data) {
                rawChannels = chs.map { ($0.id, $0.name, $0.type) }
            }
        }
        // ロール
        roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []
        isLoading = false

        // 既存パネルの値をフォームに反映
        if let p = existingPanel {
            title             = p.title
            description       = p.description
            buttonLabel       = p.buttonLabel
            buttonEmoji       = p.buttonEmoji
            selectedChannelId = p.channelId
            supportRoleId     = p.supportRoleId ?? ""
            openCategoryId    = p.openCategoryId ?? ""
            closedCategoryId  = p.closedCategoryId ?? ""
            ticketMsgContent  = p.ticketMsgContent ?? ""
            ticketEmbedTitle  = p.ticketEmbedTitle
            maxOpenPerUser    = p.maxOpenPerUser
            colorHex          = UInt32(p.color)
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var panel = existingPanel ?? TicketPanel.blank(guildId: guildId)
            panel.title             = title
            panel.description       = description
            panel.buttonLabel       = buttonLabel
            panel.buttonEmoji       = buttonEmoji
            panel.channelId         = selectedChannelId
            panel.color             = Int(colorHex)
            panel.supportRoleId     = supportRoleId.isEmpty  ? nil : supportRoleId
            panel.openCategoryId    = openCategoryId.isEmpty ? nil : openCategoryId
            panel.closedCategoryId  = closedCategoryId.isEmpty ? nil : closedCategoryId
            panel.ticketMsgContent  = ticketMsgContent.isEmpty ? nil : ticketMsgContent
            panel.ticketEmbedTitle  = ticketEmbedTitle
            panel.ticketEmbedColor  = Int(colorHex)
            panel.maxOpenPerUser    = maxOpenPerUser

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
