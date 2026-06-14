import SwiftUI

private extension View {
    func noxyTextInputStyle() -> some View {
        self
            .font(Theme.Font.body)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
    }

    func noxyMenuInputStyle() -> some View {
        self
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
    }
}

struct TempVCSourceEditView: View {
    let guildId: String
    let source: TempVCSource
    let categories: [(id: String, name: String)]
    let onSave: (TempVCSource) -> Void

    @Environment(\.dismiss)     private var dismiss
    @Environment(AppState.self) private var appState
    @State private var editedSource: TempVCSource
    @State private var isSaving = false
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
        _createTextChannel = State(initialValue: !source.textChannelCategoryId.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                NoxySection(title: "基本設定", icon: "gear",
                            footer: "トリガーVC: ユーザーが最初に参加するVCです。保存時に自動作成されます。") {
                    VStack(spacing: Theme.Spacing.md) {
                        NoxyField(label: "トリガーVCの名前", isRequired: true) {
                            TextField("例: 一時VCを作ろう", text: Binding(
                                get: { editedSource.triggerVcName },
                                set: { editedSource.triggerVcName = $0 }
                            ))
                            
                            .font(Theme.Font.body)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Theme.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button)
                                    .stroke(Theme.Color.line, lineWidth: 1)
                            )
                        }

                        NoxyRowField(label: "一時VCの作成先カテゴリ", isRequired: true) {
                            Picker("カテゴリを選択", selection: Binding(
                                get: { editedSource.vcCategoryId },
                                set: { editedSource.vcCategoryId = $0 }
                            )) {
                                Text("選択してください").tag("")
                                ForEach(categories, id: \.id) {
                                    Text($0.name).tag($0.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.Color.accent)
                        }

                        if appState.isPro {
                            NoxyRowField(label: "テキストチャンネルも作成する") {
                                Toggle("", isOn: Binding(
                                    get: { createTextChannel },
                                    set: { newValue in
                                        createTextChannel = newValue
                                        if !newValue { editedSource.textChannelCategoryId = "" }
                                    }
                                ))
                                .tint(Theme.Color.accent)
                                .labelsHidden()
                            }

                            if createTextChannel {
                                NoxyRowField(label: "テキストチャンネルのカテゴリ", isRequired: true) {
                                    Picker("カテゴリを選択", selection: Binding(
                                        get: { editedSource.textChannelCategoryId },
                                        set: { editedSource.textChannelCategoryId = $0 }
                                    )) {
                                        Text("選択してください").tag("")
                                        ForEach(categories, id: \.id) { Text($0.name).tag($0.id) }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.Color.accent)
                                }
                            }
                        } else {
                            HStack {
                                Text("テキストチャンネルも作成する")
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                Spacer()
                                Text("Pro")
                                    .font(Theme.Font.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.Color.accentInk)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.Color.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                            }
                            .padding(.vertical, Theme.Spacing.sm)
                        }
                    }
                }

                NoxySection(title: "一時VC名フォーマット", icon: "textformat",
                            footer: appState.isPro ? "{user-name}=最初の参加者  {count}=連番" : "Proプランでカスタム名を設定できます。") {
                    VStack(spacing: Theme.Spacing.md) {
                        NoxyField(label: "フォーマット") {
                            TextField("例: {user-name}のVC", text: Binding(
                                get: { editedSource.vcNameFormat },
                                set: { editedSource.vcNameFormat = $0 }
                            ))
                            .font(Theme.Font.body)
                            
                            .font(Theme.Font.body)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Theme.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button)
                                    .stroke(Theme.Color.line, lineWidth: 1)
                            )
                            .disabled(!appState.isPro)
                            .opacity(appState.isPro ? 1 : 0.6)
                        }

                        if appState.isPro {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(["{user-name}", "{count}"], id: \.self) { v in
                                        Button { editedSource.vcNameFormat += v } label: {
                                            Text(v)
                                                .font(Theme.Font.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Theme.Color.accent)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Theme.Color.accentDim)
                                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }

                NoxySection(title: "テキストチャンネル名フォーマット", icon: "textformat") {
                    VStack(spacing: Theme.Spacing.md) {
                        NoxyField(label: "フォーマット") {
                            TextField("例: {user-name}の部屋", text: Binding(
                                get: { editedSource.channelNameFormat },
                                set: { editedSource.channelNameFormat = $0 }
                            ))
                            .font(Theme.Font.body)
                            
                            .font(Theme.Font.body)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Theme.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.button)
                                    .stroke(Theme.Color.line, lineWidth: 1)
                            )
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(["{user-name}", "{count}"], id: \.self) { v in
                                    Button { editedSource.channelNameFormat += v } label: {
                                        Text(v)
                                            .font(Theme.Font.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Color.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Theme.Color.accentDim)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                NoxySection(title: "人数制限", icon: "person.2", footer: "0に設定すると無制限になります。") {
                    HStack {
                        Text("人数制限")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Spacer()
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(editedSource.userLimit == 0 ? "無制限" : "\(editedSource.userLimit)人")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .monospaced()
                                .monospaced()
                            Stepper("", value: Binding(
                                get: { editedSource.userLimit },
                                set: { editedSource.userLimit = $0 }
                            ), in: 0...99)
                            .labelsHidden()
                            .tint(Theme.Color.accent)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }

                NoxySection(title: "自動削除", icon: "trash",
                            footer: appState.isPro ? "猶予時間を設けると、全員退室後もその間はメッセージを読めます。" : "猶予時間の設定はProプランで利用できます。") {
                    VStack(spacing: Theme.Spacing.md) {
                        NoxyRowField(label: "全員退室後に自動削除") {
                            Toggle("", isOn: Binding(
                                get: { editedSource.autoDelete },
                                set: { editedSource.autoDelete = $0 }
                            ))
                            .tint(Theme.Color.accent)
                            .labelsHidden()
                        }

                        if editedSource.autoDelete {
                            if appState.isPro {
                                NoxyRowField(label: "削除までの猶予") {
                                    Picker("猶予を選択", selection: Binding(
                                        get: { editedSource.deleteDelayMinutes },
                                        set: { editedSource.deleteDelayMinutes = $0 }
                                    )) {
                                        ForEach(delayOptions, id: \.0) { sec, label in
                                            Text(label).tag(sec)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.Color.accent)
                                }
                            } else {
                                NoxyRowField(label: "削除までの猶予") {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Text("即座に削除")
                                            .font(Theme.Font.caption2)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                        Text("Pro")
                                            .font(Theme.Font.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Color.accentInk)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Theme.Color.accent)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                                    }
                                }
                            }
                        }
                    }
                }

                NoxySection(title: "待機室認証", icon: "lock.shield",
                            footer: "オンにすると、一般ユーザーが直接メインVCに入れなくなります。") {
                    VStack(spacing: Theme.Spacing.md) {
                        NoxyRowField(label: "待機室認証を有効にする") {
                            Toggle("", isOn: Binding(
                                get: { editedSource.waitingRoomEnabled },
                                set: { editedSource.waitingRoomEnabled = $0 }
                            ))
                            .tint(Theme.Color.accent)
                            .labelsHidden()
                        }

                        if editedSource.waitingRoomEnabled {
                            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Color.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("VC作成時に「〇〇のVC-待機室」が自動作成されます。")
                                        .font(Theme.Font.caption2)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                    Text("待機室は全員が見えますが、メインVCは作成者・管理者のみ表示されます。")
                                        .font(Theme.Font.caption2)
                                        .foregroundStyle(Theme.Color.textTertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                NoxySection(title: "通知", icon: "bell") {
                    NoxyRowField(label: "参加/退出の通知") {
                        Toggle("", isOn: Binding(
                            get: { editedSource.joinLeaveNotification },
                            set: { editedSource.joinLeaveNotification = $0 }
                        ))
                        .tint(Theme.Color.accent)
                        .labelsHidden()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.bottom, 24)
        }
        .background(Theme.Color.bg)
        .navigationTitle(source.id == nil ? "新規作成" : "編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中..." : "保存") {
                    Task { await save() }
                }
                .fontWeight(.semibold)
                .disabled(isSaving || !isValid)
                .foregroundStyle(isSaving || !isValid ? Theme.Color.textTertiary : Theme.Color.accent)
            }
        }
    }

    // MARK: - Valid

    private var isValid: Bool {
        !editedSource.triggerVcName.isEmpty &&
        !editedSource.vcCategoryId.isEmpty &&
        (!createTextChannel || !editedSource.textChannelCategoryId.isEmpty)
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        onSave(editedSource)
        isSaving = false
        dismiss()
    }

    // MARK: - Components

    private struct NoxySection<Content: View>: View {
        let title: String
        let icon: String?
        let footer: String?
        let content: Content

        init(title: String, icon: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
            self.title = title
            self.icon = icon
            self.footer = footer
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    SectionLabel(title: title)
                }
                VStack(spacing: 0) {
                    content
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .stroke(Theme.Color.line, lineWidth: 1)
                )
                if let footer, !footer.isEmpty {
                    Text(footer)
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
        }
    }

    private struct NoxyField<Content: View>: View {
        let label: String
        let isRequired: Bool
        let helper: String?
        let content: Content

        init(label: String, isRequired: Bool = false, helper: String? = nil, @ViewBuilder content: () -> Content) {
            self.label = label
            self.isRequired = isRequired
            self.helper = helper
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: 3) {
                    Text(label.uppercased())
                        .font(Theme.Font.sectionLabel)
                        .tracking(Theme.sectionLabelTracking)
                        .foregroundStyle(Theme.Color.textTertiary)
                    if isRequired {
                        Text("*")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                }
                content
                if let helper, !helper.isEmpty {
                    Text(helper)
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
        }
    }

    // トグル・ピッカー向けの行レイアウト
    private struct NoxyRowField<Content: View>: View {
        let label: String
        let isRequired: Bool
        let content: Content

        init(label: String, isRequired: Bool = false, @ViewBuilder content: () -> Content) {
            self.label = label
            self.isRequired = isRequired
            self.content = content()
        }

        var body: some View {
            HStack {
                HStack(spacing: 3) {
                    Text(label)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                    if isRequired {
                        Text("*")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Color.statusBad)
                    }
                }
                Spacer()
                content
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
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
