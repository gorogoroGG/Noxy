import SwiftUI

private struct HelpCategory: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
    let faqs: [(String, String)]
}

private let categories: [HelpCategory] = [
    HelpCategory(icon: "rocket.fill", title: "はじめかた", color: .accentIndigo,
                 faqs: [("BotForgeをサーバーに追加するには?", "設定 → 接続済みサーバー → サーバーを追加 でOAuth2フローに従ってください。"),
                        ("BotForgeに必要な権限は?", "最低限: メッセージ送信、Embedリンク、メッセージ履歴の読み取り。")]),
    HelpCategory(icon: "rectangle.stack.fill", title: "Embedビルダー", color: .accentPink,
                 faqs: [("文字数制限はありますか?", "Discord Embedの合計文字数制限は6,000文字です。"),
                        ("Embedに変数を使えますか?", "ウェルカムメッセージでは {user.name}、{server.name} などが使えます。")]),
    HelpCategory(icon: "bolt.fill", title: "Bot管理", color: .accentOrange,
                 faqs: [("Botを再起動するには?", "ダッシュボード → Bot状況カード → 「再起動」をタップ。"),
                        ("Botがオフラインと表示される場合は?", "Bot設定 → 接続設定 でトークンが正しいか確認してください。")]),
    HelpCategory(icon: "wrench.and.screwdriver.fill", title: "トラブルシューティング", color: .accentGreen,
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
        List {
            if !searchText.isEmpty {
                Section("検索結果") {
                    if filteredFAQs.isEmpty {
                        Text("「\(searchText)」の結果が見つかりません")
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        ForEach(filteredFAQs, id: \.0) { faq in
                            FAQRow(question: faq.0, answer: faq.1,
                                   isExpanded: expandedFAQ == faq.0) {
                                expandedFAQ = expandedFAQ == faq.0 ? nil : faq.0
                            }
                        }
                    }
                }
            } else {
                ForEach(categories) { category in
                    Section {
                        // Category header card
                        HStack(spacing: .spacing12) {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                                .frame(width: 32)
                            Text(category.title)
                                .font(.titleMedium)
                                .foregroundStyle(Color.textPrimary)
                        }
                        .padding(.vertical, .spacing4)

                        ForEach(category.faqs, id: \.0) { faq in
                            FAQRow(question: faq.0, answer: faq.1,
                                   isExpanded: expandedFAQ == faq.0) {
                                withAnimation { expandedFAQ = expandedFAQ == faq.0 ? nil : faq.0 }
                            }
                        }
                    }
                }

                Section {
                    VStack(spacing: .spacing12) {
                        Text("まだ解決しませんか?")
                            .font(.titleMedium)
                            .foregroundStyle(Color.textPrimary)
                        PrimaryButton("お問い合わせ", style: .outlined, size: .medium, icon: "envelope.fill") {}
                    }
                    .padding(.vertical, .spacing8)
                }
            }
        }
        .searchable(text: $searchText, prompt: "ヘルプ記事を検索")
        .navigationTitle("ヘルプセンター")
    }
}

private struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: .spacing8) {
                HStack {
                    Text(question)
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
                if isExpanded {
                    Text(answer)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { HelpCenterView() }
        .preferredColorScheme(.dark)
}
