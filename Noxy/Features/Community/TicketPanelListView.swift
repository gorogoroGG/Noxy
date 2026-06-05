import SwiftUI

// MARK: - TicketPanelListView
// Discordサーバーへのお問い合わせパネルの管理・設置を行う。
// パネル0件時は初心者向けガイドを表示し、設置済みパネルはカード一覧で確認できる。

struct TicketPanelListView: View {
    let guildId: String
    @Binding var panels: [TicketPanel]

    @Environment(\.services) private var services
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var showCreate = false
    @State private var editingPanel: TicketPanel? = nil
    @State private var deployingId: String? = nil
    @State private var deployTargetPanel: TicketPanel? = nil
    @State private var toast: ToastMessage? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if isLoading {
                    loadingView
                } else if let err = loadError {
                    errorView(err)
                } else if panels.isEmpty {
                    emptyView
                } else {
                    panelList
                }
            }

            // FAB
            if !isLoading {
                Button { showCreate = true } label: {
                    HStack(spacing: .spacing8) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text(panels.isEmpty ? "最初のパネルを作成" : "パネルを作成")
                            .font(.bodySmall).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacing20).padding(.vertical, .spacing12)
                    .background(Color.accentIndigo).clipShape(Capsule())
                    .shadow(color: Color.accentIndigo.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showCreate) {
            TicketPanelEditView(existingPanel: nil, guildId: guildId) { newPanel in
                panels.insert(newPanel, at: 0)
                showToast("パネルを作成しました", type: .success)
            }
        }
        .sheet(item: $editingPanel) { panel in
            TicketPanelEditView(existingPanel: panel, guildId: guildId) { updated in
                if let idx = panels.firstIndex(where: { $0.id == updated.id }) {
                    panels[idx] = updated
                }
                showToast("パネルを更新しました", type: .success)
            }
        }
        .sheet(item: $deployTargetPanel) { panel in
            DeployChannelPickerSheet(panel: panel, guildId: guildId) { channelId in
                Task { await deploy(panel, channelId: channelId) }
            }
        }
        .toast($toast)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: .spacing16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            Text("読み込みに失敗しました")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .font(.bodyRegular)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Button { Task { await load() } } label: {
                Label("再試行", systemImage: "arrow.clockwise")
                    .font(.bodySmall).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacing20).padding(.vertical, .spacing10)
                    .background(Color.accentIndigo)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, .spacing32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyView: some View {
        VStack(spacing: .spacing20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentIndigo.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentIndigo)
            }

            VStack(spacing: .spacing8) {
                Text("パネルを設置しましょう")
                    .font(.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Discordサーバーにボタンを設置して、\nメンバーからの問い合わせを受け付けられます。")
                    .font(.bodyRegular)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, .spacing32)

            Button { showCreate = true } label: {
                HStack(spacing: .spacing8) {
                    Image(systemName: "plus.circle.fill")
                    Text("パネルを作成")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
                .frame(height: 52)
                .background(Color.accentIndigo)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            }
            .buttonStyle(ScalePressButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var panelList: some View {
        List {
            ForEach(panels) { panel in
                PanelCard(
                    panel: panel,
                    isDeploying: deployingId == panel.id,
                    onEdit: { editingPanel = panel },
                    onDeploy: { deployTargetPanel = panel }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await deletePanel(panel) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }

            Color.clear.frame(height: 80)
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            panels = try await services.tickets.fetchPanels(guildId: guildId)
        } catch {
            loadError = "サーバーに接続できませんでした。ネットワークを確認してください。"
        }
        isLoading = false
    }

    private func deletePanel(_ panel: TicketPanel) async {
        do {
            try await services.tickets.deletePanel(id: panel.id)
            withAnimation {
                panels.removeAll { $0.id == panel.id }
            }
            showToast("パネルを削除しました", type: .info)
        } catch {
            showToast("削除に失敗しました", type: .error)
        }
    }

    private func deploy(_ panel: TicketPanel, channelId: String) async {
        deployingId = panel.id
        do {
            let updated = try await services.tickets.deployPanel(id: panel.id, channelId: channelId)
            if let idx = panels.firstIndex(where: { $0.id == panel.id }) {
                panels[idx] = updated
            }
            showToast("Discordに設置しました", type: .success)
        } catch {
            showToast("設置に失敗しました", type: .error)
        }
        deployingId = nil
    }

    private func showToast(_ msg: String, type: ToastType) {
        toast = ToastMessage(type: type, message: msg)
    }
}

// MARK: - PanelCard

private struct PanelCard: View {
    let panel: TicketPanel
    let isDeploying: Bool
    let onEdit: () -> Void
    let onDeploy: () -> Void

    private var panelColor: Color {
        Color(uiColor: UIColor(hex: UInt32(panel.color)))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: .spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(panelColor)
                        .frame(width: 42, height: 42)
                    Text(panel.buttonEmoji).font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(panel.title)
                        .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text(panel.description)
                        .font(.captionSmall).foregroundStyle(Color.textTertiary).lineLimit(1)
                }

                Spacer()

                // 設置状況バッジ
                HStack(spacing: 4) {
                    Image(systemName: panel.isDeployed ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 10))
                    Text(panel.isDeployed ? "設置済み" : "未設置")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(panel.isDeployed ? Color.accentGreen : Color.textTertiary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    (panel.isDeployed ? Color.accentGreen : Color(.tertiarySystemGroupedBackground))
                        .opacity(panel.isDeployed ? 0.12 : 1)
                )
                .clipShape(Capsule())

                // 編集ボタン（メニューではなく直接）
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.spacing12)

            Divider().padding(.horizontal, .spacing12)

            // Deploy Button
            Button(action: onDeploy) {
                HStack(spacing: .spacing6) {
                    if isDeploying {
                        ProgressView().scaleEffect(0.75).tint(.white)
                        Text("設置中...").font(.bodySmall).fontWeight(.semibold)
                    } else {
                        Image(systemName: panel.isDeployed ? "arrow.2.squarepath" : "paperplane.fill")
                            .font(.system(size: 13))
                        Text(panel.isDeployed ? "再設置する" : "Discordに設置する")
                            .font(.bodySmall).fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(panel.isDeployed ? Color.accentOrange : panelColor)
                .clipShape(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: .cornerRadiusMedium,
                        bottomTrailingRadius: .cornerRadiusMedium
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeploying)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }
}

// MARK: - DeployChannelPickerSheet

struct DeployChannelPickerSheet: View {
    let panel: TicketPanel
    let guildId: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var channels: [(id: String, name: String)] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let err = loadError {
                    errorView(err)
                } else if channels.isEmpty {
                    emptyView
                } else {
                    channelList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("設置先を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
            .task { await load() }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: .spacing16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            Text("読み込みに失敗しました")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .font(.bodyRegular)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Button { Task { await load() } } label: {
                Label("再試行", systemImage: "arrow.clockwise")
                    .font(.bodySmall).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacing20).padding(.vertical, .spacing10)
                    .background(Color.accentIndigo)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, .spacing32)
    }

    private var emptyView: some View {
        VStack(spacing: .spacing12) {
            Spacer()
            Image(systemName: "number")
                .font(.system(size: 40))
                .foregroundStyle(Color.textTertiary)
            Text("テキストチャンネルが見つかりません")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text("Botがアクセス可能なテキストチャンネルが存在しません。")
                .font(.bodyRegular)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, .spacing32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var channelList: some View {
        List {
            Section {
                ForEach(channels, id: \.id) { ch in
                    Button {
                        onSelect(ch.id)
                        dismiss()
                    } label: {
                        HStack(spacing: .spacing12) {
                            Image(systemName: "number")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)
                            Text(ch.name)
                                .font(.bodySmall)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if panel.channelId == ch.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentIndigo)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("「\(panel.title)」の設置先チャンネル")
            } footer: {
                Text("選択したチャンネルにパネルメッセージが投稿されます。")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func load() async {
        isLoading = true
        loadError = nil
        if let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)") {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                struct RawCh: Decodable { let id: String; let name: String; let type: Int }
                let chs = try JSONDecoder().decode([RawCh].self, from: data)
                channels = chs.filter { $0.type == 0 || $0.type == 5 }.map { ($0.id, $0.name) }
            } catch {
                loadError = "チャンネル一覧の取得に失敗しました。"
            }
        }
        isLoading = false
    }
}
