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

    private let previewTitle  = "🔗 あなた専用の招待リンク"
    private let previewBody   = "ボタンを押すと、あなただけの招待リンクが発行されます。友達をサーバーに招待しよう！"
    private let previewButton = "招待リンクを取得する"

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    channelSection
                    previewSection
                    noteSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.Color.bg)
            .navigationTitle("招待パネルを設置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isDeploying {
                        ProgressView()
                    } else {
                        Button("設置する") { Task { await deploy() } }
                            .disabled(selectedChannel == nil)
                            .fontWeight(.semibold)
                            .foregroundStyle(selectedChannel != nil ? Theme.Color.accent : Theme.Color.textTertiary)
                    }
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
        FormSection("設置先チャンネル", icon: "number") {
            if isLoadingChannels {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                    Text("チャンネルを読み込み中...")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                .padding(.vertical, Theme.Spacing.xs)
            } else {
                Picker("チャンネル", selection: $selectedChannel) {
                    Text("選択してください").tag(Optional<Channel>.none)
                    ForEach(textChannels) { ch in
                        Label(ch.name, systemImage: "number").tag(Optional(ch))
                    }
                }
                .tint(Theme.Color.accent)
                Text("テキストチャンネルのみ選択できます")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
    }

    private var previewSection: some View {
        FormSection("投稿プレビュー", icon: "eye") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Color.accent)
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(previewTitle)
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text(previewBody)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }

                Button { } label: {
                    Text(previewButton)
                        .font(Theme.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                }
                .disabled(true)
                .buttonStyle(.plain)
            }
        }
    }

    private var noteSection: some View {
        FormSection("このパネルについて", icon: "info.circle") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                noteRow(icon: "person.badge.plus",  text: "ボタンを押したメンバーに専用の招待リンクが発行されます")
                noteRow(icon: "eye.slash",           text: "リンクはそのメンバーにだけ表示されます（Ephemeral）")
                noteRow(icon: "envelope",            text: "リンクはDMにも自動送信されます")
                noteRow(icon: "1.circle",            text: "1人につき1リンクで、再押しすると既存リンクが表示されます")
            }
        }
    }

    private func noteRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 18)
            Text(text)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
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
            error = "パネルの設置に失敗しました。BotがチャンネルへのSend Messages権限を持っているか確認してください。"
        }
        isDeploying = false
    }
}

#Preview {
    InvitePanelSetupView(guildId: "g001") { _ in }
        .environment(\.services, ServiceContainer.mock())
}
