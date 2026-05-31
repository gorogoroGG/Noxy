import SwiftUI

enum OnlineStatus {
    case online, idle, dnd, offline

    var color: Color {
        switch self {
        case .online:  .accentGreen
        case .idle:    .accentOrange
        case .dnd:     .accentPink
        case .offline: Color(uiColor: .systemGray)
        }
    }
}

struct Avatar: View {
    var imageUrl: String? = nil
    var name: String = ""
    var size: CGFloat = 40
    var status: OnlineStatus? = nil
    var accentColor: Color = .accentIndigo

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var indicatorSize: CGFloat { size * 0.28 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    Text(initials)
                        .font(.system(size: size * 0.32, weight: .bold))
                        .foregroundStyle(.white)
                }

            if let status {
                Circle()
                    .fill(status.color)
                    .frame(width: indicatorSize, height: indicatorSize)
                    .overlay(Circle().strokeBorder(Color.bgPrimary, lineWidth: 2))
            }
        }
    }
}

#Preview {
    HStack(spacing: .spacing16) {
        Avatar(name: "Luna", size: 32, status: .online)
        Avatar(name: "田中太郎", size: 40, status: .idle, accentColor: .accentPink)
        Avatar(name: "DevBot", size: 56, status: .dnd, accentColor: .accentPurple)
        Avatar(name: "YK", size: 40, status: .offline, accentColor: .accentOrange)
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
