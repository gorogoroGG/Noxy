import SwiftUI

struct ConfirmModal: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let primaryLabel: String
    let primaryRole: ButtonRole?
    let onPrimary: () -> Void
    let onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { onCancel?() }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .padding(.top, Theme.Spacing.lg)

                VStack(spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Font.title3)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)

                Divider()
                    .background(Theme.Color.line)

                if let cancel = onCancel {
                    HStack(spacing: 0) {
                        Button("キャンセル") { cancel() }
                            .font(Theme.Font.callout)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .contentShape(Rectangle())

                        Divider()
                            .background(Theme.Color.line)
                            .frame(height: 50)

                        Button(primaryLabel, role: primaryRole) { onPrimary() }
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(primaryRole == .destructive ? Theme.Color.statusBad : Theme.Color.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .contentShape(Rectangle())
                    }
                } else {
                    Button(primaryLabel) { onPrimary() }
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Color.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .contentShape(Rectangle())
                }
            }
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Color.lineStrong, lineWidth: 1)
            )
            .padding(.horizontal, Theme.Spacing.xxl)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}

#Preview("破壊的操作") {
    ConfirmModal(
        icon: "trash.fill",
        iconColor: Theme.Color.statusBad,
        title: "Botを削除しますか？",
        message: "この操作は元に戻せません。",
        primaryLabel: "削除する",
        primaryRole: .destructive,
        onPrimary: {},
        onCancel: {}
    )
}

#Preview("確認") {
    ConfirmModal(
        icon: "arrow.clockwise.circle.fill",
        iconColor: Theme.Color.accent,
        title: "Botを再起動しますか？",
        message: "実行中のタスクが中断される場合があります。",
        primaryLabel: "再起動する",
        primaryRole: nil,
        onPrimary: {},
        onCancel: {}
    )
}
