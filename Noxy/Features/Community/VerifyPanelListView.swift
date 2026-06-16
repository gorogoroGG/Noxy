import SwiftUI

// MARK: - VerifyPanelListView
// Noxy Design Language に厳密に従った再設計。

struct VerifyPanelListView: View {
    let guildId: String

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var panel: VerifyPanel? = nil
    @State private var pendingCount = 0
    @State private var isLoading = true
    @State private var channels: [(id: String, name: String)] = []
    @State private var deployingId: String? = nil
    @State private var toast: ToastMessage? = nil
    @State private var showDeleteConfirm = false
    @State private var needsRedeploy = false
    @State private var showCreate = false
    @State private var showDeploySheet = false

    private var hasManualPanel: Bool { panel?.verifyType == .manual }

    var body: some View {
        Group {
            if isLoading {
                loadingView
                    .transition(.opacity)
            } else if let panel {
                VerifyPanelManageView(
                    panel: panel,
                    guildId: guildId,
                    channels: channels,
                    pendingCount: pendingCount,
                    needsRedeploy: needsRedeploy,
                    onPanelUpdated: { updated in
                        self.panel = updated
                        needsRedeploy = true
                    },
                    onPanelDeleted: { self.panel = nil },
                    onDeployComplete: { updated in
                        self.panel = updated
                        needsRedeploy = false
                    }
                )
            } else {
                emptyState
            }
        }
        .background(Theme.Color.bg)
        .refreshable { await load() }
        .navigationTitle("認証")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showCreate) {
            VerifyPanelEditView(guildId: guildId) { created in
                self.panel = created
                needsRedeploy = false
            }
        }
        .sheet(isPresented: $showDeploySheet) {
            deploySheet
        }
        .overlay {
            if showDeleteConfirm, let p = panel {
                ConfirmModal(
                    icon: "trash.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "「\(p.name)」を削除しますか？",
                    message: "Discordのパネルメッセージは手動で削除してください。",
                    primaryLabel: "削除",
                    primaryRole: .destructive,
                    onPrimary: {
                        Task { await deletePanel() }
                        showDeleteConfirm = false
                    },
                    onCancel: {
                        showDeleteConfirm = false
                    }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .toast($toast)
        .task { await load() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: .spacing12) {
            Spacer()
            ProgressView()
                .tint(Theme.Color.accent)
            Text("読み込み中...")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State
    // Noxy Design Language: ヒーローエリア + カード紹介 + FAB

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: .spacing20) {
                // ヒーローカード
                Card(padding: .spacing24, background: Theme.Color.surface, showBorder: true) {
                    VStack(spacing: .spacing20) {
                        ZStack {
                            Circle()
                                .fill(Theme.Color.accentDim)
                                .frame(width: 80, height: 80)
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(Theme.Color.accent)
                        }
                        VStack(spacing: .spacing8) {
                            Text("認証パネルで\nメンバーを自動管理")
                                .font(Theme.Font.title3)
                                .foregroundStyle(Theme.Color.textPrimary)
                                .multilineTextAlignment(.center)
                            Text("サーバー参加時にロールを自動付与。\n認証方法を選んでボット対策もできます。")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                // 各認証モードの紹介
                SectionHeader(title: "認証モードの使い分け") {}
                    .padding(.horizontal, .spacing16)

                AuthModeIntroCard(
                    icon: "shield.checkered",
                    iconColor: Theme.Color.accent,
                    title: "CAPTCHA認証",
                    subtitle: "ボット対策に最適",
                    description: "ブラウザでTurnstile認証を完了することで、本物のユーザーのみを通過させます。荒らし対策として最も強力です。",
                    useCase: "公開サーバー・荒らし対策が必要な場合"
                )
                .padding(.horizontal, .spacing16)

                AuthModeIntroCard(
                    icon: "cursorarrow.click.fill",
                    iconColor: Theme.Color.statusOK,
                    title: "ワンクリック認証",
                    subtitle: "手軽さNo.1",
                    description: "ボタンを押すだけで即時ロール付与。操作が最も簡単ですが、ボット対策はありません。",
                    useCase: "身内サーバー・信頼できるメンバーのみ"
                )
                .padding(.horizontal, .spacing16)

                AuthModeIntroCard(
                    icon: "hand.thumbsup.fill",
                    iconColor: Theme.Color.statusWarn,
                    title: "リアクション認証",
                    subtitle: "Discordらしい体験",
                    description: "パネルメッセージに絵文字リアクションすることで認証。Discordの操作に慣れていない人にも直感的です。",
                    useCase: "ゲームコミュニティ・カジュアルな雰囲気"
                )
                .padding(.horizontal, .spacing16)

                AuthModeIntroCard(
                    icon: "person.badge.clock.fill",
                    iconColor: Theme.Color.accent,
                    title: "手動認証",
                    subtitle: "完全な管理",
                    description: "管理者が申請を確認して承認・拒否を判断。完全な制御が可能ですが、対応の手間がかかります。",
                    useCase: "審査制コミュニティ・厳選されたメンバーのみ"
                )
                .padding(.horizontal, .spacing16)

                AccentButton(title: "認証パネルを作成") {
                    showCreate = true
                }
                .padding(.top, .spacing8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing12)
        }
    }

    // MARK: - Deploy Sheet

    private var deploySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(title: "設置先チャンネルを選択")
                        .padding(.horizontal, .spacing16)
                        .padding(.top, .spacing12)
                        .padding(.bottom, .spacing8)

                    Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
                        VStack(spacing: 0) {
                            ForEach(Array(channels.enumerated()), id: \.element.id) { idx, ch in
                                Button {
                                    if let p = panel {
                                        Task { await deploy(p, channelId: ch.id) }
                                    }
                                    showDeploySheet = false
                                } label: {
                                    HStack {
                                        Image(systemName: "number")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                        Text(ch.name)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Color.textTertiary)
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
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle("設置先チャンネル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("キャンセル") { showDeploySheet = false }
                        .font(Theme.Font.body)
                }
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        // 先読み済みキャッシュがあれば即表示
        if let cachedPanels: [VerifyPanel] = appState.guildData(.verifyPanels, guild: guildId) {
            panel = cachedPanels.first
            if let cachedReqs: [VerifyRequest] = appState.guildData(.verifyRequests, guild: guildId) {
                pendingCount = cachedReqs.count
            }
            isLoading = false
        } else {
            isLoading = true
        }
        async let panelTask = services.verify.fetchPanels(guildId: guildId)
        async let reqTask = services.verify.fetchRequests(guildId: guildId, status: .pending)
        async let chTask: [(id: String, name: String)] = {
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            guard let chs = try? await WorkerClient().get("/bot/channels?guild_id=\(guildId)") as [RawCh] else { return [] }
            return chs.filter { $0.type == 0 }.map { ($0.id, $0.name) }
        }()
        if let panels = try? await panelTask {
            panel = panels.first
            appState.setGuildData(panels, .verifyPanels, guild: guildId)
        }
        if let reqs = try? await reqTask {
            pendingCount = reqs.count
            appState.setGuildData(reqs, .verifyRequests, guild: guildId)
        }
        channels = await chTask
        isLoading = false
    }

    private func deploy(_ p: VerifyPanel, channelId: String) async {
        deployingId = p.id
        do {
            let updated = try await services.verify.deployPanel(id: p.id, channelId: channelId)
            panel = updated
            needsRedeploy = false
            toast = ToastMessage(type: .success, message: "Discordに設置しました")
        } catch {
            toast = ToastMessage(type: .error, message: "設置に失敗しました")
        }
        deployingId = nil
    }

    private func deletePanel() async {
        guard let p = panel else { return }
        do {
            try await services.verify.deletePanel(id: p.id)
            panel = nil
            needsRedeploy = false
            toast = ToastMessage(type: .success, message: "削除しました")
        } catch {
            toast = ToastMessage(type: .error, message: "削除に失敗しました")
        }
    }
}

// MARK: - AuthModeIntroCard
// Noxy Design Language: Card 内のリストアイテム

private struct AuthModeIntroCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    let useCase: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("· \(subtitle)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(iconColor)
                }
                Text(description)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(2)
                Text(useCase)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .padding(14)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }
}

// MARK: - VerifyPanelManageView

struct VerifyPanelManageView: View {
    let panel: VerifyPanel
    let guildId: String
    let channels: [(id: String, name: String)]
    let pendingCount: Int
    let needsRedeploy: Bool
    let onPanelUpdated: (VerifyPanel) -> Void
    let onPanelDeleted: () -> Void
    let onDeployComplete: (VerifyPanel) -> Void

    @Environment(\.services) private var services
    @State private var showEdit = false
    @State private var showDeploySheet = false
    @State private var showDeleteConfirm = false
    @State private var toast: ToastMessage? = nil
    @State private var roles: [DiscordRole] = []

    private var channelName: String? { channels.first { $0.id == panel.channelId }?.name }
    private var manualChannelName: String? {
        guard let mcId = panel.manualChannelId, !mcId.isEmpty else { return nil }
        return channels.first { $0.id == mcId }?.name
    }
    private var assignedRole: DiscordRole? { roles.first { $0.id == panel.roleId } }

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing12) {
                // 未反映バナー
                if needsRedeploy {
                    redeployBanner
                }

                // Discord プレビュー
                discordPreviewCard

                // 認証方法 + 付与ロール（横並び・等幅）
                HStack(alignment: .top, spacing: .spacing10) {
                    verifyTypeCard
                    roleCard
                }

                // 設置情報
                if panel.isDeployed {
                    deployInfoCard
                }

                // アクション
                actionsRow

                // 承認待ち（手動認証のみ）
                if panel.verifyType == .manual {
                    pendingRequestsCard
                }
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing12)
            .padding(.bottom, 40)
        }
        .background(Theme.Color.bg)
        .navigationTitle("認証パネル管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            VerifyPanelEditView(existing: panel, guildId: guildId) { updated in onPanelUpdated(updated) }
        }
        .sheet(isPresented: $showDeploySheet) { deploySheetView }
        .overlay {
            if showDeleteConfirm {
                ConfirmModal(
                    icon: "trash.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "「\(panel.name)」を削除しますか？",
                    message: "Discordのパネルメッセージは手動で削除してください。",
                    primaryLabel: "削除",
                    primaryRole: .destructive,
                    onPrimary: {
                        Task { await deletePanel() }
                        showDeleteConfirm = false
                    },
                    onCancel: {
                        showDeleteConfirm = false
                    }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .toast($toast)
        .task { await loadRoles() }
    }

    // MARK: - Redeploy Banner
    // Noxy: warn 色 + 薄い背景 + ボーダー

    private var redeployBanner: some View {
        HStack(spacing: .spacing10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Color.statusWarn)
                .font(.system(size: 14, weight: .semibold))
            Text("設定が変更されているので再送信をしてください")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.statusWarn)
            Spacer()
            Button {
                showDeploySheet = true
            } label: {
                Text("送信")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.accentInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.Color.statusWarn)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.Color.statusWarn.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Color.statusWarn.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Discord Preview
    // Noxy: sur 背景 + 14px 角丸 + line ボーダー
    // EmbedPreviewCard（Dev Components）を使用

    private var discordPreviewCard: some View {
        Card(padding: 14, background: Theme.Color.surface, showBorder: true) {
            VStack(alignment: .leading, spacing: .spacing10) {
                SectionLabel(title: "Discordでの表示")

                DiscordMessagePreview(
                    embed: EmbedData(
                        color: Color(uiColor: UIColor(hex: UInt32(panel.color))),
                        botName: "Noxy",
                        timestamp: Date(),
                        title: panel.name,
                        description: panel.description,
                        footerText: panel.footerText
                    ),
                    isCompact: true
                )
            }
        }
    }

    // MARK: - Verify Type Card
    // Noxy: sur 背景 + 14px 角丸 + line ボーダー

    private var verifyTypeCard: some View {
        Card(padding: .spacing16, background: Theme.Color.surface, showBorder: true) {
            VStack(alignment: .leading, spacing: .spacing10) {
                SectionLabel(title: "認証方法")
                Spacer(minLength: 0)
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(panel.verifyType.accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: panel.verifyType.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(panel.verifyType.accentColor)
                }
                Text(panel.verifyType.label)
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(panel.verifyType.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Role Card

    private var roleCard: some View {
        Card(padding: .spacing16, background: Theme.Color.surface, showBorder: true) {
            VStack(alignment: .leading, spacing: .spacing10) {
                SectionLabel(title: "付与ロール")
                Spacer(minLength: 0)
                if panel.roleId.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Color.statusWarn)
                        .font(.system(size: 22, weight: .semibold))
                    Text("未設定")
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.statusWarn)
                } else {
                    let roleColor: Color = assignedRole.map { Color(uiColor: UIColor(hex: UInt32($0.color))) } ?? Theme.Color.statusOK
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(roleColor.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(roleColor)
                    }
                    // Discord ロールバッジ
                    HStack(spacing: 5) {
                        Circle()
                            .fill(roleColor)
                            .frame(width: 8, height: 8)
                        Text("@\(assignedRole?.name ?? String(panel.roleId.suffix(8)))")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Color.surfaceRaised)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Theme.Color.line, lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Deploy Info Card

    private var deployInfoCard: some View {
        Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
            VStack(alignment: .leading, spacing: 0) {
                deployInfoRow(
                    icon: "number",
                    color: Theme.Color.accent,
                    label: "チャンネル",
                    value: channelName.map { "#\($0)" } ?? "—"
                )
                if panel.verifyType == .manual {
                    Divider()
                        .background(Theme.Color.line)
                        .padding(.leading, 30)
                    deployInfoRow(
                        icon: "bell.badge.fill",
                        color: Theme.Color.statusWarn,
                        label: "通知先",
                        value: manualChannelName.map { "#\($0)" } ?? "アプリのみ"
                    )
                }
            }
        }
    }

    private func deployInfoRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: .spacing12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20)
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
    }

    // MARK: - Actions Row

    private var actionsRow: some View {
        HStack(spacing: .spacing10) {
            actionButton(icon: "pencil", label: "編集", color: Theme.Color.accent) { showEdit = true }
            actionButton(icon: "paperplane.fill", label: "送信", color: Theme.Color.statusOK) { showDeploySheet = true }
            actionButton(icon: "trash", label: "削除", color: Theme.Color.statusBad) { showDeleteConfirm = true }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.1))
                        .frame(height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(Theme.Font.caption)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pending Requests Card

    private var pendingRequestsCard: some View {
        NavigationLink {
            VerifyRequestsView(guildId: guildId, panelId: panel.id)
        } label: {
            HStack(spacing: .spacing12) {
                ZStack {
                    Circle()
                        .fill(Theme.Color.statusWarn.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.badge.clock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Color.statusWarn)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("承認待ちリクエスト")
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("\(pendingCount)件が承認を待っています")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            .padding(14)
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Deploy Sheet

    private var deploySheetView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(title: "設置先チャンネルを選択")
                        .padding(.horizontal, .spacing16)
                        .padding(.top, .spacing12)
                        .padding(.bottom, .spacing8)

                    Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
                        VStack(spacing: 0) {
                            ForEach(Array(channels.enumerated()), id: \.element.id) { idx, ch in
                                Button {
                                    Task { await deploy(panel, channelId: ch.id) }
                                    showDeploySheet = false
                                } label: {
                                    HStack {
                                        Image(systemName: "number")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                        Text(ch.name)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Color.textTertiary)
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
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle("設置先チャンネル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("キャンセル") { showDeploySheet = false }
                        .font(Theme.Font.body)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadRoles() async {
        roles = (try? await DiscordService().fetchRoles(guildId: guildId)) ?? []
    }

    private func deploy(_ p: VerifyPanel, channelId: String) async {
        do {
            let updated = try await services.verify.deployPanel(id: p.id, channelId: channelId)
            onDeployComplete(updated)
            toast = ToastMessage(type: .success, message: "Discordに設置しました")
        } catch {
            toast = ToastMessage(type: .error, message: "設置に失敗しました")
        }
    }

    private func deletePanel() async {
        do {
            try await services.verify.deletePanel(id: panel.id)
            onPanelDeleted()
            toast = ToastMessage(type: .success, message: "削除しました")
        } catch {
            toast = ToastMessage(type: .error, message: "削除に失敗しました")
        }
    }
}

#Preview {
    NavigationStack {
        VerifyPanelListView(guildId: "g001")
            .navigationTitle("認証")
    }
    .environment(\.services, ServiceContainer.live())
    .environment(AppState())
}
