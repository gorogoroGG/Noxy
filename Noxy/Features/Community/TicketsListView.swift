import SwiftUI

// MARK: - TicketsListView

struct TicketsListView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var tickets: [Ticket] = []
    @State private var isLoading = true
    @State private var selectedStatus: TicketStatus = .open
    @State private var selectedPriority: TicketPriority? = nil
    @State private var searchText = ""
    @State private var selectedTicket: Ticket? = nil
    @State private var showCreateSheet = false
    @State private var sortOrder: SortOrder = .lastMessage

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
                $0.openedBy.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .lastMessage: return base.sorted { $0.lastMessageAt > $1.lastMessageAt }
        case .opened:      return base.sorted { $0.openedAt > $1.openedAt }
        case .priority:
            let order: [TicketPriority] = [.urgent, .high, .medium, .low]
            return base.sorted { order.firstIndex(of: $0.priority)! < order.firstIndex(of: $1.priority)! }
        }
    }

    private var openCount:    Int { tickets.filter { $0.status == .open    }.count }
    private var pendingCount: Int { tickets.filter { $0.status == .pending }.count }
    private var closedCount:  Int { tickets.filter { $0.status == .closed  }.count }

    var body: some View {
        VStack(spacing: 0) {
            // ── 統計ヘッダー（固定）──
            statsHeader

            // ── ステータスタブ（固定・横のみ）──
            statusTabBar

            // ── リスト本体（searchable + refreshable はここだけに適用）──
            List {
                // 優先度フィルタ行
                if selectedPriority != nil || true { // 常に表示
                    priorityFilterRow
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                }

                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                        .padding(.top, 40)
                } else if filtered.isEmpty {
                    emptyState
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                } else {
                    // 件数
                    Text("\(filtered.count)件")
                        .font(.captionSmall).foregroundStyle(Color.textTertiary)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)

                    // チケットカード
                    ForEach(filtered) { ticket in
                        TicketCard(ticket: ticket)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedTicket = ticket }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color(.systemGroupedBackground))
                            .listRowSeparator(.hidden)
                    }
                }

                Color.clear.frame(height: 60)
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            // ✅ searchable は List に付ける → 下スクロールで出現、操作時に飛び出さない
            .searchable(text: $searchText, prompt: "件名・開設者で検索")
            // ✅ refreshable も List に付ける → フィルターバーを引いてもリフレッシュしない
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
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: .spacing16) {
                    // チケット作成ボタン
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.accentIndigo)
                    }
                    // 並び順メニュー
                    Menu {
                        Picker("並び順", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Button { Task { await load() } } label: {
                            Label("更新", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.accentIndigo)
                    }
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(value: "\(openCount)",    label: "オープン", color: .accentGreen)
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
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.captionSmall).foregroundStyle(Color.textTertiary)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Status Tab Bar（横にしか動かない固定タブ）

    private var statusTabBar: some View {
        // ScrollView を使わず固定 HStack にすることで縦スクロールと干渉しない
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
                                .font(.captionRegular).fontWeight(.semibold)
                        }
                        .foregroundStyle(selectedStatus == s ? s.chipColor : Color.textTertiary)

                        // 選択インジケータ
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

    // MARK: - Priority Filter Row

    private var priorityFilterRow: some View {
        HStack(spacing: .spacing8) {
            // 優先度選択チップ（選択中のみ表示）
            if let p = selectedPriority {
                Button {
                    withAnimation { selectedPriority = nil }
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(p.color).frame(width: 7, height: 7)
                        Text(p.label).font(.captionSmall).fontWeight(.semibold).foregroundStyle(p.color)
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(p.color)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(p.color.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Menu {
                Button("すべての優先度") { withAnimation { selectedPriority = nil } }
                Divider()
                ForEach(TicketPriority.allCases, id: \.self) { p in
                    Button {
                        withAnimation { selectedPriority = p }
                    } label: {
                        if selectedPriority == p { Label(p.label, systemImage: "checkmark") }
                        else { Text(p.label) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flag\(selectedPriority != nil ? ".fill" : "")").font(.system(size: 11))
                    Text(selectedPriority == nil ? "優先度" : "変更")
                        .font(.captionSmall).fontWeight(.medium)
                    Image(systemName: "chevron.down").font(.system(size: 9))
                }
                .foregroundStyle(selectedPriority != nil ? Color.accentOrange : Color.textSecondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: .spacing12) {
            Image(systemName: "ticket")
                .font(.system(size: 36)).foregroundStyle(Color.textTertiary)
            Text("チケットがありません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
            Text(selectedStatus == .closed
                 ? "クローズ済みのチケットはありません"
                 : "条件に一致するチケットはありません")
                .font(.captionRegular).foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        tickets = (try? await services.tickets.fetchAll(guildId: guildId)) ?? []
        isLoading = false
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

            VStack(alignment: .leading, spacing: .spacing8) {
                // 件名 + ステータスバッジ
                HStack(alignment: .top, spacing: .spacing8) {
                    Text(ticket.subject)
                        .font(.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    StatusBadge(status: ticket.status)
                }

                // メタ情報
                HStack(spacing: .spacing12) {
                    Label("@\(ticket.openedBy)", systemImage: "person.fill")
                    if let assignee = ticket.assignedToUserId {
                        Label(assignee, systemImage: "person.badge.clock.fill")
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

                // 優先度バッジ
                HStack(spacing: 5) {
                    Circle().fill(ticket.priority.color).frame(width: 6, height: 6)
                    Text(ticket.priority.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ticket.priority.color)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(ticket.priority.color.opacity(0.1))
                .clipShape(Capsule())
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
                    // 説明
                    HStack(spacing: .spacing10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Color.accentIndigo)
                        Text("管理者がDiscordチャンネルを作成してチケットを開きます。件名を入力してください。")
                            .font(.captionRegular).foregroundStyle(Color.textSecondary)
                    }
                    .padding(.spacing12)
                    .background(Color.accentIndigo.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // 件名入力
                    VStack(alignment: .leading, spacing: .spacing8) {
                        Text("件名").font(.captionSmall).fontWeight(.semibold)
                            .foregroundStyle(Color.textTertiary).textCase(.uppercase)
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

                    // 作成ボタン
                    Button {
                        Task { await create() }
                    } label: {
                        HStack(spacing: .spacing8) {
                            if isCreating {
                                ProgressView().scaleEffect(0.85).tint(.white)
                            } else {
                                Image(systemName: "ticket.fill")
                            }
                            Text(isCreating ? "作成中..." : "チケットを作成")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(subject.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color(.systemGray4) : Color.accentIndigo)
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
        isCreating = true; errorMessage = nil
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

// MARK: - TicketDetailView

struct TicketDetailView: View {
    @State var ticket: Ticket
    let guildId: String
    let onUpdate: (Ticket) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var messages: [TicketMessage] = []
    @State private var isLoadingMessages = true
    @State private var replyText = ""
    @State private var isSending = false
    @State private var isActioning = false
    @State private var errorMessage: String? = nil
    @State private var showCloseConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: .spacing12) {
                            infoCard
                            priorityCard
                            messagesSection
                            Color.clear.frame(height: 8).id("bottom")
                        }
                        .padding(.horizontal, .spacing16)
                        .padding(.top, .spacing16)
                        .padding(.bottom, 100)
                    }
                    .onChange(of: messages.count) {
                        withAnimation { proxy.scrollTo("bottom") }
                    }
                }

                if ticket.status != .closed {
                    replyBar
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("# \(ticket.subject)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("チケットをクローズ", isPresented: $showCloseConfirm) {
                Button("クローズ", role: .destructive) { Task { await closeTicket() } }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("チケットをクローズします。開設者はチャンネルにアクセスできなくなります。")
            }
        }
        .task { await loadMessages() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("完了") { dismiss() }.foregroundStyle(Color.accentIndigo)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if ticket.status != .closed {
                    Button(role: .destructive) { showCloseConfirm = true }
                    label: { Label("チケットをクローズ", systemImage: "lock.fill") }
                } else {
                    Button { Task { await reopenTicket() } }
                    label: { Label("再オープン", systemImage: "lock.open.fill") }
                }
                Divider()
                Menu("優先度を変更") {
                    ForEach(TicketPriority.allCases, id: \.self) { p in
                        Button { Task { await changePriority(p) } } label: {
                            if ticket.priority == p { Label(p.label, systemImage: "checkmark") }
                            else { Text(p.label) }
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(Color.accentIndigo)
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            cardHeader("情報", icon: "ticket.fill", color: .accentIndigo)
            Divider()
            infoRow("開設者",   value: "@\(ticket.openedBy)")
            Divider().padding(.leading, .spacing16)
            infoRow("開設日時", value: ticket.openedAt.formatted(date: .abbreviated, time: .shortened))
            Divider().padding(.leading, .spacing16)
            infoRow("ステータス", value: ticket.status.label)
            Divider().padding(.leading, .spacing16)
            infoRow("優先度",   value: ticket.priority.label)
            if let assignee = ticket.assignedToUserId {
                Divider().padding(.leading, .spacing16)
                infoRow("担当者", value: "@\(assignee)")
            }
            if let closedAt = ticket.closedAt {
                Divider().padding(.leading, .spacing16)
                infoRow("クローズ", value: closedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Priority Card

    private var priorityCard: some View {
        VStack(spacing: 0) {
            cardHeader("優先度", icon: "flag.fill", color: .accentOrange)
            Divider()
            HStack(spacing: .spacing8) {
                ForEach(TicketPriority.allCases, id: \.self) { p in
                    Button {
                        guard ticket.priority != p else { return }
                        Task { await changePriority(p) }
                    } label: {
                        Text(p.label)
                            .font(.captionRegular)
                            .fontWeight(ticket.priority == p ? .bold : .regular)
                            .foregroundStyle(ticket.priority == p ? .white : Color.textSecondary)
                            .padding(.horizontal, .spacing12).padding(.vertical, .spacing8)
                            .background(ticket.priority == p ? p.color : Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.spacing12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        VStack(spacing: 0) {
            cardHeader("メッセージ (\(ticket.messageCount))", icon: "bubble.left.and.bubble.right.fill", color: .accentGreen)
            Divider()
            if isLoadingMessages {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(.spacing24)
            } else if messages.isEmpty {
                Text("メッセージはありません")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                    .padding(.spacing16)
            } else {
                VStack(spacing: .spacing8) {
                    ForEach(messages) { msg in MessageBubble(message: msg) }
                }
                .padding(.spacing12)
            }
            if let err = errorMessage {
                HStack(spacing: .spacing8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(err).font(.captionSmall).foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, .spacing16).padding(.bottom, .spacing8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Reply Bar

    private var replyBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: .spacing10) {
                ZStack(alignment: .topLeading) {
                    if replyText.isEmpty {
                        Text("スタッフとして返信…")
                            .foregroundStyle(Color.textTertiary).font(.bodySmall)
                            .padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
                    }
                    TextEditor(text: $replyText)
                        .font(.bodySmall).frame(minHeight: 38, maxHeight: 100)
                        .scrollContentBackground(.hidden)
                }
                .padding(.horizontal, .spacing10).padding(.vertical, .spacing6)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                Button {
                    guard !replyText.isEmpty else { return }
                    Task { await sendReply() }
                } label: {
                    Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(replyText.isEmpty ? Color.textTertiary : Color.accentIndigo)
                }
                .disabled(replyText.isEmpty || isSending)
            }
            .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: .spacing8) {
            Image(systemName: icon).font(.captionRegular).foregroundStyle(color)
            Text(title).font(.captionSmall).fontWeight(.semibold)
                .foregroundStyle(Color.textTertiary).textCase(.uppercase)
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

    // MARK: - Actions

    private func loadMessages() async {
        isLoadingMessages = true
        messages = (try? await services.tickets.fetchMessages(ticketId: ticket.id)) ?? []
        isLoadingMessages = false
    }

    private func sendReply() async {
        let text = replyText; isSending = true; errorMessage = nil
        do {
            try await services.tickets.reply(ticketId: ticket.id, message: text)
            replyText = ""; ticket.messageCount += 1; ticket.lastMessageAt = .now
            onUpdate(ticket)
            await loadMessages()
        } catch { errorMessage = "送信に失敗しました" }
        isSending = false
    }

    private func closeTicket() async {
        isActioning = true; errorMessage = nil
        do {
            try await services.tickets.close(id: ticket.id)
            ticket.status = .closed; ticket.closedAt = .now; onUpdate(ticket)
        } catch { errorMessage = "クローズに失敗しました" }
        isActioning = false
    }

    private func reopenTicket() async {
        isActioning = true; errorMessage = nil
        do {
            try await services.tickets.reopen(id: ticket.id)
            ticket.status = .open; ticket.closedAt = nil; onUpdate(ticket)
        } catch { errorMessage = "再オープンに失敗しました" }
        isActioning = false
    }

    private func changePriority(_ priority: TicketPriority) async {
        errorMessage = nil
        do {
            try await services.tickets.updatePriority(id: ticket.id, priority: priority)
            ticket.priority = priority; onUpdate(ticket)
        } catch { errorMessage = "優先度の変更に失敗しました" }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: TicketMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: .spacing8) {
            if message.isStaff { Spacer(minLength: 40) }

            VStack(alignment: message.isStaff ? .trailing : .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if message.isStaff {
                        Text(message.createdAt.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                        Label("スタッフ", systemImage: "shield.fill")
                            .font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.accentIndigo)
                    }
                    Text(message.username)
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.textTertiary)
                    if !message.isStaff {
                        Text(message.createdAt.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                    }
                }
                Text(message.content)
                    .font(.bodySmall)
                    .foregroundStyle(message.isStaff ? .white : Color.textPrimary)
                    .padding(.horizontal, .spacing12).padding(.vertical, .spacing8)
                    .background(message.isStaff ? Color.accentIndigo : Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if !message.isStaff { Spacer(minLength: 40) }
        }
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
        case .urgent: .red
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

// MARK: - Preview

#Preview {
    NavigationStack {
        TicketsListView(guildId: "g003").navigationTitle("チケット")
    }
    .environment(\.services, ServiceContainer.mock())
    .environment(AppState())
    .preferredColorScheme(.dark)
}
