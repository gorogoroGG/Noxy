import SwiftUI

struct ModBanListView: View {
    let guildId: String

    @State private var loadState: LoadState<[BannedUser]> = .loading
    @State private var unbanTarget: BannedUser? = nil
    @State private var isWorking = false
    @State private var toast: String? = nil
    @State private var selectedMember: Member? = nil

    private let service = ModerationService()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()
            mainContent
            if let msg = toast {
                ModSuccessToast(message: msg)
                    .padding(.bottom, .spacing32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toast != nil)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member, guildId: guildId, allRoles: [], onAction: { _ in })
        }
        .alert("BANを解除しますか？", isPresented: Binding(
            get: { unbanTarget != nil },
            set: { if !$0 { unbanTarget = nil } }
        )) {
            Button("BAN解除", role: .destructive) {
                if let t = unbanTarget { Task { await performUnban(t) } }
            }
            Button("キャンセル", role: .cancel) { unbanTarget = nil }
        } message: {
            if let t = unbanTarget {
                Text("「\(t.displayName)」のBANを解除します。\nこのユーザーはサーバーに再参加できるようになります。")
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
                ModEmptyView(icon: "checkmark.shield.fill",
                             title: "BANされたユーザーはいません",
                             subtitle: "サーバーは安全に保たれています")
            } else {
                banList(bans, onSelect: { ban in selectedMember = memberFromBan(ban) })
            }
        }
    }

    private func banList(_ bans: [BannedUser], onSelect: @escaping (BannedUser) -> Void) -> some View {
        ScrollView {
            LazyVStack(spacing: .spacing8) {
                sectionHeader(
                    icon: "hand.raised.slash.fill",
                    color: .accentRed,
                    title: "\(bans.count)人がBANされています",
                    note: "名前をタップで詳細"
                )
                ForEach(bans) { ban in
                    BanCard(ban: ban, onUnban: { unbanTarget = ban }, onSelectUser: { onSelect(ban) })
                }
                bottomPad
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing12)
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
        unbanTarget = nil
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

// MARK: - BanCard

private struct BanCard: View {
    let ban: BannedUser
    let onUnban: () -> Void
    let onSelectUser: () -> Void

    var body: some View {
        HStack(spacing: .spacing12) {
            Button(action: onSelectUser) {
                Avatar(name: ban.displayName, size: 44, accentColor: .accentRed)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Button(action: onSelectUser) {
                    Text(ban.displayName)
                        .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                }
                .buttonStyle(.plain)
                Text("@\(ban.username)")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                if let reason = ban.reason, !reason.isEmpty {
                    Label(reason, systemImage: "text.bubble")
                        .font(.captionSmall).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
            }

            Spacer()

            Button("BAN解除", action: onUnban)
                .font(.captionRegular).fontWeight(.semibold)
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.accentGreen.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.accentGreen.opacity(0.3), lineWidth: 1))
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(RoundedRectangle(cornerRadius: .cornerRadiusMedium).stroke(Color.border, lineWidth: 1))
    }
}

// MARK: - Shared helpers（同ファイル内で使う）

func loadingView(_ label: String) -> some View {
    VStack {
        Spacer()
        ProgressView(label)
            .tint(Color.accentIndigo)
            .foregroundStyle(Color.textSecondary)
        Spacer()
    }
    .frame(maxWidth: .infinity)
}

func sectionHeader(icon: String, color: Color, title: String, note: String? = nil) -> some View {
    HStack(spacing: .spacing8) {
        Image(systemName: icon).font(.captionSmall).foregroundStyle(color)
        Text(title).font(.captionRegular).fontWeight(.semibold).foregroundStyle(Color.textSecondary)
        Spacer()
        if let note {
            Text(note).font(.captionSmall).foregroundStyle(Color.textTertiary)
        }
    }
}

var bottomPad: some View { Color.clear.frame(height: 32) }
