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
                    onActivate: { await activateCurrentServer() },
                    onSubscribe: { showSubscribe = true }
                )
            } else {
                // ── 有効化済み: 通常のチャンネル管理 ─────────────────
                mainContent
            }
        }
        .navigationTitle("ステータスチャンネル")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isServerActivated {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus").foregroundStyle(Color.accentIndigo)
                    }
                }
            }
        }
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
    }

    // MARK: - 有効化済み: 通常コンテンツ

    private var mainContent: some View {
        Group {
            if channels.isEmpty {
                emptyState
            } else {
                List {
                    infoSection
                    channelsSection
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var infoSection: some View {
        Section {
            HStack(spacing: .spacing12) {
                Image(systemName: "info.circle.fill").foregroundStyle(Color.accentIndigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("チャンネル名が約10分ごとに自動更新されます")
                        .font(.captionRegular).foregroundStyle(Color.textSecondary)
                    Text("Discordの制限: 10分に2回まで変更可能")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.vertical, .spacing4)
        }
    }

    private var channelsSection: some View {
        Section("チャンネル一覧") {
            ForEach(channels) { channel in
                StatChannelRow(channel: channel) { newEnabled in
                    await toggleChannel(channel, enabled: newEnabled)
                } onRefresh: {
                    await refreshChannel(channel)
                }
            }
            .onDelete { indexSet in Task { await deleteChannels(at: indexSet) } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: .spacing24) {
            Spacer()
            VStack(spacing: .spacing16) {
                ZStack {
                    Circle().fill(Color.accentIndigo.opacity(0.1)).frame(width: 80, height: 80)
                    Text("📊").font(.system(size: 36))
                }
                VStack(spacing: .spacing8) {
                    Text("ステータスチャンネルなし")
                        .font(.titleMedium).foregroundStyle(Color.textPrimary)
                    Text("サーバーの統計をボイスチャンネルの\n名前としてリアルタイム表示できます")
                        .font(.bodySmall).foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            Button {
                showAddSheet = true
            } label: {
                Label("チャンネルを追加", systemImage: "plus")
                    .font(.bodySmall.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacing24).frame(height: 44)
                    .background(Color.accentIndigo).clipShape(Capsule())
            }
            Spacer()
        }
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
            withAnimation { toast = "このサーバーを有効化しました 🎉" }
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

    private func deleteChannels(at indexSet: IndexSet) async {
        for idx in indexSet {
            try? await services.statChannels.delete(id: channels[idx].id)
        }
        withAnimation { channels.remove(atOffsets: indexSet) }
    }

    private func toastView(_ message: String) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text(message).font(.captionRegular).fontWeight(.semibold).foregroundStyle(.white)
        }
        .padding(.horizontal, .spacing20).frame(height: 44)
        .background(Color.accentGreen).clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - PaywallView（未課金ユーザー向け）

private struct PaywallView: View {
    let onSubscribe: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing32) {
                Spacer().frame(height: .spacing16)

                // アイコン + タイトル
                VStack(spacing: .spacing16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.accentOrange.opacity(0.2), Color.accentPink.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 96, height: 96)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(colors: [Color.accentOrange, Color.accentPink],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    }

                    VStack(spacing: .spacing8) {
                        Text("Noxy Pro の機能です")
                            .font(.displayMedium).foregroundStyle(Color.textPrimary)
                        Text("サーバーの統計情報をDiscordの\nチャンネル名にリアルタイム表示できます")
                            .font(.bodySmall).foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                // チャンネル表示プレビュー（ロック付き）
                VStack(alignment: .leading, spacing: .spacing8) {
                    Text("表示イメージ")
                        .font(.captionRegular).foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, .spacing16)

                    VStack(spacing: 0) {
                        previewRow(.members,  isLast: false)
                        Divider().padding(.leading, .spacing32)
                        previewRow(.online,   isLast: false)
                        Divider().padding(.leading, .spacing32)
                        previewRow(.boosts,   isLast: false)
                        Divider().padding(.leading, .spacing32)
                        previewRow(.vcUsers,  isLast: true)
                    }
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                            .stroke(Color.accentOrange.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, .spacing16)
                }

                // 価格説明
                HStack(spacing: .spacing8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentGreen)
                    Text("サーバー1台から月額100円で利用可能")
                        .font(.bodySmall).foregroundStyle(Color.textSecondary)
                }

                // CTA ボタン
                VStack(spacing: .spacing12) {
                    Button(action: onSubscribe) {
                        HStack(spacing: .spacing8) {
                            Image(systemName: "crown.fill")
                            Text("Noxy Pro を始める")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(
                            LinearGradient(colors: [Color.accentOrange, Color.accentPink],
                                           startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    }
                    .buttonStyle(ScalePressButtonStyle())

                    Text("月額 ¥100〜 · いつでも解約可能")
                        .font(.captionRegular).foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal)

                Spacer().frame(height: .spacing16)
            }
        }
        .background(Color.bgPrimary)
    }

    private func previewRow(_ type: StatType, isLast: Bool) -> some View {
        HStack(spacing: .spacing10) {
            Image(systemName: "speaker.wave.1.fill")
                .font(.caption).foregroundStyle(Color.textTertiary)
            Text(type.channelName(value: sampleValue(type)))
                .font(.caption).foregroundStyle(Color.textSecondary)
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption2).foregroundStyle(Color.accentOrange.opacity(0.7))
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing10)
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
        VStack(spacing: .spacing32) {
            Spacer()

            VStack(spacing: .spacing16) {
                ZStack {
                    Circle()
                        .fill(Color.accentIndigo.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: availableSlots > 0 ? "server.rack" : "exclamationmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(availableSlots > 0 ? Color.accentIndigo : Color.accentOrange)
                }

                VStack(spacing: .spacing8) {
                    Text(availableSlots > 0 ? "このサーバーは未有効化です" : "スロットが満杯です")
                        .font(.titleMedium).foregroundStyle(Color.textPrimary)

                    Text(availableSlots > 0
                         ? "ステータスチャンネル機能を使うには\nこのサーバーを有効化してください"
                         : "現在のプランでは有効化できるサーバーが\n満杯です。プランをアップグレードするか\n別のサーバーの有効化を解除してください")
                        .font(.bodySmall).foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)

            VStack(spacing: .spacing12) {
                if availableSlots > 0 {
                    // 有効化ボタン
                    Button {
                        Task { await onActivate() }
                    } label: {
                        HStack(spacing: .spacing8) {
                            if isActivating {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text(isActivating ? "有効化中..." : "このサーバーを有効化")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    }
                    .disabled(isActivating)
                    .buttonStyle(ScalePressButtonStyle())

                    Text("残りスロット: \(availableSlots)台")
                        .font(.captionRegular).foregroundStyle(Color.textTertiary)
                } else {
                    // スロット不足 → アップグレード誘導
                    Button(action: onSubscribe) {
                        Text("プランをアップグレード")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Color.accentOrange)
                            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                    }
                    .buttonStyle(ScalePressButtonStyle())
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.bgPrimary)
    }
}

// MARK: - StatChannelRow（既存、変更なし）

private struct StatChannelRow: View {
    let channel: StatChannel
    let onToggle: (Bool) async -> Void
    let onRefresh: () async -> Void

    @State private var isToggling  = false
    @State private var isRefreshing = false

    var body: some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                    .fill(iconColor.opacity(0.12)).frame(width: 36, height: 36)
                Text(channel.statType.icon).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.statType.label).font(.body).foregroundStyle(Color.textPrimary)
                if channel.lastValue >= 0 {
                    Text(channel.channelName).font(.captionRegular)
                        .foregroundStyle(Color.textSecondary).lineLimit(1)
                } else {
                    Text("未取得").font(.captionRegular).foregroundStyle(Color.textTertiary)
                }
            }
            Spacer()
            Button {
                isRefreshing = true
                Task { await onRefresh(); isRefreshing = false }
            } label: {
                if isRefreshing { ProgressView().scaleEffect(0.7) }
                else { Image(systemName: "arrow.clockwise").font(.caption).foregroundStyle(Color.textTertiary) }
            }
            .buttonStyle(.plain).frame(width: 28, height: 28)
            Toggle("", isOn: Binding(
                get: { channel.isEnabled },
                set: { newVal in
                    isToggling = true
                    Task { await onToggle(newVal); isToggling = false }
                }
            ))
            .tint(Color.accentIndigo).labelsHidden().disabled(isToggling)
        }
        .padding(.vertical, .spacing4)
    }

    private var iconColor: Color {
        switch channel.statType {
        case .members: return .accentIndigo
        case .online:  return .accentGreen
        case .boosts:  return .accentOrange
        case .vcUsers: return .accentPurple
        }
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
            List {
                Section {
                    HStack(spacing: .spacing10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Color.accentIndigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ボイスチャンネルが自動作成されます").font(.captionRegular).foregroundStyle(Color.textPrimary)
                            Text("誰も入室できない設定で配置されます").font(.captionSmall).foregroundStyle(Color.textSecondary)
                        }
                    }
                    .padding(.vertical, .spacing4)
                } header: {
                    HStack {
                        Text("統計の種類を選択")
                        Spacer()
                        if !selectedTypes.isEmpty {
                            Text("\(selectedTypes.count)件選択中")
                                .font(.captionSmall)
                                .foregroundStyle(Color.accentIndigo)
                        }
                    }
                }

                Section {
                    ForEach(StatType.allCases) { type in
                        Button {
                            if selectedTypes.contains(type) {
                                selectedTypes.remove(type)
                            } else {
                                selectedTypes.insert(type)
                            }
                        } label: {
                            HStack(spacing: .spacing12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                                        .fill(accentColor(type).opacity(0.12)).frame(width: 36, height: 36)
                                    Text(type.icon).font(.system(size: 18))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.label).font(.body).foregroundStyle(Color.textPrimary)
                                    Text(type.description).font(.captionRegular).foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                Image(systemName: selectedTypes.contains(type) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedTypes.contains(type) ? Color.accentIndigo : Color.textTertiary)
                                    .font(.system(size: 20))
                                    .animation(.easeInOut(duration: 0.15), value: selectedTypes.contains(type))
                            }
                            .padding(.vertical, .spacing4).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.captionRegular).foregroundStyle(Color.accentRed)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("チャンネル追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isCreating { ProgressView() }
                    else {
                        Button("作成") { Task { await create() } }
                            .fontWeight(.semibold)
                            .foregroundStyle(canCreate ? Color.accentIndigo : Color.textTertiary)
                            .disabled(!canCreate)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func accentColor(_ type: StatType) -> Color {
        switch type {
        case .members: return .accentIndigo
        case .online:  return .accentGreen
        case .boosts:  return .accentOrange
        case .vcUsers: return .accentPurple
        }
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
