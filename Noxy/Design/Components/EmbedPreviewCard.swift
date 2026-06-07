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
    var color: Color = .accentIndigo
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
// Discordチャット画面上に表示されているような見た目。
// アプリ外観設定（ライト/ダーク）に追従する。

struct DiscordMessagePreview: View {
    let embed: EmbedData
    var isCompact = false

    var body: some View {
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
                    .frame(width: isCompact ? 32 : 40, height: isCompact ? 32 : 40)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: .spacing4) {
                // ヘッダー: 名前 + BOTバッジ + タイムスタンプ
                HStack(spacing: .spacing6) {
                    Text(embed.botName)
                        .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                        .foregroundStyle(Color.accentIndigo)

                    Text("BOT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    if let ts = embed.timestamp {
                        Text("今日 ") + Text(ts, style: .time)
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }

                    Spacer()
                }

                // メッセージ本文（Embed外）
                if let content = embed.messageContent, !content.isEmpty {
                    Text(content)
                        .font(.system(size: isCompact ? 13 : 14))
                        .foregroundStyle(Color.textPrimary)
                }

                // Embed
                embedBlock
            }
        }
        .padding(.spacing12)
    }

    // MARK: - Embed Block

    private var embedBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左カラーバー
            RoundedRectangle(cornerRadius: 2)
                .fill(embed.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: .spacing8) {
                // Title
                if let title = embed.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                        .foregroundStyle(embed.color)
                }

                // Description
                if let desc = embed.description, !desc.isEmpty {
                    Text(discordMarkdownAttributed(desc, baseColor: Color.textSecondary))
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
                    HStack(spacing: .spacing4) {
                        if let icon = embed.footerIconUrl, !icon.isEmpty,
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
                        Text(footer)
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(.spacing10)
            .background(Color.bgSurface)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.bgElevated)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 80 : 140)
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
                let cols = min(inlineFields.count, 3)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: .spacing8), count: cols),
                    spacing: .spacing8
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

            VStack(alignment: .leading, spacing: .spacing4) {
                if let title = embed.title, !title.isEmpty {
                    Text(title)
                        .font(.captionRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(embed.color)
                        .lineLimit(1)
                }
                if let desc = embed.description, !desc.isEmpty {
                    Text(desc)
                        .font(.captionSmall)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
                if !embed.fields.isEmpty {
                    Text("\(embed.fields.count) フィールド")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.spacing6)
            .background(Color.bgSurface)
        }
        .background(Color.bgSurface)
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
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text(field.value)
                .font(.system(size: compact ? 12 : 13))
                .foregroundStyle(Color.textSecondary)
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
        .font: UIFont.systemFont(ofSize: 13, weight: .regular)
    ])

    applyPattern(mutable, pattern: "\\*\\*(.+?)\\*\\*") { mutable, range in
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: 13, weight: .bold), range: range)
    }

    applyPattern(mutable, pattern: "\\*(.+?)\\*") { mutable, range in
        let italic = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.default)?
            .withSymbolicTraits(.traitItalic) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        mutable.addAttribute(.font, value: UIFont(descriptor: italic, size: 13), range: range)
    }

    applyPattern(mutable, pattern: "__(.+?)__") { mutable, range in
        mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
    }

    applyPattern(mutable, pattern: "~~(.+?)~~") { mutable, range in
        mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
    }

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
    for match in matches.reversed() {
        let innerRange = match.range(at: 1)
        guard innerRange.location != NSNotFound else { continue }
        transform(mutable, innerRange)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: .spacing16) {
            DiscordMessagePreview(embed: EmbedData(
                color: .accentPurple,
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
                color: .accentGreen,
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
    .background(Color.bgPrimary)
}
