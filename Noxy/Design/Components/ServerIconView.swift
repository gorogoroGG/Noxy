import SwiftUI

struct ServerIconView: View {
    var imageUrl: String? = nil
    var name: String = ""
    var gradientColors: [Color] = [.accentIndigo, .accentPurple]
    var size: CGFloat = 40

    private var cornerRadius: CGFloat {
        switch size {
        case ..<32: .cornerRadiusSmall
        case ..<56: .cornerRadiusMedium
        default:    .cornerRadiusLarge
        }
    }

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Group {
            if let urlString = imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var fallbackView: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Text(initials)
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    HStack(spacing: .spacing16) {
        ServerIconView(name: "Valorant JP", size: 24)
        ServerIconView(name: "星宮ルナ", gradientColors: [.accentPink, .accentPurple], size: 40)
        ServerIconView(name: "DevHub Support", gradientColors: [.accentGreen, .accentIndigo], size: 56)
        ServerIconView(name: "Premium Shop", gradientColors: [.accentOrange, .accentPink], size: 80)
    }
    .padding()
    .background(Color.bgPrimary)
}
