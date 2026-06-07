import SwiftUI

struct VerifyPanelListView: View {
    let guildId: String

    @Environment(\.services) private var services
    @State private var panels: [VerifyPanel] = []
    @State private var pendingCount = 0
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var editingPanel: VerifyPanel? = nil
    @State private var channels: [(id: String, name: String)] = []
    @State private var deployingId: String? = nil
    @State private var deployingPanelForChannel: VerifyPanel? = nil
    @State private var toast: ToastMessage? = nil

    private var hasManualPanel: Bool { panels.contains { $0.verifyType == .manual } }

    var body: some View {
        List {
            // 手動認証パネルがあれば承認待ちバナーを表示
            if hasManualPanel && pendingCount > 0 {
                NavigationLink {
                    VerifyRequestsView(guildId: guildId, panelId: nil)
                } label: {
                    HStack(spacing: .spacing12) {
                        ZStack {
                            Circle().fill(Color.accentOrange.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: "person.badge.clock.fill")
                                .font(.system(size: 15)).foregroundStyle(Color.accentOrange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("承認待ちのリクエスト")
                                .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                            Text("\(pendingCount)件のユーザーが承認を待っています")
                                .font(.captionSmall).foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Text("\(pendingCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Color.accentOrange)
                            .clipShape(Capsule())
                    }
                    .padding(.spacing12)
                    .background(Color.accentOrange.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentOrange.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
            }

            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden).padding(.top, 40)
            } else if panels.isEmpty {
                emptyState
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
            } else {
                ForEach(panels) { panel in
                    PanelCard(
                        panel: panel,
                        isDeploying: deployingId == panel.id,
                        guildId: guildId,
                        onEdit: { editingPanel = panel },
                        onDeploy: { deployingPanelForChannel = panel },
                        onDelete: { Task { await deletePanel(panel) } }
                    )
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
                }
            }

            Color.clear.frame(height: 70)
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .refreshable { await load() }
        .navigationTitle("認証パネル")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            VerifyPanelEditView(guildId: guildId) { panels.insert($0, at: 0) }
        }
        .sheet(item: $editingPanel) { panel in
            VerifyPanelEditView(existing: panel, guildId: guildId) { updated in
                if let idx = panels.firstIndex(where: { $0.id == updated.id }) { panels[idx] = updated }
            }
        }
        .confirmationDialog(
            "設置先チャンネルを選択",
            isPresented: Binding(get: { deployingPanelForChannel != nil }, set: { if !$0 { deployingPanelForChannel = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(channels, id: \.id) { ch in
                Button("#\(ch.name)") {
                    if let panel = deployingPanelForChannel { Task { await deploy(panel, channelId: ch.id) } }
                    deployingPanelForChannel = nil
                }
            }
            Button("キャンセル", role: .cancel) { deployingPanelForChannel = nil }
        }
        .toast($toast)
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: .spacing16) {
            Spacer().frame(height: 40)
            ZStack {
                Circle().fill(Color.accentGreen.opacity(0.1)).frame(width: 72, height: 72)
                Image(systemName: "checkmark.shield.fill").font(.system(size: 28)).foregroundStyle(Color.accentGreen)
            }
            VStack(spacing: .spacing8) {
                Text("認証パネルなし").font(.titleMedium).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                Text("右上の「＋」ボタンから\n認証パネルを作成してください")
                    .font(.captionRegular).foregroundStyle(Color.textTertiary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
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
        panels = (try? await panelTask) ?? []
        pendingCount = ((try? await reqTask) ?? []).count
        channels = await chTask
        isLoading = false
    }

    private func deploy(_ panel: VerifyPanel, channelId: String) async {
        deployingId = panel.id
        do {
            let updated = try await services.verify.deployPanel(id: panel.id, channelId: channelId)
            if let idx = panels.firstIndex(where: { $0.id == panel.id }) { panels[idx] = updated }
            toast = ToastMessage(type: .success, message: "✅ Discordに設置しました")
        } catch {
            toast = ToastMessage(type: .error, message: "❌ 設置に失敗しました")
        }
        deployingId = nil
    }

    private func deletePanel(_ panel: VerifyPanel) async {
        do {
            try await services.verify.deletePanel(id: panel.id)
            panels.removeAll { $0.id == panel.id }
            toast = ToastMessage(type: .success, message: "削除しました")
        } catch {
            toast = ToastMessage(type: .error, message: "削除に失敗しました")
        }
    }
}

// MARK: - PanelCard

private struct PanelCard: View {
    let panel: VerifyPanel
    let isDeploying: Bool
    let guildId: String
    let onEdit: () -> Void
    let onDeploy: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(panel.verifyType.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: panel.verifyType.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(panel.verifyType.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: .spacing6) {
                        Text(panel.name).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                        Text(panel.verifyType.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(panel.verifyType.accentColor)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(panel.verifyType.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                        Spacer()
                        Text(panel.isDeployed ? "設置済" : "未設置")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(panel.isDeployed ? Color.accentGreen : Color.textTertiary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background((panel.isDeployed ? Color.accentGreen : Color.textTertiary).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(panel.roleId.isEmpty ? "ロール未設定" : "ロール設定済")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.spacing12)

            Divider().padding(.horizontal, .spacing12)

            HStack(spacing: 0) {
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                        .font(.captionRegular).fontWeight(.medium).foregroundStyle(Color.accentIndigo)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                if panel.verifyType == .manual {
                    NavigationLink {
                        VerifyRequestsView(guildId: guildId, panelId: panel.id)
                    } label: {
                        Label("申請管理", systemImage: "person.badge.clock.fill")
                            .font(.captionRegular).fontWeight(.medium).foregroundStyle(Color.accentPurple)
                            .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 20)
                }

                Button {
                    guard !panel.roleId.isEmpty else { return }
                    onDeploy()
                } label: {
                    if isDeploying {
                        ProgressView().scaleEffect(0.7).frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                    } else {
                        Label("設置", systemImage: "paperplane.fill")
                            .font(.captionRegular).fontWeight(.medium)
                            .foregroundStyle(panel.roleId.isEmpty ? Color.textTertiary : Color.accentGreen)
                            .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                    }
                }
                .buttonStyle(.plain).disabled(isDeploying || panel.roleId.isEmpty)

                Divider().frame(height: 20)

                Button { showDeleteConfirm = true } label: {
                    Label("削除", systemImage: "trash")
                        .font(.captionRegular).fontWeight(.medium).foregroundStyle(Color.accentRed)
                        .frame(maxWidth: .infinity).padding(.vertical, .spacing10)
                }
                .buttonStyle(.plain)
            }
            .background(Color(.tertiarySystemGroupedBackground))
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .confirmationDialog("削除の確認", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("削除する", role: .destructive, action: onDelete)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(panel.name)」を削除します。Discordのパネルメッセージは手動で削除してください。")
        }
    }
}
