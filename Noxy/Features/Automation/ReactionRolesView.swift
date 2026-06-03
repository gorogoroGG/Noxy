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
    var channelId: String      // 送信後に設定される
    var channelName: String    // 送信後に設定される
    var messageId: String?     // Discord上のメッセージID（送信後に設定）
    var pairs: [ReactionPair]
    var mode: ReactionMode
    var guildId: String

    var isPublished: Bool { !(messageId ?? "").isEmpty }

    static let empty = ReactionRoleItem(
        id: "", title: "", embedId: "", channelId: "",
        channelName: "", messageId: nil, pairs: [], mode: .normal, guildId: ""
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
    @State private var sendingItem: ReactionRoleItem? = nil
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
                                    onSend: {
                                        sendingItem = item
                                    },
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
        // 編集シート
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
        // Embed新規作成シート
        .sheet(isPresented: $showEmbedEditor, onDismiss: { Task { await loadEmbeds() } }) {
            EmbedEditorView(embed: nil) { saved in
                embeds.append(saved)
            }
        }
        // チャンネル選択・送信シート
        .sheet(item: $sendingItem) { item in
            ChannelPickerForPublishView(
                item: item,
                guildId: appState.selectedGuildId
            ) { channelId, channelName, messageId in
                // 送信成功 → ローカルのitemを更新
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].channelId = channelId
                    items[idx].channelName = channelName
                    items[idx].messageId = messageId
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
    let onSend: () -> Void
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
                        if item.isPublished {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentIndigo)
                                .font(.captionSmall)
                            Text("#\(item.channelName)")
                                .foregroundStyle(Color.textSecondary)
                        } else {
                            Image(systemName: "clock")
                                .foregroundStyle(Color.accentOrange)
                                .font(.captionSmall)
                            Text("未送信")
                                .foregroundStyle(Color.accentOrange)
                        }
                        Text("·")
                            .foregroundStyle(Color.textTertiary)
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

            // アクションボタン：[送信 | 編集 | 削除]
            HStack(spacing: 0) {
                Button(action: onSend) {
                    Label("送信", systemImage: "paperplane.fill")
                        .font(.captionRegular)
                        .foregroundStyle(Color.accentIndigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing8)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 24)

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

// MARK: - Channel Picker for Publish

private struct ChannelPickerForPublishView: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    let item: ReactionRoleItem
    let guildId: String
    let onPublished: (String, String, String) -> Void  // channelId, channelName, messageId

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
                                        Text(ch.name)
                                            .foregroundStyle(Color.textPrimary)
                                        Spacer()
                                        if publishingChannelId == ch.id {
                                            ProgressView()
                                                .scaleEffect(0.8)
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
                                    .font(.captionSmall)
                                    .foregroundStyle(Color.textTertiary)
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
            } message: {
                Text(errorMessage)
            }
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
                let msg = String(data: data, encoding: .utf8) ?? "サーバーエラー"
                errorMessage = msg
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

// MARK: - Editor（チャンネル選択なし・保存のみ）

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
    @State private var pairs: [ReactionPair]
    @State private var mode: ReactionMode
    @State private var roles: [DiscordRole] = []
    @State private var showEmojiPicker = false
    @State private var showRolePicker = false
    @State private var rolePickerPairIndex = 0
    @State private var isSaving = false

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
        _pairs = State(initialValue: existing?.pairs ?? [ReactionPair(emoji: "", roleId: "", roleName: "")])
        _mode = State(initialValue: existing?.mode ?? .normal)
    }

    private var isValid: Bool {
        !title.isEmpty && !embedId.isEmpty
            && !pairs.isEmpty
            && pairs.allSatisfy { !$0.emoji.isEmpty && !$0.roleId.isEmpty }
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

                // 送信は一覧画面から行う旨を案内
                Section {
                    HStack(spacing: .spacing10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.accentIndigo)
                        Text("保存後、一覧画面の「送信」ボタンからDiscordに投稿できます")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
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
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                                .foregroundStyle(isValid ? Color.accentIndigo : Color.textTertiary)
                        }
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
        }
        .task {
            roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []
        }
    }

    private func save() {
        isSaving = true
        let item = ReactionRoleItem(
            id: existingId ?? UUID().uuidString,
            title: title,
            embedId: embedId,
            channelId: existing?.channelId ?? "",     // 既存の送信先を保持
            channelName: existing?.channelName ?? "",
            messageId: existing?.messageId,            // 既存のmessageIdを保持
            pairs: pairs.filter { !$0.emoji.isEmpty && !$0.roleId.isEmpty },
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
            onSave(saved)
            isSaving = false
            dismiss()
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
}
