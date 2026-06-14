import SwiftUI

// MARK: - StatChannelsView

struct StatChannelsView: View {
    let guildId: String
    @Environment(\.services)    private var services
    @Environment(\.dismiss)     private var dismiss

    @State private var channels:     [StatChannel]       = []
    @State private var subStatus:    SubscriptionStatus  = .inactive
    @State private var isLoading     = true
    @State private var showAddSheet  = false
    @State private var isActivating  = false
    @State private var showSubscribe = false
    @State private var toast: String? = nil
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: StatChannel? = nil
    @State private var showActivateConfirm = false

    // デバッグ時は DB から取得した subStatus をそのまま使う（debug-setup で実際に書き込むため）
    private var effectiveStatus: SubscriptionStatus { subStatus }

    private var isServerActivated: Bool {
        effectiveStatus.activatedGuildIds.contains(guildId)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else if !effectiveStatus.isActive {
                // ── 未課金: ペイウォール ──────────────────────────────
                PaywallView(onSubscribe: { showSubscribe = true })
            } else if !isServerActivated {
                // ── 課金済みだがサーバー未有効化 ──────────────────────
                ActivationPromptView(
                    availableSlots: effectiveStatus.availableSlots,
                    isActivating: isActivating,
                    onActivate: { showActivateConfirm = true },
                    onSubscribe: { showSubscribe = true }
                )
            } else {
                // ── 有効化済み: 通常のチャンネル管理 ─────────────────
                mainContent
            }
        }
        .navigationTitle("ステータスチャンネル")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddSheet) {
            StatChannelAddSheet(guildId: guildId) { newChannels in
                channels.append(contentsOf: newChannels)
                let names = newChannels.map { $0.statType.label }.joined(separator: "・")
                withAnimation { toast = "\(names)チャンネルを作成しました" }
            }
        }
        .sheet(isPresented: $showSubscribe) {
            NavigationStack { SubscriptionView() }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                toastView(toast)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { self.toast = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
        .task { await load() }
        .refreshable { await load() }
        .overlay {
            if showDeleteConfirm, let target = deleteTarget {
                ConfirmModal(
                    icon: "trash.fill",
                    iconColor: Theme.Color.statusBad,
                    title: "\(target.statType.label) を削除しますか？",
                    message: "Discord のチャンネルも削除されます。この操作は元に戻せません。",
                    primaryLabel: "削除する",
                    primaryRole: .destructive,
                    onPrimary: {
                        Task {
                            await deleteChannel(target)
                            showDeleteConfirm = false
                            deleteTarget = nil
                        }
                    },
                    onCancel: {
                        showDeleteConfirm = false
                        deleteTarget = nil
                    }
                )
            }
            if showActivateConfirm {
                ConfirmModal(
                    icon: "server.rack",
                    iconColor: Theme.Color.accent,
                    title: "このサーバーを有効化しますか？",
                    message: "有効化後、ステータスチャンネルが自動作成されます。プランのスロットを1つ消費します。",
                    primaryLabel: "有効化する",
                    primaryRole: nil,
                    onPrimary: {
                        Task {
                            await activateCurrentServer()
                            showActivateConfirm = false
                        }
                    },
                    onCancel: {
                        showActivateConfirm = false
                    }
                )
            }
        }
    }

    // MARK: - 有効化済み: 通常コンテンツ

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            if channels.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        infoSection
                        channelsSection
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .padding(.bottom, 80)
                }
                .background(Theme.Color.bg)
            }

            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Color.accentInk)
                    .frame(width: 56, height: 56)
                    .background(Theme.Color.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var infoSection: some View {
        FormSection("ステータスチャンネル", icon: "info.circle") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                    Text("チャンネル名が約10分ごとに自動更新されます")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                    Text("Discordの制限: 10分に2回まで変更可能")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
        }
    }

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "list.bullet")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
                Text("チャンネル一覧")
                    .font(Theme.Font.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(channels.count) チャンネル")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .monospaced()
            }

            Card {
                VStack(spacing: 0) {
                    ForEach(channels) { channel in
                        StatChannelRow(channel: channel) { newEnabled in
                            await toggleChannel(channel, enabled: newEnabled)
                        } onRefresh: {
                            await refreshChannel(channel)
                        } onDelete: {
                            deleteTarget = channel
                            showDeleteConfirm = true
                        }
                        if channel.id != channels.last?.id {
                            Divider().background(Theme.Color.line)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Color.surface)
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            VStack(spacing: Theme.Spacing.sm) {
                Text("ステータスチャンネルなし")
                    .font(Theme.Font.title3)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("サーバーの統計をボイスチャンネルの\n名前としてリアルタイム表示できます")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                Text("右下のボタンからチャンネルを追加できます")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.bg)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
        async let statusTask   = services.subscription.fetchStatus(discordUserId: userId)
        async let channelsTask = services.statChannels.fetchAll(guildId: guildId)
        subStatus = (try? await statusTask)   ?? .inactive
        channels  = (try? await channelsTask) ?? []
        isLoading = false
    }

    private func activateCurrentServer() async {
        isActivating = true
        do {
            try await services.subscription.activateServer(guildId: guildId)
            // ステータス再取得
            let userId = KeychainHelper.load(forKey: "discord_user_id") ?? ""
            subStatus = (try? await services.subscription.fetchStatus(discordUserId: userId)) ?? subStatus
            withAnimation { toast = "このサーバーを有効化しました" }
        } catch {
            withAnimation { toast = "有効化に失敗しました: \(error.localizedDescription)" }
        }
        isActivating = false
    }

    private func toggleChannel(_ channel: StatChannel, enabled: Bool) async {
        if let updated = try? await services.statChannels.toggle(id: channel.id, enabled: enabled) {
            withAnimation {
                if let idx = channels.firstIndex(where: { $0.id == channel.id }) {
                    channels[idx] = updated
                }
            }
        }
    }

    private func refreshChannel(_ channel: StatChannel) async {
        try? await services.statChannels.refresh(id: channel.id)
        await load()
        withAnimation { toast = "チャンネルを更新しました" }
    }

    private func deleteChannel(_ channel: StatChannel) async {
        try? await services.statChannels.delete(id: channel.id)
        withAnimation { channels.removeAll { $0.id == channel.id } }
    }

    private func toastView(_ message: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.statusOK)
            Text(message)
                .font(Theme.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(height: 44)
        .background(Theme.Color.surfaceRaised)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }
}

// MARK: - PaywallView（未課金ユーザー向け）

private struct PaywallView: View {
    let onSubscribe: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                Spacer().frame(height: Theme.Spacing.md)

                // アイコン + タイトル
                VStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .fill(Theme.Color.surface)
                            .frame(width: 96, height: 96)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.Color.accent)
                    }

                    VStack(spacing: Theme.Spacing.sm) {
                        Text("Noxy Pro の機能です")
                            .font(Theme.Font.title3)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("サーバーの統計情報をDiscordの\nチャンネル名にリアルタイム表示できます")
                            .font(Theme.Font.bodySmall)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                // チャンネル表示プレビュー（ロック付き）
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("表示イメージ")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .padding(.horizontal, Theme.Spacing.md)

                    VStack(spacing: 0) {
                        previewRow(.members,  isLast: false)
                        Divider().padding(.leading, Theme.Spacing.xl)
                        previewRow(.online,   isLast: false)
                        Divider().padding(.leading, Theme.Spacing.xl)
                        previewRow(.boosts,   isLast: false)
                        Divider().padding(.leading, Theme.Spacing.xl)
                        previewRow(.vcUsers,  isLast: true)
                    }
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.Color.lineStrong, lineWidth: 1)
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                }

                // 価格説明
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.statusOK)
                    Text("サーバー1台から月額100円で利用可能")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                // CTA ボタン
                VStack(spacing: Theme.Spacing.sm) {
                    AccentButton(title: "Noxy Pro を始める") {
                        onSubscribe()
                    }

                    Text("月額 ¥100〜 · いつでも解約可能")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                .padding(.horizontal)

                Spacer().frame(height: Theme.Spacing.md)
            }
        }
        .background(Theme.Color.bg)
    }

    private func previewRow(_ type: StatType, isLast: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "speaker.wave.1.fill")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
            Text(type.channelName(value: sampleValue(type)))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .monospaced()
            Spacer()
            Image(systemName: "lock.fill")
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func sampleValue(_ type: StatType) -> Int {
        switch type {
        case .members:  return 1_234
        case .online:   return 89
        case .boosts:   return 7
        case .vcUsers:  return 3
        }
    }
}

// MARK: - ActivationPromptView（課金済みだが未有効化）

private struct ActivationPromptView: View {
    let availableSlots: Int
    let isActivating: Bool
    let onActivate: () async -> Void
    let onSubscribe: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .fill(Theme.Color.surface)
                        .frame(width: 80, height: 80)
                    Image(systemName: availableSlots > 0 ? "server.rack" : "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(availableSlots > 0 ? Theme.Color.textTertiary : Theme.Color.statusWarn)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Text(availableSlots > 0 ? "このサーバーは未有効化です" : "スロットが満杯です")
                        .font(Theme.Font.title3)
                        .foregroundStyle(Theme.Color.textPrimary)

                    Text(availableSlots > 0
                         ? "ステータスチャンネル機能を使うには\nこのサーバーを有効化してください"
                         : "現在のプランでは有効化できるサーバーが\n満杯です。プランをアップグレードするか\n別のサーバーの有効化を解除してください")
                        .font(Theme.Font.bodySmall)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)

            VStack(spacing: Theme.Spacing.sm) {
                if availableSlots > 0 {
                    // 有効化ボタン
                    Button {
                        Task { await onActivate() }
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            if isActivating {
                                ProgressView().tint(Theme.Color.accentInk)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text(isActivating ? "有効化中..." : "このサーバーを有効化")
                                .font(Theme.Font.bodyMedium)
                        }
                        .foregroundStyle(Theme.Color.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                    .disabled(isActivating)
                    .buttonStyle(.plain)

                    Text("残りスロット: \(availableSlots)台")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .monospaced()
                } else {
                    // スロット不足 → アップグレード誘導
                    AccentButton(title: "プランをアップグレード") {
                        onSubscribe()
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Theme.Color.bg)
    }
}

// MARK: - StatChannelRow

private struct StatChannelRow: View {
    let channel: StatChannel
    let onToggle: (Bool) async -> Void
    let onRefresh: () async -> Void
    let onDelete: () -> Void

    @State private var isToggling  = false
    @State private var isRefreshing = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 状態カラーバー
            RoundedRectangle(cornerRadius: 1.5)
                .fill(channel.isEnabled ? Theme.Color.statusOK : Theme.Color.textTertiary)
                .frame(width: 3)

            // アイコン
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.chip)
                    .fill(Theme.Color.surfaceRaised)
                    .frame(width: 36, height: 36)
                Image(systemName: channel.statType.systemImage)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            // 主情報
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.statType.label)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                if channel.lastValue >= 0 {
                    Text(channel.displayValue)
                        .font(Theme.Font.mono)
                        .foregroundStyle(Theme.Color.textSecondary)
                } else {
                    Text("未取得")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }

            Spacer()

            // メタ: 最終更新
            if let updated = channel.lastUpdatedAt {
                Text(timeString(updated))
                    .font(Theme.Font.monoCap)
                    .foregroundStyle(Theme.Color.textTertiary)
            }

            // 更新ボタン
            Button {
                isRefreshing = true
                Task { await onRefresh(); isRefreshing = false }
            } label: {
                if isRefreshing { ProgressView().scaleEffect(0.7) }
                else {
                    Image(systemName: "arrow.clockwise")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)

            // Toggle
            Toggle("", isOn: Binding(
                get: { channel.isEnabled },
                set: { newVal in
                    isToggling = true
                    Task { await onToggle(newVal); isToggling = false }
                }
            ))
            .tint(Theme.Color.accent)
            .labelsHidden()
            .disabled(isToggling)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - StatChannelAddSheet（複数選択対応）

private struct StatChannelAddSheet: View {
    let guildId: String
    let onCreated: ([StatChannel]) -> Void

    @Environment(\.dismiss)  private var dismiss
    @Environment(\.services) private var services
    @State private var selectedTypes: Set<StatType> = []
    @State private var isCreating   = false
    @State private var errorMessage: String? = nil

    private var canCreate: Bool { !selectedTypes.isEmpty && !isCreating }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    FormSection("統計の種類を選択", icon: "list.bullet") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "info.circle.fill")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ボイスチャンネルが自動作成されます")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Text("誰も入室できない設定で配置されます")
                                        .font(Theme.Font.caption2)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                }
                            }
                            if !selectedTypes.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("\(selectedTypes.count)件選択中")
                                        .font(Theme.Font.caption2)
                                        .foregroundStyle(Theme.Color.accent)
                                        .monospaced()
                                }
                            }
                        }
                    }

                    FormSection("種類", icon: "chart.bar") {
                        VStack(spacing: 0) {
                            ForEach(StatType.allCases) { type in
                                Button {
                                    if selectedTypes.contains(type) {
                                        selectedTypes.remove(type)
                                    } else {
                                        selectedTypes.insert(type)
                                    }
                                } label: {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                                                .fill(Theme.Color.surfaceRaised)
                                                .frame(width: 36, height: 36)
                                            Image(systemName: type.systemImage)
                                                .font(.system(size: 16))
                                                .foregroundStyle(Theme.Color.textSecondary)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(type.label)
                                                .font(Theme.Font.body)
                                                .foregroundStyle(Theme.Color.textPrimary)
                                            Text(type.description)
                                                .font(Theme.Font.caption)
                                                .foregroundStyle(Theme.Color.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: selectedTypes.contains(type) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedTypes.contains(type) ? Theme.Color.accent : Theme.Color.textTertiary)
                                            .font(.system(size: 20))
                                            .animation(.easeInOut(duration: 0.15), value: selectedTypes.contains(type))
                                    }
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if type.id != StatType.allCases.last?.id {
                                    Divider().background(Theme.Color.line)
                                }
                            }
                        }
                    }

                    if let error = errorMessage {
                        FormSection("エラー", icon: "exclamationmark.triangle") {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.statusBad)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.Color.bg)
            .navigationTitle("チャンネル追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isCreating { ProgressView() }
                    else {
                        Button("作成") { Task { await create() } }
                            .font(Theme.Font.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundStyle(canCreate ? Theme.Color.accent : Theme.Color.textTertiary)
                            .disabled(!canCreate)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func create() async {
        isCreating = true; errorMessage = nil
        var created: [StatChannel] = []
        var failed: [String] = []

        for type in StatType.allCases where selectedTypes.contains(type) {
            do {
                let ch = try await services.statChannels.create(guildId: guildId, statType: type, categoryId: nil)
                created.append(ch)
            } catch let e as ServiceError {
                switch e {
                case .workerError(let status, let message):
                    if status == 402 {
                        failed.append("\(type.label): サーバーが有効化されていません")
                    } else {
                        failed.append("\(type.label): \(message)")
                    }
                default:
                    failed.append("\(type.label): 作成失敗")
                }
            } catch {
                failed.append("\(type.label): \(error.localizedDescription)")
            }
        }

        if !created.isEmpty {
            onCreated(created)
            if failed.isEmpty {
                dismiss()
            } else {
                errorMessage = "一部失敗: " + failed.joined(separator: "、")
            }
        } else if !failed.isEmpty {
            errorMessage = failed.joined(separator: "\n")
        }
        isCreating = false
    }
}

// MARK: - Preview

#Preview("未課金") {
    NavigationStack { StatChannelsView(guildId: "g001") }
        .environment(\.services, ServiceContainer.live())
}

#Preview("課金済み・未有効化") {
    NavigationStack { StatChannelsView(guildId: "g001") }
        .environment(\.services, ServiceContainer.live())
}

#Preview("有効化済み・空") {
    NavigationStack { StatChannelsView(guildId: "g001") }
        .environment(\.services, ServiceContainer.live())
}

#Preview("有効化済み・リスト") {
    NavigationStack { StatChannelsView(guildId: "g001") }
        .environment(\.services, ServiceContainer.live())
}

#Preview("有効化済み・リスト Dark") {
    NavigationStack { StatChannelsView(guildId: "g001") }
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}

#Preview("有効化済み・リスト Light") {
    NavigationStack { StatChannelsView(guildId: "g001") }
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.light)
}
