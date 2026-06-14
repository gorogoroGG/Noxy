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
    @State private var deletingItem: ReactionRoleItem? = nil
    @State private var toast: ToastMessage? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if isLoading {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(0..<3) { _ in
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Theme.Color.textTertiary.opacity(0.2))
                                            .frame(width: 100, height: 16)
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Theme.Color.textTertiary.opacity(0.15))
                                            .frame(width: 60, height: 12)
                                    }
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.Color.textTertiary.opacity(0.1))
                                        .frame(width: 200, height: 12)
                                }
                                .padding(Theme.Spacing.sm)
                                .background(Theme.Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.md)
                    }
                    .transition(.opacity)
                } else if items.isEmpty {
                    EmptyStateView(
                        icon: "hand.tap.fill",
                        title: "リアクションロールがありません",
                        description: "絵文字リアクションでロールを自動付与できます。",
                        actionTitle: "最初のロールを追加"
                    ) {
                        editingItem = nil
                        showEditor = true
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            SectionLabel(title: "リアクションロール")
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.top, Theme.Spacing.md)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                    ReactionRoleRow(
                                        item: item,
                                        onSend: { sendingItem = item },
                                        onEdit: { editingItem = item; showEditor = true },
                                        onDelete: { deletingItem = item }
                                    )
                                    
                                    if idx < items.count - 1 {
                                        Divider()
                                            .background(Theme.Color.line)
                                            .padding(.leading, Theme.Spacing.md)
                                    }
                                }
                            }
                            .background(Theme.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                        .padding(.bottom, Theme.Spacing.xxl)
                    }
                    .transition(.opacity)
                }
            }
            .background(Theme.Color.bg)

            if !isLoading {
                Button {
                    editingItem = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.Color.accentInk)
                        .frame(width: 56, height: 56)
                        .background(Theme.Color.accent)
                        .clipShape(Circle())
                }
                .padding(.trailing, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationTitle("リアクションロール")
        .navigationBarTitleDisplayMode(.large)
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
            .id(editingItem?.id ?? "new-reaction-role")
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
                toast = ToastMessage(type: .success, message: "Discordに送信しました")
            }
        }
        .overlay {
            if let deletingItem {
                ConfirmModal(
                    icon: "trash.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "削除しますか？",
                    message: "「\(deletingItem.title)」を削除します。この操作は元に戻せません。",
                    primaryLabel: "削除する",
                    primaryRole: .destructive,
                    onPrimary: {
                        Task { await deleteItem(deletingItem) }
                        self.deletingItem = nil
                    },
                    onCancel: { self.deletingItem = nil }
                )
            }
        }
        .toast($toast)
        .task { await load() }
        .onChange(of: appState.selectedGuildId) { _, _ in
            isLoading = true
            Task { await load() }
        }
    }

    private func load() async {
        guard !appState.selectedGuildId.isEmpty else {
            items = []
            isLoading = false
            return
        }
        // キャッシュから即座に表示（ちらつき防止）
        if let cached = appState.cachedReactionRoles[appState.selectedGuildId] {
            items = cached
            isLoading = false
        }
        // バックグラウンドで最新データを取得
        do {
            let fetched = try await services.reactionRoles.fetchAll(guildId: appState.selectedGuildId)
            items = fetched
            appState.cacheReactionRoles(fetched, for: appState.selectedGuildId)
        } catch {
            if appState.cachedReactionRoles[appState.selectedGuildId] == nil {
                items = []
            }
        }
        isLoading = false
    }

    private func deleteItem(_ item: ReactionRoleItem) async {
        try? await services.reactionRoles.delete(id: item.id)
        items.removeAll { $0.id == item.id }
        toast = ToastMessage(type: .info, message: "削除しました")
    }
}

// MARK: - Row

private struct ReactionRoleRow: View {
    let item: ReactionRoleItem
    let onSend: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var accentColor: Color {
        Color(uiColor: UIColor(hex: UInt32(max(0, item.embedColor))))
    }

    var body: some View {
        Button {
            onEdit()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                // 左カラーバー
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentColor)
                    .frame(width: 3, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(item.title.isEmpty ? "（タイトル未設定）" : item.title)
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // 状態バッジ
                        if !item.isPublished {
                            Text("未送信")
                                .font(Theme.Font.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Color.accent)
                        } else {
                            HStack(spacing: 4) {
                                StatusDot(color: Theme.Color.statusOK)
                                Text("設置済み")
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        }
                    }
                    
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: item.mode.icon)
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .frame(width: 14)
                        Text(item.mode.rawValue)
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textSecondary)
                        
                        if item.isPublished {
                            Text("·")
                                .foregroundStyle(Theme.Color.textTertiary)
                            Text("#\(item.channelName)")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        
                        if !item.pairs.isEmpty {
                            Text("·")
                                .foregroundStyle(Theme.Color.textTertiary)
                            Text("ロール\(item.pairs.count)件")
                                .font(Theme.Font.monoCap)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if !item.isPublished {
                Button {
                    onSend()
                } label: {
                    Label("送信", systemImage: "paperplane.fill")
                }
                .tint(Theme.Color.accent)
            }
            
            Button {
                onEdit()
            } label: {
                Label("編集", systemImage: "pencil")
            }
            .tint(Theme.Color.statusOK)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .contextMenu {
            if !item.isPublished {
                Button {
                    onSend()
                } label: {
                    Label("Discordに送信", systemImage: "paperplane.fill")
                }
            }
            Button {
                onEdit()
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
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
    @State private var showDiscardAlert    = false
    @State private var showDeleteConfirm   = false
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

    private var hasChanges: Bool {
        if let ex = existing {
            return internalTitle != ex.title
                || msgContent != ex.embedMessageContent
                || embedTitle != ex.embedTitle
                || embedDescription != ex.embedDescription
                || Int(embedColorHex) != ex.embedColor
                || pairs.map { $0.emoji + $0.roleId } != ex.pairs.map { $0.emoji + $0.roleId }
                || mode != ex.mode
        }
        return !internalTitle.isEmpty
            || !msgContent.isEmpty
            || embedTitle != "ロールを選択"
            || embedDescription != "リアクションを押してロールを取得してください。"
            || pairs.contains { !$0.emoji.isEmpty || !$0.roleId.isEmpty }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Theme.Spacing.md) {
                    // 内部名称
                    FormSection("基本設定", icon: "doc.text", isRequired: true) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            TextField("例：ゲームロール選択", text: $internalTitle)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textPrimary)
                                .focused($focusedField, equals: .internalTitle)
                                .padding(.vertical, Theme.Spacing.xs)
                        }
                    }

                    // Embed エディタ
                    embedEditor

                    // リアクション → ロール
                    reactionPairsSection

                    // モード
                    modeSection
                    
                    // 削除ボタン（既存の場合）
                    if existingId != nil {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("このリアクションロールを削除")
                            }
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Color.statusBad)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.never)
            .background(Theme.Color.bg)
            .navigationTitle(existingId == nil ? "リアクションロールを作成" : "編集")
            .navigationBarTitleDisplayMode(.inline)
            .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
                Button("破棄してキャンセル", role: .destructive) { dismiss() }
                Button("編集を続ける", role: .cancel) {}
            } message: {
                Text("保存されていない変更があります。")
            }
            .overlay {
                if showDeleteConfirm {
                    ConfirmModal(
                        icon: "trash.fill",
                        iconColor: Theme.Color.statusBad,
                        title: "削除しますか？",
                        message: "このリアクションロールを削除します。Discord上のメッセージは自動で削除されません。",
                        primaryLabel: "削除する",
                        primaryRole: .destructive,
                        onPrimary: {
                            Task { await delete() }
                            showDeleteConfirm = false
                        },
                        onCancel: { showDeleteConfirm = false }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        if hasChanges { showDiscardAlert = true }
                        else { dismiss() }
                    }
                    .foregroundStyle(Theme.Color.textSecondary)
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
                                .foregroundStyle(isValid ? Theme.Color.accent : Theme.Color.textTertiary)
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focusedField = nil }
                        .font(Theme.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Color.accent)
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
                        featureIcon: "hand.tap.fill",
                        featureTitle: "リアクションロール",
                        description: "Proプランでは無制限にリアクションを追加できます。認証・永続モードも利用可能です。",
                        proFeatures: [
                            ("arrow.clockwise", "リアクション数 無制限"),
                            ("checkmark.shield.fill", "認証モード（付与後に剥奪不可）"),
                            ("pin.fill", "永続モード（付与のみ）"),
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
        VStack(spacing: Theme.Spacing.sm) {
            // プレビュー
            FormSection("プレビュー", icon: "eye") {
                DiscordMessagePreview(
                    embed: EmbedData(
                        color: accentColor,
                        messageContent: msgContent.isEmpty ? nil : msgContent,
                        title: embedTitle.isEmpty ? nil : embedTitle,
                        description: embedDescription.isEmpty ? nil : embedDescription
                    ),
                    isCompact: true
                )
            }

            // 入力フィールド
            FormSection("Embed設定", icon: "rectangle.fill") {
                VStack(spacing: 0) {
                    // タイトル
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("タイトル".uppercased())
                            .font(Theme.Font.sectionLabel)
                            .tracking(Theme.sectionLabelTracking)
                            .foregroundStyle(Theme.Color.textTertiary)
                        TextField("ロールを選択", text: $embedTitle)
                            .font(Theme.Font.body)
                            .focused($focusedField, equals: .embedTitle)
                    }
                    Divider().background(Theme.Color.line).padding(.vertical, Theme.Spacing.sm)
                    // 説明
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("説明".uppercased())
                            .font(Theme.Font.sectionLabel)
                            .tracking(Theme.sectionLabelTracking)
                            .foregroundStyle(Theme.Color.textTertiary)
                        TextField("リアクションを押してロールを取得してください。", text: $embedDescription, axis: .vertical)
                            .font(Theme.Font.body)
                            .focused($focusedField, equals: .embedDesc)
                            .lineLimit(2...5)
                    }
                    Divider().background(Theme.Color.line).padding(.vertical, Theme.Spacing.sm)
                    // カラー
                    Button { showColorPicker = true } label: {
                        HStack {
                            Text("カラー".uppercased())
                                .font(Theme.Font.sectionLabel)
                                .tracking(Theme.sectionLabelTracking)
                                .foregroundStyle(Theme.Color.textTertiary)
                            Spacer()
                            Circle()
                                .fill(accentColor)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(Theme.Color.lineStrong, lineWidth: 1))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider().background(Theme.Color.line).padding(.vertical, Theme.Spacing.sm)
                    // メッセージ本文（任意）
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("メッセージ本文（任意）".uppercased())
                            .font(Theme.Font.sectionLabel)
                            .tracking(Theme.sectionLabelTracking)
                            .foregroundStyle(Theme.Color.textTertiary)
                        TextField("本文なし", text: $msgContent, axis: .vertical)
                            .font(Theme.Font.body)
                            .focused($focusedField, equals: .msgContent)
                            .lineLimit(1...3)
                    }
                }
            }
        }
    }

    // MARK: - リアクションペア

    private var reactionPairsSection: some View {
        FormSection("リアクション → ロール", icon: "arrow.right", isRequired: true) {
            VStack(spacing: Theme.Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(pairs.enumerated()), id: \.element.id) { idx, pair in
                        HStack(spacing: Theme.Spacing.sm) {
                            // 絵文字
                            Button {
                                rolePickerPairIndex = idx
                                showEmojiPicker = true
                            } label: {
                                if pair.emoji.isEmpty {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Theme.Color.accent)
                                        .frame(width: 44, height: 44)
                                        .background(Theme.Color.accentDim)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.Radius.button)
                                                .stroke(Theme.Color.accent, lineWidth: 1)
                                        )
                                } else {
                                    Text(pair.emoji)
                                        .font(.system(size: 22))
                                        .frame(width: 44, height: 44)
                                        .background(Theme.Color.accentDim)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.Radius.button)
                                                .stroke(Theme.Color.accent.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .buttonStyle(.plain)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.Color.textTertiary)

                            // ロール
                            Button {
                                rolePickerPairIndex = idx
                                showRolePicker = true
                            } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    if pair.roleName.isEmpty {
                                        Text("ロールを選択")
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                    } else {
                                        Circle()
                                            .fill(accentColor)
                                            .frame(width: 8, height: 8)
                                        Text("@\(pair.roleName)")
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.Color.textTertiary)
                                }
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.Color.surfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                            }
                            .buttonStyle(.plain)

                            // 削除
                            if pairs.count > 1 {
                                Button {
                                    pairs.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Theme.Color.statusBad.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                        
                        if idx < pairs.count - 1 {
                            Divider()
                                .background(Theme.Color.line)
                                .padding(.leading, 56)
                        }
                    }
                }

                let atFreeLimit = !appState.isPro && pairs.count >= 3
                Button {
                    if atFreeLimit { showProSheet = true }
                    else { pairs.append(ReactionPair(emoji: "", roleId: "", roleName: "")) }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(atFreeLimit ? Theme.Color.statusWarn : Theme.Color.accent)
                        Text(atFreeLimit ? "Proで追加" : "リアクションを追加")
                            .font(Theme.Font.body)
                            .foregroundStyle(atFreeLimit ? Theme.Color.statusWarn : Theme.Color.accent)
                        if atFreeLimit {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Color.statusWarn)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.plain)

                if atFreeLimit {
                    Text("無料プランは3つまで")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.statusWarn)
                }
            }
        }
    }

    // MARK: - モード

    private var modeSection: some View {
        FormSection("付与モード", icon: "gear") {
            VStack(spacing: 0) {
                ForEach(Array(ReactionMode.allCases.enumerated()), id: \.element) { idx, m in
                    let isAvailable = appState.isPro || m == .normal
                    Button {
                        if isAvailable { mode = m }
                        else { showProSheet = true }
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: m.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(mode == m ? Theme.Color.accent : Theme.Color.textTertiary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Text(m.rawValue)
                                        .font(Theme.Font.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(isAvailable ? Theme.Color.textPrimary : Theme.Color.textTertiary)
                                    if !isAvailable {
                                        Badge(text: "Pro", color: Theme.Color.statusWarn)
                                    }
                                }
                                Text(m.description)
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(Theme.Color.textTertiary)
                            }
                            Spacer()
                            if mode == m {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.Color.accent)
                                    .font(.system(size: 18))
                            }
                        }
                        .padding(.vertical, Theme.Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable)
                    .opacity(isAvailable ? 1 : 0.5)
                    
                    if idx < ReactionMode.allCases.count - 1 {
                        Divider()
                            .background(Theme.Color.line)
                            .padding(.leading, 40)
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
    
    private func delete() async {
        guard let existingId else { return }
        try? await services.reactionRoles.delete(id: existingId)
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
                    ScrollView {
                        VStack(spacing: Theme.Spacing.sm) {
                            SectionLabel(title: "送信先チャンネル")
                                .padding(.horizontal, Theme.Spacing.md)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(textChannels.enumerated()), id: \.element.id) { idx, ch in
                                    Button {
                                        guard publishingChannelId == nil else { return }
                                        Task { await publish(to: ch) }
                                    } label: {
                                        HStack(spacing: Theme.Spacing.sm) {
                                            Image(systemName: ch.type == .announcement ? "megaphone.fill" : "number")
                                                .font(Theme.Font.caption)
                                                .foregroundStyle(Theme.Color.textTertiary)
                                                .frame(width: 20)
                                            Text(ch.name)
                                                .font(Theme.Font.body)
                                                .foregroundStyle(Theme.Color.textPrimary)
                                            Spacer()
                                            if publishingChannelId == ch.id {
                                                ProgressView().scaleEffect(0.8)
                                            }
                                        }
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(publishingChannelId != nil)
                                    
                                    if idx < textChannels.count - 1 {
                                        Divider()
                                            .background(Theme.Color.line)
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .background(Theme.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                        .padding(.top, Theme.Spacing.md)
                    }
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle("送信先を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Theme.Color.textSecondary)
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
            ScrollView {
                VStack(spacing: Theme.Spacing.sm) {
                    SectionLabel(title: "ロール")
                        .padding(.horizontal, Theme.Spacing.md)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(selectableRoles.enumerated()), id: \.element.id) { idx, role in
                            Button {
                                onSelect(role)
                                dismiss()
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Circle()
                                        .fill(role.color == 0 ? Theme.Color.textTertiary
                                            : Color(uiColor: UIColor(hex: UInt32(bitPattern: Int32(role.color)))))
                                        .frame(width: 12, height: 12)
                                    Text("@\(role.name)")
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if idx < selectableRoles.count - 1 {
                                Divider()
                                    .background(Theme.Color.line)
                                    .padding(.leading, 40)
                            }
                        }
                    }
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.top, Theme.Spacing.md)
            }
            .background(Theme.Color.bg)
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
                                .background(selectedEmoji == emoji ? Theme.Color.accentDim : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Theme.Color.bg)
            .navigationTitle("絵文字を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } }
            }
        }
    }
}

// MARK: - Preview

#Preview("Dark") {
    NavigationStack { ReactionRolesView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { ReactionRolesView() }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
        .preferredColorScheme(.light)
}
