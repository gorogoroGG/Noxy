import SwiftUI

struct InviteMemberDetailView: View {
    let guildId: String
    let stats: InviteStats

    @Environment(\.services) private var services

    @State private var detail: InviteMemberDetail?
    @State private var isLoading = true
    @State private var showTree = false

    var body: some View {
        List {
            statsCardsSection
            invitePathSection
            recentInviteesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(stats.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTree = true
                } label: {
                    Image(systemName: "person.3")
                }
            }
        }
        .navigationDestination(isPresented: $showTree) {
            InviteTreeView(guildId: guildId, rootUserId: stats.userId, rootName: stats.displayName)
        }
        .task { await load() }
    }

    // MARK: - Sections

    private var statsCardsSection: some View {
        Section {
            // Header
            HStack(spacing: .spacing16) {
                AvatarCircle(displayName: stats.displayName, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    if let rank = stats.rank {
                        Label("ランク #\(rank)", systemImage: "trophy")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentOrange)
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.vertical, .spacing8)

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: .spacing8) {
                InviteStatCard(value: "\(stats.validInvites)",  label: "有効招待",  color: .accentGreen)
                InviteStatCard(value: "\(stats.leftInvites)",   label: "退出数",    color: Color.orange)
                InviteStatCard(value: "\(stats.fakeInvites)",   label: "偽招待",    color: Color.red.opacity(0.7))
                InviteStatCard(value: "\(stats.treeSize)",      label: "派生人数",  color: .accentPurple)
                InviteStatCard(value: "\(stats.influenceScore)", label: "影響力",   color: .accentPink)
                InviteStatCard(value: retentionText,            label: "定着率",    color: .accentGreen)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: .spacing16, bottom: .spacing8, trailing: .spacing16))
        }
    }

    private var invitePathSection: some View {
        Section("招待ルート") {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let detail {
                if let invitedBy = detail.invitedByDisplayName {
                    HStack(spacing: .spacing8) {
                        Image(systemName: "arrow.up.circle")
                            .foregroundStyle(Color.textTertiary)
                            .frame(width: 20)
                        Text("招待者")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                        Text(invitedBy)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                    }
                }

                if !detail.invitePathDisplayNames.isEmpty {
                    HStack(alignment: .top, spacing: .spacing8) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(Color.textTertiary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("招待チェーン")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                            Text(detail.invitePathDisplayNames.joined(separator: " → "))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }

                if detail.invitedByDisplayName == nil && detail.invitePathDisplayNames.isEmpty {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.accentOrange)
                        Text("このサーバーの創始メンバー")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }

    private var recentInviteesSection: some View {
        Section {
            if isLoading {
                ForEach(0..<3, id: \.self) { _ in
                    InviteeRowSkeleton()
                }
            } else if let invitees = detail?.recentInvitees, !invitees.isEmpty {
                ForEach(invitees) { entry in
                    InviteeRow(entry: entry)
                }
            } else {
                Text("まだ招待した人はいません")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spacing8)
            }
        } header: {
            HStack {
                Text("招待したメンバー")
                if let count = detail?.recentInvitees.count, count > 0 {
                    Text("(\(count))")
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
                NavigationLink {
                    InviteTreeView(guildId: guildId, rootUserId: stats.userId, rootName: stats.displayName)
                } label: {
                    Text("樹形図を見る")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentPurple)
                }
            }
        }
    }

    // MARK: - Helpers

    private var retentionText: String {
        let pct = Int(stats.retentionRate * 100)
        return "\(pct)%"
    }

    private func load() async {
        if let result = try? await services.inviteTracker.fetchMemberDetail(
            guildId: guildId, userId: stats.userId
        ) {
            detail = result
        }
        isLoading = false
    }
}

// MARK: - Stat Card

private struct InviteStatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacing10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))
    }
}

// MARK: - Invitee Row

private struct InviteeRow: View {
    let entry: InviteEventEntry

    var body: some View {
        HStack(spacing: .spacing12) {
            AvatarCircle(displayName: entry.displayName, size: 32)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(entry.isCurrentMember ? Color.accentGreen : Color.red.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .offset(x: 1, y: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text(entry.joinedAt.formatted(date: .abbreviated, time: .omitted) + "に参加")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            if !entry.isCurrentMember {
                Text("退出")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.red.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

private struct InviteeRowSkeleton: View {
    var body: some View {
        HStack(spacing: .spacing12) {
            Circle().fill(Color.textTertiary.opacity(0.1)).frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 3).fill(Color.textTertiary.opacity(0.1)).frame(width: 90, height: 11)
                RoundedRectangle(cornerRadius: 3).fill(Color.textTertiary.opacity(0.1)).frame(width: 120, height: 9)
            }
        }
        .padding(.vertical, 2)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InviteMemberDetailView(
            guildId: "g001",
            stats: InviteStats(
                userId: "u001", guildId: "g001",
                username: "taro", displayName: "太郎",
                avatarUrl: nil,
                totalInvites: 15, validInvites: 12, leftInvites: 2, fakeInvites: 1,
                influenceScore: 89, treeSize: 8, retentionRate: 0.80, rank: 1
            )
        )
    }
    .environment(AppState())
    .environment(\.services, ServiceContainer.mock())
}
