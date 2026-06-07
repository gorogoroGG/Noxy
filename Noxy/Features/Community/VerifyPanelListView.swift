import SwiftUI

struct VerifyPanelListView: View {
    let guildId: String

    @Environment(\.services) private var services
    @State private var panel: VerifyPanel? = nil
    @State private var pendingCount = 0
    @State private var isLoading = true
    @State private var showEdit = false
    @State private var channels: [(id: String, name: String)] = []
    @State private var deployingId: String? = nil
    @State private var toast: ToastMessage? = nil
    @State private var showDeleteConfirm = false
    @State private var needsRedeploy = false

    private var hasManualPanel: Bool { panel?.verifyType == .manual }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .background(Color(.systemGroupedBackground))
        .refreshable { await load() }
        .navigationTitle("認証パネル")
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
        .confirmationDialog("削除の確認", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("削除する", role: .destructive) { Task { await deletePanel() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let panel {
                Text("「\(panel.name)」を削除します。Discordのパネルメッセージは手動で削除してください。")
            }
        }
        .toast($toast)
        .task { await load() }
    }

    @State private var showCreate = false
    @State private var showDeploySheet = false

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ヒーローカード
                VStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Color.accentIndigo.opacity(0.1)).frame(width: 80, height: 80)
                        Image(systemName: "checkmark.shield.fill").font(.system(size: 36)).foregroundStyle(Color.accentIndigo)
                    }
                    VStack(spacing: 8) {
                        Text("認証パネルで\nメンバーを自動管理").font(.titleLarge).fontWeight(.bold).foregroundStyle(Color.textPrimary).multilineTextAlignment(.center)
                        Text("サーバー参加時にロールを自動付与。\n認証方法を選んでボット対策もできます。")
                            .font(.bodySmall).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // 各認証モードの紹介
                VStack(alignment: .leading, spacing: 12) {
                    Text("認証モードの使い分け").font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textSecondary).padding(.leading, 4)

                    AuthModeIntroCard(
                        icon: "shield.checkered", iconColor: Color.accentIndigo,
                        title: "CAPTCHA認証", subtitle: "ボット対策に最適",
                        description: "ブラウザでTurnstile認証を完了することで、本物のユーザーのみを通過させます。荒らし対策として最も強力です。",
                        useCase: "🎯 公開サーバー・荒らし対策が必要な場合"
                    )
                    AuthModeIntroCard(
                        icon: "cursorarrow.click.fill", iconColor: Color.accentGreen,
                        title: "ワンクリック認証", subtitle: "手軽さNo.1",
                        description: "ボタンを押すだけで即時ロール付与。操作が最も簡単ですが、ボット対策はありません。",
                        useCase: "🎯 身内サーバー・信頼できるメンバーのみ"
                    )
                    AuthModeIntroCard(
                        icon: "hand.thumbsup.fill", iconColor: Color.accentOrange,
                        title: "リアクション認証", subtitle: "Discordらしい体験",
                        description: "パネルメッセージに絵文字リアクションすることで認証。Discordの操作に慣れていない人にも直感的です。",
                        useCase: "🎯 ゲームコミュニティ・カジュアルな雰囲気"
                    )
                    AuthModeIntroCard(
                        icon: "person.badge.clock.fill", iconColor: Color.accentPurple,
                        title: "手動認証", subtitle: "完全な管理",
                        description: "管理者が申請を確認して承認・拒否を判断。完全な制御が可能ですが、対応の手間がかかります。",
                        useCase: "🎯 審査制コミュニティ・厳選されたメンバーのみ"
                    )
                }

                Button {
                    showCreate = true
                } label: {
                    Label("認証パネルを作成", systemImage: "plus.circle.fill")
                        .font(.bodySmall).fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 32).padding(.vertical, 14)
                        .background(Color.accentIndigo).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private var deploySheet: some View {
        NavigationStack {
            List {
                Section("設置先チャンネルを選択") {
                    ForEach(channels, id: \.id) { ch in
                        Button {
                            if let p = panel {
                                Task { await deploy(p, channelId: ch.id) }
                            }
                            showDeploySheet = false
                        } label: {
                            HStack {
                                Image(systemName: "number").font(.captionRegular).foregroundStyle(Color.textTertiary)
                                Text(ch.name).font(.bodySmall).foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.captionSmall).foregroundStyle(Color.textTertiary)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設置先チャンネル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("キャンセル") { showDeploySheet = false }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        async let panelTask = services.verify.fetchPanels(guildId: guildId)
        async let reqTask = services.verify.fetchRequests(guildId: guildId, status: .pending)
        async let chTask: [(id: String, name: String)] = {
            guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/channels?guild_id=\(guildId)") else { return [] }
            struct RawCh: Decodable { let id: String; let name: String; let type: Int }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let chs = try? JSONDecoder().decode([RawCh].self, from: data) else { return [] }
            return chs.filter { $0.type == 0 }.map { ($0.id, $0.name) }
        }()
        let panels = (try? await panelTask) ?? []
        panel = panels.first
        pendingCount = ((try? await reqTask) ?? []).count
        channels = await chTask
        isLoading = false
    }

    private func deploy(_ p: VerifyPanel, channelId: String) async {
        deployingId = p.id
        do {
            let updated = try await services.verify.deployPanel(id: p.id, channelId: channelId)
            panel = updated
            needsRedeploy = false
            toast = ToastMessage(type: .success, message: "✅ Discordに設置しました")
        } catch {
            toast = ToastMessage(type: .error, message: "❌ 設置に失敗しました")
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
                    Text(title).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text("· \(subtitle)").font(.captionSmall).foregroundStyle(iconColor)
                }
                Text(description).font(.captionSmall).foregroundStyle(Color.textSecondary).lineLimit(2)
                Text(useCase).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            VStack(spacing: 16) {
                // 未反映バナー
                if needsRedeploy {
                    redeployBanner
                }

                // Discord プレビュー
                discordPreviewCard

                // 認証方法 + 付与ロール（横並び・等幅）
                HStack(alignment: .top, spacing: 12) {
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
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("認証パネル管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: { Label("編集", systemImage: "pencil") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("削除", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            VerifyPanelEditView(existing: panel, guildId: guildId) { updated in onPanelUpdated(updated) }
        }
        .sheet(isPresented: $showDeploySheet) { deploySheetView }
        .confirmationDialog("削除の確認", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("削除する", role: .destructive) { Task { await deletePanel() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(panel.name)」を削除します。Discordのパネルメッセージは手動で削除してください。")
        }
        .toast($toast)
        .task { await loadRoles() }
    }

    // MARK: - Redeploy Banner

    private var redeployBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.accentOrange).font(.system(size: 14))
            Text("再送信してください。変更内容がDiscordに反映されていません")
                .font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.accentOrange)
            Spacer()
            Button {
                showDeploySheet = true
            } label: {
                Text("送信").font(.captionSmall).fontWeight(.semibold).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.accentOrange).clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.accentOrange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentOrange.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Discord Preview

    private var discordPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Discordでの表示", systemImage: "eye.fill")
                .font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textSecondary)

            // Embed プレビュー
            HStack(alignment: .top, spacing: 10) {
                // Bot アバター
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color.accentIndigo, Color.accentPink], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 36, height: 36)
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("Noxy").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.accentIndigo)
                        Text("BOT").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(Color.accentIndigo).clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(Color(uiColor: UIColor(hex: UInt32(panel.color)))).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(panel.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Color(uiColor: UIColor(hex: UInt32(panel.color))))
                            if !panel.description.isEmpty {
                                Text(panel.description).font(.system(size: 13)).foregroundStyle(Color.textSecondary).lineLimit(3)
                            }
                            if !panel.footerText.isEmpty {
                                Text(panel.footerText).font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                    }
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // ボタン / リアクション
                    Group {
                        switch panel.verifyType {
                        case .reaction:
                            HStack(spacing: 4) {
                                Text(panel.reactionEmoji.isEmpty ? "✅" : panel.reactionEmoji).font(.system(size: 16))
                                Text("1").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.textSecondary)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        default:
                            Text(panel.buttonLabel.isEmpty ? "✅ 認証する" : panel.buttonLabel)
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color(uiColor: UIColor(hex: UInt32(panel.color))))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Verify Type Card

    private var verifyTypeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("認証方法").font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textSecondary)
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
                .font(.bodySmall).fontWeight(.bold)
                .foregroundStyle(panel.verifyType.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Role Card

    private var roleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("付与ロール").font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textSecondary)
            Spacer(minLength: 0)
            if panel.roleId.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.accentOrange).font(.system(size: 22))
                Text("未設定").font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.accentOrange)
            } else {
                let roleColor: Color = assignedRole.map { Color(uiColor: UIColor(hex: UInt32($0.color))) } ?? Color.accentGreen
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(roleColor.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: "person.badge.key.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(roleColor)
                }
                // Discord ロールバッジ
                HStack(spacing: 5) {
                    Circle().fill(roleColor).frame(width: 8, height: 8)
                    Text("@\(assignedRole?.name ?? String(panel.roleId.suffix(8)))")
                        .font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary).lineLimit(1)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Deploy Info Card

    private var deployInfoCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                deployInfoRow(icon: "number", color: Color.accentIndigo, label: "チャンネル",
                              value: channelName.map { "#\($0)" } ?? "—")
                if panel.verifyType == .manual {
                    Divider().padding(.leading, 30)
                    deployInfoRow(icon: "bell.badge.fill", color: Color.accentOrange, label: "通知先",
                                  value: manualChannelName.map { "#\($0)" } ?? "アプリのみ")
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func deployInfoRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 14)).frame(width: 20)
            Text(label).font(.captionSmall).foregroundStyle(Color.textSecondary).frame(width: 60, alignment: .leading)
            Text(value).font(.captionSmall).fontWeight(.medium).foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Actions Row

    private var actionsRow: some View {
        HStack(spacing: 10) {
            actionButton(icon: "pencil", label: "編集", color: Color.accentIndigo) { showEdit = true }
            actionButton(icon: "paperplane.fill", label: "送信", color: Color.accentGreen) { showDeploySheet = true }
            actionButton(icon: "trash", label: "削除", color: Color.accentRed) { showDeleteConfirm = true }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.1)).frame(height: 52)
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
                }
                Text(label).font(.captionSmall).fontWeight(.medium).foregroundStyle(color)
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
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.accentOrange.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: "person.badge.clock.fill").font(.system(size: 16)).foregroundStyle(Color.accentOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("承認待ちリクエスト").font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                    Text("\(pendingCount)件が承認を待っています").font(.captionSmall).foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Deploy Sheet

    private var deploySheetView: some View {
        NavigationStack {
            List {
                Section("設置先チャンネルを選択") {
                    ForEach(channels, id: \.id) { ch in
                        Button {
                            Task { await deploy(panel, channelId: ch.id) }
                            showDeploySheet = false
                        } label: {
                            HStack {
                                Image(systemName: "number").font(.captionRegular).foregroundStyle(Color.textTertiary)
                                Text(ch.name).font(.bodySmall).foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.captionSmall).foregroundStyle(Color.textTertiary)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設置先チャンネル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("キャンセル") { showDeploySheet = false } }
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
            toast = ToastMessage(type: .success, message: "✅ Discordに設置しました")
        } catch {
            toast = ToastMessage(type: .error, message: "❌ 設置に失敗しました")
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
