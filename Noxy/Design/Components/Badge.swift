import SwiftUI

struct Badge: View {
    let text: String
    var color: Color = Theme.Color.accent
    var style: BadgeStyle = .filled

    enum BadgeStyle { case filled, outlined }

    var body: some View {
        Text(text)
            .font(Theme.Font.caption2)
            .bold()
            .tracking(0.4)
            .foregroundStyle(style == .filled ? Theme.Color.accentInk : color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Group {
                    if style == .filled {
                        RoundedRectangle(cornerRadius: 4).fill(color)
                    } else {
                        RoundedRectangle(cornerRadius: 4).strokeBorder(color, lineWidth: 1)
                    }
                }
            )
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.xs) {
        Badge(text: "BOT", color: Theme.Color.accent)
        Badge(text: "NEW", color: Theme.Color.statusOK)
        Badge(text: "BETA", color: Theme.Color.statusWarn)
        Badge(text: "PRO", color: Theme.Color.statusBad)
        Badge(text: "ADMIN", color: Theme.Color.accent, style: .outlined)
    }
    .padding()
    .background(Theme.Color.bg)
}
