import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.services) private var services
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var selectedFilter = "All"

    private let filters = ["すべて", "メンション", "チケット", "システム"]

    private var filtered: [AppNotification] {
        switch selectedFilter {
        case "メンション": return notifications.filter { $0.type == .mention }
        case "チケット":  return notifications.filter { $0.type == .ticket }
        case "システム":   return notifications.filter { $0.type == .system || $0.type == .botStatus }
        default:         return notifications
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(filters, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if isLoading {
                    ProgressView()
                } else if filtered.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle.fill",
                        title: "すべて確認済みです",
                        description: "新しい通知はありません。"
                    )
                } else {
                    List {
                        ForEach(filtered) { notification in
                            NotificationRow(notification: notification) {
                                markRead(notification)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    markRead(notification)
                                } label: {
                                    Label("既読", systemImage: "envelope.open.fill")
                                }
                                .tint(Color.accentIndigo)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("すべて既読") {
                        Task { try? await services.notifications.markAllRead() }
                        notifications.indices.forEach { notifications[$0].read = true }
                    }
                    .font(.captionRegular)
                    .foregroundStyle(Color.accentIndigo)
                }
            }
        }
        .task {
            notifications = (try? await services.notifications.fetchAll()) ?? []
            isLoading = false
        }
    }

    private func markRead(_ notification: AppNotification) {
        Task { try? await services.notifications.markRead(id: notification.id) }
        if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[idx].read = true
        }
    }
}

private struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    private var typeIcon: String {
        switch notification.type {
        case .mention:       "at"
        case .ticket:        "ticket.fill"
        case .system:        "gear"
        case .memberJoin:    "person.badge.plus"
        case .botStatus:     "bolt.fill"
        case .scheduledSend: "calendar.badge.clock"
        }
    }

    private var typeColor: Color {
        switch notification.type {
        case .mention:       .accentPink
        case .ticket:        .accentOrange
        case .system:        .textSecondary
        case .memberJoin:    .accentGreen
        case .botStatus:     .accentIndigo
        case .scheduledSend: .accentPurple
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: .spacing12) {
                // Unread indicator
                Circle()
                    .fill(notification.read ? Color.clear : Color.accentIndigo)
                    .frame(width: 8, height: 8)

                // Icon
                Image(systemName: typeIcon)
                    .font(.titleMedium)
                    .foregroundStyle(typeColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(notification.read ? .bodySmall : .titleMedium)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(notification.body)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: .spacing8) {
                        if let guildId = notification.guildId,
                           let guildName = MockData.guilds.first(where: { $0.id == guildId })?.name {
                            Text(guildName)
                                .font(.captionSmall)
                                .foregroundStyle(Color.textTertiary)
                        }
                        Text(notification.timestamp.formatted(.relative(presentation: .named)))
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(.vertical, .spacing4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NotificationCenterView()
        .environment(\.services, ServiceContainer.live())
}
