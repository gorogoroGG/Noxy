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
        (embed.title ?? "").isEmpty == false
        || (embed.description ?? "").isEmpty == false
        || !embed.fields.isEmpty
    }

    var charCount: Int { embed.totalCharCount }
    var isOverLimit: Bool { charCount > 6000 }

    func addField(inline: Bool = false) {
        embed.fields.append(EmbedFieldModel(id: UUID().uuidString, name: "", value: "", inline: inline))
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
    @State private var errorMessage: String? = nil
    @State private var showCancelConfirm = false

    @FocusState private var focusedField: FieldFocus?
    @State private var keyboardHeight: CGFloat = 0

    @State private var showColorPicker = false
    @State private var showSendSheet = false

    @State private var thumbnailPhotoItem: PhotosPickerItem? = nil
    @State private var imagePhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingThumbnail = false
    @State private var isUploadingImage = false
    @State private var uploadError: String? = nil

    @State private var reorderingFieldId: String? = nil

    let onSave: (EmbedModel) -> Void

    init(embed: EmbedModel? = nil, onSave: @escaping (EmbedModel) -> Void) {
        _vm = State(initialValue: EmbedEditorViewModel(embed: embed))
        self.onSave = onSave
    }

    enum FieldFocus: Hashable {
        case templateName
        case messageContent
        case title
        case description
        case fieldName(String), fieldValue(String)
        case footerText
        case embedUrl
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
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.md) {
                        templateNameSection
                        previewSection
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 16 : 16)
                }
                .onChange(of: focusedField) { _, newValue in
                    if let field = newValue {
                        withAnimation(.easeOut(duration: 0.2)) {
                            switch field {
                            case .fieldName(let id), .fieldValue(let id):
                                proxy.scrollTo("field-\(id)", anchor: .center)
                            case .title:
                                proxy.scrollTo("title-anchor", anchor: .top)
                            case .description:
                                proxy.scrollTo("desc-anchor", anchor: .top)
                            case .messageContent:
                                proxy.scrollTo("message-anchor", anchor: .top)
                            default:
                                break
                            }
                        }
                    }
                }
                .onChange(of: keyboardHeight) { _, newValue in
                    if newValue > 0, let field = focusedField {
                        withAnimation(.easeOut(duration: 0.2)) {
                            switch field {
                            case .fieldName(let id), .fieldValue(let id):
                                proxy.scrollTo("field-\(id)", anchor: .center)
                            case .title:
                                proxy.scrollTo("title-anchor", anchor: .top)
                            case .description:
                                proxy.scrollTo("desc-anchor", anchor: .top)
                            case .messageContent:
                                proxy.scrollTo("message-anchor", anchor: .top)
                            default:
                                break
                            }
                        }
                    }
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle(vm.embed.name.isEmpty ? "新規Embed" : vm.embed.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
                keyboardToolbar
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let value = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = value.height
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedHex: $vm.embed.colorHex)
            }
            .sheet(isPresented: $showSendSheet) {
                SendEmbedView(embed: vm.embed, isNewEmbed: vm.isNewEmbed)
            }
            .alert("保存エラー", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay {
                if showCancelConfirm {
                    ConfirmModal(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Theme.Color.statusWarn,
                        title: "変更が破棄されます",
                        message: "保存していない変更があります。このまま閉じますか？",
                        primaryLabel: "変更を破棄",
                        primaryRole: .destructive,
                        onPrimary: {
                            dismiss()
                            showCancelConfirm = false
                        },
                        onCancel: {
                            showCancelConfirm = false
                        }
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Keyboard Toolbar

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            HStack(spacing: Theme.Spacing.sm) {
                if vm.embed.fields.count < EmbedModel.maxFields {
                    Button { vm.addField() } label: {
                        Label("フィールド", systemImage: "plus")
                            .font(Theme.Font.caption)
                    }
                    .foregroundStyle(accentColor)
                }

                Spacer()

                // 文字数: IBM Plex Mono で等幅表現
                MonoText(value: "\(vm.charCount) / 6,000", font: Theme.Font.mono, color: vm.isOverLimit ? Theme.Color.statusBad : Theme.Color.textTertiary)

                Button("完了") { focusedField = nil }
                    .font(Theme.Font.caption)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Toolbar (Navigation)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("キャンセル") {
                if vm.isModified { showCancelConfirm = true } else { dismiss() }
            }
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.textSecondary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    showSendSheet = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(vm.isValid ? accentColor : Theme.Color.textTertiary)
                }
                .disabled(!vm.isValid)
                .accessibilityLabel("送信")

                if appState.isPro {
                    Button("保存") {
                        saveEmbed()
                    }
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(canSave && !isSaving ? Theme.Color.accent : Theme.Color.textTertiary)
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Template Name Section
    // Noxy Design Language: FormField を使用し、セクションビルド

    private var templateNameSection: some View {
        FormSection("基本情報", icon: "doc.text") {
            FormField.text(
                label: "テンプレート名",
                text: Binding(
                    get: { vm.embed.name },
                    set: { vm.embed.name = $0; vm.isModified = true }
                ),
                placeholder: "名前を入力",
                isRequired: true
            )
        }
    }

    // MARK: - Preview Section
    // Noxy Design Language: Card コンテナ + sur 背景 + 14px 角丸 + line ボーダー

    private var previewSection: some View {
        FormSection("プレビュー", icon: "eye") {
            editablePreview
        }
    }

    private var editablePreview: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Bot アバター
            ZStack {
                Circle()
                    .fill(Theme.Color.accent)
                    .frame(width: 40, height: 40)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.accentInk)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // ヘッダー
                HStack(spacing: Theme.Spacing.xs) {
                    Text("Noxy")
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.accent)

                    Badge(text: "BOT", color: Theme.Color.accent, style: .filled)

                    Text("今日 ") + Text(Date(), style: .time)
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)

                    Spacer()
                }

                // メッセージ本文
                TextField("メッセージを入力...", text: Binding(
                    get: { vm.embed.messageContent ?? "" },
                    set: { vm.embed.messageContent = $0.isEmpty ? nil : $0; vm.isModified = true }
                ), axis: .vertical)
                .lineLimit(2...5)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .textFieldStyle(.plain)
                .background(.clear)
                .focused($focusedField, equals: .messageContent)
                .id("message-anchor")
                .padding(.horizontal, 6).padding(.vertical, 4)
                .embedDashedBorder(focused: focusedField == .messageContent)

                // Embed ブロック
                embedBlock
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }

    private var embedBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左カラーバー
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)
                .onTapGesture { showColorPicker = true }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // タイトル
                TextField("タイトル", text: Binding(
                    get: { vm.embed.title ?? "" },
                    set: { vm.embed.title = $0.isEmpty ? nil : $0; vm.isModified = true }
                ))
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(accentColor)
                .textFieldStyle(.plain)
                .background(.clear)
                .focused($focusedField, equals: .title)
                .id("title-anchor")
                .padding(.horizontal, 6).padding(.vertical, 4)
                .embedDashedBorder(focused: focusedField == .title)

                // 説明
                ZStack(alignment: .topLeading) {
                    if (vm.embed.description ?? "").isEmpty {
                        Text("説明")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .padding(.top, 8).padding(.leading, 6)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: Binding(
                        get: { vm.embed.description ?? "" },
                        set: { vm.embed.description = $0.isEmpty ? nil : $0; vm.isModified = true }
                    ))
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 60, maxHeight: .infinity)
                    .focused($focusedField, equals: .description)
                }
                .padding(.horizontal, 2).padding(.vertical, 2)
                .embedDashedBorder(focused: focusedField == .description)
                .id("desc-anchor")

                // タイトルリンク
                if vm.embed.embedUrl != nil {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Color.textTertiary)
                        TextField("https://...", text: Binding(
                            get: { vm.embed.embedUrl ?? "" },
                            set: { vm.embed.embedUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
                        ))
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .textFieldStyle(.plain)
                        .background(.clear)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .embedUrl)

                        Button {
                            vm.embed.embedUrl = nil
                            vm.isModified = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .embedDashedBorder(focused: focusedField == .embedUrl)
                }

                // フィールド
                fieldsSection

                // 画像
                imageSection

                // フッター
                footerSection
            }
            .padding(Theme.Spacing.xs)

            // サムネイル
            thumbnailSection
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Image Section

    private var imageSection: some View {
        Group {
            if let imgUrl = vm.embed.imageUrl, !imgUrl.isEmpty,
               let url = URL(string: imgUrl) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            placeholderImage
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    Button {
                        vm.embed.imageUrl = nil
                        vm.isModified = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.Color.accentInk)
                            .background(Theme.Color.bg)
                            .clipShape(Circle())
                    }
                    .padding(Theme.Spacing.xs)
                }
            } else {
                PhotosPicker(selection: $imagePhotoItem, matching: .images) {
                    placeholderImage
                        .overlay {
                            if isUploadingImage {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Theme.Color.textTertiary)
                                    Text("タップして画像を追加")
                                        .font(Theme.Font.caption2)
                                        .foregroundStyle(Theme.Color.textTertiary)
                                }
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: imagePhotoItem) { uploadPhoto(item: imagePhotoItem, target: .image) }
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Theme.Color.surfaceRaised)
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(Theme.Color.accent.opacity(0.28))
            )
    }

    // MARK: - Thumbnail Section

    private var thumbnailSection: some View {
        Group {
            if let thumbUrl = vm.embed.thumbnailUrl, !thumbUrl.isEmpty,
               let url = URL(string: thumbUrl) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            RoundedRectangle(cornerRadius: 4).fill(Theme.Color.surfaceRaised)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    Button {
                        vm.embed.thumbnailUrl = nil
                        vm.isModified = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Color.accentInk)
                            .background(Theme.Color.bg)
                            .clipShape(Circle())
                    }
                    .offset(x: 4, y: -4)
                }
            } else {
                PhotosPicker(selection: $thumbnailPhotoItem, matching: .images) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Color.surfaceRaised)
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundStyle(Theme.Color.accent.opacity(0.28))
                        )
                        .overlay {
                            if isUploadingThumbnail {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.Color.textTertiary)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: thumbnailPhotoItem) { uploadPhoto(item: thumbnailPhotoItem, target: .thumbnail) }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let icon = vm.embed.footerIconUrl, !icon.isEmpty,
               let url = URL(string: icon) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(Theme.Color.surfaceRaised)
                    }
                }
                .frame(width: 14, height: 14)
                .clipShape(Circle())
            }

            TextField("フッターテキスト", text: Binding(
                get: { vm.embed.footerText ?? "" },
                set: { vm.embed.footerText = $0.isEmpty ? nil : $0; vm.isModified = true }
            ))
            .font(Theme.Font.caption2)
            .foregroundStyle(Theme.Color.textTertiary)
            .textFieldStyle(.plain)
            .background(.clear)
            .focused($focusedField, equals: .footerText)
            .padding(.horizontal, 5).padding(.vertical, 3)
            .embedDashedBorder(focused: focusedField == .footerText)

            Text(Date(), style: .time)
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)

            Spacer()
        }
    }

    // MARK: - Fields Section

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(vm.embed.fields) { field in
                fieldEditor(fieldBinding(for: field))
            }

            if vm.embed.fields.count < EmbedModel.maxFields {
                Button { vm.addField() } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("フィールドを追加").font(Theme.Font.caption)
                    }
                    .foregroundStyle(accentColor)
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func fieldBinding(for field: EmbedFieldModel) -> Binding<EmbedFieldModel> {
        Binding(
            get: { field },
            set: { newValue in
                if let idx = vm.embed.fields.firstIndex(where: { $0.id == field.id }) {
                    vm.embed.fields[idx] = newValue
                    vm.isModified = true
                }
            }
        )
    }

    private func fieldEditor(_ field: Binding<EmbedFieldModel>) -> some View {
        let fieldId = field.wrappedValue.id
        let isReordering = reorderingFieldId == fieldId

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                // ドラッグハンドル
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Color.textTertiary)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in
                                reorderingFieldId = fieldId
                                withAnimation(.easeInOut(duration: 0.2)) { }
                            }
                            .sequenced(before: DragGesture())
                            .onChanged { value in
                                switch value {
                                case .second(_, let drag?):
                                    let offset = drag.translation.height
                                    let estimatedFieldHeight: CGFloat = 60
                                    let moveCount = Int(round(offset / estimatedFieldHeight))
                                    if moveCount != 0,
                                       let currentIdx = vm.embed.fields.firstIndex(where: { $0.id == fieldId }) {
                                        let newIndex = max(0, min(vm.embed.fields.count - 1, currentIdx + moveCount))
                                        if newIndex != currentIdx {
                                            vm.embed.fields.swapAt(currentIdx, newIndex)
                                            reorderingFieldId = fieldId
                                            vm.isModified = true
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            .onEnded { _ in
                                reorderingFieldId = nil
                            }
                    )

                TextField("名前", text: field.name)
                    .font(Theme.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .textFieldStyle(.plain)
                    .background(.clear)
                    .focused($focusedField, equals: .fieldName(fieldId))
                    .padding(.horizontal, 4).padding(.vertical, 3)
                    .embedDashedBorder(focused: focusedField == .fieldName(fieldId))

                Spacer()

                // インライン切替
                Toggle("", isOn: field.inline)
                    .labelsHidden()
                    .tint(accentColor)
                    .scaleEffect(0.75)
                    .frame(width: 44)

                // 削除
                Button {
                    vm.embed.fields.removeAll { $0.id == fieldId }
                    vm.isModified = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Color.statusBad)
                }
            }

            TextField("値", text: field.value)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .textFieldStyle(.plain)
                .background(.clear)
                .focused($focusedField, equals: .fieldValue(fieldId))
                .padding(.horizontal, 4).padding(.vertical, 3)
                .embedDashedBorder(focused: focusedField == .fieldValue(fieldId))
        }
        .padding(Theme.Spacing.xs)
        .background(isReordering ? Theme.Color.accentDim : Theme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isReordering ? accentColor : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isReordering ? 1.02 : 1.0)
        .id("field-\(fieldId)")
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
                      let uiImage = UIImage(data: data) else {
                    uploadError = "画像の読み込みに失敗しました"
                    return
                }
                let compressed = compressImage(uiImage, maxDimension: 800, maxBytes: 500_000)
                let url = try await uploadImageData(compressed)
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

    private func compressImage(_ image: UIImage, maxDimension: CGFloat, maxBytes: Int) -> Data {
        let resized = resizeImage(image, maxDimension: maxDimension)
        var quality: CGFloat = 0.60
        var data = resized.jpegData(compressionQuality: quality)!
        while data.count > maxBytes && quality > 0.30 {
            quality -= 0.10
            if let d = resized.jpegData(compressionQuality: quality) {
                data = d
            }
        }
        return data
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resized
    }

    private func uploadImageData(_ data: Data) async throws -> String {
        let endpoint = "\(DiscordConfig.workerURL)/upload/image"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = WorkerClient.bearerToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: respData, encoding: .utf8) ?? ""
            throw UploadError.serverError(status: http.statusCode, body: bodyText)
        }
        struct UploadResponse: Decodable { let url: String }
        return try JSONDecoder().decode(UploadResponse.self, from: respData).url
    }

    enum UploadError: LocalizedError {
        case serverError(status: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .serverError(let status, let body):
                if status == 404 {
                    return "アップロードエンドポイントが見つかりません。Workerのデプロイが必要です。"
                }
                return "サーバーエラー (\(status)): \(body.prefix(200))"
            }
        }
    }

    // MARK: - Save

    private func saveEmbed() {
        guard canSave else { return }
        isSaving = true
        Task {
            var updated = vm.embed
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

// MARK: - Preview

#Preview {
    EmbedEditorView(embed: nil) { _ in }
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
}
