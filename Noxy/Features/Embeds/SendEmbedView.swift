import SwiftUI

struct SendEmbedView: View {
    let embed: EmbedModel
    var isNewEmbed: Bool = false
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var channels: [Channel] = []
    @State private var selectedChannel: Channel? = nil
    @State private var isLoading = true
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String? = nil
    @State private var showConfirm = false
    @State private var channelSearchText = ""

    // テキストチャンネルをカテゴリー別にグループ化
    private var groupedChannels: [(category: String, channels: [Channel])] {
        let textChannels = channels.filter { $0.type == .text && $0.botCanSend }
        let filtered = channelSearchText.isEmpty
            ? textChannels
            : textChannels.filter { $0.name.localizedCaseInsensitiveContains(channelSearchText) }

        var groups: [(String, [Channel])] = []
        var seen = Set<String>()

        for ch in filtered {
            let cat = ch.categoryName ?? "カテゴリーなし"
            if !seen.contains(cat) {
                seen.insert(cat)
                groups.append((cat, []))
            }
            if let idx = groups.firstIndex(where: { $0.0 == cat }) {
                groups[idx].1.append(ch)
            }
        }
        return groups.map { (category: $0.0, channels: $0.1) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if didSend {
                    SendSuccessView(embed: embed, channel: selectedChannel) { dismiss() }
                } else {
                    mainContent
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("チャンネルを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .task { await loadChannels() }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Embed プレビュー（コンパクト）
            VStack(alignment: .leading, spacing: .spacing8) {
                Text("送信するEmbed")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)
                    .padding(.horizontal)
                    .padding(.top)

                EmbedPreviewCard(embed: .from(embed))
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .background(Color.bgElevated)

            Divider().background(Color.border)

            if let errorMessage {
                HStack(spacing: .spacing8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.captionRegular)
                        .foregroundStyle(.red)
                }
                .padding()
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            } else if groupedChannels.isEmpty {
                VStack(spacing: .spacing8) {
                    Image(systemName: "number")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textTertiary)
                    Text("送信可能なチャンネルがありません")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List {
                    ForEach(groupedChannels, id: \.category) { group in
                        Section {
                            ForEach(group.channels) { ch in
                                channelRow(ch)
                            }
                        } header: {
                            Text(group.category)
                                .font(.captionSmall)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textSecondary)
                                .textCase(.uppercase)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $channelSearchText, prompt: "チャンネルを検索")
            }

            // 送信ボタン
            if let ch = selectedChannel {
                Button {
                    showConfirm = true
                } label: {
                    HStack {
                        if isSending {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("#\(ch.name) に送信する")
                        }
                    }
                    .font(.titleMedium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                }
                .padding()
                .disabled(isSending)
                .buttonStyle(ScalePressButtonStyle())
                .alert("#\(ch.name) に送信しますか？", isPresented: $showConfirm) {
                    Button("送信する") { Task { await sendEmbed() } }
                    Button("キャンセル", role: .cancel) { }
                }
            }
        }
    }

    // MARK: - Channel Row

    @ViewBuilder
    private func channelRow(_ ch: Channel) -> some View {
        Button {
            selectedChannel = ch
        } label: {
            HStack(spacing: .spacing10) {
                Image(systemName: "number")
                    .font(.captionRegular)
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 16)
                Text(ch.name)
                    .font(.bodySmall)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if selectedChannel?.id == ch.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(
            selectedChannel?.id == ch.id
                ? Color.accentIndigo.opacity(0.1)
                : Color.bgSurface
        )
    }

    // MARK: - Actions

    private func loadChannels() async {
        isLoading = true
        channels = (try? await services.guilds.fetchChannels(guildId: appState.selectedGuildId)) ?? []
        isLoading = false
    }

    private func sendEmbed() async {
        guard let channel = selectedChannel else { return }
        isSending = true
        errorMessage = nil
        do {
            let embedToSend: EmbedModel
            if isNewEmbed {
                var toSave = embed
                if toSave.name.isEmpty { toSave.name = "Untitled" }
                embedToSend = try await services.embeds.create(toSave)
            } else {
                embedToSend = embed
            }
            try await services.embeds.send(
                embedId: embedToSend.id,
                guildId: appState.selectedGuildId,
                channelId: channel.id
            )
            isSending = false
            withAnimation { didSend = true }
        } catch {
            isSending = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - SendSuccessView

struct SendSuccessView: View {
    let embed: EmbedModel
    let channel: Channel?
    let onDone: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: .spacing24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentGreen.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentGreen)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }

            VStack(spacing: .spacing8) {
                Text("送信完了！")
                    .font(.displayMedium)
                    .foregroundStyle(Color.textPrimary)
                if let ch = channel {
                    Text("#\(ch.name) に送信しました")
                        .font(.bodyRegular)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            PrimaryButton("完了", style: .filled, size: .large, action: onDone)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5)) {
                scale = 1
                opacity = 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

#Preview {
    SendEmbedView(embed: .blank())
        .environment(\.services, ServiceContainer.live())
        .environment(AppState())
}
