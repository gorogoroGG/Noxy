import SwiftUI

// MARK: - Discord Permission Bits
// チャンネル権限で使用する Discord パーミッションビット
enum DiscordChannelPerm: String, CaseIterable {
    case viewChannel      = "1024"        // 1 << 10
    case sendMessages     = "2048"        // 1 << 11
    case readHistory      = "65536"       // 1 << 16
    case connect          = "1048576"     // 1 << 20 (VC)
    case speak            = "2097152"     // 1 << 21 (VC)

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
    @State private var buttonLabel = "✅ 認証する"
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button("キャンセル") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }.foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.isEmpty || roleId.isEmpty ? Color.textTertiary : Color.accentIndigo)
                        .disabled(name.isEmpty || roleId.isEmpty || isSaving)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(Divider(), alignment: .bottom)

                Form {
                    editablePreviewSection
                    verifyTypeSection
                    roleSection
                    typeSpecificSection

                    if let err = errorMessage {
                        Section {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange).font(.captionRegular)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle(isNew ? "認証を設定" : "認証を編集")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
            .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
                Button("破棄する", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            } message: { Text("行った変更は保存されません。") }
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

    // MARK: - 認証方法セクション

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
                                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                                Text(type.description)
                                    .font(.system(size: 11)).foregroundStyle(Color.textTertiary).lineLimit(2)
                            }
                            Spacer()
                            if verifyType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(type.accentColor).font(.system(size: 18))
                            }
                        }
                        .padding(.spacing10)
                        .background(verifyType == type ? type.accentColor.opacity(0.07) : Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(verifyType == type ? type.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: { Text("認証方法") }
    }

    // MARK: - インライン編集プレビュー

    @ViewBuilder
    private var editablePreviewSection: some View {
        Section {
            Toggle("パネルを有効にする", isOn: $enabled)
        } header: { Text("基本設定") }

        Section {
            // Discord メッセージ風インライン編集プレビュー
            HStack(alignment: .top, spacing: 10) {
                // Bot アバター
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color.accentIndigo, Color.accentPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    // Bot ヘッダー
                    HStack(spacing: 5) {
                        Text("Noxy").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.accentIndigo)
                        Text("BOT").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(Color.accentIndigo).clipShape(RoundedRectangle(cornerRadius: 3))
                        Text(Date(), style: .time).font(.system(size: 11)).foregroundStyle(Color.textTertiary)
                    }

                    // Embed ブロック
                    HStack(alignment: .top, spacing: 0) {
                        // カラーバー（タップでカラー変更）
                        RoundedRectangle(cornerRadius: 2).fill(previewColor).frame(width: 4)
                            .onTapGesture { showColorPicker = true }

                        VStack(alignment: .leading, spacing: 8) {
                            // タイトル（インライン編集）
                            TextField("タイトル", text: $name)
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(previewColor)
                                .textFieldStyle(.plain).focused($previewFocus, equals: .title)
                                .padding(.horizontal, 5).padding(.vertical, 3)
                                .embedDashedBorder(focused: previewFocus == .title)

                            // 説明文（インライン編集）
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("説明文を入力...").font(.system(size: 13))
                                        .foregroundStyle(Color.textTertiary)
                                        .padding(.top, 6).padding(.leading, 6).allowsHitTesting(false)
                                }
                                TextEditor(text: $description)
                                    .font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                                    .scrollContentBackground(.hidden).background(.clear)
                                    .frame(minHeight: 52, maxHeight: .infinity)
                                    .focused($previewFocus, equals: .description)
                            }
                            .padding(.horizontal, 2).padding(.vertical, 1)
                            .embedDashedBorder(focused: previewFocus == .description)

                            // フッター（インライン編集）
                            TextField("フッターテキスト", text: $footerText)
                                .font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                                .textFieldStyle(.plain).focused($previewFocus, equals: .footer)
                                .padding(.horizontal, 5).padding(.vertical, 3)
                                .embedDashedBorder(focused: previewFocus == .footer)
                        }
                        .padding(10)
                    }
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // ボタン / リアクション（インライン編集）
                    if verifyType == .reaction {
                        HStack(spacing: 4) {
                            Text(reactionEmoji.isEmpty ? "✅" : reactionEmoji).font(.system(size: 16))
                            Text("1").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.textSecondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.bgElevated).clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        TextField("ボタンのラベル", text: $buttonLabel)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            .textFieldStyle(.plain).focused($previewFocus, equals: .buttonLabel)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(previewColor).clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    // カラー変更ヒント
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.fill").font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                        Text("左のカラーバーをタップして色を変更").font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 4) { Image(systemName: "eye.fill").font(.captionSmall); Text("プレビュー（タップして編集）") }
        }
    }

    // MARK: - ロール設定

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

                // 既存ロールの権限を編集
                if !roleId.isEmpty, let selectedRole = roles.first(where: { $0.id == roleId }) {
                    Button {
                        editingRoleId = roleId
                        showEditRolePerms = true
                    } label: {
                        Label("「@\(selectedRole.name)」の権限を編集", systemImage: "shield.lefthalf.filled")
                            .font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.accentIndigo)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showCreateRole = true
                } label: {
                    Label("新しいロールを作成して設定", systemImage: "plus.circle.fill")
                        .font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.accentIndigo)
                }
                .buttonStyle(.plain)
            }
        } header: { Text("ロール設定") }
          footer: {
              if roleId.isEmpty {
                  Label("ロールを選択または作成しないとパネルを設置できません", systemImage: "exclamationmark.triangle.fill")
                      .font(.captionSmall).foregroundStyle(.orange)
              } else {
                  Text("認証を通過したユーザーにこのロールが自動付与されます。「新しいロールを作成」でロールの権限も同時に設定できます。")
              }
          }
    }

    // MARK: - 認証タイプ固有設定

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
                            .font(.bodySmall).foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(reactionEmoji.isEmpty ? "✅" : reactionEmoji)
                            .font(.system(size: 24))
                        Image(systemName: "chevron.down")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            } header: { Text("リアクション設定") }
              footer: { Text("パネルメッセージにこの絵文字でリアクションすることで認証されます。") }
        case .manual:
            Section {
                if isLoading {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                } else {
                    Picker("申請通知チャンネル", selection: $manualChannelId) {
                        Text("なし（アプリのみ）").tag("")
                        ForEach(textChannels, id: \.id) { ch in Text("#\(ch.name)").tag(ch.id) }
                    }
                }
            } header: { Text("手動認証設定") }
              footer: { Text("ユーザーが申請するとこのチャンネルに通知が届きます。アプリの「承認待ち」からも管理できます。") }
        case .captcha, .button:
            EmptyView()
        }
    }


    // MARK: - Load & Save

    private func loadData() async {
        isLoading = true
        async let rolesTask = DiscordService().fetchRoles(guildId: guildId)
        async let chTask: [(id: String, name: String, type: Int, parentId: String?)] = {
            guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)") else { return [] }
            struct RawCh: Decodable {
                let id: String; let name: String; let type: Int
                let parent_id: String?
            }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let chs = try? JSONDecoder().decode([RawCh].self, from: data) else { return [] }
            return chs.map { ($0.id, $0.name, $0.type, $0.parent_id) }
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

// MARK: - VerifyCreateRoleSheet（ロール新規作成 + 権限設定）

// MARK: - CategoryChannelGroup（権限シート共通）

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
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button(isCreating ? "作成中..." : "作成") { Task { await createRole() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(roleName.isEmpty ? Color.textTertiary : Color.accentIndigo)
                        .disabled(roleName.isEmpty || isCreating)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(Divider(), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 16) {
                        // ロール基本情報
                        VStack(spacing: 12) {
                            HStack {
                                Text("ロール名").font(.captionSmall).foregroundStyle(Color.textSecondary).frame(width: 80, alignment: .leading)
                                TextField("認証済み", text: $roleName)
                                    .font(.bodySmall)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            HStack {
                                Text("カラー").font(.captionSmall).foregroundStyle(Color.textSecondary).frame(width: 80, alignment: .leading)
                                HStack(spacing: 8) {
                                    ForEach(colorPresets, id: \.self) { hex in
                                        ZStack {
                                            Circle().fill(Color(uiColor: UIColor(hex: hex))).frame(width: 28, height: 28)
                                            if colorHex == hex { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                                        }
                                        .onTapGesture { withAnimation { colorHex = hex } }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)

                        // 権限設定
                        VStack(alignment: .leading, spacing: 12) {
                            Text("チャンネル権限").font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, 16)

                            // 権限タブバー
                            permTabBar(textChannels: textChannels)

                            // カテゴリ別チャンネル
                            categoryPermGrid(textChannels: textChannels)
                        }

                        if let err = errorMessage {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange).font(.captionSmall).padding(.horizontal, 16)
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("ロールを作成")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func permTabBar(textChannels: [(id: String, name: String)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscordChannelPerm.allCases, id: \.self) { perm in
                    let count = textChannels.filter { allowedPerms[$0.id]?.contains(perm) == true }.count
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { activePermTab = perm }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: perm.icon).font(.system(size: 11))
                            Text(perm.label).font(.system(size: 11, weight: activePermTab == perm ? .semibold : .regular))
                            if count > 0 {
                                Text("\(count)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Color.accentGreen).clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(activePermTab == perm ? Color.accentIndigo : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(activePermTab == perm ? .white : Color.textSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryPermGrid(textChannels: [(id: String, name: String)]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 全選択/全解除
            HStack {
                Button {
                    for ch in textChannels { allowedPerms[ch.id, default: []].insert(activePermTab) }
                } label: { Text("全選択").font(.captionSmall).foregroundStyle(Color.accentIndigo) }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    for ch in textChannels { allowedPerms[ch.id]?.remove(activePermTab) }
                } label: { Text("全解除").font(.captionSmall).foregroundStyle(Color.textTertiary) }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            ForEach(categoryGroups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 16)
                    let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(group.channels, id: \.id) { ch in
                            channelToggleButton(ch: ch)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func channelToggleButton(ch: (id: String, name: String)) -> some View {
        let isAllowed = allowedPerms[ch.id]?.contains(activePermTab) == true
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isAllowed { allowedPerms[ch.id]?.remove(activePermTab) }
                else { allowedPerms[ch.id, default: []].insert(activePermTab) }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isAllowed ? Color.accentGreen.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isAllowed ? Color.accentGreen : Color.clear, lineWidth: 2))
                VStack(spacing: 2) {
                    Image(systemName: "number").font(.system(size: 10))
                        .foregroundStyle(isAllowed ? Color.accentGreen : Color.textTertiary)
                    Text(ch.name).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isAllowed ? Color.accentGreen : Color.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func createRole() async {
        guard !roleName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isCreating = true; errorMessage = nil
        let inputs: [ChannelPermissionInput] = textChannels.compactMap { ch in
            let perms = allowedPerms[ch.id] ?? []
            guard !perms.isEmpty else { return nil }
            return ChannelPermissionInput(channelId: ch.id, allow: String(perms.map { Int64($0.rawValue)! }.reduce(0, |)), deny: "0")
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
                // ヘッダー（ZStackでタイトルを完全中央揃え）
                ZStack {
                    Text(role.name).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                    HStack {
                        Button("キャンセル") {
                            if hasChanges { showDiscardAlert = true } else { dismiss() }
                        }.foregroundStyle(Color.textSecondary)
                        Spacer()
                        Button(isSaving ? "保存中..." : "保存") { Task { await savePermissions() } }
                            .fontWeight(.semibold)
                            .foregroundStyle(isSaving ? Color.textTertiary : Color.accentIndigo)
                            .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(Divider(), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 16) {
                        // ロール情報
                        HStack(spacing: 12) {
                            Circle().fill(Color(uiColor: UIColor(hex: UInt32(role.color)))).frame(width: 36, height: 36)
                            Text("@\(role.name)").font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)

                        // 権限タブバー
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DiscordChannelPerm.allCases, id: \.self) { perm in
                                    let count = textChannels.filter { allowedPerms[$0.id]?.contains(perm) == true }.count
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) { activePermTab = perm }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: perm.icon).font(.system(size: 11))
                                            Text(perm.label).font(.system(size: 11, weight: activePermTab == perm ? .semibold : .regular))
                                            if count > 0 {
                                                Text("\(count)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                                    .background(Color.accentGreen).clipShape(Capsule())
                                            }
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(activePermTab == perm ? Color.accentIndigo : Color(.tertiarySystemGroupedBackground))
                                        .foregroundStyle(activePermTab == perm ? .white : Color.textSecondary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // カテゴリ別チャンネルグリッド
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Button {
                                    for ch in textChannels { allowedPerms[ch.id, default: []].insert(activePermTab) }
                                } label: { Text("全選択").font(.captionSmall).foregroundStyle(Color.accentIndigo) }
                                .buttonStyle(.plain)
                                Spacer()
                                Button {
                                    for ch in textChannels { allowedPerms[ch.id]?.remove(activePermTab) }
                                } label: { Text("全解除").font(.captionSmall).foregroundStyle(Color.textTertiary) }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)

                            ForEach(categoryGroups) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(group.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.textTertiary)
                                        .padding(.horizontal, 16)
                                    let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                                    LazyVGrid(columns: cols, spacing: 8) {
                                        ForEach(group.channels, id: \.id) { ch in
                                            channelToggle(ch: ch)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        if let err = errorMessage {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange).font(.captionSmall).padding(.horizontal, 16)
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("権限を編集")
            .navigationBarTitleDisplayMode(.inline)
            .task { loadExistingPermissions() }
            .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
                Button("破棄する", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            } message: { Text("行った変更は保存されません。") }
        }
    }

    private func channelToggle(ch: (id: String, name: String)) -> some View {
        let isAllowed = allowedPerms[ch.id]?.contains(activePermTab) == true
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isAllowed { allowedPerms[ch.id]?.remove(activePermTab) }
                else { allowedPerms[ch.id, default: []].insert(activePermTab) }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isAllowed ? Color.accentGreen.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isAllowed ? Color.accentGreen : Color.clear, lineWidth: 2))
                VStack(spacing: 2) {
                    Image(systemName: "number").font(.system(size: 10))
                        .foregroundStyle(isAllowed ? Color.accentGreen : Color.textTertiary)
                    Text(ch.name).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isAllowed ? Color.accentGreen : Color.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func loadExistingPermissions() {
        for ch in textChannels { allowedPerms[ch.id, default: []].insert(.viewChannel) }
        initialPerms = allowedPerms
    }

    private func savePermissions() async {
        isSaving = true; errorMessage = nil
        let inputs: [ChannelPermissionInput] = textChannels.compactMap { ch in
            let perms = allowedPerms[ch.id] ?? []
            guard !perms.isEmpty else { return nil }
            return ChannelPermissionInput(channelId: ch.id, allow: String(perms.map { Int64($0.rawValue)! }.reduce(0, |)), deny: "0")
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
                        .foregroundStyle(Color.textTertiary)
                    TextField("絵文字を検索", text: $searchText)
                        .font(.bodySmall)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(10).background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16).padding(.vertical, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { idx, cat in
                            Button {
                                withAnimation { selectedCategory = idx }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(cat.icon).font(.system(size: 14))
                                    Text(cat.label).font(.system(size: 11, weight: selectedCategory == idx ? .semibold : .regular))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(selectedCategory == idx ? Color.accentIndigo : Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(selectedCategory == idx ? .white : Color.textSecondary)
                                .clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 16)
                }.padding(.bottom, 8)

                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(filteredEmojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                                dismiss()
                            } label: {
                                Text(emoji).font(.system(size: 28))
                                    .frame(width: 56, height: 56)
                                    .background(selectedEmoji == emoji ? Color.accentIndigo.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 8).padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
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
        case .faces: "😊"; case .gestures: "👋"; case .symbols: "✅"
        case .objects: "⭐"; case .nature: "🌸"
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
