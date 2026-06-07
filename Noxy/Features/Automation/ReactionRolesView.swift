import SwiftUI

// MARK: - Models

enum ReactionMode: String, CaseIterable, Codable {
    case normal    = "通常"
    case verify    = "認証"
    case permanent = "永続"

    var description: String {
        switch self {
        case .normal:    "タップで付与/剥奪"
        case .verify:    "1回付与で剥奪不可"
        case .permanent: "付与のみ・剥奪不可"
        }
    }

    var icon: String {
        switch self {
        case .normal:    "arrow.2.squarepath"
        case .verify:    "checkmark.shield.fill"
        case .permanent: "pin.fill"
        }
    }
}

struct ReactionRoleItem: Identifiable, Codable {
    var id: String
    var title: String
    var channelId: String
    var channelName: String
    var messageId: String?
    var pairs: [ReactionPair]
    var mode: ReactionMode
    var guildId: String

    // インラインEmbed
    var embedTitle: String
    var embedDescription: String
    var embedColor: Int
    var embedMessageContent: String

    var isPublished: Bool { !(messageId ?? "").isEmpty }

    var embedData: EmbedData {
        EmbedData(
            color: Color(uiColor: UIColor(hex: UInt32(max(0, embedColor)))),
            messageContent: embedMessageContent.isEmpty ? nil : embedMessageContent,
            title: embedTitle.isEmpty ? nil : embedTitle,
            description: embedDescription.isEmpty ? nil : embedDescription
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, title, channelId, channelName, messageId, pairs, mode, guildId
        case embedTitle, embedDescription, embedColor, embedMessageContent
        case embedId  // 旧フィールド：デコードのみ（無視）
    }

    static func blank(guildId: String) -> ReactionRoleItem {
        ReactionRoleItem(
            id: UUID().uuidString, title: "", channelId: "", channelName: "",
            messageId: nil, pairs: [ReactionPair(emoji: "", roleId: "", roleName: "")],
            mode: .normal, guildId: guildId,
            embedTitle: "ロールを選択", embedDescription: "リアクションを押してロールを取得してください。",
            embedColor: 0x6E5EE8, embedMessageContent: ""
        )
    }
}

extension ReactionRoleItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(String.self, forKey: .id)
        title               = try c.decode(String.self, forKey: .title)
        channelId           = try c.decode(String.self, forKey: .channelId)
        channelName         = try c.decode(String.self, forKey: .channelName)
        messageId           = try c.decodeIfPresent(String.self, forKey: .messageId)
        pairs               = try c.decode([ReactionPair].self, forKey: .pairs)
        mode                = try c.decode(ReactionMode.self, forKey: .mode)
        guildId             = try c.decode(String.self, forKey: .guildId)
        embedTitle          = try c.decodeIfPresent(String.self, forKey: .embedTitle) ?? ""
        embedDescription    = try c.decodeIfPresent(String.self, forKey: .embedDescription) ?? ""
        embedColor          = try c.decodeIfPresent(Int.self, forKey: .embedColor) ?? 0x6E5EE8
        embedMessageContent = try c.decodeIfPresent(String.self, forKey: .embedMessageContent) ?? ""
        _ = try? c.decodeIfPresent(String.self, forKey: .embedId)  // legacy
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                  forKey: .id)
        try c.encode(title,               forKey: .title)
        try c.encode(channelId,           forKey: .channelId)
        try c.encode(channelName,         forKey: .channelName)
        try c.encodeIfPresent(messageId,  forKey: .messageId)
        try c.encode(pairs,               forKey: .pairs)
        try c.encode(mode,                forKey: .mode)
        try c.encode(guildId,             forKey: .guildId)
        try c.encode(embedTitle,          forKey: .embedTitle)
        try c.encode(embedDescription,    forKey: .embedDescription)
        try c.encode(embedColor,          forKey: .embedColor)
        try c.encode(embedMessageContent, forKey: .embedMessageContent)
    }
}

struct ReactionPair: Identifiable, Codable {
    var id: UUID = UUID()
    var emoji: String
    var roleId: String
    var roleName: String
}

// MARK: - Discord Emoji Data

private let discordEmojis: [String] = [
    "👍","👎","👆","👇","👈","👉","👌","🤏","✌️","🤞","🤟","🤘","🤙",
    "❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔","💕","💖","💗",
    "😀","😃","😄","😁","😆","😅","🤣","😂","🙂","😊","😇","😍","🤩",
    "🎮","🎯","🎲","🎸","🎤","🎧","🎨","🎭","🎪","🎫","🎬","🎵","🎶",
    "✅","❌","⚠️","🚫","🔴","🟠","🟡","🟢","🔵","🟣","⚪","🟤","⭐",
    "🔥","💯","✨","🌟","💫","🎉","🎊","🏆","🥇","🥈","🥉","🏅","🎖️",
    "🔔","📣","📢","📌","📍","🔖","📎","📝","✏️","📊","📈","📉","🗂️",
    "🐱","🐶","🐭","🐹","🐰","🦊","🐻","🐼","🐨","🐯","🦁","🐮","🐷",
    "☀️","🌙","⭐","☁️","🌧️","❄️","🌈","🌊","🍀","🌸","🌺","🌻","🌹",
    "1️⃣","2️⃣","3️⃣","4️⃣","5️⃣","6️⃣","7️⃣","8️⃣","9️⃣","🔟","🔢",
    "🇯🇵","🇺🇸","🇬🇧","🇰🇷","🇨🇳","🇫🇷","🇩🇪","🏴","🇪🇸","🇮🇹",
]

// MARK: - List View

struct ReactionRolesView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState

    @State private var items: [ReactionRoleItem] = []
    @State private var isLoading = true
    @State private var showEditor = false
    @State private var editingItem: ReactionRoleItem? = nil
    @State private var sendingItem: ReactionRoleItem? = nil
    @State private var toast: ToastMessage? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    EmptyStateView(
                        icon: "heart.fill",
                        title: "リアクションロールがありません",
                        description: "絵文字リアクションでロールを自動付与できます。",
                        actionTitle: "最初のロールを追加"
                    ) {
                        editingItem = nil
                        showEditor = true
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: .spacing12) {
                            ForEach(items) { item in
                                ReactionRoleCard(
                                    item: item,
                                    onSend: { sendingItem = item },
                                    onEdit: { editingItem = item; showEditor = true },
                                    onDelete: { Task { await deleteItem(item) } }
                                )
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))

            if !isLoading {
                Button {
                    editingItem = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentPink)
                        .clipShape(Circle())
                        .shadow(color: Color.accentPink.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .padding(.trailing, .spacing20)
                .padding(.bottom, .spacing24)
            }
        }
        .navigationTitle("リアクションロール")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingItem = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showEditor, onDismiss: { Task { await load() } }) {
            ReactionRoleEditorView(
                existing: editingItem,
                guildId: appState.selectedGuildId
            ) { saved in
                if let idx = items.firstIndex(where: { $0.id == saved.id }) {
                    items[idx] = saved
                } else {
                    items.insert(saved, at: 0)
                }
                toast = ToastMessage(type: .success, message: "保存しました")
            }
        }
        .sheet(item: $sendingItem) { item in
            ChannelPickerForPublishView(
                item: item,
                guildId: appState.selectedGuildId
            ) { channelId, channelName, messageId in
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].channelId   = channelId
                    items[idx].channelName = channelName
                    items[idx].messageId   = messageId
                }
                toast = ToastMessage(type: .success, message: "Discordに送信しました 🎉")
            }
        }
        .toast($toast)
        .task { await load() }
        .onChange(of: appState.selectedGuildId) { Task { await load() } }
    }

    private func load() async {
        guard !appState.selectedGuildId.isEmpty else {
            items = []
            isLoading = false
            return
        }
        items = (try? await services.reactionRoles.fetchAll(guildId: appState.selectedGuildId)) ?? []
        isLoading = false
    }

    private func deleteItem(_ item: ReactionRoleItem) async {
        try? await services.reactionRoles.delete(id: item.id)
        items.removeAll { $0.id == item.id }
        toast = ToastMessage(type: .info, message: "削除しました")
    }
}

// MARK: - Card

private struct ReactionRoleCard: View {
    let item: ReactionRoleItem
    let onSend: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var accentColor: Color {
        Color(uiColor: UIColor(hex: UInt32(max(0, item.embedColor))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー
            HStack(spacing: .spacing12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: .spacing6) {
                        Text(item.title.isEmpty ? "（タイトル未設定）" : item.title)
                            .font(.bodyRegular).fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Badge(
                            text: item.mode.rawValue,
                            color: item.mode == .normal ? .accentIndigo
                                : (item.mode == .verify ? .accentOrange : .accentPink)
                        )
                    }
                    HStack(spacing: .spacing6) {
                        if item.isPublished {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentIndigo).font(.captionSmall)
                            Text("#\(item.channelName)")
                                .foregroundStyle(Color.textSecondary)
                        } else {
                            Image(systemName: "clock")
                                .foregroundStyle(Color.accentOrange).font(.captionSmall)
                            Text("未送信")
                                .foregroundStyle(Color.accentOrange)
                        }
                        if !item.pairs.isEmpty {
                            Text("·").foregroundStyle(Color.textTertiary)
                            Text("\(item.pairs.count)個のリアクション")
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    .font(.captionSmall)
                }
            }
            .padding(.horizontal, .spacing12)
            .padding(.top, .spacing10)

            // リアクション→ロール
            if !item.pairs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: .spacing8) {
                        ForEach(item.pairs) { pair in
                            HStack(spacing: .spacing4) {
                                Text(pair.emoji).font(.system(size: 16))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                                Text("@\(pair.roleName)")
                                    .font(.captionSmall)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .padding(.horizontal, .spacing8).padding(.vertical, .spacing4)
                            .background(Color.bgElevated)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, .spacing12)
                    .padding(.vertical, .spacing8)
                }
            }

            // Embedプレビュー（コンパクト）
            if !item.embedTitle.isEmpty || !item.embedDescription.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 3) {
                        if !item.embedTitle.isEmpty {
                            Text(item.embedTitle)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                        }
                        if !item.embedDescription.isEmpty {
                            Text(item.embedDescription)
                                .font(.captionSmall)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                }
                .background(Color.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.horizontal, .spacing12)
                .padding(.bottom, .spacing8)
            }

            Divider()

            // アクションボタン
            HStack(spacing: 0) {
                actionButton(label: "送信", icon: "paperplane.fill", color: Color.accentIndigo, action: onSend)
                Divider().frame(height: 24)
                actionButton(label: "編集", icon: "pencil", color: Color.textSecondary, action: onEdit)
                Divider().frame(height: 24)
                actionButton(label: "削除", icon: "trash", color: Color.accentPink, action: onDelete)
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.captionRegular)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacing8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editor

struct ReactionRoleEditorView: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss
    @Environment(AppState.self) private var appState

    let existing: ReactionRoleItem?
    let guildId: String
    let onSave: (ReactionRoleItem) -> Void

    // Embed フィールド
    @State private var internalTitle: String
    @State private var msgContent: String
    @State private var embedTitle: String
    @State private var embedDescription: String
    @State private var embedColorHex: UInt32
    @State private var pairs: [ReactionPair]
    @State private var mode: ReactionMode

    // UI State
    @State private var roles: [DiscordRole] = []
    @State private var showColorPicker     = false
    @State private var showEmojiPicker     = false
    @State private var showRolePicker      = false
    @State private var rolePickerPairIndex = 0
    @State private var isSaving            = false
    @State private var showProSheet        = false
    @FocusState private var focusedField: FieldFocus?

    private let existingId: String?

    enum FieldFocus: Hashable {
        case internalTitle, msgContent, embedTitle, embedDesc
    }

    init(existing: ReactionRoleItem?, guildId: String, onSave: @escaping (ReactionRoleItem) -> Void) {
        self.existing  = existing
        self.guildId   = guildId
        self.onSave    = onSave
        existingId     = existing?.id
        _internalTitle = State(initialValue: existing?.title ?? "")
        _msgContent    = State(initialValue: existing?.embedMessageContent ?? "")
        _embedTitle    = State(initialValue: existing?.embedTitle ?? "ロールを選択")
        _embedDescription = State(initialValue: existing?.embedDescription ?? "リアクションを押してロールを取得してください。")
        _embedColorHex = State(initialValue: UInt32(max(0, existing?.embedColor ?? 0x6E5EE8)))
        _pairs         = State(initialValue: existing?.pairs ?? [ReactionPair(emoji: "", roleId: "", roleName: "")])
        _mode          = State(initialValue: existing?.mode ?? .normal)
    }

    private var accentColor: Color { Color(uiColor: UIColor(hex: embedColorHex)) }

    private var isValid: Bool {
        !internalTitle.isEmpty
        && !pairs.isEmpty
        && pairs.allSatisfy { !$0.emoji.isEmpty && !$0.roleId.isEmpty }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .spacing16) {
                    // 内部名称
                    Card {
                        VStack(alignment: .leading, spacing: .spacing6) {
                            Text("内部名称")
                                .font(.captionSmall).fontWeight(.semibold)
                                .foregroundStyle(Color.textTertiary).textCase(.uppercase)
                            TextField("例：ゲームロール選択", text: $internalTitle)
                                .font(.bodySmall)
                                .focused($focusedField, equals: .internalTitle)
                        }
                    }

                    // Discord スタイルEmbedエディタ
                    embedEditor

                    // リアクション → ロール
                    reactionPairsSection

                    // モード
                    modeSection
                }
                .padding(.spacing16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.never)
            .background(Color.bgPrimary)
            .navigationTitle(existingId == nil ? "リアクションロールを作成" : "編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                                .foregroundStyle(isValid ? accentColor : Color.textTertiary)
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focusedField = nil }
                        .font(.captionRegular).fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                }
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedHex: $embedColorHex)
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: Binding(
                    get: { pairs.indices.contains(rolePickerPairIndex) ? pairs[rolePickerPairIndex].emoji : "" },
                    set: { if pairs.indices.contains(rolePickerPairIndex) { pairs[rolePickerPairIndex].emoji = $0 } }
                ))
            }
            .sheet(isPresented: $showRolePicker) {
                RolePickerView(roles: roles) { role in
                    if pairs.indices.contains(rolePickerPairIndex) {
                        pairs[rolePickerPairIndex].roleId   = role.id
                        pairs[rolePickerPairIndex].roleName = role.name
                    }
                }
            }
            .sheet(isPresented: $showProSheet) {
                NavigationStack {
                    ProUpgradeView(
                        featureIcon: "heart.fill",
                        featureTitle: "リアクションロール",
                        description: "Proプランでは無制限にリアクションを追加できます。認証・永続モードも利用可能です。",
                        proFeatures: [
                            ("♾️", "リアクション数 無制限"),
                            ("🔐", "認証モード（付与後に剥奪不可）"),
                            ("📌", "永続モード（付与のみ）"),
                        ]
                    )
                }
            }
        }
        .task {
            roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []
        }
    }

    // MARK: - Embed エディタ

    private var embedEditor: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: .spacing12) {
                // Bot アバター
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPink],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: .spacing4) {
                    // ヘッダー
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

                    // メッセージ本文
                    ZStack(alignment: .topLeading) {
                        if msgContent.isEmpty {
                            Text("メッセージを入力...（任意）")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)
                                .padding(.top, 8).padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $msgContent)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .frame(minHeight: 40, maxHeight: 80)
                            .focused($focusedField, equals: .msgContent)
                    }
                    .padding(2)
                    .embedDashedBorder(focused: focusedField == .msgContent)

                    // Embed ブロック
                    HStack(alignment: .top, spacing: 0) {
                        // 左カラーバー（タップでカラー変更）
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(width: 4)
                            .onTapGesture { showColorPicker = true }

                        VStack(alignment: .leading, spacing: .spacing8) {
                            // Embed タイトル
                            TextField("タイトル", text: $embedTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accentColor)
                                .textFieldStyle(.plain)
                                .background(.clear)
                                .focused($focusedField, equals: .embedTitle)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .embedDashedBorder(focused: focusedField == .embedTitle)

                            // Embed 説明
                            ZStack(alignment: .topLeading) {
                                if embedDescription.isEmpty {
                                    Text("説明")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textTertiary)
                                        .padding(.top, 8).padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $embedDescription)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                                    .frame(minHeight: 50, maxHeight: 120)
                                    .focused($focusedField, equals: .embedDesc)
                            }
                            .padding(2)
                            .embedDashedBorder(focused: focusedField == .embedDesc)
                        }
                        .padding(.spacing10)
                    }
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // カラー設定
            HStack(spacing: .spacing12) {
                Button { showColorPicker = true } label: {
                    HStack(spacing: .spacing6) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.border, lineWidth: 1))
                        Text("Embedカラー")
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
                Spacer()
            }
            .padding(.top, .spacing10)
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - リアクションペア

    private var reactionPairsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: .spacing12) {
                Text("リアクション → ロール")
                    .font(.captionSmall).fontWeight(.semibold)
                    .foregroundStyle(Color.textTertiary).textCase(.uppercase)

                VStack(spacing: .spacing8) {
                    ForEach(Array(pairs.enumerated()), id: \.element.id) { idx, pair in
                        HStack(spacing: .spacing10) {
                            // 絵文字
                            Button {
                                rolePickerPairIndex = idx
                                showEmojiPicker = true
                            } label: {
                                Text(pair.emoji.isEmpty ? "😀" : pair.emoji)
                                    .font(.system(size: 22))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        pair.emoji.isEmpty
                                            ? Color.bgElevated
                                            : accentColor.opacity(0.12)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                pair.emoji.isEmpty ? Color.border : accentColor.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)

                            // ロール
                            Button {
                                rolePickerPairIndex = idx
                                showRolePicker = true
                            } label: {
                                HStack(spacing: .spacing6) {
                                    if pair.roleName.isEmpty {
                                        Text("ロールを選択")
                                            .font(.bodySmall)
                                            .foregroundStyle(Color.textTertiary)
                                    } else {
                                        Circle()
                                            .fill(accentColor)
                                            .frame(width: 8, height: 8)
                                        Text("@\(pair.roleName)")
                                            .font(.bodySmall)
                                            .foregroundStyle(Color.textPrimary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textTertiary)
                                }
                                .padding(.horizontal, .spacing10).padding(.vertical, .spacing10)
                                .background(Color.bgElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            // 削除
                            if pairs.count > 1 {
                                Button {
                                    pairs.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.accentPink.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                let atFreeLimit = !appState.isPro && pairs.count >= 3
                Button {
                    if atFreeLimit { showProSheet = true }
                    else { pairs.append(ReactionPair(emoji: "", roleId: "", roleName: "")) }
                } label: {
                    HStack(spacing: .spacing6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(atFreeLimit ? Color.accentOrange : accentColor)
                        Text(atFreeLimit ? "Proで追加" : "リアクションを追加")
                            .font(.bodySmall)
                            .foregroundStyle(atFreeLimit ? Color.accentOrange : accentColor)
                        if atFreeLimit {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentOrange)
                        }
                    }
                }
                .buttonStyle(.plain)

                if atFreeLimit {
                    Text("無料プランは3つまで")
                        .font(.captionSmall)
                        .foregroundStyle(Color.accentOrange)
                }
            }
        }
    }

    // MARK: - モード

    private var modeSection: some View {
        Card {
            VStack(alignment: .leading, spacing: .spacing12) {
                Text("付与モード")
                    .font(.captionSmall).fontWeight(.semibold)
                    .foregroundStyle(Color.textTertiary).textCase(.uppercase)

                VStack(spacing: .spacing8) {
                    ForEach(ReactionMode.allCases, id: \.self) { m in
                        let isAvailable = appState.isPro || m == .normal
                        Button {
                            if isAvailable { mode = m }
                            else { showProSheet = true }
                        } label: {
                            HStack(spacing: .spacing12) {
                                Image(systemName: m.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(mode == m ? accentColor : Color.textTertiary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: .spacing6) {
                                        Text(m.rawValue)
                                            .font(.bodySmall).fontWeight(.medium)
                                            .foregroundStyle(isAvailable ? Color.textPrimary : Color.textTertiary)
                                        if !isAvailable {
                                            Badge(text: "Pro", color: .accentOrange)
                                        }
                                    }
                                    Text(m.description)
                                        .font(.captionSmall)
                                        .foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                                if mode == m {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(accentColor)
                                        .font(.system(size: 18))
                                }
                            }
                            .padding(.spacing10)
                            .background(mode == m ? accentColor.opacity(0.08) : Color.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(!isAvailable)
                        .opacity(isAvailable ? 1 : 0.5)
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        let item = ReactionRoleItem(
            id: existingId ?? UUID().uuidString,
            title: internalTitle,
            channelId: existing?.channelId ?? "",
            channelName: existing?.channelName ?? "",
            messageId: existing?.messageId,
            pairs: pairs.filter { !$0.emoji.isEmpty && !$0.roleId.isEmpty },
            mode: mode,
            guildId: guildId,
            embedTitle: embedTitle,
            embedDescription: embedDescription,
            embedColor: Int(embedColorHex),
            embedMessageContent: msgContent
        )
        let saved: ReactionRoleItem
        if existingId != nil {
            saved = (try? await services.reactionRoles.update(item)) ?? item
        } else {
            saved = (try? await services.reactionRoles.create(item)) ?? item
        }
        onSave(saved)
        isSaving = false
        dismiss()
    }
}

// MARK: - Channel Picker for Publish

private struct ChannelPickerForPublishView: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    let item: ReactionRoleItem
    let guildId: String
    let onPublished: (String, String, String) -> Void

    @State private var channels: [Channel] = []
    @State private var isLoading = true
    @State private var publishingChannelId: String? = nil
    @State private var errorMessage = ""
    @State private var showError = false

    private var textChannels: [Channel] {
        channels.filter { $0.type == .text || $0.type == .announcement }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("チャンネルを読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if textChannels.isEmpty {
                    EmptyStateView(
                        icon: "number",
                        title: "チャンネルが見つかりません",
                        description: "Botが参加しているサーバーのチャンネルを確認してください。",
                        actionTitle: nil
                    ) {}
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(textChannels) { ch in
                                Button {
                                    guard publishingChannelId == nil else { return }
                                    Task { await publish(to: ch) }
                                } label: {
                                    HStack(spacing: .spacing12) {
                                        Image(systemName: ch.type == .announcement ? "megaphone.fill" : "number")
                                            .font(.captionRegular)
                                            .foregroundStyle(Color.textTertiary)
                                            .frame(width: 20)
                                        Text(ch.name).foregroundStyle(Color.textPrimary)
                                        Spacer()
                                        if publishingChannelId == ch.id {
                                            ProgressView().scaleEffect(0.8)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                                .disabled(publishingChannelId != nil)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("「\(item.title)」を送信するチャンネルを選択")
                                Text("選択したチャンネルにEmbedが投稿され、絵文字が追加されます")
                                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("送信先を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                        .disabled(publishingChannelId != nil)
                }
            }
            .alert("送信に失敗しました", isPresented: $showError) {
                Button("OK") {}
            } message: { Text(errorMessage) }
        }
        .task {
            channels = (try? await services.guilds.fetchChannels(guildId: guildId)) ?? []
            isLoading = false
        }
    }

    private func publish(to channel: Channel) async {
        publishingChannelId = channel.id
        do {
            let url = URL(string: "\(DiscordConfig.workerURL)/bot/reaction-roles/publish")!
            var req = URLRequest(url: url, timeoutInterval: 30)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "reactionRoleId": item.id,
                "channelId": channel.id,
                "channelName": channel.name,
                "guildId": guildId
            ]
            req.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                errorMessage = String(data: data, encoding: .utf8) ?? "サーバーエラー"
                showError = true
                publishingChannelId = nil
                return
            }
            struct PublishResponse: Decodable { let messageId: String }
            let resp = try JSONDecoder().decode(PublishResponse.self, from: data)
            onPublished(channel.id, channel.name, resp.messageId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            publishingChannelId = nil
        }
    }
}

// MARK: - Role Picker

private struct RolePickerView: View {
    let roles: [DiscordRole]
    let onSelect: (DiscordRole) -> Void
    @Environment(\.dismiss) private var dismiss

    private var selectableRoles: [DiscordRole] {
        roles.filter { $0.name != "@everyone" && !$0.managed }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(selectableRoles) { role in
                    Button {
                        onSelect(role)
                        dismiss()
                    } label: {
                        HStack(spacing: .spacing10) {
                            Circle()
                                .fill(role.color == 0 ? Color.textTertiary
                                    : Color(uiColor: UIColor(hex: UInt32(bitPattern: Int32(role.color)))))
                                .frame(width: 12, height: 12)
                            Text("@\(role.name)").foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ロールを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } }
            }
        }
    }
}

// MARK: - Emoji Picker

private struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(discordEmojis, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 44, height: 44)
                                .background(selectedEmoji == emoji ? Color.accentIndigo.opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("絵文字を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } }
            }
        }
    }
}

#Preview {
    NavigationStack { ReactionRolesView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
}
