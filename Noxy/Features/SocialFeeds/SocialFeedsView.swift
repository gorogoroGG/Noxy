import SwiftUI

struct SocialFeedsView: View {
    @State private var feeds: [SocialFeed] = [
        SocialFeed(id: "1", platform: .youtube, channelName: "GoroGoro Gaming", targetChannel: "announcements", lastPost: "2時間前", isActive: true),
        SocialFeed(id: "2", platform: .twitch, channelName: "shadowx_live", targetChannel: "live-notifications", lastPost: "たった今", isActive: true),
        SocialFeed(id: "3", platform: .twitter, channelName: "@ValorantJP", targetChannel: "news", lastPost: "30分前", isActive: false),
        SocialFeed(id: "4", platform: .rss, channelName: "Game News Feed", targetChannel: "news", lastPost: "1日前", isActive: true),
    ]
    @State private var showAddSheet = false
    @State private var toast: ToastMessage? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach($feeds) { $feed in
                    FeedRow(feed: $feed)
                        .swipeActions {
                            Button(role: .destructive) {
                                feeds.removeAll { $0.id == feed.id }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("SNS通知")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddFeedSheet { newFeed in
                    feeds.append(newFeed)
                    toast = ToastMessage(type: .success, message: "通知設定を追加しました")
                }
            }
        }
        .toast($toast)
    }
}

// MARK: - Feed Row

private struct FeedRow: View {
    @Binding var feed: SocialFeed

    var body: some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                    .fill(feed.platform.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: feed.platform.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(feed.platform.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.channelName)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Text("→ #\(feed.targetChannel)")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textSecondary)
                Text("最終通知: \(feed.lastPost)")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $feed.isActive)
                .tint(Color.accentGreen)
                .labelsHidden()
        }
        .padding(.vertical, .spacing4)
    }
}

// MARK: - Add Sheet

private struct AddFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (SocialFeed) -> Void

    @State private var selectedPlatform: SocialPlatform = .youtube
    @State private var channelName = ""
    @State private var targetChannel = "announcements"

    private let targets = ["announcements", "general", "news", "live-notifications"]

    var body: some View {
        NavigationStack {
            List {
                Section("プラットフォーム") {
                    Picker("プラットフォーム", selection: $selectedPlatform) {
                        ForEach(SocialPlatform.allCases) { platform in
                            Label(platform.rawValue, systemImage: platform.icon)
                                .tag(platform)
                        }
                    }
                }

                Section("設定") {
                    TextField("チャンネル名 / URL", text: $channelName)
                    Picker("通知先チャンネル", selection: $targetChannel) {
                        ForEach(targets, id: \.self) { ch in
                            Text("#\(ch)").tag(ch)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("通知を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加") {
                        let feed = SocialFeed(
                            id: UUID().uuidString,
                            platform: selectedPlatform,
                            channelName: channelName,
                            targetChannel: targetChannel,
                            lastPost: "-",
                            isActive: true
                        )
                        onAdd(feed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(channelName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Models

enum SocialPlatform: String, CaseIterable, Identifiable {
    case youtube = "YouTube"
    case twitch = "Twitch"
    case twitter = "X (Twitter)"
    case rss = "RSS"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .twitch:  return "antenna.radiowaves.left.and.right"
        case .twitter: return "bird.fill"
        case .rss:     return "dot.radiowaves.forward"
        }
    }

    var color: Color {
        switch self {
        case .youtube: return Color(uiColor: UIColor(hex: 0xFF0000))
        case .twitch:  return Color(uiColor: UIColor(hex: 0x9146FF))
        case .twitter: return Color(uiColor: UIColor(hex: 0x000000))
        case .rss:     return Color.accentOrange
        }
    }
}

struct SocialFeed: Identifiable {
    let id: String
    var platform: SocialPlatform
    var channelName: String
    var targetChannel: String
    var lastPost: String
    var isActive: Bool
}

#Preview {
    NavigationStack { SocialFeedsView() }
        .preferredColorScheme(.dark)
}
