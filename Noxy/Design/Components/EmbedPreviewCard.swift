import SwiftUI

// MARK: - EmbedField (preview helper)

struct EmbedField: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var value: String
    var inline: Bool = false
}

// MARK: - EmbedData

struct EmbedData: Equatable {
    var color: Color = Theme.Color.accent
    var botName: String = "Noxy"
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

// MARK: - DiscordMessagePreview
// Noxy Design Language に従い、カラー・タイポグラフィ・ボーダーを統一。

struct DiscordMessagePreview: View {
    let embed: EmbedData
    var isCompact = false

    var body: some View {
        HStack(alignment: .top, spacing:         Theme.Spacing.sm) {
            // Bot アバター
            ZStack {
                Circle()
                    .fill(Theme.Color.accent)
                    .frame(width: isCompact ? 32 : 40, height: isCompact ? 32 : 40)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.accentInk)
            }

            VStack(alignment: .leading, spacing:         Theme.Spacing.xs) {
                // ヘッダー
                HStack(spacing:         Theme.Spacing.xs) {
                    Text(embed.botName)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.accent)

                    Badge(text: "BOT", color: Theme.Color.accent, style: .filled)

                    if let ts = embed.timestamp {
                        Text("今日 ") + Text(ts, style: .time)
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }

                    Spacer()
                }

                // メッセージ本文
                if let content = embed.messageContent, !content.isEmpty {
                    Text(content)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                }

                // Embed
                embedBlock
            }
        }
        .padding(        Theme.Spacing.sm)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }

    // MARK: - Embed Block

    private var embedBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左カラーバー
            RoundedRectangle(cornerRadius: 2)
                .fill(embed.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing:         Theme.Spacing.xs) {
                // Title
                if let title = embed.title, !title.isEmpty {
                    Text(title)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(embed.color)
                }

                // Description
                if let desc = embed.description, !desc.isEmpty {
                    Text(discordMarkdownAttributed(desc, baseColor: Theme.Color.textSecondary))
                        .lineLimit(isCompact ? 3 : 5)
                }

                // Fields
                if !embed.fields.isEmpty {
                    fieldsGrid
                }

                // Image
                if let imgUrl = embed.imageUrl, !imgUrl.isEmpty,
                   let url = URL(string: imgUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            placeholderImage
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 80 : 140)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Footer
                if let footer = embed.footerText, !footer.isEmpty {
                    HStack(spacing:         Theme.Spacing.xs) {
                        if let icon = embed.footerIconUrl, !icon.isEmpty,
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
                        Text(footer)
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
            }
            .padding(        Theme.Spacing.xs)
            .background(Theme.Color.surface)
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Theme.Color.surfaceRaised)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 80 : 140)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(Theme.Color.textTertiary)
            }
    }

    @ViewBuilder
    private var fieldsGrid: some View {
        let inlineFields = embed.fields.filter(\.inline)
        let blockFields  = embed.fields.filter { !$0.inline }

        VStack(alignment: .leading, spacing:         Theme.Spacing.xs) {
            if !inlineFields.isEmpty {
                let cols = min(inlineFields.count, 3)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing:         Theme.Spacing.xs), count: cols),
                    spacing:         Theme.Spacing.xs
                ) {
                    ForEach(inlineFields) { field in
                        EmbedFieldView(field: field, compact: isCompact)
                    }
                }
            }
            ForEach(blockFields) { field in
                EmbedFieldView(field: field, compact: isCompact)
            }
        }
    }
}

// MARK: - Compact Embed Preview (for list cells)

struct CompactEmbedPreview: View {
    let embed: EmbedData

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(embed.color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing:         Theme.Spacing.xs) {
                if let title = embed.title, !title.isEmpty {
                    Text(title)
                        .font(Theme.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(embed.color)
                        .lineLimit(1)
                }
                if let desc = embed.description, !desc.isEmpty {
                    Text(desc)
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(2)
                }
                if !embed.fields.isEmpty {
                    Text("\(embed.fields.count) フィールド")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
            .padding(        Theme.Spacing.xs)
            .background(Theme.Color.surface)
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - EmbedFieldView

private struct EmbedFieldView: View {
    let field: EmbedField
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(field.name)
                .font(Theme.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(field.value)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(3)
        }
    }
}

// MARK: - EmbedField init compatibility

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
        .font: UIFont.preferredFont(forTextStyle: .body)
    ])

    applyPattern(mutable, pattern: "\\*\\*(.+?)\\*\\*") { mutable, range in
        mutable.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .headline), range: range)
    }

    applyPattern(mutable, pattern: "\\*(.+?)\\*") { mutable, range in
        let italic = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.default)?
            .withSymbolicTraits(.traitItalic) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        mutable.addAttribute(.font, value: UIFont(descriptor: italic, size: 0), range: range)
    }

    applyPattern(mutable, pattern: "__(.+?)__") { mutable, range in
        mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
    }

    applyPattern(mutable, pattern: "~~(.+?)~~") { mutable, range in
        mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
    }

    applyPattern(mutable, pattern: "`(.+?)`") { mutable, range in
        mutable.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .callout), range: range)
        mutable.addAttribute(.backgroundColor, value: UIColor(Theme.Color.surfaceRaised), range: range)
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
    for match in matches.reversed() {
        let innerRange = match.range(at: 1)
        guard innerRange.location != NSNotFound else { continue }
        transform(mutable, innerRange)
    }
}

#Preview {
    ScrollView {
        VStack(spacing:         Theme.Spacing.md) {
            DiscordMessagePreview(embed: EmbedData(
                color: Theme.Color.accent,
                timestamp: .now,
                messageContent: "@everyone 新しいお知らせです！",
                title: "サーバーへようこそ！",
                description: "ルールを確認して楽しく過ごしましょう。\n**注意事項**をお読みください。",
                fields: [
                    EmbedField(name: "ルール", value: "#rules", inline: true),
                    EmbedField(name: "サポート", value: "#help", inline: true),
                ],
                footerText: "Noxy",
                footerIconUrl: nil
            ))

            DiscordMessagePreview(embed: EmbedData(
                color: Theme.Color.statusOK,
                title: "週次レポート",
                description: "今週の活動サマリーです。",
                fields: [
                    EmbedField(name: "メッセージ数", value: "1,234", inline: true),
                    EmbedField(name: "アクティブユーザー", value: "56", inline: true),
                    EmbedField(name: "新規参加", value: "12", inline: true),
                ]
            ), isCompact: true)
        }
        .padding()
    }
    .background(Theme.Color.bg)
}
