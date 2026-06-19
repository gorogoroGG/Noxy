import SwiftUI

struct PersonalInviteLinksView: View {
    let guildId: String

    @Environment(\.services) private var services

    @State private var links: [PersonalInviteLink] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var linkToRevoke: PersonalInviteLink?
    @State private var showRevokeAlert = false

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            Group {
                if isLoading {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Card(padding: 0) {
                                ForEach(0..<5, id: \.self) { i in
                                    PersonalInviteRowSkeleton()
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.sm)
                                    if i < 4 {
                                        Divider().background(Theme.Color.line).padding(.leading, Theme.Spacing.md)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                } else if filtered.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: searchText.isEmpty ? "link.badge.plus" : "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.Color.textTertiary)
                        VStack(spacing: Theme.Spacing.xs) {
                            Text(searchText.isEmpty ? "リンクなし" : "見つかりません")
                                .font(Theme.Font.title3)
                                .foregroundStyle(Theme.Color.textPrimary)
                            Text(searchText.isEmpty
                                 ? "まだ誰も招待リンクを作成していません"
                                 : "「\(searchText)」に一致するメンバーはいません")
                                .font(Theme.Font.bodySmall)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            HStack {
                                Text("\(filtered.count)件")
                                    .font(Theme.Font.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.Color.textTertiary)
                                    .textCase(.uppercase)
                                Spacer()
                            }

                            Card(padding: 0) {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, link in
                                    PersonalInviteRow(link: link) {
                                        linkToRevoke = link
                                        showRevokeAlert = true
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    if idx < filtered.count - 1 {
                                        Divider().background(Theme.Color.line).padding(.leading, Theme.Spacing.md)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                }
            }
        }
        .navigationTitle("個人招待リンク")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "メンバーで検索")
        .task { await load() }
        .refreshable { await load() }
        .alert("リンクを無効化", isPresented: $showRevokeAlert, presenting: linkToRevoke) { link in
            Button("無効化", role: .destructive) { Task { await revoke(link) } }
            Button("キャンセル", role: .cancel) {}
        } message: { link in
            Text("\(link.displayName) の招待リンク（discord.gg/\(link.inviteCode)）を無効化します。この操作は元に戻せません。")
        }
    }

    // MARK: - Computed

    private var filtered: [PersonalInviteLink] {
        guard !searchText.isEmpty else { return links }
        let q = searchText.lowercased()
        return links.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.username.lowercased().contains(q) ||
            $0.inviteCode.lowercased().contains(q)
        }
    }

    // MARK: - Data

    private func load() async {
        if let result = try? await services.inviteTracker.fetchPersonalInviteLinks(guildId: guildId) {
            links = result.sorted { $0.createdAt > $1.createdAt }
        }
        isLoading = false
    }

    private func revoke(_ link: PersonalInviteLink) async {
        try? await services.inviteTracker.revokePersonalInviteLink(id: link.id)
        withAnimation { links.removeAll { $0.id == link.id } }
    }
}

// MARK: - Row

private struct PersonalInviteRow: View {
    let link: PersonalInviteLink
    let onRevoke: () -> Void

    @State private var isCopied = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            AvatarCircle(displayName: link.displayName, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(link.displayName)
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Color.textPrimary)
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "link")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.accent)
                    Text("discord.gg/\(link.inviteCode)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.Color.accent)
                }
                Text(link.createdAt.formatted(date: .abbreviated, time: .shortened) + "に作成")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    UIPasteboard.general.string = link.inviteUrl
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCopied = false }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(Theme.Font.caption)
                        .foregroundStyle(isCopied ? Theme.Color.statusOK : Theme.Color.textTertiary)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) { onRevoke() } label: {
                    Image(systemName: "trash")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.statusBad.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PersonalInviteRowSkeleton: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle().fill(Theme.Color.textTertiary.opacity(0.1)).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(Theme.Color.textTertiary.opacity(0.1)).frame(width: 90, height: 12)
                RoundedRectangle(cornerRadius: 3).fill(Theme.Color.textTertiary.opacity(0.1)).frame(width: 150, height: 10)
                RoundedRectangle(cornerRadius: 3).fill(Theme.Color.textTertiary.opacity(0.1)).frame(width: 120, height: 9)
            }
        }
        .redacted(reason: .placeholder)
    }
}

#Preview {
    NavigationStack {
        PersonalInviteLinksView(guildId: "g001")
    }
    .environment(AppState())
    .environment(\.services, ServiceContainer.mock())
}
