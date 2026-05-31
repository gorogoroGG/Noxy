import SwiftUI

struct MembersListView: View {
    let guildId: String
    @Environment(\.services) private var services
    @State private var members: [Member] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var selectedMember: Member? = nil

    private let filters = ["すべて", "オンライン", "ブースター", "スタッフ", "BAN済み"]

    private var filtered: [Member] {
        var base = members
        if !searchText.isEmpty {
            base = base.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.username.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch selectedFilter {
        case "オンライン":   return base.filter { $0.status == .online }
        case "ブースター": return base.filter { $0.isBoosting }
        case "スタッフ":    return base.filter { $0.roles.contains(where: { ["Admin","Moderator","Staff"].contains($0) }) }
        default:         return base
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacing8) {
                    ForEach(filters, id: \.self) { filter in
                        FilterPill(title: filter, isSelected: selectedFilter == filter) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, .spacing8)
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else if filtered.isEmpty {
                EmptyStateView(icon: "person.slash", title: "メンバーが見つかりません")
            } else {
                List {
                    ForEach(filtered) { member in
                        MemberRow(member: member)
                            .onTapGesture { selectedMember = member }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "メンバーを検索")
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member)
        }
        .task { await load() }
    }

    private func load() async {
        members = (try? await services.members.fetchMembers(guildId: guildId)) ?? []
        isLoading = false
    }
}

private struct MemberRow: View {
    let member: Member

    private var statusColor: OnlineStatus {
        switch member.status {
        case .online:  .online
        case .idle:    .idle
        case .dnd:     .dnd
        case .offline: .offline
        }
    }

    var body: some View {
        HStack(spacing: .spacing12) {
            Avatar(name: member.displayName, size: 40, status: statusColor,
                   accentColor: member.isBoosting ? .accentPink : .accentIndigo)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: .spacing8) {
                    Text(member.displayName)
                        .font(.titleMedium)
                        .foregroundStyle(Color.textPrimary)
                    if member.isBoosting {
                        Badge(text: "BOOST", color: .accentPink)
                    }
                }
                HStack(spacing: .spacing4) {
                    Text("@" + member.username)
                        .font(.captionRegular)
                        .foregroundStyle(Color.textTertiary)
                    if !member.roles.isEmpty {
                        Text("·")
                            .foregroundStyle(Color.textTertiary)
                            .font(.captionRegular)
                        Text(member.roles.prefix(2).joined(separator: ", "))
                            .font(.captionRegular)
                            .foregroundStyle(Color.accentIndigo)
                    }
                }
            }

            Spacer()

            Text(member.joinedAt.formatted(.relative(presentation: .named)))
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, .spacing4)
    }
}

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.captionRegular)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .padding(.horizontal, .spacing12)
                .padding(.vertical, .spacing6)
                .background(Capsule().fill(isSelected ? Color.accentIndigo : Color.bgSurface))
        }
        .buttonStyle(.plain)
    }
}

struct MemberDetailView: View {
    let member: Member
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @State private var showBanConfirm = false

    private var statusColor: OnlineStatus {
        switch member.status {
        case .online:  .online
        case .idle:    .idle
        case .dnd:     .dnd
        case .offline: .offline
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: .spacing12) {
                            Avatar(name: member.displayName, size: 80, status: statusColor,
                                   accentColor: member.isBoosting ? .accentPink : .accentIndigo)
                            Text(member.displayName)
                                .font(.displayMedium)
                                .foregroundStyle(Color.textPrimary)
                            Text("@" + member.username)
                                .font(.bodySmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                }

                // Info
                Section("情報") {
                    LabeledContent("参加日") {
                        Text(member.joinedAt.formatted(date: .abbreviated, time: .omitted))
                    }
                    if member.isBoosting {
                        HStack {
                            Text("ブースト中")
                            Spacer()
                            Badge(text: "BOOST", color: .accentPink)
                        }
                    }
                }

                // Roles
                Section("ロール") {
                    if member.roles.isEmpty {
                        Text("ロールなし").foregroundStyle(Color.textTertiary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: .spacing8) {
                                ForEach(member.roles, id: \.self) { role in
                                    Badge(text: role, color: .accentIndigo, style: .outlined)
                                }
                            }
                        }
                    }
                }

                // Actions
                Section("アクション") {
                    Button("DMを送信") {}
                        .foregroundStyle(Color.accentIndigo)
                    Button("タイムアウト") {}
                        .foregroundStyle(Color.accentOrange)
                    Button("キック") {}
                        .foregroundStyle(Color.accentOrange)
                    Button("BAN", role: .destructive) {
                        showBanConfirm = true
                    }
                }
            }
            .navigationTitle(member.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
            .confirmationDialog("\(member.displayName)をBANしますか?", isPresented: $showBanConfirm, titleVisibility: .visible) {
                Button("BAN", role: .destructive) {
                    Task {
                        try? await services.members.ban(memberId: member.id, guildId: member.guildId, reason: nil)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MembersListView(guildId: "g001")
        .environment(\.services, ServiceContainer.live())
        .preferredColorScheme(.dark)
}
