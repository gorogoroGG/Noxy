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
        List {
            if isLoading {
                ForEach(0..<5, id: \.self) { _ in
                    PersonalInviteRowSkeleton()
                }
            } else if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "リンクなし" : "見つかりません",
                    systemImage: searchText.isEmpty ? "link.badge.plus" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                                      ? "まだ誰も招待リンクを作成していません"
                                      : "「\(searchText)」に一致するメンバーはいません")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filtered) { link in
                        PersonalInviteRow(link: link) {
                            linkToRevoke = link
                            showRevokeAlert = true
                        }
                    }
                } header: {
                    Text("\(filtered.count)件")
                }
            }
        }
        .listStyle(.insetGrouped)
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
        HStack(spacing: .spacing12) {
            AvatarCircle(displayName: link.displayName, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(link.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: .spacing4) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentPurple)
                    Text("discord.gg/\(link.inviteCode)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.accentPurple)
                }
                Text(link.createdAt.formatted(date: .abbreviated, time: .shortened) + "に作成")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            VStack(spacing: .spacing6) {
                Button {
                    UIPasteboard.general.string = link.inviteUrl
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCopied = false }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(isCopied ? Color.accentGreen : Color.textTertiary)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) { onRevoke() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, .spacing4)
    }
}

private struct PersonalInviteRowSkeleton: View {
    var body: some View {
        HStack(spacing: .spacing12) {
            Circle().fill(Color.textTertiary.opacity(0.1)).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(Color.textTertiary.opacity(0.1)).frame(width: 90, height: 12)
                RoundedRectangle(cornerRadius: 3).fill(Color.textTertiary.opacity(0.1)).frame(width: 150, height: 10)
                RoundedRectangle(cornerRadius: 3).fill(Color.textTertiary.opacity(0.1)).frame(width: 120, height: 9)
            }
        }
        .padding(.vertical, .spacing4)
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
