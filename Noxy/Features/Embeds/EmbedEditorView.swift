import SwiftUI
import Observation
import PhotosUI

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
    @State private var showSendSheet = false
    @State private var showPreview = false
    @State private var showAdvanced = false
    @State private var fieldToDelete: IndexSet? = nil
    @State private var showFieldDeleteConfirm = false
    @State private var errorMessage: String? = nil
    @State private var showCancelConfirm = false

    // 画像アップロード
    @State private var thumbnailPhotoItem: PhotosPickerItem? = nil
    @State private var imagePhotoItem: PhotosPickerItem?    = nil
    @State private var isUploadingThumbnail = false
    @State private var isUploadingImage     = false
    @State private var uploadError: String? = nil

    let onSave: (EmbedModel) -> Void

    init(embed: EmbedModel? = nil, onSave: @escaping (EmbedModel) -> Void) {
        _vm = State(initialValue: EmbedEditorViewModel(embed: embed))
        self.onSave = onSave
    }

    private var accentColor: Color {
        Color(uiColor: UIColor(hex: vm.embed.colorHex))
    }

    private var canSave: Bool {
        vm.isValid && !vm.isOverLimit && !vm.embed.hasAnyLimitViolation
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing24) {
                    nameSection
                    Divider().background(Color.border)
                    basicSection
                    fieldsSection
                    charCountRow
                    advancedSection
                }
                .padding()
                .padding(.bottom, .spacing32)
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
            .sheet(isPresented: $showPreview) {
                previewSheet
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
                // プレビュー
                Button {
                    showPreview = true
                } label: {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .accessibilityLabel("プレビュー")

                // 送信
                Button {
                    showSendSheet = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(vm.isValid ? Color.accentIndigo : Color.textTertiary)
                }
                .disabled(!vm.isValid)
                .accessibilityLabel("送信")

                // 保存（Pro のみ）
                if appState.isPro {
                    Button("保存") {
                        saveEmbed()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave && !isSaving ? Color.accentIndigo : Color.textTertiary)
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Preview Sheet

    private var previewSheet: some View {
        NavigationStack {
            ScrollView {
                EmbedPreviewCard(embed: .from(vm.embed))
                    .padding()
            }
            .background(Color.bgPrimary)
            .navigationTitle("プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { showPreview = false }
                }
            }
        }
    }

    // MARK: - Template Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: .spacing6) {
            Text("テンプレート名")
                .font(.captionSmall)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            TextField("名前なし", text: Binding(
                get: { vm.embed.name },
                set: { vm.embed.name = $0; vm.isModified = true }
            ))
            .font(.titleLarge)
            .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Basic Section

    private var basicSection: some View {
        FormSection("コンテンツ", icon: "doc.text", footer: "タイトル・説明・フィールドのいずれかが必須") {
            VStack(spacing: .spacing12) {
                FormField.text(
                    label: "タイトル",
                    text: Binding(
                        get: { vm.embed.title ?? "" },
                        set: { vm.embed.title = $0.isEmpty ? nil : $0; vm.isModified = true }
                    ),
                    helper: "\(vm.embed.title?.count ?? 0) / \(EmbedModel.limitTitle)"
                )

                FormField.text(
                    label: "説明",
                    text: Binding(
                        get: { vm.embed.description ?? "" },
                        set: { vm.embed.description = $0.isEmpty ? nil : $0; vm.isModified = true }
                    ),
                    axis: .vertical,
                    helper: "\(vm.embed.description?.count ?? 0) / \(EmbedModel.limitDescription)"
                )

                Button { showColorPicker = true } label: {
                    HStack(spacing: .spacing12) {
                        Circle().fill(accentColor).frame(width: 24, height: 24)
                        Text("カラー").font(.bodyRegular).foregroundStyle(Color.textPrimary)
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
    }

    // MARK: - Fields Section

    @ViewBuilder
    private var fieldsSection: some View {
        FormSection(
            "フィールド",
            icon: "list.bullet.rectangle",
            footer: vm.embed.fields.isEmpty ? nil : "\(vm.embed.fields.count) / \(EmbedModel.maxFields) フィールド"
        ) {
            VStack(alignment: .leading, spacing: .spacing8) {
                if vm.embed.fields.isEmpty {
                    Text("フィールドなし — 右上の＋で追加")
                        .font(.captionRegular)
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, .spacing4)
                } else {
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

                Button {
                    if vm.embed.fields.count < EmbedModel.maxFields {
                        withAnimation { vm.addField() }
                    }
                } label: {
                    Label("フィールドを追加", systemImage: "plus.circle.fill")
                        .font(.captionRegular)
                        .fontWeight(.medium)
                        .foregroundStyle(vm.embed.fields.count < EmbedModel.maxFields ? Color.accentIndigo : Color.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(vm.embed.fields.count >= EmbedModel.maxFields)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Char Count

    private var charCountRow: some View {
        HStack {
            Spacer()
            Text("\(vm.charCount) / 6,000 文字")
                .font(.mono)
                .foregroundStyle(vm.isOverLimit ? Color.accentPink : Color.textTertiary)
        }
    }

    // MARK: - Advanced Section (collapsible)

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack(spacing: .spacing8) {
                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                        .font(.captionRegular)
                        .foregroundStyle(Color.textTertiary)
                        .animation(.spring(duration: 0.2), value: showAdvanced)
                    Text("詳細設定")
                        .font(.captionSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    if !showAdvanced {
                        Text("メッセージ本文・メディア・フッター")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary.opacity(0.6))
                    }
                }
                .padding(.spacing12)
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(alignment: .leading, spacing: .spacing20) {
                    messageContentSection
                    mediaSection
                    footerSection
                }
                .padding(.horizontal, .spacing12)
                .padding(.bottom, .spacing12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    // MARK: - Advanced Sub-Sections

    private var messageContentSection: some View {
        FormSection("メッセージ本文", icon: "text.bubble") {
            VStack(alignment: .leading, spacing: .spacing8) {
                HStack(spacing: .spacing6) {
                    Image(systemName: "info.circle")
                        .font(.captionSmall)
                        .foregroundStyle(Color.accentIndigo)
                    Text("Embedの外側に表示される通常テキスト。@メンションが機能します。")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }

                TextField("例: @everyone 新しいお知らせです！", text: Binding(
                    get: { vm.embed.messageContent ?? "" },
                    set: { vm.embed.messageContent = $0.isEmpty ? nil : $0; vm.isModified = true }
                ), axis: .vertical)
                .lineLimit(2...5)
                .inputStyle()

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
                    }
                }
            }
        }
    }

    private var mediaSection: some View {
        FormSection("メディア", icon: "photo") {
            VStack(alignment: .leading, spacing: .spacing8) {
                FormField(label: "サムネイル（右上の小画像）") {
                    HStack(spacing: .spacing8) {
                        TextField("https://...", text: Binding(
                            get: { vm.embed.thumbnailUrl ?? "" },
                            set: { vm.embed.thumbnailUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
                        ))
                        .inputStyle()
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        if isUploadingThumbnail {
                            ProgressView().scaleEffect(0.8).frame(width: 32)
                        } else {
                            PhotosPicker(selection: $thumbnailPhotoItem, matching: .images) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.accentIndigo)
                            }
                            .frame(width: 32)
                        }
                    }
                }

                FormField(label: "画像（大きい画像）") {
                    HStack(spacing: .spacing8) {
                        TextField("https://...", text: Binding(
                            get: { vm.embed.imageUrl ?? "" },
                            set: { vm.embed.imageUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
                        ))
                        .inputStyle()
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        if isUploadingImage {
                            ProgressView().scaleEffect(0.8).frame(width: 32)
                        } else {
                            PhotosPicker(selection: $imagePhotoItem, matching: .images) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.accentIndigo)
                            }
                            .frame(width: 32)
                        }
                    }
                }

                FormField(label: "タイトルのリンク先URL", helper: "Embedタイトルをタップしたときの遷移先") {
                    TextField("https://...", text: Binding(
                        get: { vm.embed.embedUrl ?? "" },
                        set: { vm.embed.embedUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
                    ))
                    .inputStyle()
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                if let err = uploadError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.captionSmall).foregroundStyle(Color.accentPink)
                }
            }
        }
        .onChange(of: thumbnailPhotoItem) { uploadPhoto(item: thumbnailPhotoItem, target: .thumbnail) }
        .onChange(of: imagePhotoItem)     { uploadPhoto(item: imagePhotoItem,     target: .image) }
    }

    private var footerSection: some View {
        FormSection("フッター", icon: "doc.plaintext") {
            VStack(alignment: .leading, spacing: .spacing8) {
                FormField.text(
                    label: "フッターテキスト",
                    text: Binding(
                        get: { vm.embed.footerText ?? "" },
                        set: { vm.embed.footerText = $0.isEmpty ? nil : $0; vm.isModified = true }
                    ),
                    placeholder: "フッターに表示するテキスト"
                )
                limitLabel(vm.embed.footerText ?? "", limit: EmbedModel.limitFooter)

                FormField(label: "フッターアイコンURL", helper: "フッター横に表示する小さなアイコン画像") {
                    TextField("https://...", text: Binding(
                        get: { vm.embed.footerIconUrl ?? "" },
                        set: { vm.embed.footerIconUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
                    ))
                    .inputStyle()
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                FormField.toggle(
                    label: "タイムスタンプを表示",
                    isOn: Binding(
                        get: { vm.embed.showTimestamp },
                        set: { vm.embed.showTimestamp = $0; vm.isModified = true }
                    ),
                    helper: "送信時刻をフッターに追加"
                )
            }
        }
    }

    // MARK: - Helpers

    private func limitLabel(_ text: String, limit: Int) -> some View {
        Text("\(text.count) / \(limit)")
            .font(.captionSmall)
            .foregroundStyle(text.count > limit ? Color.accentPink : Color.textTertiary)
    }

    // MARK: - Image Upload

    private enum ImageTarget { case thumbnail, image }

    private func uploadPhoto(item: PhotosPickerItem?, target: ImageTarget) {
        guard let item else { return }
        Task {
            switch target {
            case .thumbnail: isUploadingThumbnail = true
            case .image:     isUploadingImage = true
            }
            uploadError = nil
            defer {
                switch target {
                case .thumbnail: isUploadingThumbnail = false
                case .image:     isUploadingImage = false
                }
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data),
                      let jpeg = uiImage.jpegData(compressionQuality: 0.75) else {
                    uploadError = "画像の読み込みに失敗しました"
                    return
                }
                let url = try await uploadImageData(jpeg)
                await MainActor.run {
                    switch target {
                    case .thumbnail: vm.embed.thumbnailUrl = url
                    case .image:     vm.embed.imageUrl = url
                    }
                    vm.isModified = true
                }
            } catch {
                await MainActor.run { uploadError = "アップロード失敗: \(error.localizedDescription)" }
            }
        }
    }

    private func uploadImageData(_ data: Data) async throws -> String {
        let endpoint = "\(DiscordConfig.workerURL)/upload/image"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if !DiscordConfig.workerAPISecret.isEmpty {
            request.setValue(DiscordConfig.workerAPISecret, forHTTPHeaderField: "X-Bot-Secret")
        }
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct UploadResponse: Decodable { let url: String }
        return try JSONDecoder().decode(UploadResponse.self, from: respData).url
    }

    // MARK: - Save

    private func saveEmbed() {
        guard canSave else { return }
        isSaving = true
        Task {
            var updated = vm.embed
            // 名前が空なら自動生成
            if updated.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let base = updated.title ?? "Embed"
                let date = Date.now.formatted(.dateTime.month().day())
                updated.name = "\(base) \(date)"
            }
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

    private func limitLabel(_ text: String, limit: Int) -> some View {
        Text("\(text.count) / \(limit)")
            .font(.captionSmall)
            .foregroundStyle(text.count > limit ? Color.accentPink : Color.textTertiary)
    }
}

#Preview {
    EmbedEditorView(embed: nil) { _ in }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
}
