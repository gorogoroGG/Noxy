import SwiftUI

// MARK: - ShopEditView

struct ShopEditView: View {
    var existingShop: Shop?
    let guildId: String
    let onSave: (Shop) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var name = "ショップ"
    @State private var description = "商品を選択して購入してください。"
    @State private var supportRoleId = ""
    @State private var orderCategoryId = ""
    @State private var archiveCategoryId = ""
    @State private var timeoutHours: Int? = nil
    @State private var timeoutEnabled = false
    @State private var footerText = "本Botは取引の仲介・保証・管理に一切関与しません。取引に関するトラブルはサーバー管理者および取引相手との間で解決してください。"
    @State private var colorHex: UInt32 = 0x6366f1

    @State private var roles: [DiscordRole] = []
    @State private var categories: [(id: String, name: String)] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var isNew: Bool { existingShop == nil }
    private var previewColor: Color { Color(uiColor: UIColor(hex: colorHex)) }
    private let colorPresets: [UInt32] = [0x6366f1, 0x10b981, 0xf59e0b, 0xef4444, 0x8b5cf6, 0x3b82f6]

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                previewSection
                channelSettingsSection
                timeoutSection
                footerSection

                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.captionRegular)
                    }
                }
            }
            .navigationTitle(isNew ? "ショップを作成" : "ショップを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.isEmpty ? Color.textTertiary : Color.accentIndigo)
                        .disabled(name.isEmpty || isSaving)
                }
            }
            .task { await loadData() }
        }
    }

    private var appearanceSection: some View {
        Section {
            LabeledContent("名前") {
                TextField("ショップ", text: $name).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("説明").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextEditor(text: $description)
                    .frame(minHeight: 60).scrollContentBackground(.hidden)
            }
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
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { colorHex = hex } }
                    }
                }
            }
        } header: { Text("パネルの見た目") }
    }

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: .spacing12) {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2).fill(previewColor).frame(width: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if !name.isEmpty {
                            Text(name).font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.textPrimary)
                        }
                        if !description.isEmpty {
                            Text(description).font(.captionRegular).foregroundStyle(Color.textSecondary)
                        }
                        Divider().padding(.vertical, 4)
                        Text(footerText).font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                    }
                    .padding(.leading, 10).padding(.vertical, 10).padding(.trailing, 10)
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 6) {
                    Text("🛒 商品を選択してください")
                        .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(previewColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Text("⚠️ 異議を申し立てる")
                        .font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 5) {
                Image(systemName: "eye.fill").font(.captionSmall)
                Text("パネルのプレビュー")
            }
        } footer: {
            Text("Discordに投稿されるショップパネルのイメージです。")
        }
    }

    private var channelSettingsSection: some View {
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
                Picker("注文カテゴリ", selection: $orderCategoryId) {
                    Text("なし（デフォルト）").tag("")
                    ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                }
                Picker("アーカイブカテゴリ", selection: $archiveCategoryId) {
                    Text("なし（そのまま）").tag("")
                    ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                }
            }
        } header: { Text("チャンネル設定") }
          footer: {
              Text("サポートロール：注文チャンネルに追加されるロール。\n注文カテゴリ：注文チャンネルを作成するカテゴリ。\nアーカイブカテゴリ：完了・キャンセル後にチャンネルを移動するカテゴリ。")
          }
    }

    private var timeoutSection: some View {
        Section {
            Toggle("タイムアウトを有効にする", isOn: $timeoutEnabled)
            if timeoutEnabled {
                Stepper("タイムアウト：\(timeoutHours ?? 24)時間", value: Binding(
                    get: { timeoutHours ?? 24 },
                    set: { timeoutHours = max(1, $0) }
                ), in: 1...168)
            }
        } header: { Text("注文タイムアウト") }
          footer: {
              Text(timeoutEnabled
                   ? "指定時間以内に支払いが確認されない場合、注文は自動キャンセルされます。"
                   : "タイムアウトを無効にすると、注文は手動で処理されるまで残り続けます。")
          }
    }

    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("フッターテキスト").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextEditor(text: $footerText)
                    .frame(minHeight: 60).scrollContentBackground(.hidden)
            }
        } header: { Text("フッター") }
          footer: {
              Text("ショップパネルのフッターに表示される免責事項です。")
          }
    }

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

        if let s = existingShop {
            name = s.name
            description = s.description
            supportRoleId = s.supportRoleId ?? ""
            orderCategoryId = s.orderCategoryId ?? ""
            archiveCategoryId = s.archiveCategoryId ?? ""
            timeoutHours = s.timeoutHours
            timeoutEnabled = s.timeoutHours != nil
            footerText = s.footerText
            colorHex = UInt32(s.color)
        }
    }

    private func save() async {
        isSaving = true; errorMessage = nil
        do {
            var shop = existingShop ?? Shop.blank(guildId: guildId)
            shop.name = name
            shop.description = description
            shop.color = Int(colorHex)
            shop.supportRoleId = supportRoleId.isEmpty ? nil : supportRoleId
            shop.orderCategoryId = orderCategoryId.isEmpty ? nil : orderCategoryId
            shop.archiveCategoryId = archiveCategoryId.isEmpty ? nil : archiveCategoryId
            shop.timeoutHours = timeoutEnabled ? (timeoutHours ?? 24) : nil
            shop.footerText = footerText

            let saved = isNew
                ? try await services.shops.createShop(shop)
                : try await services.shops.updateShop(shop)

            onSave(saved)
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました"
        }
        isSaving = false
    }
}
