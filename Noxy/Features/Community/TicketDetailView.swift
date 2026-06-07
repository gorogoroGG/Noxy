import SwiftUI

// MARK: - TicketDetailView
// 1件のチケット詳細。メッセージ履歴、返信、ステータス変更、優先度変更、担当者割り当てを行う。
// 初心者向けに、ステップインジケータで現在の対応状況を視覚的に表示する。

struct TicketDetailView: View {
    @State var ticket: Ticket
    let guildId: String
    let onUpdate: (Ticket) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss)  private var dismiss
    @Environment(\.colorScheme) private var colorScheme

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

    // MARK: - Status Workflow (視覚的ステップ表示)

    private var statusWorkflow: some View {
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
        .padding(.spacing12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func stepCell(title: String, icon: String, isActive: Bool, isCompleted: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentIndigo : (isCompleted ? Color.accentGreen : Color(.tertiarySystemGroupedBackground)))
                    .frame(width: 32, height: 32)
                Image(systemName: isCompleted ? "checkmark" : icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive || isCompleted ? .white : Color.textTertiary)
            }
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentIndigo : (isCompleted ? Color.accentGreen : Color.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private func stepConnector(isCompleted: Bool) -> some View {
        Rectangle()
            .fill(isCompleted ? Color.accentGreen : Color(.tertiarySystemGroupedBackground))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .offset(y: -10)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            cardHeader("詳細", icon: "ticket.fill", color: .accentIndigo)
            Divider()

            infoRow("開設者", value: "@\(ticket.openedBy)")
            Divider().padding(.leading, .spacing16)
            infoRow("開設日時", value: ticket.openedAt.formatted(date: .abbreviated, time: .shortened))
            Divider().padding(.leading, .spacing16)
            infoRow("ステータス", value: ticket.status.label)

            // 優先度（送信中は無効化）
            Divider().padding(.leading, .spacing16)
            HStack {
                Text("優先度").font(.bodySmall).foregroundStyle(Color.textSecondary)
                Spacer()
                HStack(spacing: .spacing6) {
                    ForEach(TicketPriority.allCases, id: \.self) { p in
                        Button {
                            guard ticket.priority != p else { return }
                            Task { await changePriority(p) }
                        } label: {
                            Text(p.label)
                                .font(.system(size: 11, weight: ticket.priority == p ? .bold : .regular))
                                .foregroundStyle(ticket.priority == p ? .white : Color.textSecondary)
                                .padding(.horizontal, .spacing8).padding(.vertical, 4)
                                .background(ticket.priority == p ? p.color : Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isActioning)
                    }
                }
            }
            .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)

            // 担当者
            Divider().padding(.leading, .spacing16)
            claimRow

            if let closedAt = ticket.closedAt {
                Divider().padding(.leading, .spacing16)
                infoRow("クローズ", value: closedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let err = errorMessage {
                Divider()
                HStack(spacing: .spacing8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(err).font(.captionSmall).foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, .spacing16).padding(.vertical, .spacing10)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var claimRow: some View {
        HStack {
            Text("担当者").font(.bodySmall).foregroundStyle(Color.textSecondary)
            Spacer()
            if let assignee = ticket.assignedToUserId, !assignee.isEmpty, assignee != myUserId {
                // 他のスタッフが担当中
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.clock.fill")
                        .font(.captionSmall)
                        .foregroundStyle(Color.accentIndigo)
                    Text("@\(assignee)")
                        .font(.bodySmall)
                        .foregroundStyle(Color.textTertiary)
                }
            } else if ticket.status != .closed {
                Button { Task { await claimTicket() } } label: {
                    Label(isClaimed ? "担当を外れる" : "担当する",
                          systemImage: isClaimed ? "person.badge.minus" : "person.badge.plus")
                        .font(.captionRegular).fontWeight(.medium)
                        .foregroundStyle(isClaimed ? Color.accentOrange : Color.accentIndigo)
                        .padding(.horizontal, .spacing10).padding(.vertical, 5)
                        .background((isClaimed ? Color.accentOrange : Color.accentIndigo).opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isActioning)
            } else {
                Text(ticket.assignedToUserId.map { "@\($0)" } ?? "なし")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        VStack(spacing: 0) {
            cardHeader("メッッセージ (\(ticket.messageCount))",
                       icon: "bubble.left.and.bubble.right.fill", color: .accentGreen)
            Divider()
            if isLoadingMessages {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(.spacing24)
            } else if let err = loadError {
                VStack(spacing: .spacing12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.textTertiary)
                    Text(err)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                    Button { Task { await loadMessages() } } label: {
                        Label("再試行", systemImage: "arrow.clockwise")
                            .font(.captionSmall)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.spacing16)
            } else if messages.isEmpty {
                Text("メッセージはありません")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.spacing16)
            } else {
                LazyVStack(spacing: .spacing8) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg)
                    }
                }
                .padding(.spacing12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Reply Bar（キーボード対応）

    private var replyBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: .spacing10) {
                ZStack(alignment: .topLeading) {
                    if replyText.isEmpty && !isReplyFocused {
                        Text("スタッフとして返信…")
                            .foregroundStyle(Color.textTertiary)
                            .font(.bodySmall)
                            .padding(.top, 8).padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $replyText)
                        .font(.bodySmall)
                        .frame(minHeight: 38, maxHeight: 100)
                        .scrollContentBackground(.hidden)
                        .focused($isReplyFocused)
                }
                .padding(.horizontal, .spacing10).padding(.vertical, .spacing6)
                .background(Color(.tertiarySystemGroupedBackground))
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
                            .tint(Color.accentIndigo)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundStyle(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.textTertiary : Color.accentIndigo)
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, .spacing16).padding(.top, .spacing10)
            .padding(.bottom, .spacing10)
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("完了") { dismiss() }
                .foregroundStyle(Color.accentIndigo)
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
                    .foregroundStyle(Color.accentIndigo)
            }
            .disabled(isActioning)
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
        }
        .padding(.horizontal, .spacing16).padding(.vertical, .spacing12)
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
            // 返信したら自動的に対応中に
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

private struct MessageBubble: View {
    let message: TicketMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: .spacing8) {
            if message.isStaff { Spacer(minLength: 40) }

            VStack(alignment: message.isStaff ? .trailing : .leading, spacing: 3) {
                // ヘッダー（名前・ロール・時刻）
                HStack(spacing: 5) {
                    if message.isStaff {
                        Text(message.createdAt.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textTertiary)
                        Label("スタッフ", systemImage: "shield.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.accentIndigo)
                    }
                    Text(message.username)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                    if !message.isStaff {
                        Text(message.createdAt.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                // メッセージ本文
                Text(message.content)
                    .font(.bodySmall)
                    .foregroundStyle(message.isStaff ? .white : Color.textPrimary)
                    .multilineTextAlignment(message.isStaff ? .trailing : .leading)
                    .padding(.horizontal, .spacing12).padding(.vertical, .spacing8)
                    .background(message.isStaff ? Color.accentIndigo : Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: message.isStaff ? .trailing : .leading)

            if !message.isStaff { Spacer(minLength: 40) }
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
