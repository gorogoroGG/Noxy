import SwiftUI

// MARK: - ServerRecoveryView

struct ServerRecoveryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.services) private var services

    @State private var botGuilds: [Guild] = []
    @State private var memberCounts: [String: Int] = [:]
    @State private var isLoading = true
    @State private var isLoadingCounts = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing16) {
                    if isLoading {
                        loadingView
                    } else if botGuilds.isEmpty {
                        emptyView
                    } else {
                        guildListSection
                    }
                }
                .padding(.horizontal, .spacing16)
                .padding(.vertical, .spacing12)
            }
            .background(Theme.Color.bg)
            .navigationTitle("サーバー復旧")
            .navigationBarTitleDisplayMode(.large)
            .task { await load() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: .spacing12) {
            Spacer()
            ProgressView().tint(Theme.Color.accent)
            Text("読み込み中...")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var emptyView: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Color.textTertiary)
            Text("Botが導入されているサーバーがありません")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var guildListSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            SectionLabel(title: "バックアップ元サーバーを選択")
                .padding(.horizontal, .spacing16)

            Text("選択したサーバーのOAuth2認証済みメンバーを、別のサーバーに自動参加させることができます。")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
                .padding(.horizontal, .spacing16)

            VStack(spacing: 0) {
                ForEach(Array(botGuilds.enumerated()), id: \.element.id) { idx, guild in
                    NavigationLink(destination: RecoveryDetailView(sourceGuild: guild, allGuilds: botGuilds)) {
                        HStack(spacing: .spacing12) {
                            ServerIconView(imageUrl: guild.iconUrl, name: guild.name, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(guild.name)
                                    .font(Theme.Font.bodyMedium)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                if isLoadingCounts {
                                    Text("読み込み中...")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Color.textTertiary)
                                } else {
                                    let count = memberCounts[guild.id, default: 0]
                                    Text("\(count)人のバックアップ")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(count > 0 ? Theme.Color.accent : Theme.Color.textTertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        .padding(.horizontal, .spacing16)
                        .padding(.vertical, .spacing12)
                        .background(Theme.Color.surface)
                    }
                    .buttonStyle(.plain)
                    if idx < botGuilds.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1))
        }
    }

    private func load() async {
        isLoading = true
        botGuilds = (try? await DiscordService().fetchBotGuilds()) ?? []
        isLoading = false
        let ids = botGuilds.map { $0.id }
        memberCounts = (try? await services.disasterRecovery.fetchMemberCounts(guildIds: ids)) ?? [:]
        isLoadingCounts = false
    }
}

// MARK: - RecoveryDetailView

struct RecoveryDetailView: View {
    let sourceGuild: Guild
    let allGuilds: [Guild]

    @Environment(\.services) private var services

    @State private var phase: Phase = .confirm
    @State private var eligibleUsers: [RecoveryEligibleUser] = []
    @State private var isLoadingUsers = false
    @State private var selectedUserIds: Set<String> = []
    @State private var alreadyInServer: Set<String> = []
    @State private var isCheckingMembership = false
    @State private var selectedDestGuildId: String = ""
    @State private var isExecuting = false
    @State private var errorMessage: String? = nil
    @State private var toast: ToastMessage? = nil
    @State private var jobs: [RecoveryJob] = []
    @State private var pollingJobId: String? = nil

    private enum Phase { case confirm, setup }

    private var destGuilds: [Guild] { allGuilds }

    private var notInServer: [RecoveryEligibleUser] {
        eligibleUsers.filter { !alreadyInServer.contains($0.userId) }
    }

    private var inServer: [RecoveryEligibleUser] {
        eligibleUsers.filter { alreadyInServer.contains($0.userId) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing16) {
                switch phase {
                case .confirm:
                    confirmSection
                case .setup:
                    if isLoadingUsers {
                        loadingUsersView
                    } else {
                        eligibleUsersSection
                        destinationSection
                        executeSection
                        jobsSection
                    }
                }
            }
            .padding(.horizontal, .spacing16)
            .padding(.vertical, .spacing12)
        }
        .background(Theme.Color.bg)
        .navigationTitle(sourceGuild.name)
        .navigationBarTitleDisplayMode(.large)
        .toast($toast)
        .onChange(of: selectedDestGuildId) { _, _ in Task { await checkMembership() } }
        .onChange(of: pollingJobId) { _, id in
            guard id != nil else { return }
            Task { await pollJobStatus() }
        }
    }

    // MARK: Confirm Phase

    private var confirmSection: some View {
        VStack(spacing: .spacing20) {
            VStack(spacing: .spacing16) {
                ServerIconView(imageUrl: sourceGuild.iconUrl, name: sourceGuild.name, size: 64)
                VStack(spacing: .spacing6) {
                    Text(sourceGuild.name)
                        .font(Theme.Font.title2)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("このサーバーのOAuth2認証済みメンバーを\n別のサーバーに自動参加させることができます。")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, .spacing24)

            AccentButton(title: "このサーバーからメンバーを復旧させる") {
                Task { await startSetup() }
            }
            .padding(.horizontal, .spacing8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacing16)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Color.line, lineWidth: 1))
    }

    private var loadingUsersView: some View {
        VStack(spacing: .spacing12) {
            ProgressView().tint(Theme.Color.accent)
            Text("メンバー情報を取得中...")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: Eligible Users Section

    @ViewBuilder
    private var eligibleUsersSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            HStack {
                SectionLabel(title: "自動参加させるメンバー")
                Spacer()
                if isCheckingMembership {
                    ProgressView().scaleEffect(0.7)
                } else if !eligibleUsers.isEmpty {
                    Text("選択中 \(selectedUserIds.count) / \(notInServer.count)人")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
            .padding(.horizontal, .spacing16)

            if eligibleUsers.isEmpty {
                HStack(spacing: .spacing10) {
                    Image(systemName: "person.slash.fill")
                        .foregroundStyle(Theme.Color.textTertiary)
                    Text("OAuth2認証済みのメンバーはいません")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                    Spacer()
                }
                .padding(14)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1))
            } else {
                VStack(spacing: 0) {
                    // 全選択/全解除
                    if !notInServer.isEmpty {
                        let allIds = Set(notInServer.map { $0.userId })
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedUserIds = selectedUserIds == allIds ? [] : allIds
                            }
                        } label: {
                            HStack {
                                Text(selectedUserIds == allIds ? "全解除" : "全選択")
                                    .font(Theme.Font.bodyMedium)
                                    .foregroundStyle(Theme.Color.accent)
                                Spacer()
                                Image(systemName: selectedUserIds == allIds ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Theme.Color.accent)
                                    .font(.system(size: 18))
                            }
                            .padding(.horizontal, .spacing16)
                            .padding(.vertical, .spacing12)
                            .background(Theme.Color.surface)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }

                    // 未参加ユーザー
                    ForEach(Array(notInServer.enumerated()), id: \.element.id) { idx, user in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedUserIds.contains(user.userId) {
                                    selectedUserIds.remove(user.userId)
                                } else {
                                    selectedUserIds.insert(user.userId)
                                }
                            }
                        } label: {
                            HStack(spacing: .spacing12) {
                                Avatar(imageUrl: user.avatarUrl, name: user.username, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.username)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Text("認証: \(user.authorizedAt, style: .date)")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Color.textTertiary)
                                }
                                Spacer()
                                Image(systemName: selectedUserIds.contains(user.userId) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedUserIds.contains(user.userId) ? Theme.Color.accent : Theme.Color.textTertiary)
                                    .font(.system(size: 18))
                            }
                            .padding(.horizontal, .spacing16)
                            .padding(.vertical, .spacing12)
                            .background(selectedUserIds.contains(user.userId) ? Theme.Color.surfaceRaised : Theme.Color.surface)
                        }
                        .buttonStyle(.plain)
                        if idx < notInServer.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }

                    // 参加済みユーザー
                    if !inServer.isEmpty {
                        Divider()
                        HStack {
                            Text("参加済み（選択不可）")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textTertiary)
                            Spacer()
                            Text("\(inServer.count)人")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        .padding(.horizontal, .spacing16)
                        .padding(.vertical, .spacing8)
                        .background(Theme.Color.surface)

                        ForEach(Array(inServer.enumerated()), id: \.element.id) { idx, user in
                            HStack(spacing: .spacing12) {
                                Avatar(imageUrl: user.avatarUrl, name: user.username, size: 36)
                                Text(user.username)
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Color.textSecondary)
                                Spacer()
                                Label("参加済み", systemImage: "checkmark.circle.fill")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.statusOK)
                            }
                            .padding(.horizontal, .spacing16)
                            .padding(.vertical, .spacing12)
                            .background(Theme.Color.surface)
                            if idx < inServer.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                }
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1))
            }
        }
    }

    // MARK: Destination Section

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            SectionLabel(title: "自動参加先サーバー")
                .padding(.horizontal, .spacing16)

            if destGuilds.isEmpty {
                HStack(spacing: .spacing10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Color.statusWarn)
                    Text("参加先サーバーがありません（同じサーバーは選択不可）")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                    Spacer()
                }
                .padding(14)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(destGuilds.enumerated()), id: \.element.id) { idx, guild in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDestGuildId = guild.id
                            }
                        } label: {
                            HStack(spacing: .spacing12) {
                                ServerIconView(imageUrl: guild.iconUrl, name: guild.name, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(guild.name)
                                        .font(Theme.Font.bodyMedium)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Text("Bot導入済み")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Color.textTertiary)
                                }
                                Spacer()
                                if selectedDestGuildId == guild.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.Color.accent)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, .spacing16)
                            .padding(.vertical, .spacing12)
                            .background(selectedDestGuildId == guild.id ? Theme.Color.surfaceRaised : Theme.Color.surface)
                        }
                        .buttonStyle(.plain)
                        if idx < destGuilds.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1))
            }
        }
    }

    // MARK: Execute Section

    @ViewBuilder
    private var executeSection: some View {
        if !selectedDestGuildId.isEmpty {
            VStack(spacing: .spacing8) {
                AccentButton(
                    title: isExecuting ? "復旧実行中..." : "選択した \(selectedUserIds.count) 人を復旧"
                ) {
                    Task { await executeRecovery() }
                }
                .disabled(isExecuting || selectedUserIds.isEmpty)

                if selectedUserIds.isEmpty && !notInServer.isEmpty {
                    Text("復旧させるメンバーを選択してください")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }

                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.statusWarn)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: Jobs Section

    @ViewBuilder
    private var jobsSection: some View {
        if !jobs.isEmpty {
            VStack(alignment: .leading, spacing: .spacing12) {
                SectionLabel(title: "復旧履歴")
                    .padding(.horizontal, .spacing16)
                VStack(spacing: .spacing10) {
                    ForEach(jobs) { job in
                        RecoveryJobCard(job: job)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startSetup() async {
        isLoadingUsers = true
        phase = .setup
        eligibleUsers = (try? await services.disasterRecovery.fetchEligibleUsers(sourceGuildId: sourceGuild.id)) ?? []
        await loadJobs()
        isLoadingUsers = false
    }

    private func checkMembership() async {
        guard !selectedDestGuildId.isEmpty, !eligibleUsers.isEmpty else { return }
        isCheckingMembership = true
        let userIds = eligibleUsers.map { $0.userId }
        let memberIds = (try? await services.disasterRecovery.checkMembership(
            destGuildId: selectedDestGuildId, userIds: userIds
        )) ?? []
        alreadyInServer = Set(memberIds)
        selectedUserIds.subtract(alreadyInServer)
        isCheckingMembership = false
    }

    private func loadJobs() async {
        jobs = (try? await services.disasterRecovery.fetchJobs(sourceGuildId: sourceGuild.id)) ?? []
    }

    private func executeRecovery() async {
        guard !selectedDestGuildId.isEmpty else { return }
        isExecuting = true
        errorMessage = nil
        do {
            let job = try await services.disasterRecovery.executeRecovery(
                sourceGuildId: sourceGuild.id,
                destinationGuildId: selectedDestGuildId,
                selectedUserIds: Array(selectedUserIds)
            )
            toast = ToastMessage(type: .success, message: "復旧ジョブを開始しました。完了時にDMでお知らせします。")
            pollingJobId = job.id
            await loadJobs()
        } catch {
            errorMessage = "復旧の開始に失敗しました: \(error.localizedDescription)"
            toast = ToastMessage(type: .error, message: "復旧の開始に失敗しました")
        }
        isExecuting = false
    }

    private func pollJobStatus() async {
        guard let jobId = pollingJobId else { return }
        for _ in 0..<30 {
            try? await Task.sleep(for: .seconds(2))
            guard pollingJobId == jobId else { return }
            if let job = try? await services.disasterRecovery.fetchJobDetail(jobId: jobId) {
                await loadJobs()
                if job.status == .completed || job.status == .failed {
                    pollingJobId = nil
                    return
                }
            }
        }
        pollingJobId = nil
    }
}

// MARK: - RecoveryJobCard

private struct RecoveryJobCard: View {
    let job: RecoveryJob

    var statusColor: Color {
        switch job.status {
        case .running:   Theme.Color.accent
        case .completed: Theme.Color.statusOK
        case .failed:    Theme.Color.statusBad
        }
    }

    var body: some View {
        HStack(spacing: .spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: job.status == .running ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("復旧ジョブ")
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("\(job.status.label) • 成功 \(job.successCount) / 失敗 \(job.failCount) / 合計 \(job.totalCount)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
                if let completed = job.completedAt {
                    Text("完了: \(completed, style: .date)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.line, lineWidth: 1))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServerRecoveryView()
            .environment(AppState())
            .environment(\.services, ServiceContainer.mock())
    }
}
