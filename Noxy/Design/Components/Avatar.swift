import SwiftUI

enum OnlineStatus {
    case online, idle, dnd, offline

    var color: Color {
        switch self {
        case .online:  .accentGreen
        case .idle:    .accentOrange
        case .dnd:     .accentPink
        case .offline: .gray
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
            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure, .empty:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }

            if let status {
                Circle()
                    .fill(status.color)
                    .frame(width: indicatorSize, height: indicatorSize)
                    .overlay(Circle().strokeBorder(Color.bgPrimary, lineWidth: 2))
            }
        }
    }

    private var fallbackAvatar: some View {
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
                    .font(.system(size: size * 0.32))
                    .bold()
                    .foregroundStyle(.white)
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
}
