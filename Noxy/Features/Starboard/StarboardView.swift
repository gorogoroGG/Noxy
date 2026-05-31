import SwiftUI

struct StarboardView: View {
    @State private var isEnabled = true
    @State private var threshold = 3
    @State private var channelName = "starboard"
    @State private var stars: [StarredMessage] = [
        StarredMessage(id: "1", author: "GoroGoro", content: "今回のアップデート最高すぎる！新マップ楽しみ！", stars: 12, channel: "general", date: Date().addingTimeInterval(-3600)),
        StarredMessage(id: "2", author: "ShadowX", content: "チームメンバー募集します。ランク: Immortal", stars: 8, channel: "recruitment", date: Date().addingTimeInterval(-7200)),
        StarredMessage(id: "3", author: "TaroYamada", content: "自作の壁纸をシェアします！", stars: 15, channel: "creative", date: Date().addingTimeInterval(-18000)),
        StarredMessage(id: "4", author: "NoobPlayer", content: "初心者だけど仲良くしてね", stars: 5, channel: "introductions", date: Date().addingTimeInterval(-86400)),
    ]
    @State private var toast: ToastMessage? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Toggle("スターボードを有効にする", isOn: $isEnabled.animation())
                    .tint(Color.accentGreen)
                    .padding()

                if isEnabled {
                    List {
                        Section("設定") {
                            Stepper("必要スター数: \(threshold)", value: $threshold, in: 1...20)
                            Picker("送信先チャンネル", selection: $channelName) {
                                Text("#starboard").tag("starboard")
                                Text("#best-of").tag("best-of")
                                Text("#hall-of-fame").tag("hall-of-fame")
                            }
                        }

                        Section("殿堂入りメッセージ") {
                            ForEach(stars) { star in
                                StarRow(star: star)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    Spacer()
                    EmptyStateView(
                        icon: "star.fill",
                        title: "スターボードは無効です",
                        description: "有効にすると⭐リアクションが付いたメッセージを集約できます。"
                    )
                    Spacer()
                }
            }
            .navigationTitle("スターボード")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        toast = ToastMessage(type: .success, message: "保存しました")
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .toast($toast)
    }
}

// MARK: - Star Row

private struct StarRow: View {
    let star: StarredMessage

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing8) {
            HStack(spacing: .spacing8) {
                Avatar(name: star.author, size: 28, accentColor: .accentIndigo)
                Text(star.author)
                    .font(.captionRegular)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.captionSmall)
                        .foregroundStyle(Color.accentOrange)
                    Text("\(star.stars)")
                        .font(.captionRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentOrange)
                }
            }

            Text(star.content)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(3)

            HStack(spacing: .spacing8) {
                Text("#\(star.channel)")
                    .font(.captionSmall)
                    .foregroundStyle(Color.accentIndigo)
                Text("·")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                Text(star.date.formatted(.relative(presentation: .named)))
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

// MARK: - Models

struct StarredMessage: Identifiable {
    let id: String
    let author: String
    let content: String
    let stars: Int
    let channel: String
    let date: Date
}

#Preview {
    NavigationStack { StarboardView() }
        .preferredColorScheme(.dark)
}
