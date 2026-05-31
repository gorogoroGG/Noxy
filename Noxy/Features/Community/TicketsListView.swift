import SwiftUI

// MARK: - TicketsListView

struct TicketsListView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var tickets: [Ticket] = []
    @State private var isLoading = true
    @State private var selectedStatus: TicketStatus = .open
    @State private var selectedTicket: Ticket? = nil

    private var filtered: [Ticket] {
        tickets.filter { $0.status == selectedStatus }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Status", selection: $selectedStatus) {
                Text("オープン").tag(TicketStatus.open)
                Text("対応中").tag(TicketStatus.pending)
                Text("クローズ").tag(TicketStatus.closed)
            }
            .pickerStyle(.segmented)
            .padding()

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else if filtered.isEmpty {
                EmptyStateView(
                    icon: "ticket",
                    title: "チケットがありません",
                    description: selectedStatus == .closed
                        ? "クローズ済みのチケットはありません"
                        : "現在対応中のチケットはありません"
                )
            } else {
                List {
                    ForEach(filtered) { ticket in
                        TicketRow(ticket: ticket)
                            .onTapGesture { selectedTicket = ticket }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.bgPrimary)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedTicket) { ticket in
            TicketDetailView(ticket: ticket) { updated in
                if let idx = tickets.firstIndex(where: { $0.id == updated.id }) {
                    tickets[idx] = updated
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        tickets = (try? await services.tickets.fetchAll(guildId: guildId)) ?? []
        isLoading = false
    }
}

// MARK: - TicketRow

private struct TicketRow: View {
    let ticket: Ticket

    private var priorityColor: Color {
        switch ticket.priority {
        case .urgent: .red
        case .high:   .accentOrange
        case .medium: .accentIndigo
        case .low:    .accentGreen
        }
    }

    private var statusColor: Color {
        switch ticket.status {
        case .open:    .accentGreen
        case .pending: .accentOrange
        case .closed:  .textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(width: 4)

            HStack(spacing: .spacing12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.subject)
                        .font(.titleMedium)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: .spacing4) {
                        Text("@\(ticket.openedBy)")
                        Text("·")
                        Text(ticket.openedAt.formatted(.relative(presentation: .named)))
                    }
                    .font(.captionRegular)
                    .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Badge(text: ticket.status.rawValue, color: statusColor)
                    Text("\(ticket.messageCount) msg")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.spacing12)
        }
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .padding(.horizontal)
        .padding(.vertical, .spacing4)
    }
}

// MARK: - TicketDetailView

struct TicketDetailView: View {
    @State var ticket: Ticket
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    let onUpdate: (Ticket) -> Void

    @State private var isActioning = false
    @State private var showPriorityPicker = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing16) {

                    // ===== チケット情報 =====
                    VStack(alignment: .leading, spacing: .spacing12) {
                        HStack {
                            Text(ticket.subject)
                                .font(.titleLarge)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            StatusBadge(status: ticket.status)
                        }

                        Divider().background(Color.border)

                        infoRow(label: "開設者", value: "@\(ticket.openedBy)")
                        infoRow(label: "開設日時", value: ticket.openedAt.formatted(date: .abbreviated, time: .shortened))
                        infoRow(label: "メッセージ数", value: "\(ticket.messageCount) 件")
                        if let closed = ticket.lastMessageAt as Date? {
                            infoRow(label: "最終更新", value: closed.formatted(.relative(presentation: .named)))
                        }
                    }
                    .padding()
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))

                    // ===== 優先度 =====
                    VStack(alignment: .leading, spacing: .spacing12) {
                        Text("優先度")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textTertiary)
                            .textCase(.uppercase)

                        HStack(spacing: .spacing8) {
                            ForEach(TicketPriority.allCases, id: \.self) { p in
                                Button {
                                    Task { await changePriority(p) }
                                } label: {
                                    Text(p.label)
                                        .font(.captionRegular)
                                        .fontWeight(ticket.priority == p ? .bold : .regular)
                                        .foregroundStyle(ticket.priority == p ? .white : Color.textSecondary)
                                        .padding(.horizontal, .spacing12)
                                        .padding(.vertical, .spacing6)
                                        .background(
                                            ticket.priority == p
                                                ? p.color
                                                : Color.bgSurface
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))

                    // ===== エラー =====
                    if let errorMessage {
                        Text("❌ \(errorMessage)")
                            .font(.captionRegular)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // ===== アクション =====
                    VStack(spacing: .spacing8) {
                        if ticket.status != .closed {
                            // クローズ
                            Button {
                                Task { await closeTicket() }
                            } label: {
                                actionLabel("🔒 チケットをクローズ", color: .accentOrange)
                            }
                            .buttonStyle(.plain)
                            .disabled(isActioning)
                        } else {
                            // 再オープン
                            Button {
                                Task { await reopenTicket() }
                            } label: {
                                actionLabel("🔓 再オープン", color: .accentGreen)
                            }
                            .buttonStyle(.plain)
                            .disabled(isActioning)
                        }
                    }
                    .padding(.top, .spacing8)

                    // ===== Discordで操作を案内 =====
                    HStack(spacing: .spacing8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.textTertiary)
                        Text("チャットへの返信はDiscordチャンネルで行ってください")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding()
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                }
                .padding()
            }
            .background(Color.bgPrimary)
            .navigationTitle("チケット #\(ticket.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.captionRegular)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.bodySmall)
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, color: Color) -> some View {
        HStack {
            if isActioning {
                ProgressView().scaleEffect(0.8)
            } else {
                Text(title)
                    .font(.titleMedium)
                    .foregroundStyle(color)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    // MARK: - Actions

    private func closeTicket() async {
        isActioning = true
        errorMessage = nil
        do {
            try await services.tickets.close(id: ticket.id)
            ticket.status = .closed
            onUpdate(ticket)
        } catch {
            errorMessage = error.localizedDescription
        }
        isActioning = false
    }

    private func reopenTicket() async {
        isActioning = true
        errorMessage = nil
        do {
            try await services.tickets.reopen(id: ticket.id)
            ticket.status = .open
            onUpdate(ticket)
        } catch {
            errorMessage = error.localizedDescription
        }
        isActioning = false
    }

    private func changePriority(_ priority: TicketPriority) async {
        errorMessage = nil
        do {
            try await services.tickets.updatePriority(id: ticket.id, priority: priority)
            ticket.priority = priority
            onUpdate(ticket)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - StatusBadge

private struct StatusBadge: View {
    let status: TicketStatus
    var body: some View {
        Text(status.label)
            .font(.captionRegular)
            .fontWeight(.semibold)
            .foregroundStyle(status.color)
            .padding(.horizontal, .spacing8)
            .padding(.vertical, .spacing4)
            .background(status.color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - TicketPriority / TicketStatus extensions

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
    var color: Color {
        switch self {
        case .open:    .accentGreen
        case .pending: .accentOrange
        case .closed:  .textTertiary
        }
    }
}

// MARK: - Preview

#Preview {
    TicketsListView(guildId: "1509488000504168499")
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}
