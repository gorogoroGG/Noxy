import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.Font.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.textTertiary)
                .tracking(0.8)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.accent)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    VStack(spacing: 0) {
        SectionHeader(title: "Recent Activity")
        SectionHeader(title: "Members", actionTitle: "See All") {}
    }
    .background(Theme.Color.bg)
}
