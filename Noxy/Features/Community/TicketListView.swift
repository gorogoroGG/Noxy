import SwiftUI

// MARK: - TicketListView
// 届いたチケットの一覧・検索・フィルタ・ソートを行う。
// 未対応（Open/Pending）チケットを優先して表示し、スタッフがスムーズに対応できるよう設計。

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

    var body: some View {
        VStack(spacing: 0) {
            statsHeader
            statusTabBar

            List {
                filterRow
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)

                if isLoading {
                    loadingCell
                        .transition(.opacity)
                } else if let err = loadError {
                    errorCell(err)
                        .transition(.opacity)
                } else if filtered.isEmpty {
                    emptyCell
                        .transition(.opacity)
                } else {
                    countCell
                    ForEach(filtered) { ticket in
                        TicketCard(ticket: ticket)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedTicket = ticket }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color(.systemGroupedBackground))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if ticket.status == .pending {
                                    Button {
                                        Task { await closeTicket(ticket) }
                                    } label: {
                                        Label("クローズ", systemImage: "lock.fill")
                                    }
                                    .tint(Color.accentOrange)
                                }
                            }
                    }
                }

                Color.clear.frame(height: 60)
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: "件名・開設者・担当者で検索")
            .refreshable { await load() }
        }
        .background(Color(.systemGroupedBackground))
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
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(value: "\(openCount)",    label: "オープン",   color: .accentGreen)
            Divider().frame(height: 32)
            statCell(value: "\(pendingCount)", label: "対応中",   color: .accentOrange)
            Divider().frame(height: 32)
            statCell(value: "\(closedCount)",  label: "クローズ", color: Color.textTertiary)
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

    // MARK: - Status Tab Bar

    private var statusTabBar: some View {
        HStack(spacing: 0) {
            ForEach([TicketStatus.open, .pending, .closed], id: \.self) { s in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedStatus = s }
                } label: {
                    VStack(spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: s.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(s.label)
                                .font(.captionRegular)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(selectedStatus == s ? s.chipColor : Color.textTertiary)
                        Capsule()
                            .fill(selectedStatus == s ? s.chipColor : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spacing8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, .spacing8)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing8) {
                // 優先度フィルター選択中バッジ
                if let p = selectedPriority {
                    Button { withAnimation { selectedPriority = nil } } label: {
                        HStack(spacing: 4) {
                            Circle().fill(p.color).frame(width: 7, height: 7)
                            Text(p.label)
                                .font(.captionSmall)
                                .fontWeight(.semibold)
                                .foregroundStyle(p.color)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(p.color)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(p.color.opacity(0.12)).clipShape(Capsule())
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
                            .font(.captionSmall)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }
                    .foregroundStyle(selectedPriority != nil ? Color.accentOrange : Color.textSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(.tertiarySystemGroupedBackground)).clipShape(Capsule())
                }

                // 並び順メニュー
                Menu {
                    Picker("並び順", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 11))
                        Text(sortOrder.rawValue).font(.captionSmall).fontWeight(.medium)
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(.tertiarySystemGroupedBackground)).clipShape(Capsule())
                }

                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - List Cells

    private var loadingCell: some View {
        ForEach(0..<3) { _ in
            VStack(alignment: .leading, spacing: .spacing8) {
                HStack(spacing: .spacing8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.textTertiary.opacity(0.2))
                        .frame(width: 80, height: 14)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.textTertiary.opacity(0.15))
                        .frame(width: 50, height: 12)
                }
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.textTertiary.opacity(0.1))
                    .frame(width: 200, height: 12)
            }
            .padding(.spacing12)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .listRowBackground(Color(.systemGroupedBackground))
            .listRowSeparator(.hidden)
            .padding(.top, 8)
        }
    }

    private func errorCell(_ message: String) -> some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)
            Text("読み込みに失敗しました")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .font(.bodyRegular)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Button { Task { await load() } } label: {
                Label("再試行", systemImage: "arrow.clockwise")
                    .font(.bodySmall).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacing20).padding(.vertical, .spacing10)
                    .background(Color.accentIndigo)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .listRowBackground(Color(.systemGroupedBackground))
        .listRowSeparator(.hidden)
    }

    private var emptyCell: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: selectedStatus == .closed ? "lock" : "ticket")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)
            Text(emptyTitle)
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text(emptySubtitle)
                .font(.captionRegular)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .listRowBackground(Color(.systemGroupedBackground))
        .listRowSeparator(.hidden)
    }

    private var countCell: some View {
        Text("\(filtered.count)件")
            .font(.captionSmall)
            .foregroundStyle(Color.textTertiary)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color(.systemGroupedBackground))
            .listRowSeparator(.hidden)
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
        case .open:    "条件に一致するチケットはありません"
        case .pending: "条件に一致するチケットはありません"
        case .closed:  "クローズ済みのチケットはありません"
        }
    }

    // MARK: - Actions

    private func load() async {
        loadError = nil
        // 既にデータがあるかキャッシュがあれば即座に表示
        if !tickets.isEmpty {
            isLoading = false
        } else if let cached = appState.cachedTickets[guildId] {
            tickets = cached
            isLoading = false
        } else {
            isLoading = true
        }
        // バックグラウンドで最新データを取得
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

private struct TicketCard: View {
    let ticket: Ticket

    var body: some View {
        HStack(spacing: 0) {
            // 優先度カラーバー
            RoundedRectangle(cornerRadius: 2)
                .fill(ticket.priority.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: .spacing6) {
                // 件名 + 優先度チップ + ステータスバッジ
                HStack(alignment: .top, spacing: .spacing6) {
                    Text(ticket.subject)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        StatusBadge(status: ticket.status)
                        if ticket.priority == .urgent || ticket.priority == .high {
                            Text(ticket.priority.label)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ticket.priority.color)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(ticket.priority.color.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                // メタ情報
                HStack(spacing: .spacing10) {
                    Label("@\(ticket.openedBy)", systemImage: "person.fill")

                    if let assignee = ticket.assignedToUserId, !assignee.isEmpty {
                        Label("@\(assignee)", systemImage: "person.badge.clock.fill")
                            .foregroundStyle(Color.accentIndigo)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left.fill")
                        Text("\(ticket.messageCount)")
                    }
                    Text(ticket.lastMessageAt.formatted(.relative(presentation: .named)))
                }
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
            }
            .padding(.spacing12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    HStack(spacing: .spacing10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Color.accentIndigo)
                        Text("Discordに専用チャンネルを作成してチケットを開きます。件名を入力してください。")
                            .font(.captionRegular).foregroundStyle(Color.textSecondary)
                    }
                    .padding(.spacing12)
                    .background(Color.accentIndigo.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("件名")
                            .font(.captionSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)
                        TextField("例: ログインできない、機能のリクエストなど", text: $subject, axis: .vertical)
                            .font(.bodySmall)
                            .lineLimit(2...4)
                            .padding(.spacing12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let err = errorMessage {
                        HStack(spacing: .spacing8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(err).font(.captionSmall).foregroundStyle(Color.textSecondary)
                        }
                        .padding(.spacing12)
                        .background(Color.accentOrange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button { Task { await create() } } label: {
                        HStack(spacing: .spacing8) {
                            if isCreating { ProgressView().scaleEffect(0.85).tint(.white) }
                            else { Image(systemName: "ticket.fill") }
                            Text(isCreating ? "作成中..." : "チケットを作成").fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(subject.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.gray.opacity(0.45) : Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
                .padding(.spacing16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("チケットを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color.textSecondary)
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

// MARK: - StatusBadge

private struct StatusBadge: View {
    let status: TicketStatus
    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(status.chipColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(status.chipColor.opacity(0.15))
            .clipShape(Capsule())
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
        case .urgent: .accentRed
        case .high:   .accentOrange
        case .medium: .accentIndigo
        case .low:    .accentGreen
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
        case .open:    .accentGreen
        case .pending: .accentOrange
        case .closed:  Color.textTertiary
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
