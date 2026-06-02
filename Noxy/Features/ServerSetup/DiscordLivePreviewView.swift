import SwiftUI

struct DiscordLivePreviewView: View {
    let draft: ServerSetupDraft

    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: UIColor(hex: 0x2F3136)).ignoresSafeArea()

                HStack(spacing: 0) {
                    // Sidebar
                    sidebarPanel
                    // Main area placeholder
                    mainAreaPanel
                }
            }
            .navigationTitle("Discord プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(uiColor: UIColor(hex: 0x202225)), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebarPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Server header
                HStack {
                    Text(draft.serverName.isEmpty ? "サーバー名" : draft.serverName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.captionSmall)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(uiColor: UIColor(hex: 0x2F3136)))

                Divider()
                    .background(Color.white.opacity(0.1))

                // Channels
                ForEach(draft.categories) { cat in
                    categorySection(cat)
                }

                Spacer(minLength: 40)
            }
        }
        .frame(width: 200)
        .background(Color(uiColor: UIColor(hex: 0x2F3136)))
    }

    @ViewBuilder
    private func categorySection(_ cat: SetupCategory) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Category header
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0x8E9297)))
                Text(cat.name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0x8E9297)))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Channels
            ForEach(cat.channels) { ch in
                DiscordChannelRow(channel: ch)
            }
        }
    }

    // MARK: - Main area

    private var mainAreaPanel: some View {
        VStack {
            // Fake channel header
            HStack {
                Image(systemName: "number")
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0x8E9297)))
                Text(firstTextChannel ?? "general")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: UIColor(hex: 0x36393F)))
            .overlay(alignment: .bottom) {
                Divider().background(Color.white.opacity(0.1))
            }

            // Chat area
            Spacer()
            VStack(spacing: .spacing12) {
                Image(systemName: "number")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0x4F545C)))
                Text("チャンネルの先頭")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("これは \(firstTextChannel ?? "general") の始まりです。")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0x8E9297)))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, .spacing20)
            Spacer()

            // Message input
            HStack(spacing: .spacing8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: UIColor(hex: 0x40444B)))
                    .frame(height: 44)
                    .overlay(alignment: .leading) {
                        Text("メッセージを送信")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(uiColor: UIColor(hex: 0x72767D)))
                            .padding(.leading, 12)
                    }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: UIColor(hex: 0x36393F)))
    }

    private var firstTextChannel: String? {
        draft.categories.flatMap(\.channels).first(where: { $0.type == .text })?.name
    }
}

// MARK: - Discord Channel Row

private struct DiscordChannelRow: View {
    let channel: SetupChannel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: channel.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(uiColor: UIColor(hex: 0x8E9297)))
                .frame(width: 16)

            Text(channel.name)
                .font(.system(size: 14))
                .foregroundStyle(Color(uiColor: UIColor(hex: isHovered ? 0xDCDDDE : 0x96989D)))
                .lineLimit(1)

            Spacer()

            if channel.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(uiColor: UIColor(hex: 0x8E9297)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .padding(.leading, 4)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture { isHovered.toggle() }
    }
}

#Preview {
    DiscordLivePreviewView(draft: ServerTemplate.gaming.draft)
}
