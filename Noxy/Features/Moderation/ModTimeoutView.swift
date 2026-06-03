import SwiftUI

struct ModTimeoutView: View {
    let guildId: String

    @State private var loadState: LoadState<[TimedOutMember]> = .loading
    @State private var untimeoutTarget: TimedOutMember? = nil
    @State private var toast: String? = nil
    @State private var tick = false

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
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in tick.toggle() }
        }
        .alert("タイムアウトを解除しますか？", isPresented: Binding(
            get: { untimeoutTarget != nil },
            set: { if !$0 { untimeoutTarget = nil } }
        )) {
            Button("即時解除", role: .destructive) {
                if let t = untimeoutTarget { Task { await performRemove(t) } }
            }
            Button("キャンセル", role: .cancel) { untimeoutTarget = nil }
        } message: {
            if let t = untimeoutTarget {
                Text("「\(t.displayName)」のタイムアウトを即時解除します。")
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
            LazyVStack(spacing: .spacing8) {
                sectionHeader(
                    icon: "timer",
                    color: .accentPurple,
                    title: "\(members.count)人がタイムアウト中",
                    note: "タップして即時解除"
                )
                ForEach(members) { member in
                    TimeoutCard(member: member, tick: tick) {
                        untimeoutTarget = member
                    }
                }
                bottomPad
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing12)
        }
    }

    private func performRemove(_ member: TimedOutMember) async {
        untimeoutTarget = nil
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

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

// MARK: - TimeoutCard

private struct TimeoutCard: View {
    let member: TimedOutMember
    let tick: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: .spacing12) {
            // 残り時間リング
            ZStack {
                Circle().stroke(member.severityColor.opacity(0.15), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(member.severityColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: tick)
                Text(String(member.displayName.prefix(1)).uppercased())
                    .font(.bodySmall).fontWeight(.bold).foregroundStyle(Color.textPrimary)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(member.displayName)
                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                Text("@\(member.username)")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 10))
                    Text("残り \(member.remainingLabel)").fontWeight(.semibold)
                }
                .font(.captionSmall)
                .foregroundStyle(member.severityColor)
                .id(tick)
            }

            Spacer()

            Button("解除", action: onRemove)
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
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(member.severityColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var ringProgress: CGFloat {
        let maxSec: TimeInterval = 7 * 86_400
        return CGFloat(max(0, min(1, (maxSec - member.remaining) / maxSec)))
    }
}
