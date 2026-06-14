import SwiftUI

struct ModTimeoutView: View {
    let guildId: String

    @State private var loadState: LoadState<[TimedOutMember]> = .loading
    @State private var untimeoutTarget: TimedOutMember? = nil
    @State private var showUntimeoutConfirm = false
    @State private var toast: String? = nil
    @State private var tick = false
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
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in tick.toggle() }
        }
        .overlay {
            if showUntimeoutConfirm, let t = untimeoutTarget {
                ConfirmModal(
                    icon: "timer",
                    iconColor: Theme.Color.statusWarn,
                    title: "タイムアウトを解除しますか？",
                    message: "「\(t.displayName)」のタイムアウトを即時解除します。",
                    primaryLabel: "即時解除",
                    primaryRole: .destructive,
                    onPrimary: {
                        Task { await performRemove(t) }
                        showUntimeoutConfirm = false
                        untimeoutTarget = nil
                    },
                    onCancel: {
                        showUntimeoutConfirm = false
                        untimeoutTarget = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch loadState {
        case .loading:
            loadingView("タイムアウト中のメンバーを取得中...")
        case .error(let msg):
            ModErrorView(message: msg) { Task { await load() } }
        case .loaded(let members):
            if members.isEmpty {
                ModEmptyView(icon: "timer",
                             title: "タイムアウト中のメンバーはいません")
            } else {
                timeoutList(members)
            }
        }
    }

    private func timeoutList(_ members: [TimedOutMember]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                SectionLabel(title: "タイムアウト")
                    .padding(.horizontal, Theme.Spacing.md)

                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { idx, member in
                        TimeoutRow(
                            member: member,
                            tick: tick,
                            onRemove: {
                                untimeoutTarget = member
                                showUntimeoutConfirm = true
                            },
                            onSelectUser: {
                                selectedMember = memberFromTimeout(member)
                            }
                        )
                        if idx < members.count - 1 {
                            Divider()
                                .background(Theme.Color.line)
                                .padding(.leading, 64)
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

    private func performRemove(_ member: TimedOutMember) async {
        do {
            try await service.removeTimeout(userId: member.id, guildId: guildId)
            if case .loaded(var list) = loadState {
                list.removeAll { $0.id == member.id }
                loadState = .loaded(list)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast("\(member.displayName) のタイムアウトを解除しました")
        } catch {
            showToast("タイムアウト解除に失敗しました")
        }
    }

    private func load() async {
        loadState = .loading
        do {
            loadState = .loaded(try await service.fetchTimeouts(guildId: guildId))
        } catch {
            loadState = .error("タイムアウト一覧の取得に失敗しました。\nBotのSERVER MEMBERS INTENTが有効か確認してください。")
        }
    }

    private func memberFromTimeout(_ t: TimedOutMember) -> Member {
        Member(id: t.id, guildId: guildId, username: t.username,
               displayName: t.displayName, discriminator: "0", globalName: nil,
               nick: nil, avatarUrl: nil, bannerUrl: nil, accentColor: nil,
               publicFlags: 0, isBot: false, roles: [],
               joinedAt: .distantPast, createdAt: .distantPast,
               isBoosting: false, boostSince: nil, isDeaf: false, isMute: false,
               flags: 0, communicationDisabledUntil: t.timeoutUntil, status: .offline)
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

// MARK: - TimeoutRow

private struct TimeoutRow: View {
    let member: TimedOutMember
    let tick: Bool
    let onRemove: () -> Void
    let onSelectUser: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onSelectUser) {
                ZStack {
                    Circle()
                        .stroke(member.severityColor.opacity(0.15), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(member.severityColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: tick)
                    Avatar(name: member.displayName, size: 38, accentColor: member.severityColor)
                }
                .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Button(action: onSelectUser) {
                    Text(member.displayName)
                        .font(Theme.Font.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Color.textPrimary)
                }
                .buttonStyle(.plain)
                Text("@\(member.username)")
                    .font(Theme.Font.caption2)
                    .foregroundStyle(Theme.Color.textTertiary)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("残り \(member.remainingLabel)")
                        .fontWeight(.semibold)
                }
                .font(Theme.Font.caption2)
                .monospaced()
                .foregroundStyle(member.severityColor)
                .id(tick)
            }

            Spacer()

            Button(action: onRemove) {
                Text("解除")
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

    private var ringProgress: CGFloat {
        let maxSec: TimeInterval = 7 * 86_400
        return CGFloat(max(0, min(1, (maxSec - member.remaining) / maxSec)))
    }
}
