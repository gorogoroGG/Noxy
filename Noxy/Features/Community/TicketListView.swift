import SwiftUI

// MARK: - TicketListView
// Noxy Design Language に厳密に従った再設計。

struct TicketListView: View {
    let guildId: String
    @Binding var tickets: [Ticket]

    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var selectedStatus: TicketStatus = .open
    @State private var selectedPriority: TicketPriority? = nil
    @State private var searchText = ""
    @State private var selectedTicket: Ticket? = nil
    @State private var showCreateSheet = false
    @State private var sortOrder: SortOrder = .lastMessage
    @State private var toast: ToastMessage? = nil

    enum SortOrder: String, CaseIterable {
        case lastMessage = "最終更新"
        case opened      = "開設日"
        case priority    = "優先度"
    }

    private var filtered: [Ticket] {
        var base = tickets.filter { $0.status == selectedStatus }
        if let p = selectedPriority { base = base.filter { $0.priority == p } }
        if !searchText.isEmpty {
            base = base.filter {
                $0.subject.localizedCaseInsensitiveContains(searchText) ||
                $0.openedBy.localizedCaseInsensitiveContains(searchText) ||
                ($0.assignedToUserId?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        switch sortOrder {
        case .lastMessage:
            return base.sorted { $0.lastMessageAt > $1.lastMessageAt }
        case .opened:
            return base.sorted { $0.openedAt > $1.openedAt }
        case .priority:
            let order: [TicketPriority] = [.urgent, .high, .medium, .low]
            return base.sorted {
                (order.firstIndex(of: $0.priority) ?? 99) < (order.firstIndex(of: $1.priority) ?? 99)
            }
        }
    }

    private var openCount:    Int { tickets.filter { $0.status == .open    }.count }
    private var pendingCount: Int { tickets.filter { $0.status == .pending }.count }
    private var closedCount:  Int { tickets.filter { $0.status == .closed  }.count }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            statTabBar

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    filterRow

                    if isLoading {
                        loadingContent
                    } else if let err = loadError {
                        errorContent(err)
                    } else if filtered.isEmpty {
                        emptyContent
                    } else {
                        listContent
                    }
                }
                .padding(.horizontal, .spacing16)
                .padding(.top, .spacing12)
            }
            .searchable(text: $searchText, prompt: "件名・開設者・担当者で検索")
            .refreshable { await load() }
        }
        .background(Theme.Color.bg)
        .sheet(item: $selectedTicket) { ticket in
            TicketDetailView(ticket: ticket, guildId: guildId) { updated in
                if let idx = tickets.firstIndex(where: { $0.id == updated.id }) {
                    tickets[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTicketSheet(guildId: guildId) { newTicket in
                tickets.insert(newTicket, at: 0)
                selectedStatus = .open
                showToast("チケットを作成しました", type: .success)
            }
        }
        .toast($toast)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Stat Tab Bar (統計数 + タブ選択を統合)

    private var statTabBar: some View {
        HStack(spacing: 0) {
            statTabCell(status: .open,    count: openCount)
            statTabCell(status: .pending, count: pendingCount)
            statTabCell(status: .closed,  count: closedCount)
        }
        .padding(.horizontal, .spacing8)
        .background(Theme.Color.surface)
        .overlay(
            Rectangle()
                .fill(Theme.Color.line)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func statTabCell(status: TicketStatus, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedStatus = status }
        } label: {
            VStack(spacing: 4) {
                MonoText(
                    value: "\(count)",
                    font: Theme.Font.mono,
                    color: selectedStatus == status ? status.chipColor : Theme.Color.textTertiary
                )
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(status.label)
                        .font(Theme.Font.caption)
                }
                .foregroundStyle(selectedStatus == status ? status.chipColor : Theme.Color.textTertiary)
                Capsule()
                    .fill(selectedStatus == status ? status.chipColor : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spacing8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Row
    // Noxy §4: フィルタータグ - border: 1px solid var(--line2), border-radius: 9px, padding: 5px 11px

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                // 優先度フィルター選択中バッジ
                if let p = selectedPriority {
                    Button { withAnimation { selectedPriority = nil } } label: {
                        HStack(spacing: 4) {
                            StatusDot(color: p.color)
                            Text(p.label)
                                .font(Theme.Font.caption)
                                .foregroundStyle(p.color)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(p.color)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(p.color.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // 優先度フィルターメニュー
                Menu {
                    Button("すべての優先度") { withAnimation { selectedPriority = nil } }
                    Divider()
                    ForEach(TicketPriority.allCases, id: \.self) { p in
                        Button { withAnimation { selectedPriority = p } } label: {
                            if selectedPriority == p { Label(p.label, systemImage: "checkmark") }
                            else { Text(p.label) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedPriority != nil ? "flag.fill" : "flag")
                            .font(.system(size: 11))
                        Text(selectedPriority == nil ? "優先度" : "変更")
                            .font(Theme.Font.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(selectedPriority != nil ? Theme.Color.statusWarn : Theme.Color.textSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        selectedPriority != nil ? Theme.Color.surfaceRaised : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Theme.Color.lineStrong, lineWidth: 1)
                    )
                }

                // 並び順メニュー
                Menu {
                    Picker("並び順", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text(sortOrder.rawValue)
                            .font(Theme.Font.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        Color.clear,
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Theme.Color.lineStrong, lineWidth: 1)
                    )
                }

                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - List Content

    private var listContent: some View {
        VStack(spacing: .spacing10) {
            SectionHeader(title: "\(filtered.count)件") {}

            ForEach(filtered) { ticket in
                TicketCard(ticket: ticket)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTicket = ticket }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if ticket.status == .pending {
                            Button {
                                Task { await closeTicket(ticket) }
                            } label: {
                                Label("クローズ", systemImage: "lock.fill")
                            }
                            .tint(Theme.Color.statusWarn)
                        }
                    }
            }
        }
    }

    // MARK: - Loading / Error / Empty

    private var loadingContent: some View {
        VStack(spacing: .spacing10) {
            SectionHeader(title: "読み込み中") {}
            ForEach(0..<3, id: \.self) { _ in
                SkeletonCard()
            }
        }
    }

    private func errorContent(_ message: String) -> some View {
        EmptyStateView(
            icon: "wifi.exclamationmark",
            title: "読み込みに失敗しました",
            description: message,
            actionTitle: "再試行"
        ) {
            Task { await load() }
        }
    }

    private var emptyContent: some View {
        EmptyStateView(
            icon: selectedStatus == .closed ? "lock" : "ticket",
            title: emptyTitle,
            description: emptySubtitle
        )
    }

    private var emptyTitle: String {
        switch selectedStatus {
        case .open:    "オープンなチケットはありません"
        case .pending: "対応中のチケットはありません"
        case .closed:  "クローズ済みのチケットはありません"
        }
    }

    private var emptySubtitle: String {
        switch selectedStatus {
        case .open, .pending: "条件に一致するチケットはありません"
        case .closed:  "クローズ済みのチケットはありません"
        }
    }

    // MARK: - Actions

    private func load() async {
        loadError = nil
        if !tickets.isEmpty {
            isLoading = false
        } else if let cached = appState.cachedTickets[guildId] {
            tickets = cached
            isLoading = false
        } else {
            isLoading = true
        }
        do {
            let fetched = try await services.tickets.fetchAll(guildId: guildId)
            tickets = fetched
            appState.cacheTickets(fetched, for: guildId)
        } catch {
            if tickets.isEmpty {
                loadError = "サーバーに接続できませんでした。ネットワークを確認してください。"
            }
        }
        isLoading = false
    }

    private func closeTicket(_ ticket: Ticket) async {
        do {
            try await services.tickets.setStatus(id: ticket.id, status: .closed)
            if let idx = tickets.firstIndex(where: { $0.id == ticket.id }) {
                var updated = tickets[idx]
                updated.status = .closed
                updated.closedAt = .now
                tickets[idx] = updated
            }
            showToast("チケットをクローズしました", type: .success)
        } catch {
            showToast("クローズに失敗しました", type: .error)
        }
    }

    private func showToast(_ msg: String, type: ToastType) {
        toast = ToastMessage(type: type, message: msg)
    }
}

// MARK: - TicketCard
// Noxy Design Language §3.1 カード + §3.3 リストアイテム + §6 情報密度

private struct TicketCard: View {
    let ticket: Ticket

    var body: some View {
        HStack(spacing: 0) {
            // 優先度カラーバー
            Rectangle()
                .fill(ticket.priority.color)
                .frame(width: 3)

            HStack(alignment: .top, spacing: .spacing12) {
                VStack(alignment: .leading, spacing: 4) {
                    // Row 1: 件名 + 経過時間
                    HStack(alignment: .firstTextBaseline) {
                        Text(ticket.subject)
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: .spacing8)
                        MonoText(
                            value: ticket.lastMessageAt.formatted(.relative(presentation: .named)),
                            font: Theme.Font.monoCap,
                            color: Theme.Color.textTertiary
                        )
                    }

                    // Row 2: ステータス + 優先度 + メッセージ数
                    HStack(spacing: .spacing8) {
                        StatusBadge(status: ticket.status)
                        if ticket.priority == .urgent || ticket.priority == .high {
                            Badge(text: ticket.priority.label, color: ticket.priority.color, style: .outlined)
                        }
                        Text("·")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                        if ticket.messageCount == 0 {
                            Text("未返信")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .lineLimit(1)
                        } else {
                            HStack(spacing: 2) {
                                Text("メッセージ")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textSecondary)
                                MonoText(value: "\(ticket.messageCount)", font: Theme.Font.monoCap, color: Theme.Color.textSecondary)
                                Text("件")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        }
                    }

                    // Row 3: 開設者 + 担当者
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Color.textTertiary)
                        Text(ticket.openedBy)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textTertiary)
                            .lineLimit(1)
                        if let assignee = ticket.assignedToUserId, !assignee.isEmpty {
                            Text("·")
                                .font(Theme.Font.caption)
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
            .padding(EdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13))
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
    }
}

// MARK: - StatusBadge

private struct StatusBadge: View {
    let status: TicketStatus
    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(status.chipColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.chipColor.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - CreateTicketSheet

private struct CreateTicketSheet: View {
    let guildId: String
    let onCreate: (Ticket) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss
    @State private var subject = ""
    @State private var isCreating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing20) {
                    Card(padding: .spacing12, background: Theme.Color.accentDim, showBorder: false) {
                        HStack(spacing: .spacing10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Theme.Color.accent)
                            Text("Discordに専用チャンネルを作成してチケットを開きます。件名を入力してください。")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }

                    FormSection("件名", icon: "ticket") {
                        TextField("例: ログインできない、機能のリクエストなど", text: $subject, axis: .vertical)
                            .font(Theme.Font.body)
                            .lineLimit(2...4)
                            .padding(.spacing12)
                            .background(Theme.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let err = errorMessage {
                        HStack(spacing: .spacing8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.Color.statusWarn)
                            Text(err)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        .padding(.spacing12)
                        .background(Theme.Color.statusWarn.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    AccentButton(title: isCreating ? "作成中..." : "チケットを作成") {
                        Task { await create() }
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
                .padding(.spacing16)
            }
            .background(Theme.Color.bg)
            .navigationTitle("チケットを作成")
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

    private func create() async {
        isCreating = true
        errorMessage = nil
        do {
            let ticket = try await services.tickets.create(
                guildId: guildId,
                subject: subject.trimmingCharacters(in: .whitespaces)
            )
            onCreate(ticket)
            dismiss()
        } catch {
            errorMessage = "作成に失敗しました。Botがサーバーに参加しているか確認してください。"
        }
        isCreating = false
    }
}

// MARK: - Extensions

extension TicketPriority: CaseIterable {
    public static var allCases: [TicketPriority] { [.low, .medium, .high, .urgent] }
    var label: String {
        switch self { case .low: "低"; case .medium: "中"; case .high: "高"; case .urgent: "緊急" }
    }
    var color: Color {
        switch self {
        case .urgent: Theme.Color.statusBad
        case .high:   Theme.Color.statusWarn
        case .medium: Theme.Color.accent
        case .low:    Theme.Color.textTertiary
        }
    }
}

extension TicketStatus {
    var label: String {
        switch self { case .open: "オープン"; case .pending: "対応中"; case .closed: "クローズ" }
    }
    var icon: String {
        switch self { case .open: "envelope.open.fill"; case .pending: "clock.fill"; case .closed: "lock.fill" }
    }
    var chipColor: Color {
        switch self {
        case .open:    Theme.Color.statusOK
        case .pending: Theme.Color.statusWarn
        case .closed:  Theme.Color.textTertiary
        }
    }
}

#Preview {
    NavigationStack {
        TicketListView(guildId: "g003", tickets: .constant(MockData.tickets))
            .navigationTitle("対応")
    }
    .environment(\.services, ServiceContainer.mock())
    .environment(AppState())
}
