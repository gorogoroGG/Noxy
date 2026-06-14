import SwiftUI

struct ModBanListView: View {
    let guildId: String

    @State private var loadState: LoadState<[BannedUser]> = .loading
    @State private var unbanTarget: BannedUser? = nil
    @State private var showUnbanConfirm = false
    @State private var isWorking = false
    @State private var toast: String? = nil
    @State private var selectedMember: Member? = nil

    private let service = ModerationService()

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()
            mainContent
            if let msg = toast {
                ModSuccessToast(message: msg)
                    .padding(.bottom, Theme.Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toast != nil)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member, guildId: guildId, allRoles: [], onAction: { _ in })
        }
        .overlay {
            if showUnbanConfirm, let t = unbanTarget {
                ConfirmModal(
                    icon: "hand.raised.slash",
                    iconColor: Theme.Color.statusBad,
                    title: "BANを解除しますか？",
                    message: "「\(t.displayName)」のBANを解除します。このユーザーはサーバーに再参加できるようになります。",
                    primaryLabel: "BAN解除",
                    primaryRole: .destructive,
                    onPrimary: {
                        Task { await performUnban(t) }
                        showUnbanConfirm = false
                        unbanTarget = nil
                    },
                    onCancel: {
                        showUnbanConfirm = false
                        unbanTarget = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch loadState {
        case .loading:
            loadingView("BAN一覧を取得中...")
        case .error(let msg):
            ModErrorView(message: msg) { Task { await load() } }
        case .loaded(let bans):
            if bans.isEmpty {
                ModEmptyView(icon: "checkmark.shield",
                             title: "BANされたユーザーはいません",
                             subtitle: "サーバーは安全に保たれています")
            } else {
                banList(bans, onSelect: { ban in selectedMember = memberFromBan(ban) })
            }
        }
    }

    private func banList(_ bans: [BannedUser], onSelect: @escaping (BannedUser) -> Void) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                SectionLabel(title: "BANリスト")
                    .padding(.horizontal, Theme.Spacing.md)

                VStack(spacing: 0) {
                    ForEach(Array(bans.enumerated()), id: \.element.id) { idx, ban in
                        BanRow(
                            ban: ban,
                            onUnban: {
                                unbanTarget = ban
                                showUnbanConfirm = true
                            },
                            onSelectUser: { onSelect(ban) }
                        )
                        if idx < bans.count - 1 {
                            Divider()
                                .background(Theme.Color.line)
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .padding(.horizontal, Theme.Spacing.md)

                bottomPad
            }
            .padding(.top, Theme.Spacing.md)
        }
    }

    private func memberFromBan(_ ban: BannedUser) -> Member {
        Member(id: ban.id, guildId: guildId, username: ban.username,
               displayName: ban.displayName, discriminator: "0", globalName: nil,
               nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil,
               publicFlags: 0, isBot: false, roles: [],
               joinedAt: ban.bannedAt ?? .distantPast,
               createdAt: .distantPast, isBoosting: false, boostSince: nil,
               isDeaf: false, isMute: false, flags: 0,
               communicationDisabledUntil: nil, status: .offline)
    }

    private func performUnban(_ ban: BannedUser) async {
        isWorking = true
        do {
            try await service.unban(userId: ban.id, guildId: guildId)
            if case .loaded(var list) = loadState {
                list.removeAll { $0.id == ban.id }
                loadState = .loaded(list)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast("\(ban.displayName) のBANを解除しました")
        } catch {
            showToast("BAN解除に失敗しました")
        }
        isWorking = false
    }

    private func load() async {
        loadState = .loading
        do {
            loadState = .loaded(try await service.fetchBans(guildId: guildId))
        } catch {
            loadState = .error("BAN一覧の取得に失敗しました。\nネットワーク接続を確認してください。")
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

// MARK: - BanRow

private struct BanRow: View {
    let ban: BannedUser
    let onUnban: () -> Void
    let onSelectUser: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onSelectUser) {
                Avatar(name: ban.displayName, size: 44, accentColor: Theme.Color.statusBad)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Button(action: onSelectUser) {
                    Text(ban.displayName)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.textPrimary)
                }
                .buttonStyle(.plain)
                Text("@\(ban.username)")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                if let reason = ban.reason, !reason.isEmpty {
                    Label(reason, systemImage: "text.bubble")
                        .font(Theme.Font.caption2)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onUnban) {
                Text("BAN解除")
                    .font(Theme.Font.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.Color.accentDim)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

// MARK: - Shared helpers

func loadingView(_ label: String) -> some View {
    VStack {
        Spacer()
        ProgressView(label)
            .tint(Theme.Color.accent)
            .foregroundStyle(Theme.Color.textSecondary)
        Spacer()
    }
    .frame(maxWidth: .infinity)
}

func sectionHeader(icon: String, color: Color, title: String, note: String? = nil) -> some View {
    HStack(spacing: Theme.Spacing.xs) {
        Image(systemName: icon)
            .font(Theme.Font.caption2)
            .foregroundStyle(color)
        Text(title)
            .font(Theme.Font.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.Color.textSecondary)
        Spacer()
        if let note {
            Text(note)
                .font(Theme.Font.caption2)
                .foregroundStyle(Theme.Color.textTertiary)
        }
    }
}

var bottomPad: some View { Color.clear.frame(height: 32) }
