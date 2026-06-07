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

    // Focus
    @FocusState private var focusedField: FieldFocus?

    // Keyboard
    @State private var keyboardHeight: CGFloat = 0

    // Color picker
    @State private var showColorPicker = false
    @State private var showSendSheet = false

    // Image upload
    @State private var thumbnailPhotoItem: PhotosPickerItem? = nil
    @State private var imagePhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingThumbnail = false
    @State private var isUploadingImage = false
    @State private var uploadError: String? = nil

    // Reordering
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
                    VStack(spacing: .spacing16) {
                        // テンプレート名
                        templateNameRow

                        // Discord風編集可能プレビュー
                        editablePreview
                    }
                    .padding(.spacing16)
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
            .background(Color.bgPrimary)
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
            .alert("変更が破棄されます", isPresented: $showCancelConfirm) {
                Button("変更を破棄", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("保存していない変更があります。このまま閉じますか？")
            }
        }
    }

    // MARK: - Keyboard Toolbar

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            HStack(spacing: .spacing12) {
                // +Field
                if vm.embed.fields.count < EmbedModel.maxFields {
                    Button { vm.addField() } label: {
                        Label("フィールド", systemImage: "plus").font(.captionRegular)
                    }
                    .foregroundStyle(accentColor)
                }

                Spacer()

                // 文字数
                Text("\(vm.charCount) / 6,000")
                    .font(.mono)
                    .foregroundStyle(vm.isOverLimit ? Color.accentPink : Color.textTertiary)

                // 閉じる
                Button("完了") { focusedField = nil }
                    .font(.captionRegular).fontWeight(.semibold)
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
            .foregroundStyle(Color.textSecondary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: .spacing16) {
                Button {
                    showSendSheet = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(vm.isValid ? accentColor : Color.textTertiary)
                }
                .disabled(!vm.isValid)
                .accessibilityLabel("送信")

                if appState.isPro {
                    Button("保存") {
                        saveEmbed()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave && !isSaving ? accentColor : Color.textTertiary)
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Template Name

    private var templateNameRow: some View {
        VStack(alignment: .leading, spacing: .spacing6) {
            HStack(spacing: .spacing4) {
                Text("テンプレート名")
                    .font(.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)
                Text("必須")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.accentRed)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.accentRed.opacity(0.1))
                    .clipShape(Capsule())
            }
            TextField("名前を入力", text: Binding(
                get: { vm.embed.name },
                set: { vm.embed.name = $0; vm.isModified = true }
            ))
            .font(.bodySmall)
            .inputStyle()
            .focused($focusedField, equals: .templateName)
        }
    }

    // MARK: - Editable Preview

    private var editablePreview: some View {
        HStack(alignment: .top, spacing: .spacing12) {
            // Bot アバター
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentIndigo, Color.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: .spacing4) {
                // ヘッダー: 名前 + BOT + 時刻（常時）
                HStack(spacing: .spacing6) {
                    Text("Noxy")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentIndigo)
                    Text("BOT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("今日 ") + Text(Date(), style: .time)
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                }

                // メッセージ本文（常時表示）
                TextField("メッセージを入力...", text: Binding(
                    get: { vm.embed.messageContent ?? "" },
                    set: { vm.embed.messageContent = $0.isEmpty ? nil : $0; vm.isModified = true }
                ), axis: .vertical)
                .lineLimit(2...5)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
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
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var embedBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左カラーバー（タップでカラー変更）
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)
                .onTapGesture { showColorPicker = true }

            VStack(alignment: .leading, spacing: .spacing8) {
                // タイトル（常時表示）
                TextField("タイトル", text: Binding(
                    get: { vm.embed.title ?? "" },
                    set: { vm.embed.title = $0.isEmpty ? nil : $0; vm.isModified = true }
                ))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentColor)
                .textFieldStyle(.plain)
                .background(.clear)
                .focused($focusedField, equals: .title)
                .id("title-anchor")
                .padding(.horizontal, 6).padding(.vertical, 4)
                .embedDashedBorder(focused: focusedField == .title)

                // 説明（常時表示）
                ZStack(alignment: .topLeading) {
                    if (vm.embed.description ?? "").isEmpty {
                        Text("説明")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                            .padding(.top, 8).padding(.leading, 6)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: Binding(
                        get: { vm.embed.description ?? "" },
                        set: { vm.embed.description = $0.isEmpty ? nil : $0; vm.isModified = true }
                    ))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 60, maxHeight: .infinity)
                    .focused($focusedField, equals: .description)
                }
                .padding(.horizontal, 2).padding(.vertical, 2)
                .embedDashedBorder(focused: focusedField == .description)
                .id("desc-anchor")

                // タイトルリンク（オプション）
                if vm.embed.embedUrl != nil {
                    HStack(spacing: .spacing6) {
                        Image(systemName: "link").font(.system(size: 12)).foregroundStyle(Color.textTertiary)
                        TextField("https://...", text: Binding(
                            get: { vm.embed.embedUrl ?? "" },
                            set: { vm.embed.embedUrl = $0.isEmpty ? nil : $0; vm.isModified = true }
                        ))
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
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
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .embedDashedBorder(focused: focusedField == .embedUrl)
                }

                // フィールド
                fieldsSection

                // 画像（常時枠）
                imageSection

                // フッター（常時表示）
                footerSection
            }
            .padding(.spacing10)

            // サムネイル（右上 / 常時枠）
            thumbnailSection
        }
        .background(Color.bgSurface)
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
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.spacing4)
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
                                        .foregroundStyle(Color.textTertiary)
                                    Text("タップして画像を追加")
                                        .font(.captionSmall)
                                        .foregroundStyle(Color.textTertiary)
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
            .fill(Color.bgElevated)
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(Color.accentIndigo.opacity(0.28))
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
                            RoundedRectangle(cornerRadius: 4).fill(Color.bgElevated)
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
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .offset(x: 4, y: -4)
                }
            } else {
                PhotosPicker(selection: $thumbnailPhotoItem, matching: .images) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.bgElevated)
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundStyle(Color.accentIndigo.opacity(0.28))
                        )
                        .overlay {
                            if isUploadingThumbnail {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.textTertiary)
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
        HStack(spacing: .spacing4) {
            if let icon = vm.embed.footerIconUrl, !icon.isEmpty,
               let url = URL(string: icon) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(Color.bgElevated)
                    }
                }
                .frame(width: 14, height: 14)
                .clipShape(Circle())
            }

            TextField("フッターテキスト", text: Binding(
                get: { vm.embed.footerText ?? "" },
                set: { vm.embed.footerText = $0.isEmpty ? nil : $0; vm.isModified = true }
            ))
            .font(.captionSmall)
            .foregroundStyle(Color.textTertiary)
            .textFieldStyle(.plain)
            .background(.clear)
            .focused($focusedField, equals: .footerText)
            .padding(.horizontal, 5).padding(.vertical, 3)
            .embedDashedBorder(focused: focusedField == .footerText)

            Text(Date(), style: .time)
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)

            Spacer()
        }
    }

    // MARK: - Fields Section

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            // Inline fields
            let inlineFields = vm.embed.fields.filter { $0.inline }
            if !inlineFields.isEmpty {
                let cols = min(inlineFields.count, 3)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: .spacing8), count: cols),
                    spacing: .spacing8
                ) {
                    ForEach(inlineFields) { field in
                        fieldEditor(fieldBinding(for: field))
                    }
                }
            }

            // Block fields
            let blockFields = vm.embed.fields.filter { !$0.inline }
            ForEach(blockFields) { field in
                fieldEditor(fieldBinding(for: field))
            }

            // 追加ボタン
            if vm.embed.fields.count < EmbedModel.maxFields {
                Button { vm.addField() } label: {
                    HStack(spacing: .spacing6) {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("フィールドを追加").font(.captionRegular)
                    }
                    .foregroundStyle(accentColor)
                    .padding(.vertical, .spacing6)
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

        return VStack(alignment: .leading, spacing: .spacing4) {
            HStack(spacing: .spacing6) {
                // ドラッグハンドル
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
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

                // 削除
                Button {
                    vm.embed.fields.removeAll { $0.id == fieldId }
                    vm.isModified = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                }
            }

            TextField("値", text: field.value)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
                .textFieldStyle(.plain)
                .background(.clear)
                .focused($focusedField, equals: .fieldValue(fieldId))
                .padding(.horizontal, 4).padding(.vertical, 3)
                .embedDashedBorder(focused: focusedField == .fieldValue(fieldId))
        }
        .padding(.spacing8)
        .background(isReordering ? accentColor.opacity(0.15) : Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isReordering ? accentColor : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isReordering ? 1.02 : 1.0)
        .shadow(color: isReordering ? Color.black.opacity(0.15) : .clear, radius: 4, y: 2)
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
