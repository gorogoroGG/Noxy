import SwiftUI

private struct HelpCategory: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let faqs: [(String, String)]
}

private let categories: [HelpCategory] = [
    HelpCategory(icon: "rocket.fill", title: "はじめかた",
                 faqs: [("BotForgeをサーバーに追加するには?", "設定 → 接続済みサーバー → サーバーを追加 でOAuth2フローに従ってください。"),
                        ("BotForgeに必要な権限は?", "最低限: メッセージ送信、Embedリンク、メッセージ履歴の読み取り。")]),
    HelpCategory(icon: "rectangle.stack.fill", title: "Embedビルダー",
                 faqs: [("文字数制限はありますか?", "Discord Embedの合計文字数制限は6,000文字です。"),
                        ("Embedに変数を使えますか?", "ウェルカムメッセージでは {user.name}、{server.name} などが使えます。")]),
    HelpCategory(icon: "bolt.fill", title: "Bot管理",
                 faqs: [("Botを再起動するには?", "ダッシュボード → Bot状況カード → 「再起動」をタップ。"),
                        ("Botがオフラインと表示される場合は?", "Bot設定 → 接続設定 でトークンが正しいか確認してください。")]),
    HelpCategory(icon: "wrench.and.screwdriver.fill", title: "トラブルシューティング",
                 faqs: [("Botがコマンドに反応しない。", "権限を確認してください。Botにスラッシュコマンド権限が必要です。"),
                        ("予約送信メッセージが送られなかった。", "予約時刻にBotがオンラインだったか確認してください。")]),
]

struct HelpCenterView: View {
    @State private var searchText = ""
    @State private var expandedFAQ: String? = nil

    private var allFAQs: [(String, String)] {
        categories.flatMap { $0.faqs }
    }

    private var filteredFAQs: [(String, String)] {
        guard !searchText.isEmpty else { return [] }
        return allFAQs.filter { $0.0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                if !searchText.isEmpty {
                    searchResultsSection
                } else {
                    categoriesSection
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Color.bg)
        .searchable(text: $searchText, prompt: "ヘルプ記事を検索")
        .navigationTitle("ヘルプセンター")
    }

    private var searchResultsSection: some View {
        FormSection("検索結果", icon: "magnifyingglass") {
            if filteredFAQs.isEmpty {
                Text("「\(searchText)」の結果が見つかりません")
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredFAQs, id: \.0) { faq in
                        FAQRow(question: faq.0, answer: faq.1,
                               isExpanded: expandedFAQ == faq.0) {
                            expandedFAQ = expandedFAQ == faq.0 ? nil : faq.0
                        }
                        if faq.0 != filteredFAQs.last?.0 {
                            Divider().background(Theme.Color.line)
                        }
                    }
                }
            }
        }
    }

    private var categoriesSection: some View {
        ForEach(categories) { category in
            FormSection(category.title, icon: category.icon) {
                VStack(spacing: 0) {
                    ForEach(category.faqs, id: \.0) { faq in
                        FAQRow(question: faq.0, answer: faq.1,
                               isExpanded: expandedFAQ == faq.0) {
                            withAnimation { expandedFAQ = expandedFAQ == faq.0 ? nil : faq.0 }
                        }
                        if faq.0 != category.faqs.last?.0 {
                            Divider().background(Theme.Color.line)
                        }
                    }
                }
            }
        }
    }
}

private struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(question)
                        .font(Theme.Font.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                if isExpanded {
                    Text(answer)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack { HelpCenterView() }
}

#Preview("Dark") {
    NavigationStack { HelpCenterView() }
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack { HelpCenterView() }
        .preferredColorScheme(.light)
}
