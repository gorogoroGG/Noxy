import SwiftUI

// MARK: - EmbedField (プレビュー用の軽量型)

struct EmbedField: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var value: String
    var inline: Bool = false
}

// MARK: - EmbedData

struct EmbedData: Equatable {
    var color: Color = .accentIndigo
    var botName: String = "BotForge"
    var timestamp: Date? = nil
    var messageContent: String? = nil
    var title: String? = nil
    var description: String? = nil
    var fields: [EmbedField] = []
    var thumbnailUrl: String? = nil
    var imageUrl: String? = nil
    var footerText: String? = nil
    var footerIconUrl: String? = nil

    static func from(_ e: EmbedModel) -> EmbedData {
        EmbedData(
            color: Color(uiColor: UIColor(hex: e.colorHex)),
            timestamp: e.showTimestamp ? Date() : nil,
            messageContent: e.messageContent,
            title: e.title,
            description: e.description,
            fields: e.fields.map { EmbedField(name: $0.name, value: $0.value, inline: $0.inline) },
            thumbnailUrl: e.thumbnailUrl,
            imageUrl: e.imageUrl,
            footerText: e.footerText,
            footerIconUrl: e.footerIconUrl
        )
    }
}

// MARK: - EmbedPreviewCard

struct EmbedPreviewCard: View {
    let embed: EmbedData

    private var formattedTime: String {
        guard let ts = embed.timestamp else { return "" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: ts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            // メッセージ本文（埋め込みの外＝通常テキスト）
            if let content = embed.messageContent, !content.isEmpty {
                Text(content)
                    .font(.bodySmall)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            embedBlock
        }
    }

    private var embedBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左のカラーバー
            RoundedRectangle(cornerRadius: 2)
                .fill(embed.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: .spacing8) {
                // Bot ヘッダー
                HStack(spacing: .spacing8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentIndigo)
                        .frame(width: 24, height: 24)

                    Text(embed.botName)
                        .font(.captionRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)

                    Badge(text: "BOT", color: .accentIndigo)

                    Spacer()

                    if let ts = embed.timestamp {
                        Text(ts, style: .time)
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                HStack(alignment: .top, spacing: .spacing8) {
                    VStack(alignment: .leading, spacing: .spacing4) {
                        // Title
                        if let title = embed.title, !title.isEmpty {
                            Text(title)
                                .font(.titleMedium)
                                .foregroundStyle(embed.color)
                        }

                        // Description
                        if let desc = embed.description, !desc.isEmpty {
                            Text(discordMarkdownAttributed(desc, baseColor: Color.textSecondary))
                                .lineLimit(5)
                        }

                        // Fields
                        if !embed.fields.isEmpty {
                            fieldsGrid
                        }
                    }

                    // Thumbnail
                    if let thumbUrl = embed.thumbnailUrl, !thumbUrl.isEmpty,
                       let url = URL(string: thumbUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                placeholderThumb
                            default:
                                placeholderThumb
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                    } else if embed.thumbnailUrl != nil {
                        placeholderThumb
                    }
                }

                // Image
                if let imgUrl = embed.imageUrl, !imgUrl.isEmpty,
                   let url = URL(string: imgUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            placeholderImage
                        default:
                            placeholderImage
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
                } else if embed.imageUrl != nil {
                    placeholderImage
                }

                // Footer
                if let footer = embed.footerText, !footer.isEmpty {
                    HStack(spacing: .spacing4) {
                        if let footerIcon = embed.footerIconUrl, !footerIcon.isEmpty,
                           let url = URL(string: footerIcon) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    Circle().fill(Color.bgElevated)
                                default:
                                    Circle().fill(Color.bgElevated)
                                }
                            }
                            .frame(width: 14, height: 14)
                            .clipShape(Circle())
                        }
                        Text(footer)
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(.spacing12)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    private var placeholderThumb: some View {
        RoundedRectangle(cornerRadius: .cornerRadiusSmall)
            .fill(Color.bgElevated)
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(Color.textTertiary)
            }
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: .cornerRadiusSmall)
            .fill(Color.bgElevated)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(Color.textTertiary)
            }
    }

    @ViewBuilder
    private var fieldsGrid: some View {
        let inlineFields = embed.fields.filter(\.inline)
        let blockFields  = embed.fields.filter { !$0.inline }

        VStack(alignment: .leading, spacing: .spacing8) {
            if !inlineFields.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: .spacing8), count: min(inlineFields.count, 3)),
                    spacing: .spacing8
                ) {
                    ForEach(inlineFields) { field in
                        EmbedFieldView(field: field)
                    }
                }
            }
            ForEach(blockFields) { field in
                EmbedFieldView(field: field)
            }
        }
    }
}

private struct EmbedFieldView: View {
    let field: EmbedField

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(field.name)
                .font(.captionRegular)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textPrimary)
            Text(field.value)
                .font(.captionRegular)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - EmbedField init for compatibility
extension EmbedField {
    init(id: String, name: String, value: String, inline: Bool) {
        self.name = name
        self.value = value
        self.inline = inline
    }
}

// MARK: - Discord Markdown Helper

private func discordMarkdownAttributed(_ text: String, baseColor: Color) -> AttributedString {
    let mutable = NSMutableAttributedString(string: text, attributes: [
        .foregroundColor: UIColor(baseColor),
        .font: UIFont.systemFont(ofSize: 13, weight: .regular)
    ])

    // **bold**
    applyPattern(mutable, pattern: "\\*\\*(.+?)\\*\\*") { mutable, range in
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: 13, weight: .bold), range: range)
    }

    // *italic*
    applyPattern(mutable, pattern: "\\*(.+?)\\*") { mutable, range in
        let italic = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.default)?
            .withSymbolicTraits(.traitItalic) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        mutable.addAttribute(.font, value: UIFont(descriptor: italic, size: 13), range: range)
    }

    // __underline__
    applyPattern(mutable, pattern: "__(.+?)__") { mutable, range in
        mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
    }

    // ~~strikethrough~~
    applyPattern(mutable, pattern: "~~(.+?)~~") { mutable, range in
        mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
    }

    // `code`
    applyPattern(mutable, pattern: "`(.+?)`") { mutable, range in
        mutable.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: range)
        mutable.addAttribute(.backgroundColor, value: UIColor(Color.bgElevated), range: range)
    }

    return AttributedString(mutable)
}

private func applyPattern(
    _ mutable: NSMutableAttributedString,
    pattern: String,
    transform: (NSMutableAttributedString, NSRange) -> Void
) {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
    let matches = regex.matches(in: mutable.string, options: [], range: NSRange(location: 0, length: mutable.length))
    // Apply from last to first to keep ranges valid
    for match in matches.reversed() {
        let innerRange = match.range(at: 1)
        guard innerRange.location != NSNotFound else { continue }
        transform(mutable, innerRange)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: .spacing16) {
            EmbedPreviewCard(embed: EmbedData(
                color: .accentPurple,
                timestamp: .now,
                title: "サーバーへようこそ！",
                description: "ルールを確認して楽しく過ごしましょう。",
                fields: [
                    EmbedField(name: "ルール", value: "#rules", inline: true),
                    EmbedField(name: "サポート", value: "#help", inline: true),
                ],
                footerText: "BotForge",
                footerIconUrl: "https://example.com/icon.png"
            ))
        }
        .padding()
    }
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
