import SwiftUI

struct ServerSetupApplyView: View {
    let vm: ServerSetupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isDryRun = false
    @State private var applyState: ApplyState = .idle
    @State private var progress: Double = 0

    enum ApplyState { case idle, running, done, error }

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                switch applyState {
                case .idle, .error:
                    idleContent
                case .running:
                    progressContent
                case .done:
                    doneContent
                }
            }
            .navigationTitle(applyState == .done ? "完了！" : "サーバーに適用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if applyState == .idle || applyState == .error {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") { dismiss() }
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Idle

    private var idleContent: some View {
        ScrollView {
            VStack(spacing: .spacing20) {
                // Summary card
                summaryCard

                // Diff preview
                diffPreview

                // Dry run toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ドライラン")
                            .font(.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                        Text("実際には変更せず動作確認のみ行う")
                            .font(.captionRegular)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $isDryRun)
                        .tint(Color.accentOrange)
                        .labelsHidden()
                }
                .padding(.spacing16)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))

                // Warning
                HStack(spacing: .spacing8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.accentOrange)
                    Text("既存のチャンネルは削除されません。新規追加・更新のみ行います。")
                        .font(.captionRegular)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.spacing12)
                .background(Color.accentOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall))

                // Apply button
                Button {
                    startApply()
                } label: {
                    HStack {
                        Image(systemName: isDryRun ? "play.circle" : "arrow.up.circle.fill")
                        Text(isDryRun ? "ドライランを実行" : "サーバーに適用する")
                    }
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isDryRun ? Color.accentOrange : Color.accentIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, .spacing16)
            .padding(.top, .spacing16)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Text(vm.draft.serverName.isEmpty ? "サーバー構成" : vm.draft.serverName)
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)

            Divider()

            HStack(spacing: .spacing24) {
                SummaryStatItem(value: vm.totalCategories, label: "カテゴリ", icon: "folder.fill", color: .accentPurple)
                SummaryStatItem(value: vm.totalChannels, label: "チャンネル", icon: "number", color: .accentIndigo)
                SummaryStatItem(value: vm.totalRoles, label: "ロール", icon: "shield.fill", color: .accentGreen)
            }
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    private var diffPreview: some View {
        VStack(alignment: .leading, spacing: .spacing12) {
            Text("作成される構成")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)

            ForEach(vm.draft.categories) { cat in
                VStack(alignment: .leading, spacing: .spacing4) {
                    // Category
                    HStack(spacing: .spacing6) {
                        Image(systemName: "plus")
                            .font(.captionSmall)
                            .foregroundStyle(Color.accentGreen)
                            .frame(width: 14)
                        Image(systemName: "folder")
                            .font(.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                        Text(cat.name)
                            .font(.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                    }

                    // Channels
                    ForEach(cat.channels) { ch in
                        HStack(spacing: .spacing6) {
                            Color.clear.frame(width: 14)
                            Image(systemName: "plus")
                                .font(.captionSmall)
                                .foregroundStyle(Color.accentGreen)
                                .frame(width: 14)
                            Image(systemName: ch.type.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 12)
                            Text(ch.name)
                                .font(.captionRegular)
                                .foregroundStyle(Color.textSecondary)
                            if ch.isPrivate {
                                Image(systemName: "lock.fill")
                                    .font(.captionSmall)
                                    .foregroundStyle(Color.accentOrange)
                            }
                        }
                    }
                }
            }

            if !vm.draft.roles.isEmpty {
                Divider()
                Text("ロール")
                    .font(.captionSmall)
                    .foregroundStyle(Color.textTertiary)

                ForEach(vm.draft.roles) { role in
                    HStack(spacing: .spacing6) {
                        Image(systemName: "plus")
                            .font(.captionSmall)
                            .foregroundStyle(Color.accentGreen)
                            .frame(width: 14)
                        Circle()
                            .fill(role.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text(role.name)
                            .font(.captionRegular)
                            .foregroundStyle(Color.textSecondary)
                        if role.isAutoAssigned {
                            Text("自動")
                                .font(.captionSmall)
                                .foregroundStyle(Color.accentGreen)
                        }
                    }
                }
            }
        }
        .padding(.spacing16)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
    }

    // MARK: - Progress

    private var progressContent: some View {
        VStack(spacing: .spacing24) {
            Spacer()

            ProgressView(value: progress, total: 1.0)
                .tint(Color.accentIndigo)
                .padding(.horizontal, .spacing32)

            Text(progressLabel)
                .font(.bodySmall)
                .foregroundStyle(Color.textSecondary)

            Spacer()
        }
    }

    private var progressLabel: String {
        switch progress {
        case ..<0.3:  return "カテゴリを作成中..."
        case ..<0.6:  return "チャンネルを作成中..."
        case ..<0.85: return "ロールを設定中..."
        default:       return "仕上げ中..."
        }
    }

    // MARK: - Done

    private var doneContent: some View {
        VStack(spacing: .spacing24) {
            Spacer()

            Image(systemName: isDryRun ? "checkmark.seal" : "checkmark.circle.fill")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Color.accentGreen)

            VStack(spacing: .spacing8) {
                Text(isDryRun ? "ドライラン完了" : "適用完了！")
                    .font(.displayMedium)
                    .foregroundStyle(Color.textPrimary)
                Text(isDryRun
                     ? "実際のサーバーは変更されていません"
                     : "\(vm.draft.serverName) にサーバー構成を適用しました")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: .spacing12) {
                SummaryStatItem(value: vm.totalCategories, label: "カテゴリ", icon: "folder.fill", color: .accentPurple)
                SummaryStatItem(value: vm.totalChannels, label: "チャンネル", icon: "number", color: .accentIndigo)
                SummaryStatItem(value: vm.totalRoles, label: "ロール", icon: "shield.fill", color: .accentGreen)
            }

            Button("閉じる") {
                dismiss()
            }
            .font(.bodyRegular)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.accentIndigo)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusMedium))
            .padding(.horizontal, .spacing32)

            Spacer()
        }
        .padding(.horizontal, .spacing16)
    }

    // MARK: - Apply Logic

    private func startApply() {
        applyState = .running
        progress = 0

        Task {
            let steps: [(Double, TimeInterval)] = [
                (0.28, 0.5), (0.55, 0.5), (0.82, 0.4), (1.0, 0.3)
            ]
            for (target, delay) in steps {
                try? await Task.sleep(for: .seconds(delay))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        progress = target
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                withAnimation {
                    applyState = .done
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

private struct SummaryStatItem: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: .spacing4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 18))
            Text("\(value)")
                .font(.titleMedium)
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.captionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ServerSetupApplyView(vm: ServerSetupViewModel(draft: ServerTemplate.gaming.draft))
}
