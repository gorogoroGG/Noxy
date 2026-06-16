import SwiftUI

// MARK: - Filter

private enum InboxFilter: String, CaseIterable {
    case all      = "すべて"
    case waiting  = "対応待ち"
    case mine     = "自分の担当"
    case report   = "通報"
}

// MARK: - Activity item

private struct InboxActivityItem: Identifiable, Decodable {
    var id = UUID()
    var type: String        // "ticket" | "order" | "dm" | "moderation" | etc.
    var icon: String        // SF Symbol 名
    var text: String
    var timeAgo: String
    var ticketId: String?   // type=="ticket" 時にセット
    var referenceId: String? // type=="order" 時にセット
    enum CodingKeys: String, CodingKey { case type, icon, text, timeAgo, ticketId, referenceId }
}

// MARK: - Scroll offset key

private struct ServerHeaderMaxYKey: PreferenceKey {
    static let defaultValue: CGFloat = 999
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - InboxView

struct InboxView: View {
    @Environment(\.services)      private var services
    @Environment(AppState.self)   private var appState
    @Environment(AuthManager.self) private var authManager

    // Data
    @State private var tickets:    [Ticket]            = []
    @State private var warnings:   [ModWarning]        = []
    @State private var activities: [InboxActivityItem] = []
    @State private var isLoading = true

    // UI State
    @State private var filter: InboxFilter = .all
    @State private var toast: ToastMessage? = nil

    // Navigation
    @State private var selectedTicket:      Ticket? = nil
    @State private var deepLinkTicketId:    String? = nil
    @State private var navigateToTickets    = false
    @State private var navigateToModeration = false
    @State private var navigateToOrders     = false

    // Compact nav header visibility
    @State private var serverHeaderVisible = true

    // ConfirmModal for close
    @State private var closingTicket: Ticket? = nil
    @State private var isClosing = false

    // メンバー詳細
    @State private var selectedOpenedByMember: Member? = nil

    // サーバー切替
    @State private var showGuildPicker = false

    private var myDiscordId: String {
        authManager.currentUser?.discordId
            ?? KeychainHelper.load(forKey: "discord_user_id")
            ?? ""
    }

    // MARK: - Filtered subsets

    private var openTickets: [Ticket] {
        tickets.filter { $0.status == .open }
    }
    private var pendingTickets: [Ticket] {
        tickets.filter { $0.status == .pending }
    }
    private var activeWarnings: [ModWarning] {
        warnings.filter { !$0.isRevoked }
    }

    private var waitingSection: [Ticket] {
        switch filter {
        case .all, .waiting: return openTickets
        case .mine:          return openTickets.filter { $0.assignedToUserId == myDiscordId }
        case .report:        return []
        }
    }
    private var inProgressSection: [Ticket] {
        switch filter {
        case .all, .mine: return pendingTickets.filter {
            filter == .mine ? $0.assignedToUserId == myDiscordId : true
        }
        case .waiting: return []
        case .report:  return []
        }
    }
    private var reportSection: [ModWarning] {
        switch filter {
        case .all, .report:   return activeWarnings
        case .waiting, .mine: return []
        }
    }

    private var chipCount: (waiting: Int, mine: Int, report: Int) {
        (
            waiting: openTickets.count,
            mine:    (openTickets + pendingTickets).filter { $0.assignedToUserId == myDiscordId }.count,
            report:  activeWarnings.count
        )
    }

    private var isEmpty: Bool {
        waitingSection.isEmpty && inProgressSection.isEmpty && reportSection.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.bg.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainContent
                }

                // クローズ確認モーダル
                if let ticket = closingTicket {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .onTapGesture { closingTicket = nil }
                    ConfirmModal(
                        icon: "xmark.circle.fill",
                        iconColor: Theme.Color.statusBad,
                        title: "実行しますか？",
                        message: "「\(ticket.subject)」をクローズする",
                        primaryLabel: isClosing ? "処理中..." : "クローズ",
                        primaryRole: .destructive,
                        onPrimary: { Task { await closeTicket(ticket) } },
                        onCancel: { closingTicket = nil }
                    )
                    .padding(.horizontal, Theme.Spacing.lg)
                    .zIndex(10)
                }
            }
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    compactServerHeader
                }
            }
            .navigationDestination(item: $selectedTicket) { ticket in
                TicketDetailView(ticket: ticket, guildId: appState.selectedGuildId) { updated in
                    if let idx = tickets.firstIndex(where: { $0.id == updated.id }) {
                        tickets[idx] = updated
                        syncBadge()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToTickets) {
                TicketsCoordinatorView(guildId: appState.selectedGuildId, initialTab: .respond)
            }
            .navigationDestination(isPresented: $navigateToModeration) {
                ModerationCenterView()
            }
            .navigationDestination(isPresented: $navigateToOrders) {
                OrdersListView(guildId: appState.selectedGuildId)
            }
        }
        .toast($toast)
        .sheet(isPresented: $showGuildPicker) {
            GuildPickerSheet()
        }
        .sheet(item: $selectedOpenedByMember) { member in
            MemberDetailView(
                member: member,
                guildId: appState.selectedGuildId,
                allRoles: selectableRoles(for: appState.selectedGuildId),
                onAction: { action in await handleMemberAction(action, member: member) }
            )
        }
        .task(id: appState.selectedGuildId) { await load() }
        .onOpenURL { url in
            guard url.scheme == "noxy", url.host == "inbox" else { return }
            let components = url.pathComponents.filter { $0 != "/" }
            if components.count >= 2, components[0] == "ticket" {
                deepLinkTicketId = components[1]
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openInboxTab)) { _ in }
        .onChange(of: deepLinkTicketId) { _, ticketId in
            guard let id = ticketId else { return }
            if let found = tickets.first(where: { $0.id == id }) {
                selectedTicket = found
            }
            deepLinkTicketId = nil
        }
    }

    // MARK: - コンパクトナビゲーションバーヘッダー（スクロール後に表示）

    private var compactServerHeader: some View {
        Button { showGuildPicker = true } label: {
            HStack(spacing: 6) {
                ServerIconView(
                    imageUrl: appState.selectedGuild?.iconUrl,
                    name: appState.selectedGuild?.name ?? "",
                    size: 22
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(appState.selectedGuild?.name ?? "サーバーを選択")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)
                    if let status = appState.botStatus {
                        HStack(spacing: 3) {
                            StatusDot(color: status.isOnline ? Theme.Color.statusOK : Theme.Color.statusBad)
                            Text(status.isOnline ? "稼働中" : "オフライン")
                                .font(.system(size: 10))
                                .foregroundStyle(status.isOnline ? Theme.Color.statusOK : Theme.Color.statusBad)
                        }
                    }
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .opacity(serverHeaderVisible ? 0 : 1)
        .animation(.easeInOut(duration: 0.22), value: serverHeaderVisible)
    }

    // MARK: - Main content

    private var mainContent: some View {
        List {
            homeSection
            activitySectionView
            inboxListSection
            // タブバーと重ならないための余白
            Color.clear
                .frame(height: 24)
                .listRowBackground(Theme.Color.bg)
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg)
        .refreshable { await load() }
        .onPreferenceChange(ServerHeaderMaxYKey.self) { maxY in
            withAnimation(.easeInOut(duration: 0.22)) {
                serverHeaderVisible = maxY > 130
            }
        }
    }

    // MARK: - ホームセクション（サーバーヘッダー＋サマリーカード）

    private var homeSection: some View {
        Section {
            // サーバーヘッダー（スクロール対象）
            InboxServerHeader(onSwitch: { showGuildPicker = true })
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ServerHeaderMaxYKey.self,
                            value: geo.frame(in: .global).maxY
                        )
                    }
                )
                .listRowInsets(EdgeInsets(
                    top: Theme.Spacing.sm,
                    leading: Theme.Spacing.md,
                    bottom: Theme.Spacing.sm,
                    trailing: Theme.Spacing.md
                ))
                .listRowBackground(Theme.Color.bg)
                .listRowSeparator(.hidden)

            // サマリーカード
            HStack(spacing: Theme.Spacing.sm) {
                summaryCard(
                    icon: "ticket",
                    label: "対応待ち",
                    count: chipCount.waiting,
                    color: Theme.Color.accent
                ) { navigateToTickets = true }

                summaryCard(
                    icon: "exclamationmark.triangle.fill",
                    label: "通報・警告",
                    count: chipCount.report,
                    color: Theme.Color.statusWarn
                ) { navigateToModeration = true }
            }
            .listRowInsets(EdgeInsets(
                top: 0,
                leading: Theme.Spacing.md,
                bottom: Theme.Spacing.sm,
                trailing: Theme.Spacing.md
            ))
            .listRowBackground(Theme.Color.bg)
            .listRowSeparator(.hidden)
        }
        .listSectionSeparator(.hidden)
    }

    private func summaryCard(
        icon: String,
        label: String,
        count: Int,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                Text("\(count)")
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(count > 0 ? Theme.Color.textPrimary : Theme.Color.textTertiary)
                    .contentTransition(.numericText())
                Text(label)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(count > 0 ? color.opacity(0.25) : Theme.Color.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 最近のアクティビティ

    @ViewBuilder
    private var activitySectionView: some View {
        if !activities.isEmpty {
            Section {
                ForEach(Array(activities.prefix(5))) { item in
                    activityRow(item)
                        .listRowInsets(EdgeInsets(
                            top: 0, leading: Theme.Spacing.md,
                            bottom: 0, trailing: Theme.Spacing.md
                        ))
                        .listRowBackground(Theme.Color.bg)
                        .listRowSeparatorTint(Theme.Color.line)
                }
            } header: {
                SectionLabel(title: "最近のアクティビティ")
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, 4)
            }
            .listSectionSeparator(.hidden)
        }
    }

    // MARK: - 受信箱リストセクション

    private var inboxListSection: some View {
        Section {
            if isEmpty {
                inboxEmptyState
                    .listRowBackground(Theme.Color.bg)
                    .listRowSeparator(.hidden)
            } else {
                if !waitingSection.isEmpty {
                    inboxSubheader("対応待ち", count: waitingSection.count)
                    ForEach(waitingSection) { ticket in
                        ticketRow(ticket, priority: true)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    Task { await claimTicket(ticket) }
                                } label: {
                                    Label("担当する", systemImage: "person.badge.plus.fill")
                                }
                                .tint(Theme.Color.statusOK)
                            }
                            .contextMenu { ticketContextMenu(ticket) }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Theme.Color.surface)
                            .listRowSeparatorTint(Theme.Color.line)
                    }
                }
                if !inProgressSection.isEmpty {
                    inboxSubheader("対応中", count: inProgressSection.count)
                    ForEach(inProgressSection) { ticket in
                        ticketRow(ticket, priority: false)
                            .contextMenu { ticketContextMenu(ticket) }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Theme.Color.surface)
                            .listRowSeparatorTint(Theme.Color.line)
                    }
                }
                if !reportSection.isEmpty {
                    inboxSubheader("通報", count: reportSection.count)
                    ForEach(reportSection) { warning in
                        reportRow(warning)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Theme.Color.surface)
                            .listRowSeparatorTint(Theme.Color.line)
                    }
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 0) {
                // アクティビティセクションとの視覚的境界
                Rectangle()
                    .fill(Theme.Color.lineStrong)
                    .frame(height: 1)

                HStack(alignment: .center, spacing: Theme.Spacing.xs) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.textTertiary)
                    SectionLabel(title: "受信箱")
                    let total = waitingSection.count + inProgressSection.count + reportSection.count
                    if total > 0 {
                        Text("\(total)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.Color.accentInk)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.Color.accent, in: Capsule())
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, 6)

                filterChipBar
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)
            }
            .background(Theme.Color.bg)
        }
    }

    // サブセクションヘッダー行（受信箱の子グループとして表示）
    private func inboxSubheader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Color.textTertiary)
                .tracking(0.4)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Color.accent)
            Rectangle()
                .fill(Theme.Color.line)
                .frame(height: 1)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Theme.Color.bg)
        .listRowSeparator(.hidden)
    }

    // MARK: - Filter chips

    private var filterChipBar: some View {
        FlowLayout(spacing: 6) {
            ForEach(InboxFilter.allCases, id: \.rawValue) { f in
                filterChip(f)
            }
        }
    }

    private func filterChip(_ f: InboxFilter) -> some View {
        let isSelected = filter == f
        let count: Int? = {
            switch f {
            case .all:     return nil
            case .waiting: return chipCount.waiting
            case .mine:    return chipCount.mine
            case .report:  return chipCount.report
            }
        }()

        let countLabel = count.map { $0 > 0 ? "、\($0)件" : "" } ?? ""
        return Button { filter = f } label: {
            HStack(spacing: 4) {
                Text(f.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textSecondary)
                if let n = count, n > 0 {
                    Text("\(n)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? Theme.Color.accent : Theme.Color.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isSelected ? Theme.Color.surfaceRaised : Color.clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Theme.Color.lineStrong, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: filter)
        .accessibilityLabel("\(f.rawValue)\(countLabel)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Ticket row

    private func ticketRow(_ ticket: Ticket, priority: Bool) -> some View {
        Button {
            selectedTicket = ticket
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(priorityColor(ticket.priority))
                    .frame(width: 3)

                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(ticket.subject)
                                .font(Theme.Font.bodyMedium)
                                .foregroundStyle(Theme.Color.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: Theme.Spacing.xs)
                            MonoText(
                                value: elapsed(ticket.lastMessageAt),
                                font: Theme.Font.monoCap,
                                color: Theme.Color.textTertiary
                            )
                        }

                        HStack(spacing: Theme.Spacing.xs) {
                            MonoText(
                                value: ticketIdLabel(ticket.id),
                                font: Theme.Font.monoCap,
                                color: Theme.Color.accent
                            )
                            Text("·")
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                            Text(messagePreview(ticket))
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.Color.textTertiary)
                            if let member = memberForId(ticket.openedBy) {
                                Button {
                                    selectedOpenedByMember = member
                                } label: {
                                    Text("@\(member.username)")
                                        .font(Theme.Font.caption2)
                                        .foregroundStyle(Theme.Color.accent)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.borderless)
                            } else {
                                Text(ticket.openedBy)
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                    .lineLimit(1)
                            }
                            if let assignee = ticket.assignedToUserId, !assignee.isEmpty {
                                Text("·")
                                    .font(Theme.Font.caption2)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                Image(systemName: "person.badge.checkmark.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.Color.statusOK)
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Color.textTertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.Color.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ticket.subject)、優先度\(priorityLabel(ticket.priority))、\(elapsed(ticket.lastMessageAt))前")
        .accessibilityHint("ダブルタップでチケット詳細を開く")
    }

    // MARK: - Report row

    private func reportRow(_ warning: ModWarning) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Color.statusBad)
                .frame(width: 3)

            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("警告: \(warning.displayName)")
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: Theme.Spacing.xs)
                        MonoText(
                            value: elapsed(warning.createdAt),
                            font: Theme.Font.monoCap,
                            color: Theme.Color.textTertiary
                        )
                    }

                    Text(warning.reason)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Color.textTertiary)
                        Text(warning.staffName)
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Color.surface)
    }

    // MARK: - Activity row

    private func activityRow(_ item: InboxActivityItem) -> some View {
        Button {
            navigateFromActivity(item)
        } label: {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                // アイコン（type → SF Symbol にマッピング）
                ZStack {
                    Circle()
                        .fill(activityIconColor(for: item.type).opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: sfIcon(for: item.type))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(activityIconColor(for: item.type))
                }

                // テキスト
                activityText(item.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 経過時間（右側）
                Text(item.timeAgo)
                    .font(Theme.Font.monoCap)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// アクティビティ type → SF Symbol 名
    private func sfIcon(for type: String) -> String {
        switch type {
        case "ticket":     return "ticket.fill"
        case "order":      return "cart.fill"
        case "dm":         return "message.fill"
        case "moderation": return "shield.lefthalf.filled"
        case "warning":    return "exclamationmark.triangle.fill"
        case "ban":        return "hand.raised.slash.fill"
        default:           return "bell.fill"
        }
    }

    /// アクティビティ type → アクセントカラー
    private func activityIconColor(for type: String) -> Color {
        switch type {
        case "ticket":              return Theme.Color.accent
        case "order":               return Theme.Color.statusOK
        case "dm":                  return Color.accentIndigo
        case "moderation",
             "warning",
             "ban":                 return Theme.Color.statusWarn
        default:                    return Theme.Color.textSecondary
        }
    }

    /// type に応じて最適な画面へ遷移
    private func navigateFromActivity(_ item: InboxActivityItem) {
        switch item.type {
        case "ticket":
            // ticketId が既にロード済みチケットと一致する場合は直接詳細へ
            if let ticketId = item.ticketId,
               let ticket = tickets.first(where: { $0.id == ticketId }) {
                selectedTicket = ticket
            } else {
                // 未ロードの場合はチケット対応一覧へ
                navigateToTickets = true
            }
        case "order":
            navigateToOrders = true
        case "moderation", "warning", "ban":
            navigateToModeration = true
        default:
            // その他は対応タブへ
            navigateToTickets = true
        }
    }

    /// アクティビティテキストの文頭を太字にする
    private func activityText(_ text: String) -> some View {
        let parts = text.split(separator: " ", maxSplits: 1)
        if parts.count == 2 {
            return (
                Text(String(parts[0]))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                + Text(" ")
                + Text(String(parts[1]))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            )
        }
        return (
            Text(text)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
            + Text("")
        )
    }

    // MARK: - Context menu

    @ViewBuilder
    private func ticketContextMenu(_ ticket: Ticket) -> some View {
        Button {
            selectedTicket = ticket
        } label: {
            Label("詳細を開く", systemImage: "arrow.up.right.square")
        }

        Divider()

        Menu("優先度を変更") {
            ForEach([TicketPriority.urgent, .high, .medium, .low], id: \.self) { p in
                Button {
                    Task { await changePriority(ticket, to: p) }
                } label: {
                    Label(priorityLabel(p), systemImage: priorityIcon(p))
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            closingTicket = ticket
        } label: {
            Label("クローズ", systemImage: "xmark.circle")
        }
    }

    // MARK: - Empty state

    private var inboxEmptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "tray.fill")
                .font(.system(size: 28))
                .foregroundStyle(Theme.Color.textTertiary)
            Text(filter == .all ? "受信箱は空です" : "該当するアイテムがありません")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
            Text(filter == .all ? "新しいチケットや通報はありません" : "フィルタを変更してみてください")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Data loading

    private func load() async {
        let guildId = appState.selectedGuildId
        guard !guildId.isEmpty else { isLoading = false; return }

        // 先読み済みチケットがあれば即表示（共有キャッシュ）
        if let cachedTickets = appState.cachedTickets[guildId] {
            tickets = cachedTickets
            isLoading = false
        } else {
            isLoading = true
        }

        async let ticketsTask   = (try? await services.tickets.fetchAll(guildId: guildId)) ?? []
        async let warningsTask  = (try? await ModerationService().fetchWarnings(guildId: guildId)) ?? []
        async let activityTask  = fetchActivities(guildId: guildId)

        let (t, w, a) = await (ticketsTask, warningsTask, activityTask)

        withAnimation {
            tickets    = t
            warnings   = w
            activities = a
            isLoading  = false
        }
        appState.cacheTickets(t, for: guildId)

        syncBadge()
    }

    private func fetchActivities(guildId: String) async -> [InboxActivityItem] {
        guard let url = URL(string: "\(DiscordConfig.workerURL)/bot/recent-activity?guild_id=\(guildId)") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: DiscordConfig.makeWorkerRequest(url: url)) else { return [] }
        return (try? JSONDecoder().decode([InboxActivityItem].self, from: data)) ?? []
    }

    private func syncBadge() {
        let count = tickets.filter { $0.status == .open }.count + warnings.filter { !$0.isRevoked }.count
        InboxState.shared.update(unreadCount: count)
    }

    // MARK: - Actions

    @MainActor
    private func claimTicket(_ ticket: Ticket) async {
        guard !myDiscordId.isEmpty else {
            toast = ToastMessage(type: .warning, message: "ユーザー情報が取得できません")
            return
        }
        do {
            try await services.tickets.assign(ticketId: ticket.id, userId: myDiscordId)
            try await services.tickets.setStatus(id: ticket.id, status: .pending)
            if let idx = tickets.firstIndex(where: { $0.id == ticket.id }) {
                tickets[idx].assignedToUserId = myDiscordId
                tickets[idx].status = .pending
            }
            syncBadge()
            withAnimation {
                toast = ToastMessage(type: .success, message: "「\(ticket.subject)」を担当しました")
            }
        } catch {
            toast = ToastMessage(type: .error, message: "担当の設定に失敗しました")
        }
    }

    @MainActor
    private func changePriority(_ ticket: Ticket, to priority: TicketPriority) async {
        do {
            try await services.tickets.updatePriority(id: ticket.id, priority: priority)
            if let idx = tickets.firstIndex(where: { $0.id == ticket.id }) {
                tickets[idx].priority = priority
            }
            withAnimation {
                toast = ToastMessage(type: .success, message: "優先度を「\(priorityLabel(priority))」に変更しました")
            }
        } catch {
            toast = ToastMessage(type: .error, message: "優先度の変更に失敗しました")
        }
    }

    @MainActor
    private func closeTicket(_ ticket: Ticket) async {
        isClosing = true
        defer { isClosing = false }
        do {
            try await services.tickets.close(id: ticket.id)
            withAnimation {
                tickets.removeAll { $0.id == ticket.id }
                closingTicket = nil
            }
            syncBadge()
            toast = ToastMessage(type: .success, message: "「\(ticket.subject)」をクローズしました")
        } catch {
            closingTicket = nil
            toast = ToastMessage(type: .error, message: "クローズに失敗しました")
        }
    }

    // MARK: - Member helpers

    private func memberForId(_ userId: String) -> Member? {
        let members: [Member]? = appState.guildData(.members, guild: appState.selectedGuildId)
        return members?.first(where: { $0.id == userId })
    }

    private func selectableRoles(for guildId: String) -> [DiscordRole] {
        (appState.guildData(.roles, guild: guildId) ?? [])
            .filter { $0.name != "@everyone" && !$0.managed }
    }

    @MainActor
    private func handleMemberAction(_ action: MemberAction, member: Member) async {
        let guildId = appState.selectedGuildId
        do {
            switch action {
            case .kick(let dm):
                if let msg = dm, !msg.isEmpty { try? await services.members.sendDM(memberId: member.id, message: msg) }
                try await services.members.kick(memberId: member.id, guildId: guildId, reason: nil)
            case .ban(let dm):
                if let msg = dm, !msg.isEmpty { try? await services.members.sendDM(memberId: member.id, message: msg) }
                try await services.members.ban(memberId: member.id, guildId: guildId, reason: nil)
            case .timeout(let until, let dm):
                if let msg = dm, !msg.isEmpty { try? await services.members.sendDM(memberId: member.id, message: msg) }
                try await services.members.timeout(memberId: member.id, guildId: guildId, until: until)
            case .sendDM(let msg):
                try await services.members.sendDM(memberId: member.id, message: msg)
            case .addRole(let roleId):
                try await services.members.addRole(memberId: member.id, guildId: guildId, roleId: roleId)
            case .removeRole(let roleId):
                try await services.members.removeRole(memberId: member.id, guildId: guildId, roleId: roleId)
            }
            selectedOpenedByMember = nil
        } catch {
            toast = ToastMessage(type: .error, message: "操作に失敗しました")
        }
    }

    // MARK: - Helpers

    private func priorityColor(_ priority: TicketPriority) -> Color {
        switch priority {
        case .urgent: Theme.Color.statusBad
        case .high:   Theme.Color.statusWarn
        case .medium: Theme.Color.accent
        case .low:    Theme.Color.textTertiary
        }
    }

    private func priorityLabel(_ priority: TicketPriority) -> String {
        switch priority {
        case .urgent: "緊急"
        case .high:   "高"
        case .medium: "中"
        case .low:    "低"
        }
    }

    private func priorityIcon(_ priority: TicketPriority) -> String {
        switch priority {
        case .urgent: "exclamationmark.2"
        case .high:   "exclamationmark"
        case .medium: "minus"
        case .low:    "arrow.down"
        }
    }

    private func ticketIdLabel(_ id: String) -> String {
        "#T-\(id.prefix(4).uppercased())"
    }

    private func messagePreview(_ ticket: Ticket) -> String {
        ticket.messageCount == 0
            ? "未返信"
            : "メッセージ \(ticket.messageCount)件"
    }

    private func elapsed(_ date: Date) -> String {
        let diff = Int(Date.now.timeIntervalSince(date))
        if diff < 60     { return "今" }
        if diff < 3600   { return "\(diff / 60)m" }
        if diff < 86400  { return "\(diff / 3600)h" }
        return "\(diff / 86400)d"
    }
}

// MARK: - Preview

#Preview {
    InboxView()
        .environment(\.services, ServiceContainer.mock())
        .environment(AppState())
        .environment(AuthManager(services: ServiceContainer.mock()))
}
