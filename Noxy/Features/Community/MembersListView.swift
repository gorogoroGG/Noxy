import SwiftUI

// MARK: - MembersListView

struct MembersListView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var members: [Member] = []
    @State private var isLoading = true
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
        case name     = "名前順"
        case joined   = "参加日順"
        case status   = "ステータス順"
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
        case .online:   base = base.filter { $0.status == .online }
        case .boosting: base = base.filter { $0.isBoosting }
        case .staff:    base = base.filter { $0.roles.contains(where: { ["Admin","Moderator","Staff","モデレーター","管理者"].contains($0) }) }
        case .all:      break
        }
        switch sortOrder {
        case .name:   return base.sorted { $0.displayName < $1.displayName }
        case .joined: return base.sorted { $0.joinedAt > $1.joinedAt }
        case .status: return base.sorted { $0.status.sortPriority < $1.status.sortPriority }
        }
    }

    private var onlineCount: Int { members.filter { $0.status == .online || $0.status == .idle || $0.status == .dnd }.count }

    var body: some View {
        VStack(spacing: 0) {
            // ── ヘッダー統計 ──
            memberStats

            // ── フィルター ──
            filterBar

            // ── リスト ──
            if isLoading {
                Spacer()
                ProgressView("メンバーを読み込み中...")
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
                            Label(order.rawValue, systemImage: sortIcon(order)).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member, guildId: guildId)
        }
        .task { await load() }
    }

    // MARK: - 統計バー

    private var memberStats: some View {
        HStack(spacing: 0) {
            statCell(value: "\(members.count)", label: "メンバー", color: .accentIndigo)
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
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
                Text("\(filtered.count)人を表示中")
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

                Spacer(minLength: 100)
            }
        }
    }

    private func sortIcon(_ order: SortOrder) -> String {
        switch order {
        case .name:   return "textformat.abc"
        case .joined: return "calendar"
        case .status: return "circle.fill"
        }
    }

    private func load() async {
        members = (try? await services.members.fetchMembers(guildId: guildId)) ?? []
        isLoading = false
    }
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
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.captionRegular).fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, .spacing12)
            .padding(.vertical, 7)
            .background(isSelected ? color : color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MemberCard

private struct MemberCard: View {
    let member: Member

    var body: some View {
        HStack(spacing: .spacing12) {
            // アバター
            ZStack(alignment: .bottomTrailing) {
                Avatar(name: member.displayName, size: 48,
                       accentColor: member.isBoosting ? .accentPink : .accentIndigo)
                    .overlay(
                        Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 2)
                            .frame(width: 54, height: 54)
                    )

                Circle()
                    .fill(member.status.color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
            .frame(width: 54, height: 54)

            // メイン情報
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: .spacing6) {
                    Text(member.displayName)
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if member.isBoosting {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentPink)
                    }
                }
                Text("@\(member.username)")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)

                // ロールバッジ（最大3つ）
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
                                .font(.system(size: 9))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            // 右端：参加日
            VStack(alignment: .trailing, spacing: 3) {
                Text(member.status.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(member.status.color)
                Text(relativeJoinDate(member.joinedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.spacing12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }

    private func relativeJoinDate(_ date: Date) -> String {
        let diff = Calendar.current.dateComponents([.day], from: date, to: Date())
        if let days = diff.day {
            if days == 0 { return "今日参加" }
            if days < 30 { return "\(days)日前" }
            if days < 365 { return "\(days / 30)ヶ月前" }
            return "\(days / 365)年前"
        }
        return ""
    }
}

// MARK: - MemberDetailView

struct MemberDetailView: View {
    let member: Member
    let guildId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @State private var showBanConfirm = false
    @State private var showKickConfirm = false
    @State private var showTimeoutSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ── プロフィールヘッダー ──
                    profileHeader

                    // ── 情報カード群 ──
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
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.accentIndigo)
                }
            }
            .confirmationDialog(
                "\(member.displayName) をBANしますか？",
                isPresented: $showBanConfirm, titleVisibility: .visible
            ) {
                Button("BANする", role: .destructive) {
                    Task {
                        try? await services.members.ban(memberId: member.id, guildId: guildId, reason: nil)
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "\(member.displayName) をキックしますか？",
                isPresented: $showKickConfirm, titleVisibility: .visible
            ) {
                Button("キックする", role: .destructive) {
                    Task {
                        try? await services.members.kick(memberId: member.id, guildId: guildId, reason: nil)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - プロフィールヘッダー

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    member.isBoosting ? Color.accentPink.opacity(0.6) : Color.accentIndigo.opacity(0.6),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 180)

            VStack(spacing: .spacing12) {
                // アバター
                ZStack(alignment: .bottomTrailing) {
                    Avatar(name: member.displayName, size: 80,
                           accentColor: member.isBoosting ? .accentPink : .accentIndigo)
                        .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 3))

                    Circle()
                        .fill(member.status.color)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 3))
                        .offset(x: 2, y: 2)
                }

                VStack(spacing: 4) {
                    HStack(spacing: .spacing8) {
                        Text(member.displayName)
                            .font(.displayMedium)
                            .foregroundStyle(Color.textPrimary)
                        if member.isBoosting {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(Color.accentPink)
                        }
                    }
                    Text("@\(member.username)")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textSecondary)

                    // ステータスバッジ
                    HStack(spacing: 5) {
                        Circle().fill(member.status.color).frame(width: 8, height: 8)
                        Text(member.status.label)
                            .font(.captionSmall).fontWeight(.medium)
                            .foregroundStyle(member.status.color)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(member.status.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.bottom, .spacing20)
        }
    }

    // MARK: - 情報カード

    private var infoCard: some View {
        VStack(spacing: 0) {
            detailCardHeader("情報", icon: "info.circle.fill", color: .accentIndigo)
            Divider()
            detailRow("参加日", value: member.joinedAt.formatted(date: .long, time: .omitted))
            Divider().padding(.leading, 16)
            detailRow("ブースト", value: member.isBoosting ? "ブースト中 ⚡️" : "なし")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - ロールカード

    private var rolesCard: some View {
        VStack(spacing: 0) {
            detailCardHeader("ロール（\(member.roles.count)）", icon: "tag.fill", color: .accentPurple)
            Divider()
            if member.roles.isEmpty {
                Text("ロールなし")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textTertiary)
                    .padding()
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(member.roles, id: \.self) { role in
                        HStack(spacing: 5) {
                            Circle().fill(Color.accentIndigo).frame(width: 8, height: 8)
                            Text("@\(role)")
                                .font(.captionRegular).fontWeight(.medium)
                                .foregroundStyle(Color.accentIndigo)
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
            detailCardHeader("アクション", icon: "bolt.circle.fill", color: .accentOrange)
            Divider()

            actionRow(icon: "message.fill", label: "DMを送信", color: .accentIndigo) {}
            Divider().padding(.leading, 52)

            actionRow(icon: "clock.badge.exclamationmark.fill", label: "タイムアウト", color: .accentOrange) {
                showTimeoutSheet = true
            }
            Divider().padding(.leading, 52)

            actionRow(icon: "figure.walk", label: "キック", color: .accentOrange) {
                showKickConfirm = true
            }
            Divider().padding(.leading, 52)

            actionRow(icon: "hammer.fill", label: "BAN", color: .red, isDestructive: true) {
                showBanConfirm = true
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - パーツ

    private func detailCardHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: icon).font(.captionRegular).foregroundStyle(color)
            Text(title).font(.captionSmall).fontWeight(.semibold).foregroundStyle(Color.textTertiary).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.bodySmall).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value).font(.bodySmall).fontWeight(.medium).foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
    }

    private func actionRow(icon: String, label: String, color: Color, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: .spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.bodySmall)
                    .foregroundStyle(isDestructive ? Color.red : Color.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout (ロールを折り返し表示)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += rowHeight + spacing
                x = 0; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
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
    var sortPriority: Int {
        switch self {
        case .online: 0; case .idle: 1; case .dnd: 2; case .offline: 3
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
