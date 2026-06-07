import SwiftUI

struct VerifyPanelEditView: View {
    var existing: VerifyPanel? = nil
    let guildId: String
    let onSave: (VerifyPanel) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var name = "認証"
    @State private var description = "下のボタンを押して認証を完了してください。"
    @State private var buttonLabel = "✅ 認証する"
    @State private var roleId = ""
    @State private var footerText = ""
    @State private var colorHex: UInt32 = 0x10b981
    @State private var enabled = true
    @State private var verifyType: VerifyType = .captcha
    @State private var reactionEmoji = "✅"
    @State private var manualChannelId = ""

    @State private var roles: [DiscordRole] = []
    @State private var textChannels: [(id: String, name: String)] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showDiscardAlert = false

    private var isNew: Bool { existing == nil }
    private let colorPresets: [UInt32] = [0x10b981, 0x6366f1, 0xf59e0b, 0x3b82f6, 0x8b5cf6, 0xef4444]
    private var previewColor: Color { Color(uiColor: UIColor(hex: colorHex)) }

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
                // ツールバー
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
                    verifyTypeSection
                    basicSection
                    roleSection
                    typeSpecificSection
                    appearanceSection
                    previewSection

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
            .navigationTitle(isNew ? "認証パネルを作成" : "認証パネルを編集")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
            .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
                Button("破棄する", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            } message: { Text("行った変更は保存されません。") }
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
                                    .font(.bodySmall).fontWeight(.semibold)
                                    .foregroundStyle(Color.textPrimary)
                                Text(type.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textTertiary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if verifyType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(type.accentColor)
                                    .font(.system(size: 18))
                            }
                        }
                        .padding(.spacing10)
                        .background(
                            verifyType == type
                                ? type.accentColor.opacity(0.07)
                                : Color(.tertiarySystemGroupedBackground)
                        )
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
        } header: { Text("認証方法") }
          footer: { Text("認証後にロールを自動付与します。") }
    }

    // MARK: - 基本設定

    private var basicSection: some View {
        Section {
            Toggle("パネルを有効にする", isOn: $enabled)
            LabeledContent("名前") {
                TextField("認証", text: $name).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("説明文").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextEditor(text: $description).frame(minHeight: 60).scrollContentBackground(.hidden)
            }
            if verifyType != .reaction {
                LabeledContent("ボタンのラベル") {
                    TextField("✅ 認証する", text: $buttonLabel).multilineTextAlignment(.trailing)
                }
            }
        } header: { Text("基本設定") }
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
            }
        } header: { Text("ロール設定") }
          footer: {
              if roleId.isEmpty {
                  Label("ロールを選択しないとパネルを設置できません", systemImage: "exclamationmark.triangle.fill")
                      .font(.captionSmall).foregroundStyle(.orange)
              } else {
                  Text("認証を通過したユーザーにこのロールが自動付与されます。")
              }
          }
    }

    // MARK: - 認証タイプ固有設定

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch verifyType {
        case .reaction:
            Section {
                LabeledContent("認証絵文字") {
                    TextField("✅", text: $reactionEmoji)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            } header: { Text("リアクション設定") }
              footer: { Text("パネルメッセージにこの絵文字でリアクションすることで認証されます。Unicode絵文字またはカスタム絵文字を使用できます。") }

        case .manual:
            Section {
                if isLoading {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                } else {
                    Picker("申請通知チャンネル", selection: $manualChannelId) {
                        Text("なし（アプリのみ）").tag("")
                        ForEach(textChannels, id: \.id) { Text("#\($0.name)").tag($0.id) }
                    }
                }
            } header: { Text("手動認証設定") }
              footer: { Text("ユーザーが申請すると、このチャンネルに通知が届きます。アプリの「承認待ち」からも管理できます。") }

        case .captcha, .button:
            EmptyView()
        }
    }

    // MARK: - 外観

    private var appearanceSection: some View {
        Section {
            HStack {
                Text("カラー")
                Spacer()
                HStack(spacing: 8) {
                    ForEach(colorPresets, id: \.self) { hex in
                        ZStack {
                            Circle().fill(Color(uiColor: UIColor(hex: hex))).frame(width: 26, height: 26)
                            if colorHex == hex {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                        .onTapGesture { withAnimation { colorHex = hex } }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("フッターテキスト").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextEditor(text: $footerText).frame(minHeight: 44).scrollContentBackground(.hidden)
            }
        } header: { Text("外観") }
    }

    // MARK: - プレビュー

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: .spacing12) {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2).fill(previewColor).frame(width: 4)
                    VStack(alignment: .leading, spacing: 5) {
                        if !name.isEmpty {
                            Text(name).font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                        }
                        if !description.isEmpty {
                            Text(description).font(.captionRegular).foregroundStyle(Color.textSecondary)
                        }
                        if !footerText.isEmpty {
                            Divider().padding(.vertical, 2)
                            Text(footerText).font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                        }
                    }
                    .padding(.leading, 10).padding(.vertical, 10).padding(.trailing, 10)
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                switch verifyType {
                case .reaction:
                    HStack(spacing: 6) {
                        Text(reactionEmoji.isEmpty ? "✅" : reactionEmoji)
                            .font(.system(size: 20))
                        Text("← この絵文字にリアクションして認証")
                            .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                default:
                    Text(buttonLabel.isEmpty ? "✅ 認証する" : buttonLabel)
                        .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(previewColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 5) {
                Image(systemName: "eye.fill").font(.captionSmall)
                Text("プレビュー")
            }
        }
    }

    // MARK: - Load & Save

    private func loadData() async {
        isLoading = true
        async let rolesTask = DiscordService().fetchRoles(guildId: guildId)
        async let chTask: [(id: String, name: String)] = {
            guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)") else { return [] }
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let chs = try? JSONDecoder().decode([RawCh].self, from: data) else { return [] }
            return chs.filter { $0.type == 0 }.map { ($0.id, $0.name) }
        }()
        roles = (try? await rolesTask) ?? []
        textChannels = await chTask
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
            let saved = isNew
                ? try await services.verify.createPanel(panel)
                : try await services.verify.updatePanel(panel)
            onSave(saved); dismiss()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
        isSaving = false
    }
}
