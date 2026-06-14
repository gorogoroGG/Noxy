import SwiftUI

// MARK: - MembersListView
// Noxy Design Language に厳密に従った再設計。

struct MembersListView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var members: [Member] = []
    @State private var roles: [DiscordRole] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var searchText = ""
    @State private var selectedStatus: StatusFilter = .all
    @State private var selectedRoleName: String? = nil
    @State private var selectedMember: Member? = nil
    @State private var sortOrder: SortOrder = .name
    @State private var verifyPanel: VerifyPanel? = nil

    enum StatusFilter: String, CaseIterable {
        case all        = "すべて"
        case staff      = "スタッフ"
        case unverified = "未認証"
        case timeout    = "タイムアウト中"
        case bot        = "Bot"
    }

    enum SortOrder: String, CaseIterable {
        case name   = "名前順"
        case joined = "参加日順"
    }

    // MARK: Computed helpers

    private var selectableRoles: [DiscordRole] { roles.filter { $0.name != "@everyone" && !$0.managed } }

    private var availableFilters: [StatusFilter] {
        var filters: [StatusFilter] = [.all, .staff, .timeout, .bot]
        if let panel = verifyPanel, panel.enabled, !panel.roleId.isEmpty {
            filters.append(.unverified)
        }
        return filters
    }

    private func isStaff(_ m: Member) -> Bool {
        let keywords = ["mod", "admin", "owner", "staff", "モデレーター", "管理者", "スタッフ"]
        return m.roles.contains { r in keywords.contains { r.lowercased().contains($0) } }
    }

    private func isUnverified(_ m: Member) -> Bool {
        guard let panel = verifyPanel, panel.enabled, !panel.roleId.isEmpty else { return false }
        let verifyRoleName = roles.first { $0.id == panel.roleId }?.name
        guard let roleName = verifyRoleName else { return true }
        return !m.roles.contains(roleName)
    }

    private var todayMembers: [Member] {
        members.filter { Calendar.current.isDateInToday($0.joinedAt) }
              .sorted { $0.joinedAt > $1.joinedAt }
    }
    private var staffMembers: [Member] {
        members.filter { isStaff($0) && !Calendar.current.isDateInToday($0.joinedAt) }
    }
    private var unverifiedMembers: [Member] { members.filter { isUnverified($0) } }
    private var timedOutMembers: [Member] {
        members.filter {
            guard let u = $0.communicationDisabledUntil else { return false }
            return u > Date.now
        }
    }
    private var todayJoinedCount: Int { todayMembers.count }
    private var unverifiedCount: Int { unverifiedMembers.count }

    private var filtered: [Member] {
        var base: [Member]
        switch selectedStatus {
        case .all:        base = members
        case .staff:      base = members.filter { isStaff($0) }
        case .unverified: base = unverifiedMembers
        case .timeout:    base = timedOutMembers
        case .bot:        base = members.filter { $0.isBot }
        }
        if !searchText.isEmpty {
            base = base.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.username.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .name:   return base.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        case .joined: return base.sorted { $0.joinedAt > $1.joinedAt }
        }
    }

    // Sections for .all filter: 本日参加 / スタッフ / others
    private var memberSections: [(title: String, hint: String?, items: [Member])] {
        guard selectedStatus == .all && searchText.isEmpty else { return [] }
        var result: [(String, String?, [Member])] = []
        if !todayMembers.isEmpty { result.append(("本日参加", "長押しで操作", todayMembers)) }
        if !staffMembers.isEmpty { result.append(("スタッフ", nil, staffMembers)) }
        let usedIds = Set(todayMembers.map(\.id)).union(staffMembers.map(\.id))
        let others = members.filter { !usedIds.contains($0.id) }.sorted { $0.displayName < $1.displayName }
        if !others.isEmpty { result.append(("メンバー", nil, others)) }
        return result
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if let error = errorMessage { errorBanner(error) }

            // ── メンバー統計 ──
            memberStatsCard
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xs)

            // ── フィルターチップ ──
            filterChips
                .padding(.vertical, Theme.Spacing.xs)

            Divider().background(Theme.Color.line)

            // ── リスト ──
            if isLoading {
                loadingView
            } else if filtered.isEmpty && memberSections.isEmpty {
                emptyView
            } else {
                memberList
            }
        }
        .background(Theme.Color.bg)
        .searchable(text: $searchText, prompt: "名前・IDで検索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("並び順", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Button { Task { await load() } } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member, guildId: guildId, allRoles: selectableRoles,
                onAction: { await handleAction($0, member: member) })
        }
        .navigationTitle("メンバー")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
    }

    // MARK: - Stats Card

    private var memberStatsCard: some View {
        HStack(spacing: 0) {
            memberStatCell(
                value: "\(members.count)",
                label: "メンバー",
                color: Theme.Color.textPrimary
            )
            Divider().frame(height: 36).background(Theme.Color.line)
            memberStatCell(
                value: todayJoinedCount > 0 ? "+\(todayJoinedCount)" : "0",
                label: "今日参加",
                color: todayJoinedCount > 0 ? Theme.Color.statusOK : Theme.Color.textTertiary
            )
            Divider().frame(height: 36).background(Theme.Color.line)
            memberStatCell(
                value: "\(unverifiedCount)",
                label: "未認証",
                color: unverifiedCount > 0 ? Theme.Color.statusWarn : Theme.Color.textTertiary
            )
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }

    private func memberStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            // 数値: IBM Plex Mono で等幅表現
            MonoText(value: value, font: Theme.Font.mono, color: color)
            Text(label.uppercased())
                .font(Theme.Font.sectionLabel)
                .tracking(Theme.sectionLabelTracking)
                .foregroundStyle(Theme.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Chips
    // Noxy Design Language §4: フィルタータグ
    // border: 1px solid var(--line2), border-radius: 9px, padding: 5px 11px
    // .on 時: background: var(--sur2), color: var(--t1), font-weight: 600

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(availableFilters, id: \.rawValue) { f in
                    let count = filterCount(f)
                    let isActive = selectedStatus == f
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedStatus = f }
                    } label: {
                        HStack(spacing: 4) {
                            Text(f.rawValue)
                                .font(isActive ? Theme.Font.caption : Theme.Font.caption2)
                                .foregroundStyle(isActive ? Theme.Color.textPrimary : Theme.Color.textSecondary)
                            if let n = count, n > 0 {
                                // 数値: IBM Plex Mono
                                MonoText(value: "\(n)", font: Theme.Font.monoCap, color: isActive ? Theme.Color.accent : Theme.Color.textTertiary)
                            }
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            isActive ? Theme.Color.surfaceRaised : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Theme.Color.lineStrong, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    // MARK: - Loading / Empty

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            ProgressView()
                .tint(Theme.Color.accent)
            Text("メンバーを読み込み中...")
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            Image(systemName: "person.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.Color.textTertiary)
            Text("メンバーが見つかりません")
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("条件に一致するメンバーがいません")
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
        }
    }

    // MARK: - Member List

    private var memberList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !memberSections.isEmpty {
                    ForEach(memberSections, id: \.title) { sec in
                        Section {
                            memberSectionCard(sec.items)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.bottom, Theme.Spacing.sm)
                        } header: {
                            SectionHeader(title: sec.title, actionTitle: sec.hint) {}
                                .padding(.horizontal, Theme.Spacing.md)
                        }
                    }
                } else {
                    memberSectionCard(filtered)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                Color.clear.frame(height: 80)
            }
        }
    }

    // MARK: - Section Card
    // Noxy Design Language §3.1 カード: border-radius: 14px, border: 1px solid var(--line), background: var(--sur)

    private func memberSectionCard(_ items: [Member]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, member in
                memberRow(member)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedMember = member }
                if idx < items.count - 1 {
                    Theme.Color.line.frame(height: 1)
                        .padding(.leading, 13 + 34 + 12) // アバター幅 + 間隔
                }
            }
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }

    // MARK: - Member Row
    // Noxy Design Language §3.3 リストアイテム: padding: 12px 13px
    // 隣接境界は border-top: 1px solid var(--line)
    // §6 情報密度: 時刻・ID・数値は font-size: 9.5px〜11px, IBM Plex Mono

    private func memberRow(_ member: Member) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Avatar + ステータスドット
            Avatar(
                imageUrl: member.avatarUrl,
                name: member.displayName,
                size: 34,
                status: member.status.toOnlineStatus,
                accentColor: member.isBoosting ? Theme.Color.statusOK : Theme.Color.accent
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)

                    if let role = member.roles.first {
                        let isOwnerRole = role.lowercased().contains("owner")
                        Text(role)
                            .font(Theme.Font.caption2)
                            .fontWeight(isOwnerRole ? .bold : .semibold)
                            .foregroundStyle(isOwnerRole ? Theme.Color.accent : Theme.Color.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isOwnerRole ? Theme.Color.accentDim : Theme.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(
                                        isOwnerRole ? Theme.Color.accent.opacity(0.4) : Theme.Color.lineStrong,
                                        lineWidth: 1
                                    )
                            )
                    }
                }

                Text("@\(member.username)")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // 右端: 参加時刻 + 認証状態
            VStack(alignment: .trailing, spacing: 2) {
                MonoText(
                    value: joinLabel(member.joinedAt),
font: Theme.Font.monoCap,
                    color: Theme.Color.textTertiary
                )

                Text(isUnverified(member) ? "未認証" : "認証済み")
                    .font(Theme.Font.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isUnverified(member) ? Theme.Color.statusWarn : Theme.Color.statusOK)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13))
    }

    private func joinLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.year(.twoDigits).month(.twoDigits))
    }

    private func filterCount(_ f: StatusFilter) -> Int? {
        switch f {
        case .all:        return nil
        case .staff:      return members.filter { isStaff($0) }.count
        case .unverified: return unverifiedCount > 0 ? unverifiedCount : nil
        case .timeout:    return timedOutMembers.count > 0 ? timedOutMembers.count : nil
        case .bot:        return members.filter { $0.isBot }.count > 0 ? members.filter { $0.isBot }.count : nil
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Color.statusWarn)
            Text(msg)
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
            Button { errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Color.statusWarn.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(Theme.Color.statusWarn)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Actions

    private func handleAction(_ action: MemberAction, member: Member) async {
        do {
            switch action {
            case .kick(let dm): try await executeMod(dm: dm, member: member) { try await services.members.kick(memberId: member.id, guildId: guildId, reason: nil) }; members.removeAll { $0.id == member.id }
            case .ban(let dm):  try await executeMod(dm: dm, member: member) { try await services.members.ban(memberId: member.id, guildId: guildId, reason: nil) };  members.removeAll { $0.id == member.id }
            case .timeout(let until, let dm): try await executeMod(dm: dm, member: member) { try await services.members.timeout(memberId: member.id, guildId: guildId, until: until) }
            case .sendDM(let msg): try await services.members.sendDM(memberId: member.id, message: msg)
            case .addRole(let roleId): try await services.members.addRole(memberId: member.id, guildId: guildId, roleId: roleId)
            case .removeRole(let roleId): try await services.members.removeRole(memberId: member.id, guildId: guildId, roleId: roleId)
            }
            selectedMember = nil
        } catch {
            errorMessage = "操作に失敗しました"
        }
    }

    private func executeMod(dm: String?, member: Member, action: () async throws -> Void) async throws {
        if let msg = dm, !msg.isEmpty {
            let text = substituteVariables(msg, member: member)
            try? await services.members.sendDM(memberId: member.id, message: text)
        }
        try await action()
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        async let mTask = services.members.fetchMembers(guildId: guildId)
        async let rTask = DiscordService().fetchRoles(guildId: guildId)
        async let vTask = services.verify.fetchPanels(guildId: guildId)
        do { members = try await mTask } catch { errorMessage = "メンバー取得失敗。BotのSERVER MEMBERS INTENTを確認してください。" }
        roles = (try? await rTask) ?? []
        let panels = (try? await vTask) ?? []
        verifyPanel = panels.first
        isLoading = false
    }
}

// MARK: - MemberStatus → OnlineStatus

private extension MemberStatus {
    var toOnlineStatus: OnlineStatus {
        switch self {
        case .online: return .online
        case .idle:   return .idle
        case .dnd:    return .dnd
        case .offline: return .offline
        }
    }
}

// MARK: - MemberAction

enum MemberAction {
    case kick(dmMessage: String?)
    case ban(dmMessage: String?)
    case timeout(until: Date, dmMessage: String?)
    case sendDM(message: String)
    case addRole(roleId: String)
    case removeRole(roleId: String)
}

// MARK: - MemberDetailView

struct MemberDetailView: View {
    let member: Member
    let guildId: String
    let allRoles: [DiscordRole]
    let onAction: (MemberAction) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var showDMSheet = false
    @State private var showRoleSheet = false
    @State private var showTimeoutSheet = false
    @State private var showKickSheet = false
    @State private var showBanSheet = false
    @State private var toast: ToastMessage? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    VStack(spacing: Theme.Spacing.sm) {
                        infoCard
                        rolesCard
                        communicationCard
                        actionsCard
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.accent)
                }
            }
            .toast($toast)
            .sheet(isPresented: $showDMSheet) {
                SendDMSheet(member: member, services: services) { msg in
                    await onAction(.sendDM(message: msg))
                    dismiss()
                }
            }
            .sheet(isPresented: $showRoleSheet) {
                RoleManagerSheet(member: member, guildId: guildId, allRoles: allRoles, services: services)
            }
            .sheet(isPresented: $showTimeoutSheet) {
                TimeoutActionSheet(member: member) { until, dm in
                    await onAction(.timeout(until: until, dmMessage: dm))
                    dismiss()
                }
            }
            .sheet(isPresented: $showKickSheet) {
                KickActionSheet(member: member) { dm in
                    await onAction(.kick(dmMessage: dm))
                    dismiss()
                }
            }
            .sheet(isPresented: $showBanSheet) {
                BanActionSheet(member: member) { dm in
                    await onAction(.ban(dmMessage: dm))
                    dismiss()
                }
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    member.isBoosting ? Theme.Color.statusOK.opacity(0.5) : Theme.Color.accent.opacity(0.5),
                    Theme.Color.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)

            VStack(spacing: Theme.Spacing.sm) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(
                        imageUrl: member.avatarUrl,
                        name: member.displayName,
                        size: 84,
                        status: member.status.toOnlineStatus,
                        accentColor: member.isBoosting ? Theme.Color.statusOK : Theme.Color.accent
                    )
                    .overlay(Circle().strokeBorder(Theme.Color.bg, lineWidth: 4))

                    Circle()
                        .fill(member.status.color)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(Theme.Color.bg, lineWidth: 3))
                        .offset(x: 2, y: 2)
                }

                VStack(spacing: 5) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(member.displayName)
                            .font(Theme.Font.title3)
                            .foregroundStyle(Theme.Color.textPrimary)

                        if member.isBoosting {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(Theme.Color.statusOK)
                        }
                    }

                    Text("@\(member.username)")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)

                    if member.discriminator != "0" {
                        Text("#\(member.discriminator)")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }

                    HStack(spacing: 5) {
                        StatusDot(color: member.status.color)
                        Text(member.status.label)
                            .font(Theme.Font.caption)
                            .foregroundStyle(member.status.color)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(member.status.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
            VStack(spacing: 0) {
                SectionLabel(title: "ユーザー情報")
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)

                Divider().background(Theme.Color.line)

                infoRow("ID", value: member.id)
                infoRow("ユーザー名", value: member.fullUsername)
                if let nick = member.nick, !nick.isEmpty {
                    infoRow("サーバーニックネーム", value: nick)
                }
                infoRow("アカウント作成日", value: member.createdAt.formatted(date: .long, time: .shortened))
                infoRow("サーバー参加日", value: member.joinedAt.formatted(date: .long, time: .shortened))
                infoRow("ブースト", value: member.isBoosting ? (member.boostSince != nil ? "ブースト中" : "ブースト中") : "なし")
                if member.isDeaf {
                    infoRow("音声", value: "スピーカーミュート")
                }
                if member.isMute {
                    infoRow("マイク", value: "ミュート")
                }
                if let until = member.communicationDisabledUntil {
                    infoRow("タイムアウト", value: "\(until.formatted(date: .abbreviated, time: .shortened)) まで")
                }
                infoRow("ロール数", value: "\(member.roles.count)個")
                infoRow("Bot", value: member.isBot ? "はい" : "いいえ")
            }
        }
    }

    // MARK: - Roles Card

    private var rolesCard: some View {
        Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
            VStack(spacing: 0) {
                HStack {
                    SectionLabel(title: "ロール (\(member.roles.count))")
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)

                    Spacer()

                    Button {
                        showRoleSheet = true
                    } label: {
                        Label("管理", systemImage: "pencil")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.accent)
                    }
                    .padding(.trailing, Theme.Spacing.md)
                }

                Divider().background(Theme.Color.line)

                if member.roles.isEmpty {
                    Text("ロールなし")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(member.roles, id: \.self) { role in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Theme.Color.accent)
                                    .frame(width: 7, height: 7)
                                Text("@\(role)")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.accent)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.Color.accentDim)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(Theme.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Communication Card

    private var communicationCard: some View {
        Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
            VStack(spacing: 0) {
                SectionLabel(title: "コミュニケーション")
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)

                Divider().background(Theme.Color.line)

                actionButton(
                    icon: "envelope.fill",
                    label: "DMを送信",
                    description: "ユーザーにダイレクトメッセージを送る",
                    color: Theme.Color.statusOK
                ) {
                    showDMSheet = true
                }
            }
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
            VStack(spacing: 0) {
                SectionLabel(title: "モデレーション")
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)

                Divider().background(Theme.Color.line)

                actionButton(
                    icon: "clock.badge.exclamationmark.fill",
                    label: "タイムアウト",
                    description: "一時的にメッセージ送信を禁止する",
                    color: Theme.Color.statusWarn
                ) { showTimeoutSheet = true }

                Divider()
                    .background(Theme.Color.line)
                    .padding(.leading, 52)

                actionButton(
                    icon: "figure.walk",
                    label: "キック",
                    description: "サーバーから退出させる（再参加可）",
                    color: Theme.Color.statusWarn
                ) { showKickSheet = true }

                Divider()
                    .background(Theme.Color.line)
                    .padding(.leading, 52)

                actionButton(
                    icon: "hammer.fill",
                    label: "BAN",
                    description: "永続的にサーバーへのアクセスを禁止する",
                    color: Theme.Color.statusBad,
                    isDestructive: true
                ) { showBanSheet = true }
            }
        }
    }

    // MARK: - Info Row
    // Noxy §5: 長押しで編集・詳細操作のトリガー（コピー）

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.Font.body)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Color.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .onLongPressGesture {
            UIPasteboard.general.string = value
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            toast = ToastMessage(type: .success, message: "\(label)をコピーしました")
        }
    }

    // MARK: - Action Button

    private func actionButton(
        icon: String,
        label: String,
        description: String,
        color: Color,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Theme.Font.body)
                        .fontWeight(.medium)
                        .foregroundStyle(isDestructive ? Theme.Color.statusBad : Theme.Color.textPrimary)
                    Text(description)
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Variables

private let memberVariables = ["{user.name}", "{user.username}", "{user.mention}", "{server.name}"]

private let memberVariableHelp: [(String, String)] = [
    ("{user.name}", "表示名"),
    ("{user.username}", "@ユーザー名"),
    ("{user.mention}", "メンション通知"),
    ("{server.name}", "サーバー名"),
    ("{duration}", "タイムアウト期間"),
]

private func substituteVariables(_ text: String, member: Member, serverName: String = "サーバー", duration: String? = nil) -> String {
    var result = text
        .replacingOccurrences(of: "{user.name}", with: member.displayName)
        .replacingOccurrences(of: "{user.username}", with: "@\(member.username)")
        .replacingOccurrences(of: "{user.mention}", with: "<@\(member.id)>")
        .replacingOccurrences(of: "{server.name}", with: serverName)
    if let duration { result = result.replacingOccurrences(of: "{duration}", with: duration) }
    return result
}

private func substitutePreview(_ text: String, member: Member, duration: String? = nil) -> AttributedString {
    var map: [(String, String)] = [
        ("{user.name}", member.displayName),
        ("{user.username}", "@\(member.username)"),
        ("{user.mention}", "@\(member.displayName)"),
        ("{server.name}", "サーバー名"),
    ]
    if let duration { map.append(("{duration}", duration)) }
    var result = AttributedString()
    var remaining = text
    while !remaining.isEmpty {
        var matched = false
        for (v, r) in map {
            if remaining.hasPrefix(v) {
                var chunk = AttributedString(r)
                chunk.foregroundColor = UIColor(Theme.Color.accent)
                chunk.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
                result.append(chunk)
                remaining = String(remaining.dropFirst(v.count))
                matched = true; break
            }
        }
        if !matched { result.append(AttributedString(String(remaining.removeFirst()))) }
    }
    return result
}

// MARK: - SendDMSheet

private struct SendDMSheet: View {
    let member: Member
    let services: ServiceContainer
    let onSend: (String) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // ユーザー情報
                    HStack(spacing: Theme.Spacing.sm) {
                        Avatar(
                            imageUrl: member.avatarUrl,
                            name: member.displayName,
                            size: 44,
                            accentColor: Theme.Color.accent
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                                .font(Theme.Font.bodyMedium)
                            Text("@\(member.username)")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                        Text("DM")
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .stroke(Theme.Color.line, lineWidth: 1)
                    )

                    // メッセージ入力
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        SectionLabel(title: "メッセージ")
                        ZStack(alignment: .topLeading) {
                            if message.isEmpty {
                                Text("メッセージを入力...")
                                    .foregroundStyle(Theme.Color.textTertiary)
                                    .font(Theme.Font.body)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $message)
                                .font(Theme.Font.body)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        variableRow
                    }

                    // プレビュー
                    if !message.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            SectionLabel(title: "プレビュー")
                            dmBubble(text: substitutePreview(message, member: member))
                        }
                    }

                    // エラー表示
                    if let errorMessage {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.Color.statusWarn)
                            Text(errorMessage)
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Color.statusWarn.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 送信ボタン
                    AccentButton(title: isSending ? "送信中..." : "DMを送信") {
                        isSending = true
                        errorMessage = nil
                        Task {
                            do {
                                let msg = substituteVariables(message, member: member)
                                try await services.members.sendDM(memberId: member.id, message: msg)
                                await onSend(msg)
                                dismiss()
                            } catch {
                                isSending = false
                                errorMessage = "DMの送信に失敗しました。BotがDM送信権限を持っているか確認してください。"
                            }
                        }
                    }
                    .disabled(message.isEmpty || isSending)
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.bg)
            .navigationTitle("DMを送信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
        }
    }

    private var variableRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                Text("変数:")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                ForEach(memberVariables, id: \.self) { v in
                    Button { message += v } label: {
                        Text(v)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Color.accentDim)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dmBubble(text: AttributedString) -> some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            Avatar(name: "Noxy", size: 28, accentColor: Theme.Color.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Noxy BOT")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                Text(text)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Spacer()
        }
    }
}

// MARK: - RoleManagerSheet

private struct RoleManagerSheet: View {
    let member: Member
    let guildId: String
    let allRoles: [DiscordRole]
    let services: ServiceContainer
    @Environment(\.dismiss) private var dismiss
    @State private var assignedRoleNames: Set<String>
    @State private var working: Set<String> = []
    @State private var errorMessage: String? = nil

    init(member: Member, guildId: String, allRoles: [DiscordRole], services: ServiceContainer) {
        self.member = member
        self.guildId = guildId
        self.allRoles = allRoles
        self.services = services
        _assignedRoleNames = State(initialValue: Set(member.roles))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let errorMessage {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.Color.statusWarn)
                            Text(errorMessage)
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .stroke(Theme.Color.line, lineWidth: 1)
                        )
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)
                    }

                    SectionLabel(title: "\(member.displayName) のロール管理")
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)

                    VStack(spacing: 0) {
                        ForEach(allRoles, id: \.id) { role in
                            let has = assignedRoleNames.contains(role.name)
                            let busy = working.contains(role.id)
                            Button {
                                Task { await toggle(role) }
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Circle()
                                        .fill(role.color == 0 ? Theme.Color.textTertiary : Color(uiColor: UIColor(hex: UInt32(bitPattern: Int32(role.color)))))
                                        .frame(width: 12, height: 12)
                                    Text("@\(role.name)")
                                        .font(Theme.Font.body)
                                        .foregroundStyle(Theme.Color.textPrimary)
                                    Spacer()
                                    if busy {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else if has {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.Color.accent)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(Theme.Color.statusOK)
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                            .disabled(busy)
                        }
                    }
                    .background(Theme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.Color.line, lineWidth: 1)
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)

                    Text("チェック = 付与済み（タップで剥奪）　＋ = 未付与（タップで付与）")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle("ロール管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .font(Theme.Font.bodyMedium)
                }
            }
        }
    }

    private func toggle(_ role: DiscordRole) async {
        guard !working.contains(role.id) else { return }
        working.insert(role.id)
        errorMessage = nil
        let had = assignedRoleNames.contains(role.name)
        defer { working.remove(role.id) }
        do {
            if had {
                try await services.members.removeRole(memberId: member.id, guildId: guildId, roleId: role.id)
                assignedRoleNames.remove(role.name)
            } else {
                try await services.members.addRole(memberId: member.id, guildId: guildId, roleId: role.id)
                assignedRoleNames.insert(role.name)
            }
        } catch {
            errorMessage = "ロールの変更に失敗しました。Botのロールが対象ロールより上位か確認してください。"
            if had {
                assignedRoleNames.insert(role.name)
            } else {
                assignedRoleNames.remove(role.name)
            }
        }
    }
}

// MARK: - TimeoutActionSheet

private struct TimeoutActionSheet: View {
    let member: Member
    let onConfirm: (Date, String?) async -> Void
    @Environment(\.dismiss) private var dismiss

    private let durations: [(String, TimeInterval)] = [
        ("60秒", 60), ("5分", 300), ("10分", 600), ("1時間", 3600),
        ("12時間", 43200), ("1日", 86400), ("1週間", 604800),
    ]
    @State private var selectedDuration: TimeInterval = 3600
    @State private var sendDM = true
    @State private var dmText = """
    {user.name}さん

    {server.name} の運営です。コミュニティのルールに違反する行為が確認されたため、{duration} のタイムアウト措置を行いました。

    期間中はメッセージの送信やリアクションができません。お手数ですが、今一度ルールのご確認をお願いいたします。心当たりがない場合は運営までご連絡ください。
    """

    var body: some View {
        ModActionSheet(
            member: member,
            title: "タイムアウト",
            icon: "clock.badge.exclamationmark.fill",
            color: Theme.Color.statusWarn,
            warningText: "指定期間中、メッセージの送信・リアクションができなくなります。",
            sendDM: $sendDM,
            dmText: $dmText,
            confirmLabel: "タイムアウトする",
            isDestructive: false,
            variables: memberVariables + ["{duration}"],
            previewDuration: durationLabel,
            additionalContent: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    SectionLabel(title: "タイムアウト期間")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.xs) {
                            ForEach(durations, id: \.0) { label, seconds in
                                Button {
                                    selectedDuration = seconds
                                } label: {
                                    Text(label)
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(selectedDuration == seconds ? Theme.Color.accentInk : Theme.Color.statusWarn)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, 8)
                                        .background(selectedDuration == seconds ? Theme.Color.statusWarn : Theme.Color.statusWarn.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            },
            onConfirm: {
                let until = Date().addingTimeInterval(selectedDuration)
                let dm = sendDM ? dmText.replacingOccurrences(of: "{duration}", with: durationLabel) : nil
                await onConfirm(until, dm)
            }
        )
    }

    private var durationLabel: String { durations.first(where: { $0.1 == selectedDuration })?.0 ?? "" }
}

// MARK: - KickActionSheet

private struct KickActionSheet: View {
    let member: Member
    let onConfirm: (String?) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sendDM = true
    @State private var dmText = """
    {user.name}さん

    {server.name} の運営です。ルール違反が確認されたため、サーバーからの退出（キック）措置を行いました。

    再参加は可能です。ルールをご確認のうえ、改めてのご参加をお待ちしています。ご不明な点があれば運営までお問い合わせください。
    """

    var body: some View {
        ModActionSheet(
            member: member, title: "キック", icon: "figure.walk", color: Theme.Color.statusWarn,
            warningText: "メンバーはサーバーから退出しますが、再参加することができます。",
            sendDM: $sendDM, dmText: $dmText,
            confirmLabel: "キックする", isDestructive: false,
            additionalContent: { EmptyView() },
            onConfirm: { await onConfirm(sendDM ? dmText : nil) }
        )
    }
}

// MARK: - BanActionSheet

private struct BanActionSheet: View {
    let member: Member
    let onConfirm: (String?) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sendDM = true
    @State private var dmText = """
    {user.name}さん

    {server.name} の運営です。重大なルール違反が確認されたため、サーバーへのアクセスを禁止（BAN）する措置を行いました。

    この措置についてご不明な点や異議がある場合は、サーバー管理者までお問い合わせください。
    """

    var body: some View {
        ModActionSheet(
            member: member, title: "BAN", icon: "hammer.fill", color: Theme.Color.statusBad,
            warningText: "BANされたメンバーはサーバーに参加できなくなります。この操作は慎重に行ってください。",
            sendDM: $sendDM, dmText: $dmText,
            confirmLabel: "BANする", isDestructive: true,
            additionalContent: { EmptyView() },
            onConfirm: { await onConfirm(sendDM ? dmText : nil) }
        )
    }
}

// MARK: - ModActionSheet（共通シート）

private struct ModActionSheet<Additional: View>: View {
    let member: Member
    let title: String
    let icon: String
    let color: Color
    let warningText: String
    @Binding var sendDM: Bool
    @Binding var dmText: String
    let confirmLabel: String
    let isDestructive: Bool
    var variables: [String] = memberVariables
    var previewDuration: String? = nil
    @ViewBuilder let additionalContent: Additional
    let onConfirm: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // ── ターゲットユーザー ──
                    HStack(spacing: Theme.Spacing.sm) {
                        ZStack {
                            Avatar(
                                imageUrl: member.avatarUrl,
                                name: member.displayName,
                                size: 52,
                                accentColor: color
                            )
                            .overlay(Circle().strokeBorder(color.opacity(0.3), lineWidth: 2))

                            ZStack {
                                Circle()
                                    .fill(color)
                                    .frame(width: 20, height: 20)
                                Image(systemName: icon)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.Color.accentInk)
                            }
                            .offset(x: 18, y: 18)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.displayName)
                                .font(Theme.Font.bodyMedium)
                            Text("@\(member.username)")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(Theme.Spacing.md)
                    .background(color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                    // ── 警告文 ──
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(color)
                        Text(warningText)
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // ── 追加コンテンツ（タイムアウトの期間選択など） ──
                    additionalContent

                    // ── DM設定 ──
                    VStack(spacing: 0) {
                        HStack {
                            Toggle("アクション前にDMを送信", isOn: $sendDM.animation())
                                .tint(Theme.Color.accent)
                                .font(Theme.Font.body)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                        if sendDM {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                SectionLabel(title: "DMメッセージ")
                                ZStack(alignment: .topLeading) {
                                    if dmText.isEmpty {
                                        Text("メッセージを入力...")
                                            .foregroundStyle(Theme.Color.textTertiary)
                                            .font(Theme.Font.body)
                                            .padding(.top, 8)
                                            .padding(.leading, 4)
                                            .allowsHitTesting(false)
                                    }
                                    TextEditor(text: $dmText)
                                        .font(Theme.Font.body)
                                        .frame(minHeight: 80)
                                        .scrollContentBackground(.hidden)
                                        .tint(color)
                                }
                                .padding(Theme.Spacing.sm)
                                .background(Theme.Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                // 変数チップ
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Text("変数:")
                                            .font(Theme.Font.caption2)
                                            .foregroundStyle(Theme.Color.textTertiary)
                                        ForEach(variables, id: \.self) { v in
                                            Button { dmText += v } label: {
                                                Text(v)
                                                    .font(Theme.Font.caption)
                                                    .foregroundStyle(color)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(color.opacity(0.1))
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // DM プレビュー
                                if !dmText.isEmpty {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                        SectionLabel(title: "プレビュー")
                                        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                            Avatar(name: "Noxy", size: 28, accentColor: color)
                                            Text(substitutePreview(dmText, member: member, duration: previewDuration))
                                                .font(Theme.Font.caption2)
                                                .foregroundStyle(Theme.Color.textPrimary)
                                                .padding(.horizontal, Theme.Spacing.sm)
                                                .padding(.vertical, Theme.Spacing.xs)
                                                .background(Theme.Color.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                    .padding(Theme.Spacing.sm)
                                    .background(Theme.Color.surfaceRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // ── 実行ボタン ──
                    Button {
                        showConfirm = true
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .semibold))
                            Text(confirmLabel)
                                .font(Theme.Font.bodyMedium)
                        }
                        .foregroundStyle(Theme.Color.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isDestructive ? Theme.Color.statusBad : color)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    }

                    Button("キャンセル") { dismiss() }
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .overlay {
                if showConfirm {
                    ConfirmModal(
                        icon: icon,
                        iconColor: isDestructive ? Theme.Color.statusBad : color,
                        title: "\(title)しますか？",
                        message: "\(member.displayName) に対して\(title)を実行します。",
                        primaryLabel: confirmLabel,
                        primaryRole: isDestructive ? .destructive : nil,
                        onPrimary: {
                            showConfirm = false
                            Task { await onConfirm() }
                        },
                        onCancel: {
                            showConfirm = false
                        }
                    )
                }
            }
        }
    }
}

// MARK: - MemberStatus 拡張

extension MemberStatus {
    var color: Color { switch self { case .online: Theme.Color.statusOK; case .idle: Theme.Color.statusWarn; case .dnd: Theme.Color.statusBad; case .offline: Theme.Color.textTertiary } }
    var label: String { switch self { case .online: "オンライン"; case .idle: "退席中"; case .dnd: "取込中"; case .offline: "オフライン" } }
}

#Preview {
    NavigationStack {
        MembersListView(guildId: "g001")
            .navigationTitle("メンバー")
    }
    .environment(\.services, ServiceContainer.live())
    .environment(AppState())
}
