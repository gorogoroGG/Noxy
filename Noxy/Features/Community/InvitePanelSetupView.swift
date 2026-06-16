import SwiftUI

struct InvitePanelSetupView: View {
    let guildId: String
    let onDeploy: (InvitePanel) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var channels: [Channel] = []
    @State private var selectedChannel: Channel?
    @State private var isLoadingChannels = true
    @State private var isDeploying = false
    @State private var error: String?

    private let previewTitle = "🔗 あなた専用の招待リンク"
    private let previewBody  = "ボタンを押すと、あなただけの招待リンクが発行されます。友達をサーバーに招待しよう！"
    private let previewButton = "招待リンクを取得する"

    var body: some View {
        NavigationStack {
            Form {
                channelSection
                previewSection
                noteSection
            }
            .navigationTitle("招待パネルを設置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("設置する") { Task { await deploy() } }
                        .disabled(selectedChannel == nil || isDeploying)
                        .fontWeight(.semibold)
                }
            }
        }
        .task { await loadChannels() }
        .alert("エラー", isPresented: .constant(error != nil), actions: {
            Button("OK") { error = nil }
        }, message: { Text(error ?? "") })
    }

    // MARK: - Sections

    private var channelSection: some View {
        Section {
            if isLoadingChannels {
                HStack {
                    ProgressView()
                    Text("チャンネルを読み込み中...")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                }
            } else {
                Picker("チャンネル", selection: $selectedChannel) {
                    Text("選択してください").tag(Optional<Channel>.none)
                    ForEach(textChannels) { ch in
                        Label(ch.name, systemImage: "number").tag(Optional(ch))
                    }
                }
            }
        } header: {
            Text("設置先チャンネル")
        } footer: {
            Text("テキストチャンネルのみ選択できます")
        }
    }

    private var previewSection: some View {
        Section("Discordに投稿されるメッセージ") {
            VStack(alignment: .leading, spacing: .spacing12) {
                HStack(spacing: .spacing10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentPurple)
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(previewTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(previewBody)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                HStack {
                    Text(previewButton)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacing12)
                        .padding(.vertical, .spacing8)
                        .background(Color.accentPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                }
            }
            .padding(.vertical, .spacing4)
            .listRowBackground(Theme.Color.surfaceRaised)
        }
    }

    private var noteSection: some View {
        Section {
            VStack(alignment: .leading, spacing: .spacing8) {
                noteRow(icon: "person.badge.plus", text: "ボタンを押したメンバーに専用の招待リンクが発行されます")
                noteRow(icon: "eye.slash", text: "リンクはそのメンバーにだけ表示されます（Ephemeral）")
                noteRow(icon: "envelope", text: "リンクはDMにも自動送信されます")
                noteRow(icon: "1.circle", text: "1人につき1リンクで、再押しすると既存リンクが表示されます")
            }
            .padding(.vertical, .spacing4)
        } header: {
            Text("このパネルについて")
        }
    }

    private func noteRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: .spacing8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.accentPurple)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Data

    private var textChannels: [Channel] {
        channels.filter { $0.type == .text && $0.botCanSend }
    }

    private func loadChannels() async {
        channels = (try? await services.guilds.fetchChannels(guildId: guildId)) ?? []
        isLoadingChannels = false
        if selectedChannel == nil { selectedChannel = textChannels.first }
    }

    private func deploy() async {
        guard let ch = selectedChannel else { return }
        isDeploying = true
        if let panel = try? await services.inviteTracker.deployInvitePanel(
            guildId: guildId, channelId: ch.id, channelName: ch.name
        ) {
            onDeploy(panel)
            dismiss()
        } else {
            error = "パネルの設置に失敗しました。Botがチャンネルへの送信権限を持っているか確認してください。"
        }
        isDeploying = false
    }
}

#Preview {
    InvitePanelSetupView(guildId: "g001") { _ in }
        .environment(\.services, ServiceContainer.mock())
}
