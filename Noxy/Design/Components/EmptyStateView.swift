import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var description: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.Color.textTertiary)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Font.title3)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .multilineTextAlignment(.center)

                if let description {
                    Text(description)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle, let action {
                PrimaryButton(actionTitle, style: .filled, size: .medium, action: action)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack {
        EmptyStateView(
            icon: "rectangle.stack.badge.plus",
            title: "No embeds yet",
            description: "Create your first embed to get started.",
            actionTitle: "Create Embed"
        ) {}

        EmptyStateView(
            icon: "checkmark.circle",
            title: "All caught up!",
            description: "No new notifications."
        )
    }
    .background(Color.bgPrimary)
}
