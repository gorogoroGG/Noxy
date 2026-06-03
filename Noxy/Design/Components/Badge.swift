import SwiftUI

struct Badge: View {
    let text: String
    var color: Color = .accentIndigo
    var style: BadgeStyle = .filled

    enum BadgeStyle { case filled, outlined }

    var body: some View {
        Text(text)
            .font(.captionSmall)
            .bold()
            .tracking(0.4)
            .foregroundStyle(style == .filled ? .white : color)
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
    HStack(spacing: .spacing8) {
        Badge(text: "BOT", color: .accentIndigo)
        Badge(text: "NEW", color: .accentGreen)
        Badge(text: "BETA", color: .accentOrange)
        Badge(text: "PRO", color: .accentPink)
        Badge(text: "ADMIN", color: .accentPurple, style: .outlined)
    }
    .padding()
    .background(Color.bgPrimary)
}
