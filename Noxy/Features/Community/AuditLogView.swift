import SwiftUI

struct AuditLogView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var logs: [AuditLog] = []
    @State private var isLoading = true
    @State private var expandedLogId: String? = nil

    private var groupedLogs: [(String, [AuditLog])] {
        let grouped = Dictionary(grouping: logs) { log -> String in
            Calendar.current.isDateInToday(log.timestamp) ? "今日" :
            Calendar.current.isDateInYesterday(log.timestamp) ? "昨日" :
            log.timestamp.formatted(date: .abbreviated, time: .omitted)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if logs.isEmpty {
                EmptyStateView(icon: "doc.text", title: "No audit logs")
            } else {
                List {
                    ForEach(groupedLogs, id: \.0) { (dateLabel, entries) in
                        Section(dateLabel) {
                            ForEach(entries) { log in
                                AuditLogRow(log: log,
                                            isExpanded: expandedLogId == log.id) {
                                    withAnimation {
                                        expandedLogId = expandedLogId == log.id ? nil : log.id
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        logs = (try? await services.auditLogs.fetch(guildId: guildId, page: 0)) ?? []
        isLoading = false
    }
}

private struct AuditLogRow: View {
    let log: AuditLog
    let isExpanded: Bool
    let onTap: () -> Void

    private var icon: String {
        switch log.action {
        case "member_ban":     "hammer.fill"
        case "member_kick":    "person.badge.minus"
        case "embed_sent":     "paperplane.fill"
        case "role_added":     "person.badge.plus"
        case "bot_restart":    "arrow.clockwise"
        case "command_toggle": "bolt.badge.checkmark"
        default:               "doc.text.fill"
        }
    }

    private var iconColor: Color {
        switch log.action {
        case "member_ban", "member_kick": .accentRed
        case "embed_sent":  .accentGreen
        case "role_added":  .accentIndigo
        case "bot_restart": .accentOrange
        default:            .textSecondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: .spacing8) {
                HStack(spacing: .spacing12) {
                    Image(systemName: icon)
                        .font(.titleMedium)
                        .foregroundStyle(iconColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(log.userId) → \(log.action.replacingOccurrences(of: "_", with: " ")) → \(log.target)")
                            .font(.bodySmall)
                            .foregroundStyle(Color.textPrimary)

                        Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.captionSmall)
                        .foregroundStyle(Color.textTertiary)
                }

                if isExpanded, let details = log.details {
                    Text(details)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.leading, 44)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuditLogView(guildId: "g001")
        .environment(\.services, ServiceContainer.live())
}
