import SwiftUI

struct ModTimeoutView: View {
    @State private var members: [TimedOutMember] = TimedOutMember.mock
    @State private var untimeoutTarget: TimedOutMember? = nil
    @State private var showSuccess: String? = nil

    // 残り時間を更新するタイマー
    @State private var tick = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            if members.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: .spacing8) {
                        countHeader
                        ForEach(members) { member in
                            TimeoutRow(member: member, tick: tick) {
                                untimeoutTarget = member
                            }
                        }
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, .spacing16)
                    .padding(.top, .spacing12)
                }
            }

            if let msg = showSuccess {
                successToast(msg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("タイムアウトを解除しますか？", isPresented: Binding(
            get: { untimeoutTarget != nil },
            set: { if !$0 { untimeoutTarget = nil } }
        )) {
            Button("解除", role: .destructive) {
                if let t = untimeoutTarget { removeTimeout(t) }
            }
            Button("キャンセル", role: .cancel) { untimeoutTarget = nil }
        } message: {
            Text("「\(untimeoutTarget?.displayName ?? "")」のタイムアウトを即時解除します。")
        }
        // 毎秒残り時間を更新
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                tick.toggle()
                // 期限切れを除去
                withAnimation { members.removeAll { $0.isExpired } }
            }
        }
    }

    // MARK: - Sub Views

    private var countHeader: some View {
        HStack {
            Text("\(members.count)人がタイムアウト中")
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: .spacing16) {
            Image(systemName: "timer")
                .font(.system(size: 48)).foregroundStyle(Color.accentGreen.opacity(0.6))
            Text("タイムアウト中のメンバーはいません")
                .font(.titleMedium).foregroundStyle(Color.textPrimary)
        }
    }

    private func successToast(_ msg: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: .spacing8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                Text(msg).font(.bodySmall).fontWeight(.semibold).foregroundStyle(.white)
            }
            .padding(.horizontal, .spacing16)
            .frame(height: 48)
            .background(Color.accentGreen)
            .clipShape(Capsule())
            .shadow(radius: 8)
            .padding(.bottom, .spacing32)
        }
    }

    // MARK: - Action

    private func removeTimeout(_ member: TimedOutMember) {
        // 実際のAPI: PATCH /bot/members/{userId}/untimeout
        withAnimation { members.removeAll { $0.id == member.id } }
        let msg = "\(member.displayName) のタイムアウトを解除しました"
        withAnimation(.spring()) { showSuccess = msg }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { withAnimation { showSuccess = nil } }
        }
        untimeoutTarget = nil
    }
}

// MARK: - TimeoutRow

private struct TimeoutRow: View {
    let member: TimedOutMember
    let tick: Bool  // triggers re-render every second
    let onUntimeout: () -> Void

    var body: some View {
        HStack(spacing: .spacing12) {
            // Severity ring avatar
            ZStack {
                Circle()
                    .stroke(member.severityColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(member.severityColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 50, height: 50)
                    .animation(.linear(duration: 1), value: tick)
                Text(member.displayName.prefix(1).uppercased())
                    .font(.titleMedium).foregroundStyle(Color.textPrimary)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(member.displayName)
                    .font(.bodySmall).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                Text("@\(member.username)")
                    .font(.captionSmall).foregroundStyle(Color.textTertiary)
                if let reason = member.reason {
                    Text("理由: \(reason)")
                        .font(.captionSmall).foregroundStyle(Color.textSecondary)
                }
                HStack(spacing: 4) {
                    Text("実行者: \(member.mutedByName)")
                    Text("·")
                    // 残り時間（毎秒更新）
                    Text("残り \(member.remainingLabel)")
                        .foregroundStyle(member.severityColor)
                        .fontWeight(.semibold)
                        .id(tick) // force re-render
                }
                .font(.captionSmall).foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Button("解除", action: onUntimeout)
                .font(.captionRegular).fontWeight(.semibold)
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, .spacing10).padding(.vertical, 5)
                .background(Color.accentGreen.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.spacing12)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(member.severityColor.opacity(0.3), lineWidth: 1)
        )
    }

    // 最大タイムアウトを7日として進捗を計算
    private var progress: CGFloat {
        let maxDuration: TimeInterval = 7 * 86_400
        let elapsed = maxDuration - member.remaining
        return CGFloat(max(0, min(1, elapsed / maxDuration)))
    }
}
