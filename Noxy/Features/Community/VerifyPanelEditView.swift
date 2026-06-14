import SwiftUI

// MARK: - Discord Permission Bits

enum DiscordChannelPerm: String, CaseIterable {
    case viewChannel      = "1024"
    case sendMessages     = "2048"
    case readHistory      = "65536"
    case connect          = "1048576"
    case speak            = "2097152"

    var label: String {
        switch self {
        case .viewChannel:  "チャンネルを見る"
        case .sendMessages: "メッセージを送る"
        case .readHistory:  "メッセージ履歴を読む"
        case .connect:      "ボイスチャンネルに接続"
        case .speak:        "ボイスで話す"
        }
    }
    var icon: String {
        switch self {
        case .viewChannel:  "eye.fill"
        case .sendMessages: "bubble.left.fill"
        case .readHistory:  "clock.fill"
        case .connect:      "headphones"
        case .speak:        "mic.fill"
        }
    }
}

// MARK: - VerifyPanelEditView

struct VerifyPanelEditView: View {
    var existing: VerifyPanel? = nil
    let guildId: String
    let onSave: (VerifyPanel) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    // 基本設定
    @State private var name = "認証"
    @State private var description = "下のボタンを押して認証を完了してください。"
    @State private var buttonLabel = "認証する"
    @State private var footerText = ""
    @State private var colorHex: UInt32 = 0x10b981
    @State private var enabled = true
    @State private var verifyType: VerifyType = .captcha
    @State private var reactionEmoji = "✅"
    @State private var showEmojiPicker = false
    @State private var manualChannelId = ""

    // ロール
    @State private var roleId = ""
    @State private var showCreateRole = false
    @State private var showEditRolePerms = false
    @State private var editingRoleId: String? = nil

    // データ
    @State private var roles: [DiscordRole] = []
    @State private var allChannels: [(id: String, name: String, type: Int, parentId: String?)] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showDiscardAlert = false

    // インライン編集プレビュー
    @FocusState private var previewFocus: PreviewFocus?
    @State private var showColorPicker = false

    enum PreviewFocus: Hashable { case title, description, footer, buttonLabel }

    private var isNew: Bool { existing == nil }
    private var previewColor: Color { Color(uiColor: UIColor(hex: colorHex)) }
    private var textChannels: [(id: String, name: String, type: Int, parentId: String?)] { allChannels.filter { $0.type == 0 } }

    private var hasChanges: Bool {
        guard let e = existing else { return true }
        return name != e.name || description != e.description || buttonLabel != e.buttonLabel ||
            roleId != e.roleId || footerText != e.footerText || colorHex != UInt32(e.color) ||
            enabled != e.enabled || verifyType != e.verifyType ||
            reactionEmoji != e.reactionEmoji || manualChannelId != (e.manualChannelId ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // カスタムツールバー
                HStack {
                    Button("キャンセル") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)

                    Spacer()

                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(name.isEmpty || roleId.isEmpty ? Theme.Color.textTertiary : Theme.Color.accent)
                        .disabled(name.isEmpty || roleId.isEmpty || isSaving)
                }
                .padding(.horizontal, .spacing16)
                .padding(.vertical, .spacing10)
                .background(Theme.Color.surface)
                .overlay(
                    Rectangle()
                        .fill(Theme.Color.line)
                        .frame(height: 1),
                    alignment: .bottom
                )

                Form {
                    editablePreviewSection
                    verifyTypeSection
                    roleSection
                    typeSpecificSection

                    if let err = errorMessage {
                        Section {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.statusWarn)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.Color.bg)
            }
            .navigationTitle(isNew ? "認証を設定" : "認証を編集")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
            .overlay {
                if showDiscardAlert {
                    ConfirmModal(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Theme.Color.statusWarn,
                        title: "変更を破棄しますか？",
                        message: "行った変更は保存されません。",
                        primaryLabel: "破棄する",
                        primaryRole: .destructive,
                        onPrimary: {
                            dismiss()
                            showDiscardAlert = false
                        },
                        onCancel: {
                            showDiscardAlert = false
                        }
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showCreateRole) {
                VerifyCreateRoleSheet(guildId: guildId, channels: allChannels, services: services) { created in
                    let newRole = DiscordRole(id: created.id, name: created.name,
                                              color: created.color, position: 0, managed: false)
                    roles.append(newRole)
                    roleId = created.id
                }
            }
            .sheet(isPresented: $showEditRolePerms) {
                if let roleId = editingRoleId, let role = roles.first(where: { $0.id == roleId }) {
                    EditRolePermissionsSheet(
                        guildId: guildId,
                        role: role,
                        channels: allChannels,
                        services: services
                    ) { success in
                        if success { errorMessage = nil }
                    }
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerSheet(selectedEmoji: $reactionEmoji)
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedHex: $colorHex)
            }
        }
    }

    // MARK: - Verify Type Section
    // Noxy: Card 内のリストアイテム。選択状態は accentColor + sur2 背景

    private var verifyTypeSection: some View {
        Section {
            VStack(spacing: .spacing8) {
                ForEach(VerifyType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { verifyType = type }
                    } label: {
                        HStack(spacing: .spacing12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(type.accentColor.opacity(verifyType == type ? 0.2 : 0.08))
                                    .frame(width: 36, height: 36)
                                Image(systemName: type.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(type.accentColor)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.label)
                                    .font(Theme.Font.bodyMedium)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                Text(type.description)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if verifyType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(type.accentColor)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .padding(.spacing10)
                        .background(verifyType == type ? Theme.Color.surfaceRaised : Theme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(verifyType == type ? type.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            SectionLabel(title: "認証方法")
                .padding(.horizontal, .spacing16)
        }
    }

    // MARK: - Editable Preview Section
    // Noxy: Discord プレビュー + sur 背景 + 14px 角丸 + line ボーダー

    @ViewBuilder
    private var editablePreviewSection: some View {
        Section {
            Toggle("パネルを有効にする", isOn: $enabled)
                .tint(Theme.Color.accent)
                .font(Theme.Font.body)
        } header: {
            SectionLabel(title: "基本設定")
                .padding(.horizontal, .spacing16)
        }

        Section {
            // Discord メッセージ風インライン編集プレビュー
            HStack(alignment: .top, spacing: .spacing10) {
                // Bot アバター
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Color.accent, Theme.Color.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Color.accentInk)
                }

                VStack(alignment: .leading, spacing: 5) {
                    // Bot ヘッダー
                    HStack(spacing: 5) {
                        Text("Noxy")
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Color.accent)
                        Badge(text: "BOT", color: Theme.Color.accent, style: .filled)
                        Text(Date(), style: .time)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }

                    // Embed ブロック
                    HStack(alignment: .top, spacing: 0) {
                        // カラーバー（タップでカラー変更）
                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewColor)
                            .frame(width: 4)
                            .onTapGesture { showColorPicker = true }

                        VStack(alignment: .leading, spacing: 8) {
                            // タイトル（インライン編集）
                            TextField("タイトル", text: $name)
                                .font(Theme.Font.bodyMedium)
                                .foregroundStyle(previewColor)
                                .textFieldStyle(.plain)
                                .focused($previewFocus, equals: .title)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .embedDashedBorder(focused: previewFocus == .title)

                            // 説明文（インライン編集）
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("説明文を入力...")
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.Color.textTertiary)
                                        .padding(.top, 6)
                                        .padding(.leading, 6)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $description)
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Color.textSecondary)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                                    .frame(minHeight: 52, maxHeight: .infinity)
                                    .focused($previewFocus, equals: .description)
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 1)
                            .embedDashedBorder(focused: previewFocus == .description)

                            // フッター（インライン編集）
                            TextField("フッターテキスト", text: $footerText)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textTertiary)
                                .textFieldStyle(.plain)
                                .focused($previewFocus, equals: .footer)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .embedDashedBorder(focused: previewFocus == .footer)
                        }
                        .padding(.spacing10)
                    }
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // ボタン / リアクション（インライン編集）
                    Group {
                        if verifyType == .reaction {
                            HStack(spacing: 4) {
                                Text(reactionEmoji.isEmpty ? "✅" : reactionEmoji)
                                    .font(.system(size: 16))
                                Text("1")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            TextField("ボタンのラベル", text: $buttonLabel)
                                .font(Theme.Font.bodyMedium)
                                .foregroundStyle(Theme.Color.accentInk)
                                .textFieldStyle(.plain)
                                .focused($previewFocus, equals: .buttonLabel)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(previewColor)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    // カラー変更ヒント
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Color.textTertiary)
                        Text("左のカラーバーをタップして色を変更")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Color.textTertiary)
                    }

                    HStack(spacing: 3) {
                        Text("*")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Color.statusBad)
                        Text("タイトルは必須項目です")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(Theme.Font.caption)
                Text("プレビュー（タップして編集）")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .padding(.horizontal, .spacing16)
        }
    }

    // MARK: - Role Section
    // Noxy: FormField + 標準 Picker

    private var roleSection: some View {
        Section {
            if isLoading {
                HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
            } else {
                Picker("認証後に付与するロール", selection: $roleId) {
                    Text("選択してください").tag("")
                    ForEach(roles.filter { !$0.managed && $0.name != "@everyone" }) {
                        Text("@\($0.name)").tag($0.id)
                    }
                }
                .font(Theme.Font.body)
                .pickerStyle(.menu)

                // 既存ロールの権限を編集
                if !roleId.isEmpty, let selectedRole = roles.first(where: { $0.id == roleId }) {
                    Button {
                        editingRoleId = roleId
                        showEditRolePerms = true
                    } label: {
                        Label("「@\(selectedRole.name)」の権限を編集", systemImage: "shield.lefthalf.filled")
                            .font(Theme.Font.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Color.accent)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showCreateRole = true
                } label: {
                    Label("新しいロールを作成して設定", systemImage: "plus.circle.fill")
                        .font(Theme.Font.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Color.accent)
                }
                .buttonStyle(.plain)
            }
        } header: {
            SectionLabel(title: "ロール設定", isRequired: true)
                .padding(.horizontal, .spacing16)
        } footer: {
            if roleId.isEmpty {
                Label("ロールを選択または作成しないとパネルを設置できません", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.statusWarn)
                    .padding(.horizontal, .spacing16)
            } else {
                Text("認証を通過したユーザーにこのロールが自動付与されます。「新しいロールを作成」でロールの権限も同時に設定できます。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .padding(.horizontal, .spacing16)
            }
        }
    }

    // MARK: - Type Specific Section

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch verifyType {
        case .reaction:
            Section {
                Button {
                    showEmojiPicker = true
                } label: {
                    HStack {
                        Text("認証絵文字")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Spacer()
                        Text(reactionEmoji.isEmpty ? "✅" : reactionEmoji)
                            .font(.system(size: 24))
                        Image(systemName: "chevron.down")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                SectionLabel(title: "リアクション設定")
                    .padding(.horizontal, .spacing16)
            } footer: {
                Text("パネルメッセージにこの絵文字でリアクションすることで認証されます。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .padding(.horizontal, .spacing16)
            }
        case .manual:
            Section {
                if isLoading {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                } else {
                    Picker("申請通知チャンネル", selection: $manualChannelId) {
                        Text("なし（アプリのみ）").tag("")
                        ForEach(textChannels, id: \.id) { ch in Text("#\(ch.name)").tag(ch.id) }
                    }
                    .font(Theme.Font.body)
                    .pickerStyle(.menu)
                }
            } header: {
                SectionLabel(title: "手動認証設定")
                    .padding(.horizontal, .spacing16)
            } footer: {
                Text("ユーザーが申請するとこのチャンネルに通知が届きます。アプリの「承認待ち」からも管理できます。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .padding(.horizontal, .spacing16)
            }
        case .captcha, .button:
            EmptyView()
        }
    }

    // MARK: - Load & Save

    private func loadData() async {
        isLoading = true
        async let rolesTask = DiscordService().fetchRoles(guildId: guildId)
        async let chTask: [(id: String, name: String, type: Int, parentId: String?)] = {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int; let parentId: String? }
            guard let chs = try? await WorkerClient().get("/bot/channels?guild_id=\(guildId)") as [RawCh] else { return [] }
            return chs.map { ($0.id, $0.name, $0.type, $0.parentId) }
        }()
        roles = (try? await rolesTask) ?? []
        allChannels = await chTask
        if let e = existing {
            name = e.name; description = e.description; buttonLabel = e.buttonLabel
            roleId = e.roleId; footerText = e.footerText; colorHex = UInt32(e.color)
            enabled = e.enabled; verifyType = e.verifyType; reactionEmoji = e.reactionEmoji
            manualChannelId = e.manualChannelId ?? ""
        }
        isLoading = false
    }

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var panel = existing ?? VerifyPanel.blank(guildId: guildId)
            panel.name = name; panel.description = description; panel.buttonLabel = buttonLabel
            panel.roleId = roleId; panel.footerText = footerText; panel.color = Int(colorHex)
            panel.enabled = enabled; panel.verifyType = verifyType; panel.reactionEmoji = reactionEmoji
            panel.manualChannelId = manualChannelId.isEmpty ? nil : manualChannelId

            let saved: VerifyPanel
            if isNew {
                saved = try await services.verify.createPanel(panel)
            } else {
                saved = try await services.verify.updatePanel(panel)
            }
            onSave(saved)
            dismiss()
        } catch let error as NSError {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)\n\nBotの権限とWorkerの稼働を確認してください。"
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

// MARK: - CategoryChannelGroup

private struct CategoryChannelGroup: Identifiable {
    let id: String
    let name: String
    var channels: [(id: String, name: String)]
}

private func buildCategoryGroups(from channels: [(id: String, name: String, type: Int, parentId: String?)]) -> [CategoryChannelGroup] {
    let cats = channels.filter { $0.type == 4 }
    let textChs = channels.filter { $0.type == 0 }
    let catIds = Set(cats.map { $0.id })
    var groups: [CategoryChannelGroup] = cats.compactMap { cat in
        let chs = textChs.filter { $0.parentId == cat.id }
        return chs.isEmpty ? nil : CategoryChannelGroup(id: cat.id, name: cat.name.uppercased(), channels: chs.map { ($0.id, $0.name) })
    }
    let uncategorized = textChs.filter { $0.parentId == nil || !catIds.contains($0.parentId ?? "") }
    if !uncategorized.isEmpty {
        groups.append(CategoryChannelGroup(id: "__none__", name: "カテゴリなし", channels: uncategorized.map { ($0.id, $0.name) }))
    }
    return groups
}

// MARK: - VerifyCreateRoleSheet

struct VerifyCreateRoleSheet: View {
    let guildId: String
    let channels: [(id: String, name: String, type: Int, parentId: String?)]
    let services: ServiceContainer
    let onCreate: (CreatedRole) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var roleName = "認証済み"
    @State private var colorHex: UInt32 = 0x10b981
    @State private var isCreating = false
    @State private var errorMessage: String? = nil
    @State private var allowedPerms: [String: Set<DiscordChannelPerm>] = [:]
    @State private var activePermTab: DiscordChannelPerm = .viewChannel

    private let colorPresets: [UInt32] = [0x10b981, 0x6366f1, 0xf59e0b, 0x3b82f6, 0x8b5cf6, 0xef4444]
    private var textChannels: [(id: String, name: String)] { channels.filter { $0.type == 0 }.map { ($0.id, $0.name) } }
    private var categoryGroups: [CategoryChannelGroup] { buildCategoryGroups(from: channels) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button("キャンセル") { dismiss() }
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Spacer()
                    Button(isCreating ? "作成中..." : "作成") { Task { await createRole() } }
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(roleName.isEmpty ? Theme.Color.textTertiary : Theme.Color.accent)
                        .disabled(roleName.isEmpty || isCreating)
                }
                .padding(.horizontal, .spacing16)
                .padding(.vertical, .spacing10)
                .background(Theme.Color.surface)
                .overlay(
                    Rectangle()
                        .fill(Theme.Color.line)
                        .frame(height: 1),
                    alignment: .bottom
                )

                ScrollView {
                    VStack(spacing: .spacing16) {
                        // ロール基本情報
                        Card(padding: .spacing12, background: Theme.Color.surface, showBorder: true) {
                            VStack(spacing: .spacing12) {
                                HStack {
                                    Text("ロール名")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                        .frame(width: 80, alignment: .leading)
                                    TextField("認証済み", text: $roleName)
                                        .font(Theme.Font.body)
                                        .padding(.horizontal, .spacing12)
                                        .padding(.vertical, .spacing8)
                                        .background(Theme.Color.surfaceRaised)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                HStack {
                                    Text("カラー")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                        .frame(width: 80, alignment: .leading)
                                    HStack(spacing: 8) {
                                        ForEach(colorPresets, id: \.self) { hex in
                                            ZStack {
                                                Circle()
                                                    .fill(Color(uiColor: UIColor(hex: hex)))
                                                    .frame(width: 28, height: 28)
                                                if colorHex == hex {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(Theme.Color.accentInk)
                                                }
                                            }
                                            .onTapGesture { withAnimation { colorHex = hex } }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, .spacing16)

                        // 権限設定
                        VStack(alignment: .leading, spacing: .spacing12) {
                            SectionLabel(title: "チャンネル権限")
                                .padding(.horizontal, .spacing16)

                            // 権限タブバー
                            permTabBar(textChannels: textChannels)

                            // カテゴリ別チャンネル
                            categoryPermGrid(textChannels: textChannels)
                        }

                        if let err = errorMessage {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.statusWarn)
                                .padding(.horizontal, .spacing16)
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, .spacing16)
                }
                .background(Theme.Color.bg)
            }
            .navigationTitle("ロールを作成")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func permTabBar(textChannels: [(id: String, name: String)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscordChannelPerm.allCases, id: \.self) { perm in
                    let count = categoryGroups.filter { allowedPerms[$0.id]?.contains(perm) == true }.count
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { activePermTab = perm }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: perm.icon)
                                .font(.system(size: 11))
                            Text(perm.label)
                                .font(Theme.Font.caption)
                                .fontWeight(activePermTab == perm ? .semibold : .regular)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.Color.accentInk)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Theme.Color.statusOK)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(activePermTab == perm ? Theme.Color.accent : Theme.Color.surfaceRaised)
                        .foregroundStyle(activePermTab == perm ? Theme.Color.accentInk : Theme.Color.textSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .spacing16)
        }
    }

    private func categoryPermGrid(textChannels: [(id: String, name: String)]) -> some View {
        VStack(alignment: .leading, spacing: .spacing16) {
            // 全選択/全解除
            HStack {
                Button {
                    for group in categoryGroups { allowedPerms[group.id, default: []].insert(activePermTab) }
                } label: {
                    Text("全選択")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.accent)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    for group in categoryGroups { allowedPerms[group.id]?.remove(activePermTab) }
                } label: {
                    Text("全解除")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, .spacing16)

            ForEach(categoryGroups) { group in
                categoryToggleButton(group: group)
            }
        }
    }

    private func categoryToggleButton(group: CategoryChannelGroup) -> some View {
        let isAllowed = allowedPerms[group.id]?.contains(activePermTab) == true
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isAllowed { allowedPerms[group.id]?.remove(activePermTab) }
                    else { allowedPerms[group.id, default: []].insert(activePermTab) }
                }
            } label: {
                HStack(spacing: .spacing12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isAllowed ? Theme.Color.statusOK.opacity(0.15) : Theme.Color.surfaceRaised)
                            .frame(width: 40, height: 40)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(isAllowed ? Theme.Color.statusOK : Theme.Color.textTertiary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(Theme.Font.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(isAllowed ? Theme.Color.statusOK : Theme.Color.textPrimary)
                        Text("\(group.channels.count)チャンネル")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isAllowed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isAllowed ? Theme.Color.statusOK : Theme.Color.textTertiary)
                        .font(.system(size: 20))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, .spacing16)
            .padding(.vertical, 8)

            // カテゴリ内チャンネル一覧（表示のみ）
            ForEach(group.channels, id: \.id) { ch in
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                    Text(ch.name)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Spacer()
                }
                .padding(.leading, 68)
                .padding(.vertical, 2)
            }
            .padding(.bottom, 8)
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, .spacing16)
    }

    private func createRole() async {
        guard !roleName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isCreating = true; errorMessage = nil
        let inputs: [ChannelPermissionInput] = categoryGroups.flatMap { group in
            let perms = allowedPerms[group.id] ?? []
            guard !perms.isEmpty else { return [ChannelPermissionInput]() }
            let allowValue = String(perms.map { Int64($0.rawValue)! }.reduce(0, |))
            return group.channels.map { ch in
                ChannelPermissionInput(channelId: ch.id, allow: allowValue, deny: "0")
            }
        }
        do {
            let created = try await services.verify.createRole(guildId: guildId, name: roleName.trimmingCharacters(in: .whitespaces), color: Int(colorHex), channelPermissions: inputs)
            onCreate(created); dismiss()
        } catch {
            errorMessage = "ロールの作成に失敗しました。Botの権限（ロール管理権限）を確認してください。"
        }
        isCreating = false
    }
}

// MARK: - EditRolePermissionsSheet

struct EditRolePermissionsSheet: View {
    let guildId: String
    let role: DiscordRole
    let channels: [(id: String, name: String, type: Int, parentId: String?)]
    let services: ServiceContainer
    let onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var allowedPerms: [String: Set<DiscordChannelPerm>] = [:]
    @State private var initialPerms: [String: Set<DiscordChannelPerm>] = [:]
    @State private var activePermTab: DiscordChannelPerm = .viewChannel
    @State private var showDiscardAlert = false

    private var textChannels: [(id: String, name: String)] { channels.filter { $0.type == 0 }.map { ($0.id, $0.name) } }
    private var categoryGroups: [CategoryChannelGroup] { buildCategoryGroups(from: channels) }
    private var hasChanges: Bool { allowedPerms != initialPerms }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー
                ZStack {
                    Text(role.name)
                        .font(Theme.Font.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                    HStack {
                        Button("キャンセル") {
                            if hasChanges { showDiscardAlert = true } else { dismiss() }
                        }
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                        Spacer()
                        Button(isSaving ? "保存中..." : "保存") { Task { await savePermissions() } }
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(isSaving ? Theme.Color.textTertiary : Theme.Color.accent)
                            .disabled(isSaving)
                    }
                }
                .padding(.horizontal, .spacing16)
                .padding(.vertical, .spacing10)
                .background(Theme.Color.surface)
                .overlay(
                    Rectangle()
                        .fill(Theme.Color.line)
                        .frame(height: 1),
                    alignment: .bottom
                )

                ScrollView {
                    VStack(spacing: .spacing16) {
                        // ロール情報
                        Card(padding: .spacing12, background: Theme.Color.surface, showBorder: true) {
                            HStack(spacing: .spacing12) {
                                Circle()
                                    .fill(Color(uiColor: UIColor(hex: UInt32(role.color))))
                                    .frame(width: 36, height: 36)
                                Text("@\(role.name)")
                                    .font(Theme.Font.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, .spacing16)

                        // 権限タブバー
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DiscordChannelPerm.allCases, id: \.self) { perm in
                                    let count = categoryGroups.filter { allowedPerms[$0.id]?.contains(perm) == true }.count
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) { activePermTab = perm }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: perm.icon)
                                                .font(.system(size: 11))
                                            Text(perm.label)
                                                .font(Theme.Font.caption)
                                                .fontWeight(activePermTab == perm ? .semibold : .regular)
                                            if count > 0 {
                                                Text("\(count)")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(Theme.Color.accentInk)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(Theme.Color.statusOK)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(activePermTab == perm ? Theme.Color.accent : Theme.Color.surfaceRaised)
                                        .foregroundStyle(activePermTab == perm ? Theme.Color.accentInk : Theme.Color.textSecondary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, .spacing16)
                        }

                        // カテゴリ別チャンネルグリッド
                        VStack(alignment: .leading, spacing: .spacing16) {
                            HStack {
                                Button {
                                    for group in categoryGroups { allowedPerms[group.id, default: []].insert(activePermTab) }
                                } label: {
                                    Text("全選択")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Color.accent)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Button {
                                    for group in categoryGroups { allowedPerms[group.id]?.remove(activePermTab) }
                                } label: {
                                    Text("全解除")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Color.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, .spacing16)

                            ForEach(categoryGroups) { group in
                                categoryToggleEdit(group: group)
                            }
                        }

                        if let err = errorMessage {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.statusWarn)
                                .padding(.horizontal, .spacing16)
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, .spacing16)
                }
                .background(Theme.Color.bg)
            }
            .navigationTitle("権限を編集")
            .navigationBarTitleDisplayMode(.inline)
            .task { loadExistingPermissions() }
            .overlay {
                if showDiscardAlert {
                    ConfirmModal(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Theme.Color.statusWarn,
                        title: "変更を破棄しますか？",
                        message: "行った変更は保存されません。",
                        primaryLabel: "破棄する",
                        primaryRole: .destructive,
                        onPrimary: {
                            dismiss()
                            showDiscardAlert = false
                        },
                        onCancel: {
                            showDiscardAlert = false
                        }
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
        }
    }

    private func categoryToggleEdit(group: CategoryChannelGroup) -> some View {
        let isAllowed = allowedPerms[group.id]?.contains(activePermTab) == true
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isAllowed { allowedPerms[group.id]?.remove(activePermTab) }
                    else { allowedPerms[group.id, default: []].insert(activePermTab) }
                }
            } label: {
                HStack(spacing: .spacing12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isAllowed ? Theme.Color.statusOK.opacity(0.15) : Theme.Color.surfaceRaised)
                            .frame(width: 40, height: 40)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(isAllowed ? Theme.Color.statusOK : Theme.Color.textTertiary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(Theme.Font.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(isAllowed ? Theme.Color.statusOK : Theme.Color.textPrimary)
                        Text("\(group.channels.count)チャンネル")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isAllowed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isAllowed ? Theme.Color.statusOK : Theme.Color.textTertiary)
                        .font(.system(size: 20))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, .spacing16)
            .padding(.vertical, 8)

            // カテゴリ内チャンネル一覧（表示のみ）
            ForEach(group.channels, id: \.id) { ch in
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                    Text(ch.name)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Spacer()
                }
                .padding(.leading, 68)
                .padding(.vertical, 2)
            }
            .padding(.bottom, 8)
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, .spacing16)
    }

    private func loadExistingPermissions() {
        for group in categoryGroups { allowedPerms[group.id, default: []].insert(.viewChannel) }
        initialPerms = allowedPerms
    }

    private func savePermissions() async {
        isSaving = true; errorMessage = nil
        let inputs: [ChannelPermissionInput] = categoryGroups.flatMap { group in
            let perms = allowedPerms[group.id] ?? []
            guard !perms.isEmpty else { return [ChannelPermissionInput]() }
            let allowValue = String(perms.map { Int64($0.rawValue)! }.reduce(0, |))
            return group.channels.map { ch in
                ChannelPermissionInput(channelId: ch.id, allow: allowValue, deny: "0")
            }
        }
        do {
            _ = try await services.verify.createRole(guildId: guildId, name: role.name, color: role.color, channelPermissions: inputs)
            onComplete(true); dismiss()
        } catch {
            errorMessage = "権限の更新に失敗しました。Botの権限を確認してください。"
        }
        isSaving = false
    }
}

// MARK: - EmojiPickerSheet

struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory = 0

    let categories: [EmojiCategory]
    let allEmojis: [[String]]

    init(selectedEmoji: Binding<String>) {
        _selectedEmoji = selectedEmoji
        categories = EmojiCategory.allCases
        allEmojis = [
            EmojiCategory.faces.emojis,
            EmojiCategory.gestures.emojis,
            EmojiCategory.symbols.emojis,
            EmojiCategory.objects.emojis,
            EmojiCategory.nature.emojis,
        ]
    }

    var filteredEmojis: [String] {
        if searchText.isEmpty {
            return allEmojis[selectedCategory]
        }
        return allEmojis.flatMap { $0 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Color.textTertiary)
                    TextField("絵文字を検索", text: $searchText)
                        .font(Theme.Font.body)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.spacing10)
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, .spacing16)
                .padding(.vertical, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { idx, cat in
                            Button {
                                withAnimation { selectedCategory = idx }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(cat.icon)
                                        .font(.system(size: 14))
                                    Text(cat.label)
                                        .font(Theme.Font.caption)
                                        .fontWeight(selectedCategory == idx ? .semibold : .regular)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategory == idx ? Theme.Color.accent : Theme.Color.surfaceRaised)
                                .foregroundStyle(selectedCategory == idx ? Theme.Color.accentInk : Theme.Color.textSecondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, .spacing16)
                }
                .padding(.bottom, 8)

                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(filteredEmojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                                dismiss()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 56, height: 56)
                                    .background(selectedEmoji == emoji ? Theme.Color.accent.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 20)
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle("絵文字を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

enum EmojiCategory: String, CaseIterable {
    case faces = "顔"
    case gestures = "ジェスチャー"
    case symbols = "記号"
    case objects = "オブジェクト"
    case nature = "自然"

    var icon: String {
        switch self {
        case .faces: "face.smiling"; case .gestures: "hand.wave.fill"; case .symbols: "checkmark.circle.fill"
        case .objects: "star.fill"; case .nature: "leaf.fill"
        }
    }
    var label: String { rawValue }

    var emojis: [String] {
        switch self {
        case .faces:
            ["😊", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉",
             "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😜",
             "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐",
             "😑", "😶", "😏", "😒", "🙄", "😬", "🤥", "😔", "😪", "🤤",
             "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🥵", "🥶", "🥴", "😵"]
        case .gestures:
            ["👋", "🤚", "🖐", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞",
             "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👍",
             "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝",
             "🙏", "✍️", "💪", "🦾", "🫶", "🫰", "🫱", "🫲", "🫳", "🫴"]
        case .symbols:
            ["✅", "❌", "⭕", "🚫", "💯", "🔴", "🟠", "🟡", "🟢", "🔵",
             "🟣", "⚫", "⚪", "🟤", "🔶", "🔷", "🔸", "🔹", "🔺", "🔻",
             "💠", "🔘", "🔳", "🔲", "▪️", "▫️", "◾", "◽", "◼️", "◻️",
             "🟥", "🟧", "🟨", "🟩", "🟦", "🟪", "⬛", "⬜", "🔈", "🔉"]
        case .objects:
            ["⭐", "🌟", "✨", "💫", "🎉", "🎊", "🎈", "🎁", "🏆", "🥇",
             "🥈", "🥉", "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🎱", "🏓",
             "🎮", "🎲", "🧩", "🎯", "🎭", "🎨", "🎬", "🎤", "🎧", "🎵",
             "🎶", "🎹", "🥁", "🎷", "🎺", "🎸", "🪕", "🎻", "🎪", "🎢"]
        case .nature:
            ["🌸", "🌺", "🌻", "🌹", "🌷", "🌼", "💐", "🌿", "☘️", "🍀",
             "🍁", "🍂", "🍃", "🌱", "🌲", "🌳", "🌴", "🌵", "🌾", "🌊",
             "🌈", "☀️", "🌤", "⛅", "🌥", "☁️", "🌦", "🌧", "⛈", "🌩",
             "❄️", "☃️", "⛄", "🌬", "💨", "🌪", "🌫", "🔥", "💧", "🌙"]
        }
    }
}

#Preview {
    NavigationStack {
        VerifyPanelEditView(guildId: "g001") { _ in }
    }
    .environment(\.services, ServiceContainer.live())
    .environment(AppState())
}
