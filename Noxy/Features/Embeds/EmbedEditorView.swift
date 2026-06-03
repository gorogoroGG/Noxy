import SwiftUI
import Observation

// MARK: - ViewModel

@Observable
final class EmbedEditorViewModel {
    var embed: EmbedModel
    var isModified = false
    let isNewEmbed: Bool

    init(embed: EmbedModel? = nil) {
        self.isNewEmbed = embed == nil
        self.embed = embed ?? .blank()
    }

    var isValid: Bool {
        let hasContent = (embed.title ?? "").isEmpty == false
            || (embed.description ?? "").isEmpty == false
            || !embed.fields.isEmpty
        return hasContent
    }

    var charCount: Int { embed.totalCharCount }
    var isOverLimit: Bool { charCount > 6000 }

    func addField() {
        embed.fields.append(EmbedFieldModel(id: UUID().uuidString, name: "", value: "", inline: false))
        isModified = true
    }

    func removeField(at offsets: IndexSet) {
        embed.fields.remove(atOffsets: offsets)
        isModified = true
    }

    func moveField(from source: IndexSet, to destination: Int) {
        embed.fields.move(fromOffsets: source, toOffset: destination)
        isModified = true
    }
}

// MARK: - EmbedEditorView

struct EmbedEditorView: View {
    @State private var vm: EmbedEditorViewModel
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var showColorPicker = false
    @State private var showSaveModal = false
    @State private var showSendSheet = false
    @State private var saveName = ""
    @State private var fieldToDelete: IndexSet? = nil
    @State private var showFieldDeleteConfirm = false
    @State private var errorMessage: String? = nil
    @State private var showCancelConfirm = false
    @State private var isPreviewExpanded = true

    let onSave: (EmbedModel) -> Void

    init(embed: EmbedModel? = nil, onSave: @escaping (EmbedModel) -> Void) {
        _vm = State(initialValue: EmbedEditorViewModel(embed: embed))
        self.onSave = onSave
    }

    private var accentColor: Color {
        Color(uiColor: UIColor(hex: vm.embed.colorHex))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // エディター（上半分）
                    ScrollView {
                        VStack(alignment: .leading, spacing: .spacing20) {
                            messageContentSection
                            contentSection
                            colorSection
                            mediaSection
                            fieldsSection
                            footerSection
                        }
                        .padding()
                    }
                    .frame(height: isPreviewExpanded ? geo.size.height * 0.55 : geo.size.height - 44)

                    Divider().background(Color.border)

                    // ライブプレビュー（下半分）
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    isPreviewExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: .spacing4) {
                                    Image(systemName: isPreviewExpanded ? "chevron.down" : "chevron.up")
                                        .font(.captionSmall)
                                    Text("— PREVIEW —")
                                        .font(.captionSmall)
                                        .tracking(1)
                                }
                                .foregroundStyle(Color.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isPreviewExpanded ? "プレビューを折りたたむ" : "プレビューを展開する")

                            Spacer()
                            Text("\(vm.charCount) / 6,000")
                                .font(.mono)
                                .foregroundStyle(vm.isOverLimit ? Color.accentPink : Color.textTertiary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, .spacing8)

                        if isPreviewExpanded {
                            ScrollView {
                                EmbedPreviewCard(embed: .from(vm.embed))
                                    .padding(.horizontal)
                                    .padding(.bottom)
                            }
                        }
                    }
                    .frame(height: isPreviewExpanded ? geo.size.height * 0.45 : 44)
                    .background(Color.bgElevated)
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle(vm.embed.name.isEmpty ? "新規Embed" : vm.embed.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedHex: $vm.embed.colorHex)
            }
            .sheet(isPresented: $showSendSheet) {
                SendEmbedView(embed: vm.embed, isNewEmbed: vm.isNewEmbed)
            }
            .alert("テンプレートとして保存", isPresented: $showSaveModal) {
                TextField("テンプレート名", text: $saveName)
                Button("保存") { saveEmbed() }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("このEmbedをテンプレートとして保存します")
            }
            .alert("保存エラー", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("このフィールドを削除しますか？", isPresented: $showFieldDeleteConfirm) {
                Button("削除", role: .destructive) {
                    if let offsets = fieldToDelete {
                        withAnimation { vm.removeField(at: offsets) }
                        fieldToDelete = nil
                    }
                }
                Button("キャンセル", role: .cancel) { fieldToDelete = nil }
            }
            .alert("変更が破棄されます", isPresented: $showCancelConfirm) {
                Button("変更を破棄", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("保存していない変更があります。このまま閉じますか？")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("キャンセル") {
                if vm.isModified {
                    showCancelConfirm = true
                } else {
                    dismiss()
                }
            }
            .foregroundStyle(Color.textSecondary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: .spacing16) {
                // 送信ボタン
                Button {
                    showSendSheet = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(vm.isValid ? Color.accentIndigo : Color.textTertiary)
                }
                .disabled(!vm.isValid)
                .accessibilityLabel("送信")

                // 保存ボタン
                Button("保存") {
                    saveName = vm.embed.name
                    showSaveModal = true
                }
                .fontWeight(.semibold)
                .foregroundStyle(vm.isOverLimit || !vm.isValid || vm.embed.hasAnyLimitViolation ? Color.textTertiary : Color.accentIndigo)
                .disabled(vm.isOverLimit || !vm.isValid || vm.embed.hasAnyLimitViolation || isSaving)
            }
        }
    }

    // MARK: - Editor Sections

    @ViewBuilder
    private var messageContentSection: some View {
        SectionCard(title: "メッセージ本文") {
            VStack(alignment: .leading, spacing: .spacing8) {
                Text("埋め込みの上に表示される通常テキストです。ここに入れたメンション（@everyone・@here・ロール・ユーザー）は実際に通知されます。")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)

                TextField("例: @everyone 新しいお知らせです！", text: Binding(
                    get: { vm.embed.messageContent ?? "" },
                    set: { vm.embed.messageContent = $0.isEmpty ? nil : $0; vm.isModified = true }
                ), axis: .vertical)
                .lineLimit(2...5)
                .inputStyle()

                // メンション挿入チップ
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: .spacing6) {
                        Text("挿入:").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        ForEach(["@everyone", "@here"], id: \.self) { token in
                            Button {
                                let current = vm.embed.messageContent ?? ""
                                let sep = current.isEmpty || current.hasSuffix(" ") ? "" : " "
                                vm.embed.messageContent = current + sep + token + " "
                                vm.isModified = true
                            } label: {
                                Text(token)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.accentIndigo)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.accentIndigo.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Text("ロール: <@&ロールID>  ユーザー: <@ユーザーID>")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        SectionCard(title: "コンテンツ") {
            VStack(alignment: .leading, spacing: .spacing4) {
                HStack {
                    Text("タイトル").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    Text("※ タイトル・説明・フィールドのいずれかが必須")
                        .font(.captionSmall)
                        .foregroundStyle(Color.accentOrange)
                }
                TextField("Embedタイトル", text: Binding(
                    get: { vm.embed.title ?? "" },
                    set: { vm.embed.title = $0.isEmpty ? nil : $0; vm.isModified = true }
                ))
                .inputStyle()
                limitLabel(for: \.title, limit: EmbedModel.limitTitle)
            }

            editorField("タイトルのリンク先URL", placeholder: "https://...", binding: Binding(
                get: { vm.embed.embedUrl ?? "" },
                set: { vm.embed.embedUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
            ), isURL: true)

            VStack(alignment: .leading, spacing: .spacing4) {
                Text("説明").font(.captionSmall).foregroundStyle(Color.textTertiary)
                TextField("Embedの説明...", text: Binding(
                    get: { vm.embed.description ?? "" },
                    set: { vm.embed.description = $0.isEmpty ? nil : $0; vm.isModified = true }
                ), axis: .vertical)
                .lineLimit(3...8)
                .inputStyle()
                limitLabel(for: \.description, limit: EmbedModel.limitDescription)
            }
        }
    }

    @ViewBuilder
    private var colorSection: some View {
        SectionCard(title: "カラー") {
            Button { showColorPicker = true } label: {
                HStack(spacing: .spacing12) {
                    Circle().fill(accentColor).frame(width: 24, height: 24)
                    Text("カラーを選択").font(.bodyRegular).foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(String(format: "#%06X", vm.embed.colorHex))
                        .font(.mono).foregroundStyle(Color.textTertiary)
                    Image(systemName: "chevron.right").font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
                .inputStyle()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        SectionCard(title: "メディア") {
            editorField("サムネイルURL（右上の小画像）", placeholder: "https://...", binding: Binding(
                get: { vm.embed.thumbnailUrl ?? "" },
                set: { vm.embed.thumbnailUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
            ), isURL: true)
            editorField("画像URL（大きい画像）", placeholder: "https://...", binding: Binding(
                get: { vm.embed.imageUrl ?? "" },
                set: { vm.embed.imageUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
            ), isURL: true)
        }
    }

    @ViewBuilder
    private var fieldsSection: some View {
        SectionCard(title: "フィールド", trailing: {
            Button {
                if vm.embed.fields.count < EmbedModel.maxFields {
                    withAnimation { vm.addField() }
                }
            } label: {
                Label("追加", systemImage: "plus")
                    .font(.captionRegular)
                    .foregroundStyle(vm.embed.fields.count < EmbedModel.maxFields ? Color.accentIndigo : Color.textTertiary)
            }
            .disabled(vm.embed.fields.count >= EmbedModel.maxFields)
        }) {
            if vm.embed.fields.isEmpty {
                Text("フィールドなし")
                    .font(.captionRegular)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, .spacing4)
            } else {
                VStack(alignment: .leading, spacing: .spacing4) {
                    Text("\(vm.embed.fields.count) / \(EmbedModel.maxFields) フィールド")
                        .font(.captionSmall)
                        .foregroundStyle(vm.embed.fields.count > EmbedModel.maxFields ? Color.accentPink : Color.textTertiary)
                    ForEach($vm.embed.fields) { $field in
                        EmbedFieldEditorRow(field: $field)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    if let idx = vm.embed.fields.firstIndex(where: { $0.id == field.id }) {
                                        fieldToDelete = IndexSet(integer: idx)
                                        showFieldDeleteConfirm = true
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { from, to in vm.moveField(from: from, to: to) }
                    .onDelete { offsets in
                        fieldToDelete = offsets
                        showFieldDeleteConfirm = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        SectionCard(title: "フッター") {
            editorField("フッターテキスト", placeholder: "フッターに表示するテキスト", binding: Binding(
                get: { vm.embed.footerText ?? "" },
                set: { vm.embed.footerText = $0.isEmpty ? nil : $0; vm.isModified = true }
            ), limit: EmbedModel.limitFooter)
            editorField("フッターアイコンURL", placeholder: "https://...", binding: Binding(
                get: { vm.embed.footerIconUrl ?? "" },
                set: { vm.embed.footerIconUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
            ), isURL: true)
            Toggle(isOn: $vm.embed.showTimestamp) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("タイムスタンプを表示")
                        .font(.bodyRegular)
                        .foregroundStyle(Color.textPrimary)
                    Text("送信時刻をフッターに追加")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .tint(Color.accentIndigo)
            .onChange(of: vm.embed.showTimestamp) { vm.isModified = true }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func editorField(
        _ label: String,
        placeholder: String,
        binding: Binding<String>,
        isURL: Bool = false,
        limit: Int? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: .spacing4) {
            Text(label).font(.captionSmall).foregroundStyle(Color.textTertiary)
            TextField(placeholder, text: binding)
                .inputStyle()
                .keyboardType(isURL ? .URL : .default)
                .autocorrectionDisabled(isURL)
                .textInputAutocapitalization(isURL ? .never : .sentences)
                .onChange(of: binding.wrappedValue) { vm.isModified = true }
            if let limit = limit {
                limitLabel(binding.wrappedValue, limit: limit)
            }
        }
    }

    @ViewBuilder
    private func limitLabel(for path: KeyPath<EmbedModel, String?>, limit: Int) -> some View {
        let text = vm.embed[keyPath: path] ?? ""
        let isOver = text.count > limit
        Text("\(text.count) / \(limit)")
            .font(.captionSmall)
            .foregroundStyle(isOver ? Color.accentPink : Color.textTertiary)
    }

    @ViewBuilder
    private func limitLabel(_ text: String, limit: Int) -> some View {
        let isOver = text.count > limit
        Text("\(text.count) / \(limit)")
            .font(.captionSmall)
            .foregroundStyle(isOver ? Color.accentPink : Color.textTertiary)
    }

    // MARK: - Save

    private func saveEmbed() {
        guard !saveName.isEmpty else { return }
        isSaving = true
        Task {
            var updated = vm.embed
            updated.name = saveName
            updated.guildId = appState.selectedGuildId
            updated.updatedAt = .now

            do {
                let saved: EmbedModel
                if vm.isNewEmbed {
                    saved = try await services.embeds.create(updated)
                } else {
                    saved = try await services.embeds.update(updated)
                }
                onSave(saved)
                isSaving = false
                dismiss()
            } catch {
                errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionCard<Content: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack {
                Text(title)
                    .font(.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                trailing()
            }
            VStack(alignment: .leading, spacing: .spacing8) {
                content()
            }
        }
    }
}

extension SectionCard where Trailing == EmptyView {
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = { EmptyView() }
        self.content = content
    }
}

private struct EmbedFieldEditorRow: View {
    @Binding var field: EmbedFieldModel

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack(spacing: .spacing8) {
                TextField("フィールド名", text: $field.name)
                    .font(.captionRegular)
                    .fontWeight(.semibold)
                    .inputStyle()

                Toggle("インライン表示", isOn: $field.inline)
                    .labelsHidden()
                    .tint(Color.accentIndigo)
                    .scaleEffect(0.85)
                    .accessibilityLabel("インライン表示")
            }
            limitLabel(field.name, limit: EmbedModel.limitFieldName)

            TextField("フィールドの内容", text: $field.value, axis: .vertical)
                .font(.captionRegular)
                .lineLimit(2...4)
                .inputStyle()
            limitLabel(field.value, limit: EmbedModel.limitFieldValue)
        }
        .padding(.spacing8)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
    }

    @ViewBuilder
    private func limitLabel(_ text: String, limit: Int) -> some View {
        let isOver = text.count > limit
        Text("\(text.count) / \(limit)")
            .font(.captionSmall)
            .foregroundStyle(isOver ? Color.accentPink : Color.textTertiary)
    }
}

// MARK: - TextField スタイル

extension View {
    func inputStyle() -> some View {
        self
            .padding(.spacing10)
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
            .font(.bodySmall)
    }
}

#Preview {
    EmbedEditorView(embed: nil) { _ in }
        .environment(\.services, ServiceContainer.live())
}
