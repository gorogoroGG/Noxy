import SwiftUI

// MARK: - MembersListView

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

    enum StatusFilter: String, CaseIterable {
        case all      = "すべて"
        case online   = "オンライン"
        case boosting = "ブースター"

        var icon: String {
            switch self { case .all: "person.3.fill"; case .online: "circle.fill"; case .boosting: "bolt.fill" }
        }
        var color: Color {
            switch self { case .all: .accentIndigo; case .online: .accentGreen; case .boosting: .accentPink }
        }
    }

    enum SortOrder: String, CaseIterable {
        case name   = "名前順"
        case joined = "参加日順"
    }

    private var filtered: [Member] {
        var base = members
        if !searchText.isEmpty {
            base = base.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.username.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch selectedStatus {
        case .online:   base = base.filter { $0.status == .online || $0.status == .idle || $0.status == .dnd }
        case .boosting: base = base.filter { $0.isBoosting }
        case .all:      break
        }
        if let roleName = selectedRoleName {
            base = base.filter { $0.roles.contains(roleName) }
        }
        switch sortOrder {
        case .name:   return base.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        case .joined: return base.sorted { $0.joinedAt > $1.joinedAt }
        }
    }

    private var onlineCount: Int { members.filter { $0.status == .online || $0.status == .idle || $0.status == .dnd }.count }
    private var selectableRoles: [DiscordRole] { roles.filter { $0.name != "@everyone" && !$0.managed } }

    var body: some View {
        VStack(spacing: 0) {
            memberStats

            if let error = errorMessage { errorBanner(error) }

            // ── ステータスフィルター ──
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacing8) {
                    ForEach(StatusFilter.allCases, id: \.self) { f in
                        FilterChip(label: f.rawValue, icon: f.icon, color: f.color, isSelected: selectedStatus == f) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedStatus = f }
                        }
                    }
                    Divider().frame(height: 20).padding(.horizontal, 4)
                    // ── ロールフィルター ──
                    if selectedRoleName != nil {
                        FilterChip(label: selectedRoleName!, icon: "tag.fill", color: .accentPurple, isSelected: true) {
                            withAnimation { selectedRoleName = nil }
                        }
                    }
                    Menu {
                        Button("ロールで絞り込まない") { withAnimation { selectedRoleName = nil } }
                        Divider()
                        ForEach(selectableRoles, id: \.id) { role in
                            Button(role.name) { withAnimation { selectedRoleName = role.name } }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "tag").font(.system(size: 11, weight: .semibold))
                            Text("ロール").font(.captionRegular).fontWeight(.medium)
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .foregroundStyle(Color.accentPurple)
                        .padding(.horizontal, .spacing12).padding(.vertical, 7)
                        .background(Color.accentPurple.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.accentPurple.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(Divider(), alignment: .bottom)

            // ── リスト ──
            if isLoading {
                Spacer()
                VStack(spacing: .spacing12) {
                    ProgressView()
                    Text("メンバーを読み込み中...").font(.bodySmall).foregroundStyle(Color.textTertiary)
                }
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                EmptyStateView(icon: "person.slash", title: "メンバーが見つかりません",
                               description: "条件に一致するメンバーがいません", actionTitle: nil) {}
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: .spacing8) {
                        Text("\(filtered.count)人を表示").font(.captionSmall).foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, .spacing16).padding(.top, .spacing8)
                        ForEach(filtered) { member in
                            MemberCard(member: member)
                                .onTapGesture { selectedMember = member }
                                .padding(.horizontal, .spacing16)
                        }
                        Color.clear.frame(height: 80)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "名前・ユーザー名で検索")
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
                    Image(systemName: "ellipsis.circle").font(.system(size: 18)).foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member, guildId: guildId, allRoles: selectableRoles,
                onAction: { handleAction($0, member: member) })
        }
        .task { await load() }
    }

    private var memberStats: some View {
        HStack(spacing: 0) {
            statCell(value: "\(members.count)", label: "総メンバー", color: .accentIndigo)
            Divider().frame(height: 32)
            statCell(value: "\(onlineCount)", label: "オンライン", color: .accentGreen)
            Divider().frame(height: 32)
            statCell(value: "\(members.filter(\.isBoosting).count)", label: "ブースター", color: .accentPink)
        }
        .padding(.vertical, .spacing12)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.captionSmall).foregroundStyle(Color.textTertiary)
        }.frame(maxWidth: .infinity)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(msg).font(.captionSmall).foregroundStyle(Color.textSecondary)
            Spacer()
            Button { errorMessage = nil } label: { Image(systemName: "xmark").font(.captionSmall).foregroundStyle(Color.textTertiary) }
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing8)
        .background(Color.accentOrange.opacity(0.1))
        .overlay(Divider(), alignment: .bottom)
    }

    private func handleAction(_ action: MemberAction, member: Member) {
        Task {
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
        do { members = try await mTask } catch { errorMessage = "メンバー取得失敗。BotのSERVER MEMBERS INTENTを確認してください。" }
        roles = (try? await rTask) ?? []
        isLoading = false
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

// MARK: - FilterChip

private struct FilterChip: View {
    let label: String; let icon: String; let color: Color; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.captionRegular).fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, .spacing12).padding(.vertical, 7)
            .background(isSelected ? color : color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - MemberCard

private struct MemberCard: View {
    let member: Member
    var body: some View {
        HStack(spacing: .spacing12) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(name: member.displayName, size: 48, accentColor: member.isBoosting ? .accentPink : .accentIndigo)
                Circle().fill(member.status.color).frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2)).offset(x: 2, y: 2)
            }.frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: .spacing6) {
                    Text(member.displayName).font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary).lineLimit(1)
                    if member.isBoosting { Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(Color.accentPink) }
                }
                Text("@\(member.username)").font(.captionSmall).foregroundStyle(Color.textTertiary).lineLimit(1)
                if !member.roles.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(member.roles.prefix(3), id: \.self) { role in
                            Text(role).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.accentIndigo)
                                .padding(.horizontal, 5).padding(.vertical, 2).background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
                        }
                        if member.roles.count > 3 { Text("+\(member.roles.count - 3)").font(.system(size: 9)).foregroundStyle(Color.textTertiary) }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(member.status.label).font(.system(size: 10, weight: .medium)).foregroundStyle(member.status.color)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.spacing12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }
}

// MARK: - MemberDetailView

struct MemberDetailView: View {
    let member: Member
    let guildId: String
    let allRoles: [DiscordRole]
    let onAction: (MemberAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDMSheet = false
    @State private var showRoleSheet = false
    @State private var showTimeoutSheet = false
    @State private var showKickSheet = false
    @State private var showBanSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    VStack(spacing: .spacing12) {
                        infoCard
                        rolesCard
                        communicationCard
                        actionsCard
                    }
                    .padding(.horizontal, .spacing16).padding(.vertical, .spacing16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .sheet(isPresented: $showDMSheet) {
            SendDMSheet(member: member) { msg in onAction(.sendDM(message: msg)); dismiss() }
        }
        .sheet(isPresented: $showRoleSheet) {
            RoleManagerSheet(member: member, guildId: guildId, allRoles: allRoles)
        }
        .sheet(isPresented: $showTimeoutSheet) {
            TimeoutActionSheet(member: member) { until, dm in onAction(.timeout(until: until, dmMessage: dm)); dismiss() }
        }
        .sheet(isPresented: $showKickSheet) {
            KickActionSheet(member: member) { dm in onAction(.kick(dmMessage: dm)); dismiss() }
        }
        .sheet(isPresented: $showBanSheet) {
            BanActionSheet(member: member) { dm in onAction(.ban(dmMessage: dm)); dismiss() }
        }
    }

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [member.isBoosting ? Color.accentPink.opacity(0.5) : Color.accentIndigo.opacity(0.5), Color(.systemGroupedBackground)], startPoint: .top, endPoint: .bottom).frame(height: 200)
            VStack(spacing: .spacing12) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(name: member.displayName, size: 84, accentColor: member.isBoosting ? .accentPink : .accentIndigo)
                        .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 4))
                    Circle().fill(member.status.color).frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 3)).offset(x: 2, y: 2)
                }
                VStack(spacing: 5) {
                    HStack(spacing: .spacing8) {
                        Text(member.displayName).font(.displayMedium).foregroundStyle(Color.textPrimary)
                        if member.isBoosting { Image(systemName: "bolt.fill").foregroundStyle(Color.accentPink) }
                    }
                    Text("@\(member.username)").font(.bodySmall).foregroundStyle(Color.textSecondary)
                    HStack(spacing: 5) {
                        Circle().fill(member.status.color).frame(width: 8, height: 8)
                        Text(member.status.label).font(.captionSmall).fontWeight(.medium).foregroundStyle(member.status.color)
                    }.padding(.horizontal, 10).padding(.vertical, 4).background(member.status.color.opacity(0.12)).clipShape(Capsule())
                }
            }.padding(.bottom, .spacing24)
        }
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            cardHeader("情報", icon: "info.circle.fill", color: .accentIndigo)
            Divider()
            infoRow("参加日", value: member.joinedAt.formatted(date: .long, time: .omitted))
            Divider().padding(.leading, .spacing16)
            infoRow("ブースト", value: member.isBoosting ? "ブースト中 ⚡️" : "なし")
            Divider().padding(.leading, .spacing16)
            infoRow("ロール数", value: "\(member.roles.count)個")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var rolesCard: some View {
        VStack(spacing: 0) {
            HStack {
                cardHeader("ロール (\(member.roles.count))", icon: "tag.fill", color: .accentPurple)
                Spacer()
                Button {
                    showRoleSheet = true
                } label: {
                    Label("管理", systemImage: "pencil")
                        .font(.captionSmall).fontWeight(.medium).foregroundStyle(Color.accentPurple)
                }
                .padding(.trailing, .spacing16)
            }
            Divider()
            if member.roles.isEmpty {
                Text("ロールなし").font(.bodySmall).foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.spacing16)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(member.roles, id: \.self) { role in
                        HStack(spacing: 5) {
                            Circle().fill(Color.accentIndigo).frame(width: 7, height: 7)
                            Text("@\(role)").font(.captionRegular).fontWeight(.medium).foregroundStyle(Color.accentIndigo)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
                    }
                }.padding(.spacing12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var communicationCard: some View {
        VStack(spacing: 0) {
            cardHeader("コミュニケーション", icon: "message.fill", color: .accentGreen)
            Divider()
            actionButton(icon: "envelope.fill", label: "DMを送信", description: "ユーザーにダイレクトメッセージを送る", color: .accentGreen) {
                showDMSheet = true
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            cardHeader("モデレーション", icon: "shield.fill", color: .accentOrange)
            Divider()
            actionButton(icon: "clock.badge.exclamationmark.fill", label: "タイムアウト", description: "一時的にメッセージ送信を禁止する", color: .accentOrange) { showTimeoutSheet = true }
            Divider().padding(.leading, 52)
            actionButton(icon: "figure.walk", label: "キック", description: "サーバーから退出させる（再参加可）", color: .accentOrange) { showKickSheet = true }
            Divider().padding(.leading, 52)
            actionButton(icon: "hammer.fill", label: "BAN", description: "永続的にサーバーへのアクセスを禁止する", color: .red, isDestructive: true) { showBanSheet = true }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func cardHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: icon).font(.captionRegular).foregroundStyle(color)
            Text(title).font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textTertiary).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.bodySmall).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value).font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.textPrimary)
        }.padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
    }

    private func actionButton(icon: String, label: String, description: String, color: Color, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: .spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.bodySmall).fontWeight(.medium).foregroundStyle(isDestructive ? Color.red : Color.textPrimary)
                    Text(description).font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, .spacing16).padding(.vertical, .spacing12).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: - 変数定義

/// 利用可能な変数（DM文面のチップに表示）
private let memberVariables = ["{user.name}", "{user.username}", "{user.mention}", "{server.name}"]

/// 変数の説明（ユーザー向け）
private let memberVariableHelp: [(String, String)] = [
    ("{user.name}", "表示名"),
    ("{user.username}", "@ユーザー名"),
    ("{user.mention}", "メンション通知"),
    ("{server.name}", "サーバー名"),
    ("{duration}", "タイムアウト期間"),
]

/// DM送信用に変数を実際の値へ置換する
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
                chunk.foregroundColor = UIColor(.accentIndigo)
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
    let onSend: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing20) {
                    // ユーザー情報
                    HStack(spacing: .spacing12) {
                        Avatar(name: member.displayName, size: 44, accentColor: .accentIndigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName).font(.bodySmall).fontWeight(.semibold)
                            Text("@\(member.username)").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "lock.fill").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        Text("DM").font(.captionSmall).foregroundStyle(Color.textTertiary)
                    }
                    .padding(.spacing16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // メッセージ入力
                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("メッセージ").font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textTertiary).textCase(.uppercase)
                        ZStack(alignment: .topLeading) {
                            if message.isEmpty {
                                Text("メッセージを入力...").foregroundStyle(Color.textTertiary).font(.bodySmall)
                                    .padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
                            }
                            TextEditor(text: $message)
                                .font(.bodySmall).frame(minHeight: 100).scrollContentBackground(.hidden)
                        }
                        .padding(.spacing12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        variableRow
                    }

                    // プレビュー
                    if !message.isEmpty {
                        VStack(alignment: .leading, spacing: .spacing8) {
                            Text("プレビュー").font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textTertiary).textCase(.uppercase)
                            dmBubble(text: substitutePreview(message, member: member))
                        }
                    }

                    // 送信ボタン
                    Button {
                        isSending = true
                        onSend(substituteVariables(message, member: member))
                    } label: {
                        Label(isSending ? "送信中..." : "DMを送信", systemImage: "paperplane.fill")
                            .font(.bodySmall).fontWeight(.semibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(message.isEmpty ? Color(.systemGray4) : Color.accentIndigo)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(message.isEmpty || isSending)
                }
                .padding(.spacing16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DMを送信").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary) } }
        }
    }

    private var variableRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing6) {
                Text("変数:").font(.captionSmall).foregroundStyle(Color.textTertiary)
                ForEach(memberVariables, id: \.self) { v in
                    Button { message += v } label: {
                        Text(v).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentIndigo)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentIndigo.opacity(0.1)).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func dmBubble(text: AttributedString) -> some View {
        HStack(alignment: .bottom, spacing: .spacing8) {
            Avatar(name: "Noxy", size: 28, accentColor: .accentIndigo)
            VStack(alignment: .leading, spacing: 3) {
                Text("Noxy BOT").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.textTertiary)
                Text(text).font(.bodySmall).foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, .spacing12).padding(.vertical, .spacing8)
                    .background(Color(.secondarySystemGroupedBackground))
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
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var assignedRoleNames: Set<String>
    @State private var working: Set<String> = []
    @State private var errorMessage: String? = nil

    init(member: Member, guildId: String, allRoles: [DiscordRole]) {
        self.member = member
        self.guildId = guildId
        self.allRoles = allRoles
        _assignedRoleNames = State(initialValue: Set(member.roles))
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Section {
                        HStack(spacing: .spacing8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(errorMessage).font(.captionRegular).foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                Section {
                    ForEach(allRoles, id: \.id) { role in
                        let has = assignedRoleNames.contains(role.name)
                        let busy = working.contains(role.id)
                        Button {
                            Task { await toggle(role) }
                        } label: {
                            HStack(spacing: .spacing12) {
                                Circle()
                                    .fill(role.color == 0 ? Color(.systemGray3) : Color(uiColor: UIColor(hex: UInt32(bitPattern: Int32(role.color)))))
                                    .frame(width: 12, height: 12)
                                Text("@\(role.name)").font(.bodySmall).foregroundStyle(Color.textPrimary)
                                Spacer()
                                if busy {
                                    ProgressView().scaleEffect(0.7)
                                } else if has {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentIndigo)
                                } else {
                                    Image(systemName: "plus.circle").foregroundStyle(Color.accentGreen)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                    }
                } header: {
                    Text("\(member.displayName) のロール管理")
                } footer: {
                    Text("✅ = 付与済み（タップで剥奪）　＋ = 未付与（タップで付与）")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ロール管理").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private func toggle(_ role: DiscordRole) async {
        guard !working.contains(role.id) else { return }
        working.insert(role.id)
        errorMessage = nil
        defer { working.remove(role.id) }
        do {
            if assignedRoleNames.contains(role.name) {
                try await services.members.removeRole(memberId: member.id, guildId: guildId, roleId: role.id)
                assignedRoleNames.remove(role.name)
            } else {
                try await services.members.addRole(memberId: member.id, guildId: guildId, roleId: role.id)
                assignedRoleNames.insert(role.name)
            }
        } catch {
            errorMessage = "ロールの変更に失敗しました。Botのロールが対象ロールより上位か確認してください。"
        }
    }
}

// MARK: - TimeoutActionSheet

private struct TimeoutActionSheet: View {
    let member: Member
    let onConfirm: (Date, String?) -> Void
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
            color: .accentOrange,
            warningText: "指定期間中、メッセージの送信・リアクションができなくなります。",
            sendDM: $sendDM,
            dmText: $dmText,
            confirmLabel: "タイムアウトする",
            isDestructive: false,
            variables: memberVariables + ["{duration}"],
            previewDuration: durationLabel,
            additionalContent: {
                VStack(alignment: .leading, spacing: .spacing8) {
                    Text("タイムアウト期間").font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textTertiary).textCase(.uppercase)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: .spacing8) {
                            ForEach(durations, id: \.0) { label, seconds in
                                Button {
                                    selectedDuration = seconds
                                } label: {
                                    Text(label).font(.captionRegular).fontWeight(.medium)
                                        .foregroundStyle(selectedDuration == seconds ? .white : Color.accentOrange)
                                        .padding(.horizontal, .spacing12).padding(.vertical, 8)
                                        .background(selectedDuration == seconds ? Color.accentOrange : Color.accentOrange.opacity(0.1))
                                        .clipShape(Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            },
            onConfirm: {
                let until = Date().addingTimeInterval(selectedDuration)
                let dm = sendDM ? dmText.replacingOccurrences(of: "{duration}", with: durationLabel) : nil
                onConfirm(until, dm)
            }
        )
    }

    private var durationLabel: String { durations.first(where: { $0.1 == selectedDuration })?.0 ?? "" }
}

// MARK: - KickActionSheet

private struct KickActionSheet: View {
    let member: Member
    let onConfirm: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sendDM = true
    @State private var dmText = """
    {user.name}さん

    {server.name} の運営です。ルール違反が確認されたため、サーバーからの退出（キック）措置を行いました。

    再参加は可能です。ルールをご確認のうえ、改めてのご参加をお待ちしています。ご不明な点があれば運営までお問い合わせください。
    """

    var body: some View {
        ModActionSheet(
            member: member, title: "キック", icon: "figure.walk", color: .accentOrange,
            warningText: "メンバーはサーバーから退出しますが、再参加することができます。",
            sendDM: $sendDM, dmText: $dmText,
            confirmLabel: "キックする", isDestructive: false,
            additionalContent: { EmptyView() },
            onConfirm: { onConfirm(sendDM ? dmText : nil) }
        )
    }
}

// MARK: - BanActionSheet

private struct BanActionSheet: View {
    let member: Member
    let onConfirm: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sendDM = true
    @State private var dmText = """
    {user.name}さん

    {server.name} の運営です。重大なルール違反が確認されたため、サーバーへのアクセスを禁止（BAN）する措置を行いました。

    この措置についてご不明な点や異議がある場合は、サーバー管理者までお問い合わせください。
    """

    var body: some View {
        ModActionSheet(
            member: member, title: "BAN", icon: "hammer.fill", color: .red,
            warningText: "⚠️ BANされたメンバーはサーバーに参加できなくなります。この操作は慎重に行ってください。",
            sendDM: $sendDM, dmText: $dmText,
            confirmLabel: "BANする", isDestructive: true,
            additionalContent: { EmptyView() },
            onConfirm: { onConfirm(sendDM ? dmText : nil) }
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
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing20) {
                    // ── ターゲットユーザー ──
                    HStack(spacing: .spacing12) {
                        ZStack {
                            Avatar(name: member.displayName, size: 52, accentColor: color)
                                .overlay(Circle().strokeBorder(color.opacity(0.3), lineWidth: 2))
                            ZStack {
                                Circle().fill(color).frame(width: 20, height: 20)
                                Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            }.offset(x: 18, y: 18)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.displayName).font(.bodySmall).fontWeight(.bold)
                            Text("@\(member.username)").font(.captionSmall).foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.spacing16)
                    .background(color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // ── 警告文 ──
                    HStack(spacing: .spacing10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(color)
                        Text(warningText).font(.captionRegular).foregroundStyle(Color.textSecondary)
                    }
                    .padding(.spacing12)
                    .background(color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // ── 追加コンテンツ（タイムアウトの期間選択など） ──
                    additionalContent

                    // ── DM設定 ──
                    VStack(spacing: 0) {
                        HStack {
                            Toggle("アクション前にDMを送信", isOn: $sendDM.animation()).tint(Color.accentIndigo).font(.bodySmall)
                        }
                        .padding(.spacing16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        if sendDM {
                            VStack(alignment: .leading, spacing: .spacing10) {
                                Text("DMメッセージ").font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textTertiary).textCase(.uppercase)
                                ZStack(alignment: .topLeading) {
                                    if dmText.isEmpty {
                                        Text("メッセージを入力...").foregroundStyle(Color.textTertiary).font(.bodySmall)
                                            .padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
                                    }
                                    TextEditor(text: $dmText).font(.bodySmall).frame(minHeight: 80).scrollContentBackground(.hidden).tint(color)
                                }
                                .padding(.spacing12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                // 変数チップ
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: .spacing6) {
                                        Text("変数:").font(.captionSmall).foregroundStyle(Color.textTertiary)
                                        ForEach(variables, id: \.self) { v in
                                            Button { dmText += v } label: {
                                                Text(v).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                                    .background(color.opacity(0.1)).clipShape(Capsule())
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }

                                // DM プレビュー
                                if !dmText.isEmpty {
                                    VStack(alignment: .leading, spacing: .spacing6) {
                                        Text("プレビュー").font(.captionSmall).foregroundStyle(Color.textTertiary)
                                        HStack(alignment: .top, spacing: .spacing8) {
                                            Avatar(name: "Noxy", size: 28, accentColor: color)
                                            Text(substitutePreview(dmText, member: member, duration: previewDuration))
                                                .font(.captionRegular).foregroundStyle(Color.textPrimary)
                                                .padding(.horizontal, .spacing10).padding(.vertical, .spacing8)
                                                .background(Color(.secondarySystemGroupedBackground))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                    .padding(.spacing12)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // ── 実行ボタン ──
                    Button(action: onConfirm) {
                        HStack(spacing: .spacing8) {
                            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                            Text(confirmLabel).font(.bodySmall).fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(isDestructive ? Color.red : color)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button("キャンセル") { dismiss() }
                        .font(.bodySmall).foregroundStyle(Color.textSecondary)
                }
                .padding(.spacing16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() }.foregroundStyle(Color.textSecondary) } }
        }
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let w = proposal.width ?? 300; var h: CGFloat = 0; var x: CGFloat = 0; var rh: CGFloat = 0
        for v in subviews { let s = v.sizeThatFits(.unspecified); if x + s.width > w && x > 0 { h += rh + spacing; x = 0; rh = 0 }; x += s.width + spacing; rh = max(rh, s.height) }
        return CGSize(width: w, height: h + rh)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = b.minX; var y = b.minY; var rh: CGFloat = 0
        for v in subviews { let s = v.sizeThatFits(.unspecified); if x + s.width > b.maxX && x > b.minX { y += rh + spacing; x = b.minX; rh = 0 }; v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s)); x += s.width + spacing; rh = max(rh, s.height) }
    }
}

// MARK: - MemberStatus 拡張

extension MemberStatus {
    var color: Color { switch self { case .online: .accentGreen; case .idle: .accentOrange; case .dnd: .red; case .offline: Color(.systemGray3) } }
    var label: String { switch self { case .online: "オンライン"; case .idle: "退席中"; case .dnd: "取込中"; case .offline: "オフライン" } }
}

#Preview {
    NavigationStack {
        MembersListView(guildId: "g001").navigationTitle("メンバー")
    }
    .environment(\.services, ServiceContainer.live())
    .environment(AppState())
    .preferredColorScheme(.dark)
}
