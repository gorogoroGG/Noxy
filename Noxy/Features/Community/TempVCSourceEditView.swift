import SwiftUI

struct TempVCSourceEditView: View {
    let guildId: String
    let source: TempVCSource
    let categories: [(id: String, name: String)]
    let onSave: (TempVCSource) -> Void

    @Environment(\.dismiss)     private var dismiss
    @Environment(AppState.self) private var appState
    @State private var editedSource: TempVCSource
    @State private var isSaving = false
    // テキストチャンネル作成トグル（有料のみ設定可、無料は常にfalse）
    @State private var createTextChannel = true

    private let delayOptions = [
        (0, "即座に削除"),
        (1, "1分後"),
        (3, "3分後"),
        (5, "5分後"),
        (10, "10分後"),
        (30, "30分後"),
    ]

    init(
        guildId: String,
        source: TempVCSource,
        categories: [(id: String, name: String)],
        onSave: @escaping (TempVCSource) -> Void
    ) {
        self.guildId = guildId
        self.source = source
        self.categories = categories
        self.onSave = onSave
        _editedSource = State(initialValue: source)
        // textChannelCategoryIdが空でなければ「作成する」とみなす
        _createTextChannel = State(initialValue: !source.textChannelCategoryId.isEmpty)
    }

    var body: some View {
        Form {
            // 基本設定
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("トリガーVCの名前")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    TextField("例: 一時VCを作ろう", text: Binding(
                        get: { editedSource.triggerVcName },
                        set: { editedSource.triggerVcName = $0 }
                    ))
                    .font(.bodySmall)
                }

                Picker("一時VCの作成先カテゴリ", selection: Binding(
                    get: { editedSource.vcCategoryId },
                    set: { editedSource.vcCategoryId = $0 }
                )) {
                    Text("選択してください").tag("")
                    ForEach(categories, id: \.id) {
                        Text($0.name).tag($0.id)
                    }
                }

                // テキストチャンネル作成トグル（Proのみ）
                if appState.isPro {
                    Toggle(isOn: $createTextChannel.animation()) {
                        Text("テキストチャンネルも作成する")
                    }
                    .tint(Color.accentIndigo)
                    .onChange(of: createTextChannel) {
                        if !createTextChannel { editedSource.textChannelCategoryId = "" }
                    }

                    if createTextChannel {
                        Picker("テキストチャンネルのカテゴリ", selection: Binding(
                            get: { editedSource.textChannelCategoryId },
                            set: { editedSource.textChannelCategoryId = $0 }
                        )) {
                            Text("選択してください").tag("")
                            ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                        }
                    }
                } else {
                    HStack {
                        Text("テキストチャンネルも作成する")
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                        Badge(text: "Pro", color: .accentOrange)
                    }
                }
            } header: { Text("基本設定") }
              footer: { Text("トリガーVC: ユーザーが最初に参加するVCです。保存時に自動作成されます。\nテキストチャンネル: Proプランでは一時VCと同時にテキストチャンネルも作成できます。") }

            // VC名フォーマット（Proのみ変更可）
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("一時VC名フォーマット").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        Spacer()
                        if !appState.isPro { Badge(text: "Pro", color: .accentOrange) }
                    }
                    TextField("例: {user-name}のVC", text: Binding(
                        get: { editedSource.vcNameFormat },
                        set: { editedSource.vcNameFormat = $0 }
                    ))
                    .font(.bodySmall)
                    .disabled(!appState.isPro)
                    .foregroundStyle(appState.isPro ? Color.textPrimary : Color.textTertiary)
                    if appState.isPro {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(["{user-name}", "{count}"], id: \.self) { v in
                                    Button { editedSource.vcNameFormat += v } label: {
                                        Text(v).font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.accentIndigo)
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            } header: { Text("一時VC名フォーマット") }
              footer: { Text(appState.isPro ? "{user-name}=最初の参加者  {count}=連番" : "Proプランでカスタム名を設定できます。") }

            // チャンネル名フォーマット
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("テキストチャンネル名フォーマット").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    TextField("例: {user-name}の部屋", text: Binding(
                        get: { editedSource.channelNameFormat },
                        set: { editedSource.channelNameFormat = $0 }
                    ))
                    .font(.bodySmall)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["{user-name}", "{count}"], id: \.self) { v in
                                Button { editedSource.channelNameFormat += v } label: {
                                    Text(v).font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.accentIndigo)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            } header: { Text("テキストチャンネル名フォーマット") }

            // 人数制限
            Section {
                Stepper("人数制限：\(editedSource.userLimit == 0 ? "無制限" : "\(editedSource.userLimit)人")", value: Binding(
                    get: { editedSource.userLimit },
                    set: { editedSource.userLimit = $0 }
                ), in: 0...99)
            } header: { Text("人数制限") }
              footer: { Text("0に設定すると無制限になります。") }

            // 自動削除
            Section {
                Toggle("全員退室後に自動削除", isOn: Binding(
                    get: { editedSource.autoDelete },
                    set: { editedSource.autoDelete = $0 }
                )).tint(Color.accentIndigo)

                if editedSource.autoDelete {
                    if appState.isPro {
                        Picker("削除までの猶予", selection: Binding(
                            get: { editedSource.deleteDelayMinutes },
                            set: { editedSource.deleteDelayMinutes = $0 }
                        )) {
                            ForEach(delayOptions, id: \.0) { sec, label in
                                Text(label).tag(sec)
                            }
                        }
                    } else {
                        HStack {
                            Text("削除までの猶予").foregroundStyle(Color.textTertiary)
                            Spacer()
                            Text("即座に削除").font(.captionRegular).foregroundStyle(Color.textTertiary)
                            Badge(text: "Pro", color: .accentOrange)
                        }
                    }
                }
            } header: { Text("自動削除") }
              footer: { Text(appState.isPro ? "猶予時間を設けると、全員退室後もその間はメッセージを読めます。" : "猶予時間の設定はProプランで利用できます。") }

            // 通知
            Section {
                Toggle("参加/退出の通知", isOn: Binding(
                    get: { editedSource.joinLeaveNotification },
                    set: { editedSource.joinLeaveNotification = $0 }
                )).tint(Color.accentIndigo)
            } header: { Text("通知") }

            // 有効/無効
            Section {
                Toggle("有効にする", isOn: Binding(
                    get: { editedSource.enabled },
                    set: { editedSource.enabled = $0 }
                )).tint(Color.accentIndigo)
            } footer: { Text("無効にすると、トリガーVCは非表示になります。") }
        }
        .navigationTitle(source.id == nil ? "新規作成" : "編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中..." : "保存") {
                    Task { await save() }
                }
                .fontWeight(.semibold)
                .disabled(isSaving || !isValid)
            }
        }
    }

    private var isValid: Bool {
        !editedSource.triggerVcName.isEmpty &&
        !editedSource.vcCategoryId.isEmpty &&
        // テキストチャンネル作成オフの場合はカテゴリ不要
        (!createTextChannel || !editedSource.textChannelCategoryId.isEmpty)
    }

    private func save() async {
        isSaving = true
        onSave(editedSource)
        isSaving = false
        dismiss()
    }
}

#Preview {
    NavigationStack {
        TempVCSourceEditView(
            guildId: "g001",
            source: TempVCSource.defaultSource(guildId: "g001"),
            categories: [("cat1", "カテゴリ1"), ("cat2", "カテゴリ2")]
        ) { _ in }
    }
}
