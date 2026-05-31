import SwiftUI

private struct AutoModRule: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var enabled: Bool
}

struct AutoModRulesView: View {
    @State private var rules: [AutoModRule] = [
        AutoModRule(name: "スパム対策", description: "5秒以内に5件以上のメッセージ", enabled: true),
        AutoModRule(name: "大文字フィルター", description: "70%以上が大文字の場合", enabled: true),
        AutoModRule(name: "メンションスパム", description: "1メッセージに5件以上@メンション", enabled: true),
        AutoModRule(name: "リンクフィルター", description: "ホワイトリストのリンクのみ許可", enabled: false),
        AutoModRule(name: "絵文字フラッド", description: "1メッセージに絵文字10件以上", enabled: false),
    ]

    var body: some View {
        List {
            ForEach($rules) { $rule in
                VStack(alignment: .leading, spacing: .spacing4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name).font(.titleMedium).foregroundStyle(Color.textPrimary)
                            Text(rule.description).font(.captionRegular).foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $rule.enabled).labelsHidden().tint(Color.accentIndigo)
                    }
                }
                .padding(.vertical, .spacing4)
            }
        }
        .navigationTitle("自動モデレーション")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    rules.append(AutoModRule(name: "新規ルール", description: "このルールを設定してください", enabled: false))
                } label: { Image(systemName: "plus") }
            }
        }
    }
}

struct WordFilterView: View {
    @State private var blockedWords: [String] = ["spam", "scam", "hack", "porn", "nsfw"]
    @State private var newWord = ""
    @State private var strictnessLevel = 1
    @State private var action = "Delete"
    @State private var whitelistChannels = ""

    private let strictnessLabels = ["緩め", "厳格", "非常に厳格"]
    private let actions = ["削除", "警告", "ミュート", "BAN"]

    var body: some View {
        Form {
            Section("ブロックワード") {
                ForEach(blockedWords, id: \.self) { word in
                    HStack {
                        Text(word).font(.mono).foregroundStyle(Color.textPrimary)
                        Spacer()
                        Button {
                            blockedWords.removeAll { $0 == word }
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("ワードを追加...", text: $newWord)
                        .font(.mono)
                    Button("追加") {
                        guard !newWord.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        blockedWords.append(newWord.lowercased())
                        newWord = ""
                    }
                    .foregroundStyle(Color.accentIndigo)
                    .disabled(newWord.isEmpty)
                }
            }

            Section("設定") {
                Picker("厳格さ", selection: $strictnessLevel) {
                    ForEach(0..<strictnessLabels.count, id: \.self) { i in
                        Text(strictnessLabels[i]).tag(i)
                    }
                }

                Picker("アクション", selection: $action) {
                    ForEach(actions, id: \.self) { Text($0).tag($0) }
                }

                TextField("ホワイトリストチャンネル（カンマ区切り）", text: $whitelistChannels)
                    .font(.captionRegular)
            }
        }
        .navigationTitle("ワードフィルター")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {}.fontWeight(.semibold).foregroundStyle(Color.accentIndigo)
            }
        }
    }
}

#Preview {
    NavigationStack { AutoModRulesView() }
        .preferredColorScheme(.dark)
}
