import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.services) private var services
    @Environment(AppState.self) private var appState
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
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { notification in
                                NotificationRow(
                                    notification: notification,
                                    guildName: notification.guildId.flatMap { gid in
                                        appState.guilds.first { $0.id == gid }?.name
                                            ?? appState.botGuilds.first { $0.id == gid }?.name
                                    },
                                    onTap: { markRead(notification) }
                                )
                                .swipeActions(edge: .leading) {
                                    Button {
                                        markRead(notification)
                                    } label: {
                                        Label("既読", systemImage: "envelope.open.fill")
                                    }
                                    .tint(Theme.Color.accent)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteNotification(notification)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                                if notification.id != filtered.last?.id {
                                    Divider().background(Theme.Color.line)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                    .background(Theme.Color.bg)
                }
            }
            .background(Theme.Color.bg)
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("すべて既読") {
                        Task { try? await services.notifications.markAllRead() }
                        notifications.indices.forEach { notifications[$0].read = true }
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.accent)
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

    private func deleteNotification(_ notification: AppNotification) {
        Task { try? await services.notifications.delete(id: notification.id) }
        withAnimation {
            notifications.removeAll { $0.id == notification.id }
        }
    }
}

private struct NotificationRow: View {
    let notification: AppNotification
    let guildName: String?
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

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                // Unread indicator
                StatusDot(color: notification.read ? Color.clear : Theme.Color.accent)

                // Icon
                Image(systemName: typeIcon)
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(notification.read ? Theme.Font.bodySmall : Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)

                    Text(notification.body)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: Theme.Spacing.sm) {
                        if let name = guildName {
                            Text(name)
                                .font(Theme.Font.caption2)
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                        Text(notification.timestamp.formatted(.relative(presentation: .named)))
                            .font(Theme.Font.caption2)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    NotificationCenterView()
        .environment(\.services, ServiceContainer.mock())
        .environment(AppState())
}

#Preview("Dark") {
    NotificationCenterView()
        .environment(\.services, ServiceContainer.mock())
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    NotificationCenterView()
        .environment(\.services, ServiceContainer.mock())
        .environment(AppState())
        .preferredColorScheme(.light)
}
