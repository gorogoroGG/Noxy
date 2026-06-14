import SwiftUI

// MARK: - TicketDetailView
// Noxy Design Language に厳密に従った再設計。

struct TicketDetailView: View {
    @State var ticket: Ticket
    let guildId: String
    let onUpdate: (Ticket) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss

    @State private var messages: [TicketMessage] = []
    @State private var isLoadingMessages = true
    @State private var loadError: String? = nil
    @State private var replyText = ""
    @State private var isSending = false
    @State private var isActioning = false
    @State private var errorMessage: String? = nil
    @State private var showCloseConfirm = false
    @FocusState private var isReplyFocused: Bool

    private var myUserId: String { KeychainHelper.load(forKey: "discord_user_id") ?? "" }
    private var isClaimed: Bool { !myUserId.isEmpty && ticket.assignedToUserId == myUserId }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: .spacing12) {
                        statusWorkflow
                        infoCard
                        messagesSection
                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing16)
                    .padding(.bottom, 8)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if ticket.status != .closed {
                    replyBar
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle("# \(ticket.subject)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .overlay {
                if showCloseConfirm {
                    ConfirmModal(
                        icon: "lock.fill",
                        iconColor: Theme.Color.statusWarn,
                        title: "チケットをクローズ",
                        message: "チケットをクローズします。開設者はチャンネルにアクセスできなくなります。",
                        primaryLabel: "クローズ",
                        primaryRole: .destructive,
                        onPrimary: {
                            Task { await closeTicket() }
                            showCloseConfirm = false
                        },
                        onCancel: {
                            showCloseConfirm = false
                        }
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
        }
        .task { await loadMessages() }
    }

    // MARK: - Status Workflow
    // Noxy: sur 背景 + 14px 角丸 + line ボーダー + ステップ表示

    private var statusWorkflow: some View {
        Card(padding: .spacing12, background: Theme.Color.surface, showBorder: true) {
            HStack(spacing: 0) {
                stepCell(
                    title: "対応待ち",
                    icon: "envelope.open.fill",
                    isActive: ticket.status == .open,
                    isCompleted: ticket.status != .open
                )
                stepConnector(isCompleted: ticket.status == .pending || ticket.status == .closed)
                stepCell(
                    title: "対応中",
                    icon: "clock.fill",
                    isActive: ticket.status == .pending,
                    isCompleted: ticket.status == .closed
                )
                stepConnector(isCompleted: ticket.status == .closed)
                stepCell(
                    title: "クローズ",
                    icon: "lock.fill",
                    isActive: ticket.status == .closed,
                    isCompleted: false
                )
            }
        }
    }

    private func stepCell(title: String, icon: String, isActive: Bool, isCompleted: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive ? Theme.Color.accent : (isCompleted ? Theme.Color.statusOK : Theme.Color.surfaceRaised))
                    .frame(width: 32, height: 32)
                Image(systemName: isCompleted ? "checkmark" : icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive || isCompleted ? Theme.Color.accentInk : Theme.Color.textTertiary)
            }
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isActive ? Theme.Color.accent : (isCompleted ? Theme.Color.statusOK : Theme.Color.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private func stepConnector(isCompleted: Bool) -> some View {
        Rectangle()
            .fill(isCompleted ? Theme.Color.statusOK : Theme.Color.surfaceRaised)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .offset(y: -10)
    }

    // MARK: - Info Card
    // Noxy: Card + SectionLabel + infoRow（長押しコピー対応）

    private var infoCard: some View {
        Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
            VStack(spacing: 0) {
                SectionLabel(title: "詳細")
                    .padding(.horizontal, .spacing16)
                    .padding(.vertical, .spacing10)

                Divider().background(Theme.Color.line)

                infoRow("開設者", value: "@\(ticket.openedBy)")
                infoRowMono("開設日時", value: ticket.openedAt.formatted(date: .abbreviated, time: .shortened))
                infoRow("ステータス", value: ticket.status.label)

                // 優先度
                Divider()
                    .background(Theme.Color.line)
                    .padding(.leading, .spacing16)
                HStack {
                    Text("優先度")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Spacer()
                    HStack(spacing: .spacing6) {
                        ForEach(TicketPriority.allCases, id: \.self) { p in
                            Button {
                                guard ticket.priority != p else { return }
                                Task { await changePriority(p) }
                            } label: {
                                Text(p.label)
                                    .font(.system(size: 11, weight: ticket.priority == p ? .bold : .regular))
                                    .foregroundStyle(ticket.priority == p ? Theme.Color.accentInk : Theme.Color.textSecondary)
                                    .padding(.horizontal, .spacing8)
                                    .padding(.vertical, 4)
                                    .background(ticket.priority == p ? p.color : Theme.Color.surfaceRaised)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isActioning)
                        }
                    }
                }
                .padding(.horizontal, .spacing16)
                .padding(.vertical, .spacing12)

                // 担当者
                Divider()
                    .background(Theme.Color.line)
                    .padding(.leading, .spacing16)
                claimRow

                if let closedAt = ticket.closedAt {
                    Divider()
                        .background(Theme.Color.line)
                        .padding(.leading, .spacing16)
                    infoRowMono("クローズ", value: closedAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let err = errorMessage {
                    Divider().background(Theme.Color.line)
                    HStack(spacing: .spacing8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Color.statusWarn)
                        Text(err)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    .padding(.horizontal, .spacing16)
                    .padding(.vertical, .spacing10)
                }
            }
        }
    }

    private var claimRow: some View {
        HStack {
            Text("担当者")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
            if let assignee = ticket.assignedToUserId, !assignee.isEmpty, assignee != myUserId {
                // 他のスタッフが担当中
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.clock.fill")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.accent)
                    Text("@\(assignee)")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            } else if ticket.status != .closed {
                Button { Task { await claimTicket() } } label: {
                    Label(isClaimed ? "担当を外れる" : "担当する",
                          systemImage: isClaimed ? "person.badge.minus" : "person.badge.plus")
                        .font(Theme.Font.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isClaimed ? Theme.Color.statusWarn : Theme.Color.accent)
                        .padding(.horizontal, .spacing10)
                        .padding(.vertical, 5)
                        .background((isClaimed ? Theme.Color.statusWarn : Theme.Color.accent).opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isActioning)
            } else {
                Text(ticket.assignedToUserId.map { "@\($0)" } ?? "なし")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        Card(padding: 0, background: Theme.Color.surface, showBorder: true) {
            VStack(spacing: 0) {
                SectionLabel(title: "メッセージ (\(ticket.messageCount))")
                    .padding(.horizontal, .spacing16)
                    .padding(.vertical, .spacing10)

                Divider().background(Theme.Color.line)

                if isLoadingMessages {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.spacing24)
                } else if let err = loadError {
                    VStack(spacing: .spacing12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.Color.textTertiary)
                        Text(err)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                        Button { Task { await loadMessages() } } label: {
                            Label("再試行", systemImage: "arrow.clockwise")
                                .font(Theme.Font.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.spacing16)
                } else if messages.isEmpty {
                    Text("メッセージはありません")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .padding(.spacing16)
                } else {
                    LazyVStack(spacing: .spacing8) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg, myUserId: myUserId)
                        }
                    }
                    .padding(.spacing12)
                }
            }
        }
    }

    // MARK: - Reply Bar
    // Noxy: sur 背景 + line 上境界

    private var replyBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.Color.line)
            HStack(spacing: .spacing10) {
                ZStack(alignment: .topLeading) {
                    if replyText.isEmpty && !isReplyFocused {
                        Text("スタッフとして返信…")
                            .foregroundStyle(Theme.Color.textTertiary)
                            .font(Theme.Font.body)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $replyText)
                        .font(Theme.Font.body)
                        .frame(minHeight: 38, maxHeight: 100)
                        .scrollContentBackground(.hidden)
                        .focused($isReplyFocused)
                }
                .padding(.horizontal, .spacing10)
                .padding(.vertical, .spacing6)
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                Button {
                    let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task { await sendReply() }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 24, height: 24)
                            .tint(Theme.Color.accent)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundStyle(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.Color.textTertiary : Theme.Color.accent)
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing10)
            .padding(.bottom, .spacing10)
            .background(Theme.Color.surface)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("完了") { dismiss() }
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if ticket.status == .open {
                    Button { Task { await setStatus(.pending) } } label: {
                        Label("対応開始", systemImage: "clock.fill")
                    }
                    .disabled(isActioning)
                } else if ticket.status == .pending {
                    Button { Task { await setStatus(.open) } } label: {
                        Label("対応待ちに戻す", systemImage: "envelope.open.fill")
                    }
                    .disabled(isActioning)
                }

                if ticket.status != .closed {
                    Button(role: .destructive) { showCloseConfirm = true } label: {
                        Label("チケットをクローズ", systemImage: "lock.fill")
                    }
                    .disabled(isActioning)
                } else {
                    Button { Task { await setStatus(.open) } } label: {
                        Label("再オープン", systemImage: "lock.open.fill")
                    }
                    .disabled(isActioning)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
            }
            .disabled(isActioning)
        }
    }

    // MARK: - Helpers
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
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
        .contentShape(Rectangle())
        .onLongPressGesture {
            UIPasteboard.general.string = value
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func infoRowMono(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
            MonoText(value: value, font: Theme.Font.mono, color: Theme.Color.textPrimary)
        }
        .padding(.horizontal, .spacing16)
        .padding(.vertical, .spacing12)
        .contentShape(Rectangle())
        .onLongPressGesture {
            UIPasteboard.general.string = value
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Actions

    private func loadMessages() async {
        isLoadingMessages = true
        loadError = nil
        do {
            messages = try await services.tickets.fetchMessages(ticketId: ticket.id)
        } catch {
            loadError = "メッセージの読み込みに失敗しました。"
        }
        isLoadingMessages = false
    }

    private func sendReply() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        errorMessage = nil
        do {
            try await services.tickets.reply(ticketId: ticket.id, message: text)
            replyText = ""
            ticket.messageCount += 1
            ticket.lastMessageAt = .now
            onUpdate(ticket)
            await loadMessages()
            if ticket.status == .open {
                try? await services.tickets.setStatus(id: ticket.id, status: .pending)
                ticket.status = .pending
                onUpdate(ticket)
            }
        } catch {
            errorMessage = "送信に失敗しました。もう一度お試しください。"
        }
        isSending = false
    }

    private func setStatus(_ newStatus: TicketStatus) async {
        isActioning = true
        errorMessage = nil
        do {
            try await services.tickets.setStatus(id: ticket.id, status: newStatus)
            ticket.status = newStatus
            if newStatus == .closed {
                ticket.closedAt = .now
            } else if newStatus == .open || newStatus == .pending {
                ticket.closedAt = nil
            }
            onUpdate(ticket)
        } catch {
            errorMessage = "ステータスの変更に失敗しました。"
        }
        isActioning = false
    }

    private func closeTicket() async {
        await setStatus(.closed)
    }

    private func changePriority(_ priority: TicketPriority) async {
        isActioning = true
        errorMessage = nil
        do {
            try await services.tickets.updatePriority(id: ticket.id, priority: priority)
            ticket.priority = priority
            onUpdate(ticket)
        } catch {
            errorMessage = "優先度の変更に失敗しました。"
        }
        isActioning = false
    }

    private func claimTicket() async {
        isActioning = true
        errorMessage = nil
        let targetId = isClaimed ? "" : myUserId
        do {
            try await services.tickets.assign(ticketId: ticket.id, userId: targetId)
            ticket.assignedToUserId = targetId.isEmpty ? nil : targetId
            onUpdate(ticket)
        } catch {
            errorMessage = "担当者の変更に失敗しました。"
        }
        isActioning = false
    }
}

// MARK: - MessageBubble
// source == "app"  → 右側「あなた(app)」
// source != "app" && userId == myUserId → 右側「あなた(discord)」
// それ以外 → 左側

private struct MessageBubble: View {
    let message: TicketMessage
    let myUserId: String

    private var isMine: Bool {
        if message.source == "app" { return true }
        return !myUserId.isEmpty && message.userId == myUserId
    }

    private var senderLabel: String {
        if message.source == "app" { return "あなた(app)" }
        if !myUserId.isEmpty && message.userId == myUserId { return "あなた(discord)" }
        return message.username
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: .spacing8) {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                // ヘッダー（名前・ロール・時刻）
                HStack(spacing: 5) {
                    if isMine {
                        MonoText(
                            value: message.createdAt.formatted(.dateTime.hour().minute()),
                            font: Theme.Font.monoCap,
                            color: Theme.Color.textTertiary
                        )
                        if message.isStaff {
                            Label("スタッフ", systemImage: "shield.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.Color.accent)
                        }
                    }
                    Text(senderLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.textTertiary)
                    if !isMine {
                        MonoText(
                            value: message.createdAt.formatted(.dateTime.hour().minute()),
                            font: Theme.Font.monoCap,
                            color: Theme.Color.textTertiary
                        )
                    }
                }

                // メッセージ本文
                Text(message.content)
                    .font(Theme.Font.body)
                    .foregroundStyle(isMine ? Theme.Color.accentInk : Theme.Color.textPrimary)
                    .multilineTextAlignment(isMine ? .trailing : .leading)
                    .padding(.horizontal, .spacing12)
                    .padding(.vertical, .spacing8)
                    .background(isMine ? Theme.Color.accent : Theme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)

            if !isMine { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        TicketDetailView(
            ticket: MockData.tickets[0],
            guildId: "g003",
            onUpdate: { _ in }
        )
    }
    .environment(\.services, ServiceContainer.mock())
    .environment(AppState())
}
