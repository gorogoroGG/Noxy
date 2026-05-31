import SwiftUI

// MARK: - MembersListView

struct MembersListView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var members: [Member] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var searchText = ""
    @State private var selectedFilter: MemberFilter = .all
    @State private var selectedMember: Member? = nil
    @State private var sortOrder: SortOrder = .name

    enum MemberFilter: String, CaseIterable {
        case all      = "すべて"
        case online   = "オンライン"
        case boosting = "ブースター"
        case staff    = "スタッフ"

        var icon: String {
            switch self {
            case .all:      "person.3.fill"
            case .online:   "circle.fill"
            case .boosting: "bolt.fill"
            case .staff:    "shield.fill"
            }
        }
        var color: Color {
            switch self {
            case .all:      .accentIndigo
            case .online:   .accentGreen
            case .boosting: .accentPink
            case .staff:    .accentOrange
            }
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
        switch selectedFilter {
        case .online:   base = base.filter { $0.status == .online || $0.status == .idle || $0.status == .dnd }
        case .boosting: base = base.filter { $0.isBoosting }
        case .staff:    base = base.filter { $0.roles.contains(where: { ["Admin","Moderator","Staff","モデレーター","管理者"].contains($0) }) }
        case .all:      break
        }
        switch sortOrder {
        case .name:   return base.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        case .joined: return base.sorted { $0.joinedAt > $1.joinedAt }
        }
    }

    private var onlineCount: Int { members.filter { $0.status == .online || $0.status == .idle || $0.status == .dnd }.count }

    var body: some View {
        VStack(spacing: 0) {
            memberStats

            if let error = errorMessage {
                errorBanner(error)
            }

            filterBar

            if isLoading {
                Spacer()
                VStack(spacing: .spacing12) {
                    ProgressView()
                    Text("メンバーを読み込み中...")
                        .font(.bodySmall).foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "person.slash",
                    title: "メンバーが見つかりません",
                    description: searchText.isEmpty ? "条件に一致するメンバーがいません" : "「\(searchText)」に一致するメンバーがいません",
                    actionTitle: nil
                ) {}
                Spacer()
            } else {
                memberList
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "名前・ユーザー名で検索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("並び順", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    Button {
                        Task { await load() }
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(
                member: member,
                guildId: guildId,
                onAction: { action in
                    handleAction(action, member: member)
                }
            )
        }
        .task { await load() }
    }

    // MARK: - 統計バー

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
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.captionSmall)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Button { errorMessage = nil } label: {
                Image(systemName: "xmark").font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing8)
        .background(Color.accentOrange.opacity(0.1))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - フィルターバー

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                ForEach(MemberFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        icon: filter.icon,
                        color: filter.color,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedFilter = filter }
                    }
                }
            }
            .padding(.horizontal, .spacing16)
            .padding(.vertical, .spacing10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - メンバーリスト

    private var memberList: some View {
        ScrollView {
            LazyVStack(spacing: .spacing8) {
                Text("\(filtered.count)人を表示")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing8)

                ForEach(filtered) { member in
                    MemberCard(member: member)
                        .onTapGesture { selectedMember = member }
                        .padding(.horizontal, .spacing16)
                }

                Color.clear.frame(height: 80)
            }
        }
    }

    // MARK: - アクション処理

    private func handleAction(_ action: MemberAction, member: Member) {
        Task {
            do {
                switch action {
                case .kick:
                    try await services.members.kick(memberId: member.id, guildId: guildId, reason: nil)
                    members.removeAll { $0.id == member.id }
                case .ban:
                    try await services.members.ban(memberId: member.id, guildId: guildId, reason: nil)
                    members.removeAll { $0.id == member.id }
                case .timeout(let until):
                    try await services.members.timeout(memberId: member.id, guildId: guildId, until: until)
                }
                selectedMember = nil
            } catch {
                errorMessage = "操作に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            members = try await services.members.fetchMembers(guildId: guildId)
        } catch {
            errorMessage = "メンバーの取得に失敗しました。BotがサーバーにいてSERVER MEMBERS INTENTが有効か確認してください。"
        }
        isLoading = false
    }
}

// MARK: - MemberAction

enum MemberAction {
    case kick
    case ban
    case timeout(until: Date)
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MemberCard

private struct MemberCard: View {
    let member: Member

    var body: some View {
        HStack(spacing: .spacing12) {
            // アバター＋ステータスドット
            ZStack(alignment: .bottomTrailing) {
                Avatar(name: member.displayName, size: 48,
                       accentColor: member.isBoosting ? .accentPink : .accentIndigo)
                Circle()
                    .fill(member.status.color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
            .frame(width: 52, height: 52)

            // メイン情報
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: .spacing6) {
                    Text(member.displayName)
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary).lineLimit(1)
                    if member.isBoosting {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10)).foregroundStyle(Color.accentPink)
                    }
                }
                Text("@\(member.username)")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary).lineLimit(1)

                if !member.roles.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(member.roles.prefix(3), id: \.self) { role in
                            Text(role)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.accentIndigo)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.accentIndigo.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        if member.roles.count > 3 {
                            Text("+\(member.roles.count - 3)")
                                .font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            // 右端
            VStack(alignment: .trailing, spacing: 3) {
                Text(member.status.label)
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(member.status.color)
                Text(relativeDate(member.joinedAt))
                    .font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10)).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.spacing12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "今日参加" }
        if days < 30 { return "\(days)日前" }
        if days < 365 { return "\(days / 30)ヶ月前" }
        return "\(days / 365)年前"
    }
}

// MARK: - MemberDetailView

struct MemberDetailView: View {
    let member: Member
    let guildId: String
    let onAction: (MemberAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showKickConfirm = false
    @State private var showBanConfirm = false
    @State private var showTimeoutSheet = false
    @State private var isActioning = false
    @State private var actionError: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader

                    VStack(spacing: .spacing12) {
                        infoCard
                        rolesCard
                        actionsCard
                    }
                    .padding(.horizontal, .spacing16)
                    .padding(.vertical, .spacing16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.foregroundStyle(Color.accentIndigo)
                }
            }
            .alert("エラー", isPresented: .constant(actionError != nil)) {
                Button("OK") { actionError = nil }
            } message: {
                Text(actionError ?? "")
            }
            .confirmationDialog(
                "\(member.displayName) をキックしますか？",
                isPresented: $showKickConfirm, titleVisibility: .visible
            ) {
                Button("キックする", role: .destructive) { performAction(.kick) }
            } message: {
                Text("キックされたメンバーは再び参加できます。")
            }
            .confirmationDialog(
                "\(member.displayName) をBANしますか？",
                isPresented: $showBanConfirm, titleVisibility: .visible
            ) {
                Button("BANする", role: .destructive) { performAction(.ban) }
            } message: {
                Text("BANされたメンバーはサーバーに参加できなくなります。")
            }
            .sheet(isPresented: $showTimeoutSheet) {
                TimeoutSheet(memberName: member.displayName) { duration in
                    let until = Date().addingTimeInterval(duration)
                    performAction(.timeout(until: until))
                }
            }
        }
    }

    // MARK: - プロフィールヘッダー

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    member.isBoosting ? Color.accentPink.opacity(0.5) : Color.accentIndigo.opacity(0.5),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 200)

            VStack(spacing: .spacing12) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(name: member.displayName, size: 84,
                           accentColor: member.isBoosting ? .accentPink : .accentIndigo)
                        .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 4))
                    Circle()
                        .fill(member.status.color)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 3))
                        .offset(x: 2, y: 2)
                }

                VStack(spacing: 5) {
                    HStack(spacing: .spacing8) {
                        Text(member.displayName)
                            .font(.displayMedium).foregroundStyle(Color.textPrimary)
                        if member.isBoosting {
                            Image(systemName: "bolt.fill").foregroundStyle(Color.accentPink)
                        }
                    }
                    Text("@\(member.username)")
                        .font(.bodySmall).foregroundStyle(Color.textSecondary)
                    HStack(spacing: 5) {
                        Circle().fill(member.status.color).frame(width: 8, height: 8)
                        Text(member.status.label)
                            .font(.captionSmall).fontWeight(.medium).foregroundStyle(member.status.color)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(member.status.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.bottom, .spacing24)
        }
    }

    // MARK: - 情報カード

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

    // MARK: - ロールカード

    private var rolesCard: some View {
        VStack(spacing: 0) {
            cardHeader("ロール (\(member.roles.count))", icon: "tag.fill", color: .accentPurple)
            Divider()
            if member.roles.isEmpty {
                Text("ロールなし")
                    .font(.bodySmall).foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.spacing16)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(member.roles, id: \.self) { role in
                        HStack(spacing: 5) {
                            Circle().fill(Color.accentIndigo).frame(width: 7, height: 7)
                            Text("@\(role)").font(.captionRegular).fontWeight(.medium).foregroundStyle(Color.accentIndigo)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.accentIndigo.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.spacing12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - アクションカード

    private var actionsCard: some View {
        VStack(spacing: 0) {
            cardHeader("モデレーションアクション", icon: "shield.fill", color: .accentOrange)
            Divider()

            actionButton(
                icon: "clock.badge.exclamationmark.fill",
                label: "タイムアウト",
                description: "一時的にメッセージ送信を禁止",
                color: .accentOrange
            ) { showTimeoutSheet = true }

            Divider().padding(.leading, 52)

            actionButton(
                icon: "figure.walk",
                label: "キック",
                description: "サーバーから退出させる（再参加可）",
                color: .accentOrange
            ) { showKickConfirm = true }

            Divider().padding(.leading, 52)

            actionButton(
                icon: "hammer.fill",
                label: "BAN",
                description: "永続的にサーバーへのアクセスを禁止",
                color: .red,
                isDestructive: true
            ) { showBanConfirm = true }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(isActioning ? 0.6 : 1)
        .overlay {
            if isActioning {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGroupedBackground).opacity(0.5))
                ProgressView()
            }
        }
    }

    // MARK: - パーツ

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
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
    }

    private func actionButton(
        icon: String, label: String, description: String,
        color: Color, isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: .spacing12) {
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
                        .font(.bodySmall).fontWeight(.medium)
                        .foregroundStyle(isDestructive ? Color.red : Color.textPrimary)
                    Text(description)
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isActioning)
    }

    private func performAction(_ action: MemberAction) {
        isActioning = true
        onAction(action)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - TimeoutSheet

private struct TimeoutSheet: View {
    let memberName: String
    let onConfirm: (TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss

    private let options: [(String, TimeInterval)] = [
        ("60秒（テスト）", 60),
        ("1時間",         3600),
        ("12時間",        43200),
        ("1日",           86400),
        ("1週間",         604800),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(options, id: \.0) { label, duration in
                        Button {
                            onConfirm(duration)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(Color.accentOrange)
                                    .frame(width: 24)
                                Text(label)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.captionSmall)
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(memberName) のタイムアウト期間を選択")
                } footer: {
                    Text("タイムアウト中はメッセージの送信・反応ができなくなります。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("タイムアウト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0; var x: CGFloat = 0; var rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { height += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: height + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}

// MARK: - MemberStatus 拡張

extension MemberStatus {
    var color: Color {
        switch self {
        case .online:  .accentGreen
        case .idle:    .accentOrange
        case .dnd:     .red
        case .offline: Color(.systemGray3)
        }
    }
    var label: String {
        switch self {
        case .online:  "オンライン"
        case .idle:    "退席中"
        case .dnd:     "取込中"
        case .offline: "オフライン"
        }
    }
}

#Preview {
    NavigationStack {
        MembersListView(guildId: "g001")
            .navigationTitle("メンバー")
    }
    .environment(\.services, ServiceContainer.live())
    .environment(AppState())
    .preferredColorScheme(.dark)
}
