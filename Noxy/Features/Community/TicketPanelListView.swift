import SwiftUI

// MARK: - TicketPanelListView
// Noxy Design Language に厳密に従った再設計。

struct TicketPanelListView: View {
    let guildId: String
    @Binding var panels: [TicketPanel]
    @Binding var isLoading: Bool

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var loadError: String? = nil
    @State private var showCreate = false
    @State private var editingPanel: TicketPanel? = nil
    @State private var deployingId: String? = nil
    @State private var deployTargetPanel: TicketPanel? = nil
    @State private var toast: ToastMessage? = nil
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: TicketPanel? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.Color.bg.ignoresSafeArea()

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

            // FAB — Noxy §7
            if !isLoading {
                fabButton
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
        .overlay {
            if showDeleteConfirm, let target = deleteTarget {
                ConfirmModal(
                    icon: "trash.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "「\(target.title)」を削除しますか？",
                    message: "Discordのパネルメッセージは手動で削除してください。",
                    primaryLabel: "削除",
                    primaryRole: .destructive,
                    onPrimary: {
                        Task { await deletePanel(target) }
                        showDeleteConfirm = false
                        deleteTarget = nil
                    },
                    onCancel: {
                        showDeleteConfirm = false
                        deleteTarget = nil
                    }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .toast($toast)
        .task(id: guildId) { await load() }
        .refreshable { await load() }
    }

    // MARK: - FAB
    // Noxy §7: bottom: 20px, right: 16px, 56px 円形, acc/acc-ink, shadow 0 4px 16px rgba(214,179,106,.3)

    private var fabButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            editingPanel = nil
            showCreate = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.Color.accentInk)
                .frame(width: 56, height: 56)
                .background(Theme.Color.accent)
                .clipShape(Circle())
        }
        .padding(.trailing, .spacing16)
        .padding(.bottom, 20)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - States

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: .spacing10) {
                SectionHeader(title: "読み込み中") {}
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing12)
        }
    }

    private func errorView(_ message: String) -> some View {
        EmptyStateView(
            icon: "wifi.exclamationmark",
            title: "読み込みに失敗しました",
            description: message,
            actionTitle: "再試行"
        ) {
            Task { await load() }
        }
    }

    private var emptyView: some View {
        EmptyStateView(
            icon: "rectangle.stack.badge.plus",
            title: "パネルを設置しましょう",
            description: "Discordサーバーにボタンを設置して、\nメンバーからの問い合わせを受け付けられます。",
            actionTitle: "パネルを作成"
        ) {
            showCreate = true
        }
    }

    // MARK: - Panel List

    private var panelList: some View {
        ScrollView {
            LazyVStack(spacing: .spacing10) {
                SectionHeader(title: "\(panels.count)件") {}
                    .padding(.horizontal, .spacing16)

                ForEach(panels) { panel in
                    PanelCard(
                        panel: panel,
                        isDeploying: deployingId == panel.id,
                        onEdit: { editingPanel = panel },
                        onDeploy: { deployTargetPanel = panel },
                        onDelete: {
                            deleteTarget = panel
                            showDeleteConfirm = true
                        }
                    )
                    .padding(.horizontal, .spacing16)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteTarget = panel
                            showDeleteConfirm = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }

                Color.clear.frame(height: 80)
            }
            .padding(.top, .spacing12)
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        loadError = nil
        if let cached = appState.cachedTicketPanels[guildId] {
            panels = cached
            isLoading = false
        }
        do {
            let fetched = try await services.tickets.fetchPanels(guildId: guildId)
            panels = fetched
            appState.cacheTicketPanels(fetched, for: guildId)
            loadError = nil
        } catch {
            if appState.cachedTicketPanels[guildId] == nil {
                loadError = "サーバーに接続できませんでした。ネットワークを確認してください。"
                panels = []
            }
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
        } catch ServiceError.workerError(let status, let msg) {
            showToast("設置失敗(\(status)): \(msg.prefix(80))", type: .error)
        } catch {
            showToast("設置に失敗しました: \(error.localizedDescription)", type: .error)
        }
        deployingId = nil
    }

    private func showToast(_ msg: String, type: ToastType) {
        toast = ToastMessage(type: type, message: msg)
    }
}

// MARK: - PanelCard
// Noxy: Card + sur + 14px 角丸 + line ボーダー + Badge（設置状況）

private struct PanelCard: View {
    let panel: TicketPanel
    let isDeploying: Bool
    let onEdit: () -> Void
    let onDeploy: () -> Void
    let onDelete: () -> Void

    private var panelColor: Color {
        Color(uiColor: UIColor(hex: UInt32(panel.color)))
    }

    var body: some View {
        Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: .spacing12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(panelColor)
                            .frame(width: 42, height: 42)
                        Text(panel.buttonEmoji)
                            .font(.system(size: 20))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(panel.title)
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text(panel.description)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 設置状況バッジ
                    Badge(
                        text: panel.isDeployed ? "設置済み" : "未設置",
                        color: panel.isDeployed ? Theme.Color.statusOK : Theme.Color.textTertiary,
                        style: .filled
                    )

                    // 編集ボタン
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
                .padding(.spacing12)

                Divider()
                    .background(Theme.Color.line)
                    .padding(.horizontal, .spacing12)

                // Deploy Button
                Button(action: onDeploy) {
                    HStack(spacing: .spacing6) {
                        if isDeploying {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(Theme.Color.accentInk)
                            Text("設置中...")
                                .font(Theme.Font.body)
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: panel.isDeployed ? "arrow.2.squarepath" : "paperplane.fill")
                                .font(.system(size: 13))
                            Text(panel.isDeployed ? "再設置する" : "Discordに設置する")
                                .font(Theme.Font.body)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(Theme.Color.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(panel.isDeployed ? Theme.Color.accent : panelColor)
                    .clipShape(
                        UnevenRoundedRectangle(
                            bottomLeadingRadius: Theme.Radius.card,
                            bottomTrailingRadius: Theme.Radius.card
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeploying)
            }
        }
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
            .background(Theme.Color.bg)
            .navigationTitle("設置先を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .task { await load() }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(Theme.Color.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        EmptyStateView(
            icon: "wifi.exclamationmark",
            title: "読み込みに失敗しました",
            description: message,
            actionTitle: "再試行"
        ) {
            Task { await load() }
        }
    }

    private var emptyView: some View {
        EmptyStateView(
            icon: "number",
            title: "テキストチャンネルが見つかりません",
            description: "Botがアクセス可能なテキストチャンネルが存在しません。"
        )
    }

    private var channelList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(title: "「\(panel.title)」の設置先チャンネル")
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing12)
                    .padding(.bottom, .spacing8)

                Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(channels.enumerated()), id: \.element.id) { idx, ch in
                            Button {
                                onSelect(ch.id)
                                dismiss()
                            } label: {
                                HStack(spacing: .spacing12) {
                                    Image(systemName: "number")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.Color.textTertiary)
                                    Text(ch.name)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Spacer()
                                    if panel.channelId == ch.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.Color.accent)
                                    }
                                }
                                .padding(.horizontal, .spacing16)
                                .padding(.vertical, .spacing12)
                            }
                            .buttonStyle(.plain)
                            if idx < channels.count - 1 {
                                Divider()
                                    .padding(.leading, .spacing16)
                            }
                        }
                    }
                }
                .padding(.horizontal, .spacing16)

                Text("選択したチャンネルにパネルメッセージが投稿されます。")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing8)
            }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            let client = WorkerClient()
            let chs: [RawCh] = try await client.get("/bot/channels?guild_id=\(guildId)")
            channels = chs.filter { $0.type == 0 || $0.type == 5 }.map { ($0.id, $0.name) }
        } catch {
            loadError = "チャンネル一覧の取得に失敗しました。"
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        TicketPanelListView(
            guildId: "g001",
            panels: .constant([]),
            isLoading: .constant(false)
        )
    }
    .environment(\.services, ServiceContainer.live())
    .environment(AppState())
}
