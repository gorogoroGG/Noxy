import SwiftUI

struct AccentButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Color.accentInk)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Color.accent)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.Color.accent, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        AccentButton(title: "実行する", action: {})
        GhostButton(title: "キャンセル", action: {})
    }
    .padding()
}
