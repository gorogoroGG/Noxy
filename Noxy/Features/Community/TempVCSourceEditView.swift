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
        ScrollView {
            VStack(spacing: .spacing16) {
                FormSection("基本設定", icon: "gear",
                            footer: "トリガーVC: ユーザーが最初に参加するVCです。保存時に自動作成されます。\nテキストチャンネル: Proプランでは一時VCと同時にテキストチャンネルも作成できます。") {
                    VStack(spacing: .spacing12) {
                        FormField.text(
                            label: "トリガーVCの名前",
                            text: Binding(
                                get: { editedSource.triggerVcName },
                                set: { editedSource.triggerVcName = $0 }
                            ),
                            placeholder: "例: 一時VCを作ろう"
                        )

                        FormField.picker(
                            label: "一時VCの作成先カテゴリ",
                            selection: Binding(
                                get: { editedSource.vcCategoryId },
                                set: { editedSource.vcCategoryId = $0 }
                            )
                        ) {
                            Text("選択してください").tag("")
                            ForEach(categories, id: \.id) {
                                Text($0.name).tag($0.id)
                            }
                        }

                        // テキストチャンネル作成トグル（Proのみ）
                        if appState.isPro {
                            FormField.toggle(
                                label: "テキストチャンネルも作成する",
                                isOn: Binding(
                                    get: { createTextChannel },
                                    set: { newValue in
                                        createTextChannel = newValue
                                        if !newValue { editedSource.textChannelCategoryId = "" }
                                    }
                                )
                            )

                            if createTextChannel {
                                FormField.picker(
                                    label: "テキストチャンネルのカテゴリ",
                                    selection: Binding(
                                        get: { editedSource.textChannelCategoryId },
                                        set: { editedSource.textChannelCategoryId = $0 }
                                    )
                                ) {
                                    Text("選択してください").tag("")
                                    ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                                }
                            }
                        } else {
                            HStack {
                                Text("テキストチャンネルも作成する")
                                    .font(.bodySmall)
                                    .foregroundStyle(Color.textTertiary)
                                Spacer()
                                Badge(text: "Pro", color: .accentOrange)
                            }
                            .inputStyle(height: 44)
                        }
                    }
                }

                FormSection("一時VC名フォーマット", icon: "textformat",
                            footer: appState.isPro ? "{user-name}=最初の参加者  {count}=連番" : "Proプランでカスタム名を設定できます。") {
                    VStack(spacing: .spacing8) {
                        FormField(label: "フォーマット") {
                            TextField("例: {user-name}のVC", text: Binding(
                                get: { editedSource.vcNameFormat },
                                set: { editedSource.vcNameFormat = $0 }
                            ))
                            .font(.bodySmall)
                            .inputStyle()
                            .disabled(!appState.isPro)
                            .foregroundStyle(appState.isPro ? Color.textPrimary : Color.textTertiary)
                        }
                        .opacity(appState.isPro ? 1 : 0.6)

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
                }

                FormSection("テキストチャンネル名フォーマット", icon: "textformat") {
                    VStack(spacing: .spacing8) {
                        FormField(label: "フォーマット") {
                            TextField("例: {user-name}の部屋", text: Binding(
                                get: { editedSource.channelNameFormat },
                                set: { editedSource.channelNameFormat = $0 }
                            ))
                            .font(.bodySmall)
                            .inputStyle()
                        }

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
                }

                FormSection("人数制限", icon: "person.2", footer: "0に設定すると無制限になります。") {
                    FormField.stepper(
                        label: "人数制限",
                        value: Binding(
                            get: { editedSource.userLimit },
                            set: { editedSource.userLimit = $0 }
                        ),
                        range: 0...99,
                        helper: editedSource.userLimit == 0 ? "無制限" : "\(editedSource.userLimit)人"
                    )
                }

                FormSection("自動削除", icon: "trash",
                            footer: appState.isPro ? "猶予時間を設けると、全員退室後もその間はメッセージを読めます。" : "猶予時間の設定はProプランで利用できます。") {
                    VStack(spacing: .spacing12) {
                        FormField.toggle(
                            label: "全員退室後に自動削除",
                            isOn: Binding(
                                get: { editedSource.autoDelete },
                                set: { editedSource.autoDelete = $0 }
                            )
                        )

                        if editedSource.autoDelete {
                            if appState.isPro {
                                FormField.picker(
                                    label: "削除までの猶予",
                                    selection: Binding(
                                        get: { editedSource.deleteDelayMinutes },
                                        set: { editedSource.deleteDelayMinutes = $0 }
                                    )
                                ) {
                                    ForEach(delayOptions, id: \.0) { sec, label in
                                        Text(label).tag(sec)
                                    }
                                }
                            } else {
                                HStack {
                                    Text("削除までの猶予")
                                        .font(.bodySmall)
                                        .foregroundStyle(Color.textTertiary)
                                    Spacer()
                                    Text("即座に削除").font(.captionRegular).foregroundStyle(Color.textTertiary)
                                    Badge(text: "Pro", color: .accentOrange)
                                }
                                .inputStyle(height: 44)
                            }
                        }
                    }
                }

                FormSection("通知", icon: "bell") {
                    FormField.toggle(
                        label: "参加/退出の通知",
                        isOn: Binding(
                            get: { editedSource.joinLeaveNotification },
                            set: { editedSource.joinLeaveNotification = $0 }
                        )
                    )
                }

            }
            .padding(.spacing16)
            .padding(.bottom, 24)
        }
        .background(Color.bgPrimary)
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
