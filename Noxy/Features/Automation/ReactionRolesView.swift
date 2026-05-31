import SwiftUI

// MARK: - Model

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
}

struct ReactionRoleItem: Identifiable, Codable {
    var id: String
    var title: String
    var embedId: String
    var channelId: String
    var channelName: String
    var pairs: [ReactionPair]
    var mode: ReactionMode
    var guildId: String

    static let empty = ReactionRoleItem(
        id: "", title: "", embedId: "", channelId: "",
        channelName: "", pairs: [], mode: .normal, guildId: ""
    )
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
    @State private var embeds: [EmbedModel] = []
    @State private var isLoading = true
    @State private var showEditor = false
    @State private var editingItem: ReactionRoleItem? = nil
    @State private var toast: ToastMessage? = nil
    @State private var showEmbedEditor = false

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
                                    embed: embeds.first(where: { $0.id == item.embedId }),
                                    onEdit: {
                                        editingItem = item
                                        showEditor = true
                                    },
                                    onDelete: {
                                        Task { await deleteItem(item) }
                                    }
                                )
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))

            if !isLoading && !items.isEmpty {
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
                embeds: embeds,
                existing: editingItem,
                guildId: appState.selectedGuildId
            ) { saved in
                if let idx = items.firstIndex(where: { $0.id == saved.id }) {
                    items[idx] = saved
                } else {
                    items.insert(saved, at: 0)
                }
                toast = ToastMessage(type: .success, message: "保存しました")
            } onCreateTemplate: {
                showEditor = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showEmbedEditor = true
                }
            }
        }
        .sheet(isPresented: $showEmbedEditor, onDismiss: { Task { await loadEmbeds() } }) {
            EmbedEditorView(embed: nil) { saved in
                embeds.append(saved)
            }
        }
        .toast($toast)
        .task { await load() }
        .onChange(of: appState.selectedGuildId) { Task { await load() } }
    }

    private func load() async {
        guard !appState.selectedGuildId.isEmpty else {
            items = []
            embeds = []
            isLoading = false
            return
        }
        items = (try? await services.reactionRoles.fetchAll(guildId: appState.selectedGuildId)) ?? []
        embeds = (try? await services.embeds.fetchAll()) ?? []
        isLoading = false
    }

    private func loadEmbeds() async {
        embeds = (try? await services.embeds.fetchAll()) ?? []
    }

    private func deleteItem(_ item: ReactionRoleItem) async {
        try? await services.reactionRoles.delete(id: item.id)
        items.removeAll { $0.id == item.id }
        toast = ToastMessage(type: .info, message: "削除しました")
    }
}

// MARK: - Card Row

private struct ReactionRoleCard: View {
    let item: ReactionRoleItem
    let embed: EmbedModel?
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var embedColor: Color {
        if let e = embed {
            return Color(uiColor: UIColor(hex: e.colorHex))
        }
        return .accentPink
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー
            HStack(spacing: .spacing12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(embedColor)
                    .frame(width: 4, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.bodyRegular)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: .spacing6) {
                        Text("#\(item.channelName)")
                            .foregroundStyle(Color.textSecondary)
                        Text("·")
                        Text("\(item.pairs.count)個のリアクション")
                            .foregroundStyle(Color.textTertiary)
                    }
                    .font(.captionSmall)
                }

                Spacer()

                Badge(text: item.mode.rawValue,
                      color: item.mode == .normal ? .accentIndigo
                        : (item.mode == .verify ? .accentOrange : .accentPink))
            }
            .padding(.horizontal, .spacing12)
            .padding(.vertical, .spacing10)

            // リアクション→ロール マッピング
            if !item.pairs.isEmpty {
                VStack(alignment: .leading, spacing: .spacing6) {
                    ForEach(item.pairs) { pair in
                        HStack(spacing: .spacing8) {
                            Text(pair.emoji)
                                .font(.system(size: 20))
                                .frame(width: 36)
                            Image(systemName: "arrow.right")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                            Text("@\(pair.roleName)")
                                .font(.captionRegular)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, .spacing12)
                .padding(.bottom, .spacing8)
            }

            // Embed プレビュー
            if let embed {
                EmbedPreviewCard(embed: .from(embed))
                    .padding(.horizontal, .spacing12)
                    .padding(.bottom, .spacing10)
            }

            Divider().background(Color.border)

            // アクションボタン
            HStack(spacing: 0) {
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing8)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 24)

                Button(action: onDelete) {
                    Label("削除", systemImage: "trash")
                        .font(.captionRegular)
                        .foregroundStyle(Color.accentPink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

// MARK: - Editor

struct ReactionRoleEditorView: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    let embeds: [EmbedModel]
    let existing: ReactionRoleItem?
    let guildId: String
    let onSave: (ReactionRoleItem) -> Void
    let onCreateTemplate: () -> Void

    @State private var title: String
    @State private var embedId: String
    @State private var channelId: String
    @State private var channelName: String
    @State private var pairs: [ReactionPair]
    @State private var mode: ReactionMode
    @State private var channels: [Channel] = []
    @State private var isLoadingChannels = true
    @State private var roles: [DiscordRole] = []
    @State private var showEmojiPicker = false
    @State private var showRolePicker = false
    @State private var rolePickerPairIndex = 0
    @State private var isSaving = false
    @State private var showCompletionModal = false
    @State private var savedItem: ReactionRoleItem? = nil

    private let existingId: String?

    init(embeds: [EmbedModel], existing: ReactionRoleItem?, guildId: String,
         onSave: @escaping (ReactionRoleItem) -> Void,
         onCreateTemplate: @escaping () -> Void) {
        self.embeds = embeds
        self.existing = existing
        self.guildId = guildId
        self.onSave = onSave
        self.onCreateTemplate = onCreateTemplate
        existingId = existing?.id
        _title = State(initialValue: existing?.title ?? "")
        _embedId = State(initialValue: existing?.embedId ?? (embeds.first?.id ?? ""))
        _channelId = State(initialValue: existing?.channelId ?? "")
        _channelName = State(initialValue: existing?.channelName ?? "")
        _pairs = State(initialValue: existing?.pairs ?? [ReactionPair(emoji: "", roleId: "", roleName: "")])
        _mode = State(initialValue: existing?.mode ?? .normal)
    }

    private var isValid: Bool {
        !title.isEmpty && !embedId.isEmpty && !channelId.isEmpty
            && !pairs.isEmpty && pairs.allSatisfy { !$0.emoji.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("リアクションロールのタイトル", text: $title)
                } header: { Text("タイトル") }

                Section {
                    Picker(selection: $embedId) {
                        Text("埋め込みメッセージを選択").tag("")
                        ForEach(embeds) { embed in
                            Text(embed.name).tag(embed.id)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.menu)

                    Button {
                        onCreateTemplate()
                    } label: {
                        Label("新規作成", systemImage: "plus.circle.fill")
                            .font(.bodySmall)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.accentIndigo)
                    }
                    .buttonStyle(.borderless)

                    if let embed = embeds.first(where: { $0.id == embedId }) {
                        EmbedPreviewCard(embed: .from(embed))
                            .padding(.vertical, .spacing4)
                    }
                } header: { Text("埋め込みメッセージ") }

                Section {
                    if isLoadingChannels {
                        ProgressView()
                    } else if channels.isEmpty {
                        Text("チャンネルを取得できませんでした")
                            .font(.bodySmall)
                            .foregroundStyle(Color.textTertiary)
                    } else {
                        ForEach(channels.filter { $0.type == .text || $0.type == .announcement }) { ch in
                            Button {
                                channelId = ch.id
                                channelName = ch.name
                            } label: {
                                HStack {
                                    Image(systemName: ch.type == .announcement ? "megaphone.fill" : "number")
                                        .font(.captionRegular)
                                        .foregroundStyle(Color.textTertiary)
                                        .frame(width: 20)
                                    Text(ch.name)
                                        .font(.bodyRegular)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    if channelId == ch.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentIndigo)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: { Text("送信先チャンネル") }

                Section {
                    ForEach(Array($pairs.enumerated()), id: \.element.id) { idx, $pair in
                        HStack(spacing: .spacing12) {
                            Button {
                                rolePickerPairIndex = idx
                                showEmojiPicker = true
                            } label: {
                                Text(pair.emoji.isEmpty ? "😀" : pair.emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 36)
                                    .background(Color.bgElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)

                            Image(systemName: "arrow.right")
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)

                            Button {
                                rolePickerPairIndex = idx
                                showRolePicker = true
                            } label: {
                                HStack {
                                    Text(pair.roleName.isEmpty ? "ロール" : "@\(pair.roleName)")
                                        .foregroundStyle(pair.roleName.isEmpty ? Color.textTertiary : Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.captionSmall)
                                        .foregroundStyle(Color.textTertiary)
                                }
                                .padding(.horizontal, .spacing10)
                                .padding(.vertical, 8)
                                .background(Color.bgElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete { pairs.remove(atOffsets: $0) }

                    Button {
                        pairs.append(ReactionPair(emoji: "", roleId: "", roleName: ""))
                    } label: {
                        Label("追加", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.accentPink)
                    }
                } header: { Text("リアクション → ロール") }

                Section {
                    Picker("モード", selection: $mode) {
                        ForEach(ReactionMode.allCases, id: \.self) { m in
                            Text("\(m.rawValue)（\(m.description)）").tag(m)
                        }
                    }
                } header: { Text("詳細") }
            }
            .navigationTitle(existingId == nil ? "新規作成" : "編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Text("完了")
                            .fontWeight(.semibold)
                            .foregroundStyle(isValid ? Color.accentIndigo : Color.textTertiary)
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: Binding(
                    get: { pairs.indices.contains(rolePickerPairIndex) ? pairs[rolePickerPairIndex].emoji : "" },
                    set: { new in
                        if pairs.indices.contains(rolePickerPairIndex) {
                            pairs[rolePickerPairIndex].emoji = new
                        }
                    }
                ))
            }
            .sheet(isPresented: $showRolePicker) {
                RolePickerView(roles: roles) { role in
                    if pairs.indices.contains(rolePickerPairIndex) {
                        pairs[rolePickerPairIndex].roleId = role.id
                        pairs[rolePickerPairIndex].roleName = role.name
                    }
                }
            }
            .confirmationDialog("完了しました", isPresented: $showCompletionModal, titleVisibility: .visible) {
                Button {
                    if let item = savedItem { sendToDiscord(item) }
                    dismiss()
                } label: {
                    Text("📨 保存して送信")
                }
                Button("保存のみ", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("#\(channelName) に送信しますか？")
            }
        }
        .task {
            async let chTask = services.guilds.fetchChannels(guildId: guildId)
            async let rolesTask = DiscordService().fetchRoles(guildId: guildId)
            channels = (try? await chTask) ?? []
            isLoadingChannels = false
            roles = (try? await rolesTask) ?? []
        }
    }

    private func save() {
        isSaving = true
        let item = ReactionRoleItem(
            id: existingId ?? UUID().uuidString,
            title: title,
            embedId: embedId,
            channelId: channelId,
            channelName: channelName,
            pairs: pairs.filter { !$0.emoji.isEmpty },
            mode: mode,
            guildId: guildId
        )
        Task {
            let saved: ReactionRoleItem
            if existingId != nil {
                saved = (try? await services.reactionRoles.update(item)) ?? item
            } else {
                saved = (try? await services.reactionRoles.create(item)) ?? item
            }
            savedItem = saved
            onSave(saved)
            isSaving = false
            showCompletionModal = true
        }
    }

    private func sendToDiscord(_ item: ReactionRoleItem) {
        Task {
            let msg = ScheduledMessage(
                id: UUID().uuidString,
                guildId: item.guildId,
                channelId: item.channelId,
                embedId: item.embedId,
                title: item.title,
                scheduledFor: Date(),
                repeatRule: .none,
                status: .pending,
                endDate: nil
            )
            _ = try? await services.scheduledMessages.create(msg)
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
                            Text("@\(role.name)")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ロールを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReactionRolesView()
    }
    .environment(\.services, ServiceContainer.live())
    .environment(AppState())
    .preferredColorScheme(.dark)
}
